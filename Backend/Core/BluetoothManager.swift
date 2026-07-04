//
//  BluetoothManager.swift
//  PIDHunter by Ahmed AlQady
//
//
import Foundation
import CoreBluetooth
import SwiftUI
@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    // MARK: Published
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var lastResponse = ""
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var detectedTX = ""
    @Published var detectedRX = ""
    @Published var detectedService = ""
    @Published var status: ECUStatus = .disconnected
    @Published var txCount = 0
    @Published var rxCount = 0

    // MARK: BLE
    private var central: CBCentralManager!
    private var elmPeripheral: CBPeripheral?
    private(set) var writeCharacteristic: CBCharacteristic?
    private(set) var notifyCharacteristic: CBCharacteristic?
    private var elmInitialized = false
    private var retriedProtocol = false
    private var lastSendTime = Date()
    //=====================================================
    // MARK: Send and Wait
    private struct PendingRequest {
        let id: UUID
        let continuation: CheckedContinuation<(response: ELMResponse, latency: TimeInterval), Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var pendingRequest: PendingRequest?

    private func clearPendingRequest(resumingWith error: Error? = nil) {
        guard let pending = pendingRequest else {
            return
        }

        pending.timeoutTask?.cancel()
        pendingRequest = nil

        if let error {
            pending.continuation.resume(throwing: error)
        }
    }
    
    enum BluetoothError: Error {
        case busy
        case timeout
        case disconnected
    }
    
    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: nil
        )
    }
    
    @MainActor
    func reconnect() async {
        disconnect()

        try? await Task.sleep(for: .milliseconds(500))

        startScan()

        let deadline = Date().addingTimeInterval(5)
        while !isConnected && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        if !isConnected {
            Logger.shared.error("Reconnect timed out")
            stopScan()
        }
    }
    
    // MARK: Scan
        func startScan() {
            ELMResponseAssembler.shared.clear()
            txCount = 0
            rxCount = 0
            status = .scanningBLE
            
            guard central.state == .poweredOn else { return }
            
            isConnected = false
            lastResponse = ""
            detectedTX = ""
            detectedRX = ""
            detectedService = ""
            
            elmPeripheral = nil
            writeCharacteristic = nil
            notifyCharacteristic = nil
            elmInitialized = false
            
            discoveredDevices.removeAll()
            isScanning = true
            
            central.scanForPeripherals(
                withServices: nil,
                options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: false
                ]
            )
            
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))

                guard let self else { return }

                if self.isScanning {
                    self.status = .timeout
                    self.stopScan()
                    Logger.shared.warning("Scan timed out")
                }
            }
        Logger.shared.console("Scanning...")
        Logger.shared.info("Scanning...")
    }
    func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
    }
    // MARK: Connection
    func connect(
        to peripheral: CBPeripheral
    ) {
        elmPeripheral = peripheral
        peripheral.delegate = self
        central.connect(
            peripheral,
            options: nil
        )
    }
    func disconnect() {
        stopScan()
        guard let peripheral = elmPeripheral else {
            return
        }
        central.cancelPeripheralConnection(
            peripheral
        )
        status = .disconnected
        ELMResponseAssembler.shared.clear()
        ECUInfo.shared.clear()

        clearPendingRequest(resumingWith: BluetoothError.disconnected)
    }
    // MARK: TX - SEND
    func send(
        _ command: String
    ) throws {
        guard isConnected else {
            Logger.shared.error("Not connected")
            throw BluetoothError.disconnected
        }
        guard
            let peripheral = elmPeripheral,
            let tx = writeCharacteristic
        else {
            Logger.shared.error("TX characteristic unavailable")
            throw BluetoothError.disconnected
        }
        let payload = command + "\r"
        guard
            let data = payload.data(using: .utf8)
        else {
            throw BluetoothError.disconnected
        }
        Logger.shared.console("TX UUID = \(tx.uuid.uuidString)")
        Logger.shared.console("TX Props = \(tx.properties)")
        Logger.shared.console(">> \(command)")
        Logger.shared.tx(command)
        Logger.shared.debug("TX UUID = \(tx.uuid.uuidString)")
        Logger.shared.debug("TX Props = \(tx.properties)")
        lastSendTime = Date()
        let type: CBCharacteristicWriteType =
        tx.properties.contains(.write)
        ? .withResponse
        : .withoutResponse
        
        let hex = data.map {
            String(format: "%02X", $0)
        }.joined(separator: " ")
        
        Logger.shared.debug("TX HEX = \(hex)")
        
        status = .waitingResponse
        peripheral.writeValue(
            data,
            for: tx,
            type: type
        )
        txCount += 1
//        if !command.uppercased().hasPrefix("AT") {
//            ScanStatistics.shared.requestsSent += 1
//        }
    }
    
    // MARK: Send & Wait
    
    func sendAndWait(
        _ command: String,
        timeout: Duration = .seconds(1)
    ) async throws -> (response: ELMResponse, latency: TimeInterval) {
        guard pendingRequest == nil else {
            throw BluetoothError.busy
        }

        return try await withCheckedThrowingContinuation { continuation in
            Logger.shared.debug("📌 Registering continuation")
            let requestID = UUID()
            // Assign pendingRequest BEFORE sending command, with timeoutTask nil
            pendingRequest = PendingRequest(
                id: requestID,
                continuation: continuation,
                timeoutTask: nil
            )
            // Now create the real timeout task
            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self else { return }
                guard let pending = self.pendingRequest,
                      pending.id == requestID else {
                    return
                }
                self.clearPendingRequest(resumingWith: BluetoothError.timeout)
            }
            // Update the timeoutTask in the pending request
            pendingRequest?.timeoutTask = timeoutTask
            do {
                try send(command)
                Logger.shared.debug("📤 Command sent successfully")
            } catch {
                timeoutTask.cancel()
                clearPendingRequest()
                continuation.resume(throwing: error)
                return
            }
        }
    }
    @inline(__always)
    private func ensureConnected() -> Bool {
        guard isConnected else {
            status = .disconnected
            return false
        }
        return true
    }

    @discardableResult
    private func runInitializationCommand(
        _ command: String,
        timeout: Duration = .seconds(2)
    ) async -> Bool {
        do {
            _ = try await sendAndWait(command, timeout: timeout)
            return ensureConnected()
        } catch {
            Logger.shared.error("Initialization command failed: \(command): \(error)")
            return false
        }
    }

    @MainActor
    private func initializeELM() async {
        status = .initializingELM

        try? send("ATZ")
        try? await Task.sleep(for: .milliseconds(1500))
        guard isConnected else {
            status = .disconnected
            return
        }

        guard await runInitializationCommand("ATE0") else { return }
        guard await runInitializationCommand("ATL0") else { return }
        guard await runInitializationCommand("ATS0") else { return }
        guard await runInitializationCommand("ATH1") else { return }
        ECUInfo.shared.header = ELM327.shared.currentHeader

        status = .settingProtocol
        guard await runInitializationCommand("ATSP5") else { return }

        status = .checkingProtocol
        guard await runInitializationCommand("ATDP") else { return }
        guard await runInitializationCommand("ATI") else { return }

        status = .testingECU
        do {
            let result = try await sendAndWait("0100", timeout: .seconds(2))
            Logger.shared.success("ECU Test Response: \(result.response.raw)")
        } catch {
            Logger.shared.error("ECU test failed: \(error)")
            return
        }

        Logger.shared.success("ELM initialization finished")

        guard ensureConnected() else { return }
        status = .connected

        ECUInfo.shared.status = "Connected"
        ECUInfo.shared.lastConnected = Date()
    }
}
// ======================================================
// MARK: CBCentralManagerDelegate
// ======================================================
extension BluetoothManager:
    CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                Logger.shared.console("Bluetooth Ready")
                Logger.shared.success("Bluetooth Ready")
            case .poweredOff:
                Logger.shared.console("Bluetooth Off")
                Logger.shared.error("Bluetooth Off")
            case .resetting:
                Logger.shared.console("Bluetooth Resetting")
                Logger.shared.warning("Bluetooth Restarting")
            case .unsupported:
                Logger.shared.console("Bluetooth Unsupported")
                Logger.shared.error("Bluetooth Unsupported")
            case .unauthorized:
                Logger.shared.console("Bluetooth Unauthorized")
                Logger.shared.error("Bluetooth Unauthorized")
            default:
                Logger.shared.console("Bluetooth Unknown")
                Logger.shared.warning("Bluetooth Unknown")
            }
        }
    }
    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            if !discoveredDevices.contains(
                where: {
                    $0.identifier ==
                    peripheral.identifier
                }
            ) {
                discoveredDevices.append(
                    peripheral
                )
                if let name = peripheral.name, !name.isEmpty {
                    Logger.shared.console("Found: \(name)")
                }
                if let name = peripheral.name?.lowercased() {
                    Logger.shared.success("Found: \(name)")
                    
                    if elmPeripheral == nil &&
                        (name.contains("elm") || name.contains("obd")) {
                        
                        Logger.shared.console("🚀 Auto connecting to \(name)")
                        stopScan()
                        status = .connecting
                        connect(to: peripheral)
                    }
                }
            }
        }
    }
    nonisolated func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        Task { @MainActor in
            Logger.shared.console("Connected to \(peripheral.name ?? "Unknown")")
            Logger.shared.success("Connected to \(peripheral.name ?? "Unknown")")
            stopScan()
            peripheral.discoverServices(nil)
        }
    }
    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    )
    {
        Task { @MainActor in
            ELMResponseAssembler.shared.clear()
            status = .disconnected
            self.isConnected = false
            self.writeCharacteristic = nil
            self.notifyCharacteristic = nil

            self.elmInitialized = false
            self.elmPeripheral = nil
            self.lastResponse = ""
            self.detectedTX = ""
            self.detectedRX = ""
            self.detectedService = ""

            txCount = 0
            rxCount = 0

            self.discoveredDevices.removeAll()

            self.stopScan()
            ECUInfo.shared.clear()

            Logger.shared.console("Disconnected")
            if let error {
                Logger.shared.error("Disconnected: \(error.localizedDescription)")
            } else {
                Logger.shared.error("Disconnected")
            }

            clearPendingRequest(resumingWith: BluetoothError.disconnected)
        }
    }
}
// ======================================================
// MARK: CBPeripheralDelegate
// ======================================================
extension BluetoothManager:
    CBPeripheralDelegate {
    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        Task { @MainActor in
            guard
                error == nil,
                let services = peripheral.services
            else {
                return
            }
            for service in services {
                Logger.shared.console("===== SERVICE =====")
                Logger.shared.console(service.uuid.uuidString)
                Logger.shared.success("===== SERVICE =====")
                Logger.shared.success(service.uuid.uuidString)
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task{@MainActor in
            guard
                error == nil,
                let chars =
                    service.characteristics
            else {
                return
            }
            guard service.uuid.uuidString.uppercased() == "FFF0" else {
                return
            }
            guard writeCharacteristic == nil &&
                  notifyCharacteristic == nil else {
                return
            }
            for c in chars {
                Logger.shared.console("SERVICE : \(service.uuid.uuidString)")
                Logger.shared.console("CHAR    : \(c.uuid.uuidString)")
                Logger.shared.console("PROPS   : \(c.properties)")
                
                Logger.shared.debug("SERVICE: \(service.uuid.uuidString)")
                Logger.shared.debug("CHAR: \(c.uuid.uuidString)")
                Logger.shared.debug("PROPS: \(c.properties)")
                
                // RX
                if c.uuid.uuidString.uppercased() == "FFF1" {
                    notifyCharacteristic = c
                    detectedRX = c.uuid.uuidString
                    peripheral.setNotifyValue(true, for: c)
                }
                
                // TX
                if c.uuid.uuidString.uppercased() == "FFF2" {
                    writeCharacteristic = c
                    detectedService = service.uuid.uuidString
                    detectedTX = c.uuid.uuidString
                }
            }
        }
    }
    
    // MARK: - Response Analysis

    private func handleBusError() {
        Logger.shared.error("🔥 BUS ERROR")
        ScanStatistics.shared.busErrors += 1

        Task {
            guard self.isConnected else {
                return
            }

            Logger.shared.warning("Retrying...")

            if !retriedProtocol {
                retriedProtocol = true
                try? self.send("ATZ")
                try? await Task.sleep(for: .milliseconds(1500))

                guard self.isConnected else {
                    return
                }

                try? self.send("ATSP5")
            }
        }
    }

    private func analyzeResponse(_ response: ELMResponse) {
        switch response.type {

        case .mode01, .mode21, .mode22:
            retriedProtocol = false
            status = response.type.status
            Logger.shared.success("🎉 \(response.type.displayName) Supported")
            ECUInfo.shared.addService(response.service)
            ScanStatistics.shared.positiveResponses += 1

        case .negative:
            ScanStatistics.shared.negativeResponses += 1
            Logger.shared.warning("Negative Response")
            
        case .noData:
            Logger.shared.error("❌ NO DATA")
            ScanStatistics.shared.noData += 1

        case .busError:
            handleBusError()

        case .unableToConnect:
            status = .unableToConnect
            Logger.shared.error("💀 UNABLE TO CONNECT")

        case .searching:
            status = .searching

        default:
            break
        }
    }
    
    
    // MARK: - didUpdateValueFor helpers
    private static let ecuFramePrefixes: Set<String> = ["41", "61", "62", "7F"]

    private func updateECUInfo(from response: ELMResponse) {
        let upper = response.raw.uppercased()

        if upper.hasPrefix("ELM") {
            ECUInfo.shared.elmVersion = response.raw
        }

        if upper.contains("ISO") ||
            upper.contains("KWP") ||
            upper.contains("CAN") ||
            upper.contains("J1850") {
            ECUInfo.shared.protocolName = response.raw
        }
    }

    private func logResponse(_ raw: String) {
        Logger.shared.rx(raw)

        let hex = Array(raw.utf8)
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")

        Logger.shared.console("<< TEXT: \(raw)")
        Logger.shared.console("<< HEX : \(hex)")
        Logger.shared.debug("RX HEX = \(hex)")
    }

    private func completePendingRequest(with response: ELMResponse, latency: TimeInterval) {
        guard let pending = pendingRequest else {
            Logger.shared.debug("No pending request. Dropping response.")
            return
        }

        Logger.shared.debug("Completing pending request \(pending.id)")
        pending.timeoutTask?.cancel()

        defer {
            pendingRequest = nil
        }

        pending.continuation.resume(returning: (response, latency))
        Logger.shared.debug("🟢 Continuation RESUMED: \(response.type)")
    }

    // MARK: didUpdateValueFor
    
    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            guard error == nil,
                  let value = characteristic.value
            else { return }

            let latency = Date().timeIntervalSince(lastSendTime)
            Logger.shared.info("Response Time: \(Int(latency * 1000)) ms")

            let chunk = String(data: value, encoding: .utf8) ?? "<non-utf8>"

            let responses = await ELMResponseAssembler.shared.append(chunk)
            guard !responses.isEmpty else {
                Logger.shared.debug("RX Chunk (\(value.count) bytes)")
                return
            }
            for response in responses {
                Logger.shared.debug("🔵 ENTER didUpdateValueFor loop")
                Logger.shared.debug("🔵 Parsed type = \(response.type)")
                let raw = response.raw

                updateECUInfo(from: response)

                Logger.shared.debug("RX Complete (\(responses.count) response(s))")
                logResponse(raw)

                rxCount += 1
                if !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lastResponse = raw
                }

                // removed guard response.type != .unknown block

                analyzeResponse(response)

                // Do not complete a pending request on informational or unparsed
                // responses. Some ELM327 adapters prepend BUS INIT / SEARCHING
                // before the actual ECU frame.
                if response.type == .unknown {
                    let compact = response.raw
                        .uppercased()
                        .replacingOccurrences(of: " ", with: "")
                    let containsFrame = Self.ecuFramePrefixes.contains {
                        compact.contains($0)
                    }
                    if !containsFrame {
                        Logger.shared.debug("Ignoring transient response: \(response.raw)")
                        continue
                    }
                }

                guard response.type.canResumeContinuation || response.type == .unknown else {
                    Logger.shared.warning("Ignoring response type: \(response.type)")
                    continue
                }

                completePendingRequest(with: response, latency: latency)
            }
        }
    }
    
    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                Logger.shared.error("Notify Error: \(error.localizedDescription)")
                return
            }

            Logger.shared.debug(
                "Notify \(characteristic.uuid.uuidString): \(characteristic.isNotifying)"
            )

            Logger.shared.console("Notify \(characteristic.uuid.uuidString): \(characteristic.isNotifying)")
            
            guard characteristic.uuid.uuidString.uppercased() == "FFF1" else {
                return
            }

            guard characteristic.isNotifying else {
                return
            }

            guard !elmInitialized else {
                return
            }

            elmInitialized = true
            isConnected = true

            await initializeELM()
        }
    }
}

extension ELMResponseType {

    var canResumeContinuation: Bool {
        switch self {
        case .mode01,
             .mode21,
             .mode22,
             .negative,
             .noData,
             .atResponse,
             .unknown:
            return true
        default:
            return false
        }
    }
}

extension ELMResponseType {

    var displayName: String {
        switch self {
        case .mode01: return "Mode 01"
        case .mode21: return "Mode 21"
        case .mode22: return "Mode 22"
        default: return "Response"
        }
    }

    var status: ECUStatus {
        switch self {
        case .mode01: return .mode01OK
        case .mode21: return .mode21OK
        case .mode22: return .mode22OK
        default: return .connected
        }
    }
}

