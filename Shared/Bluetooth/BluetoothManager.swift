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

        // Start PreSession logging as soon as BLE scan begins
        Task {
            if !LogSessionManager.shared.isSessionStarted {
                let metadata = LogSessionManager.Metadata(
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                    mode: nil,
                    header: nil,
                    searchEngine: nil,
                    requestDelay: nil,
                    requestTimeout: nil,
                    autoPreflight: nil,
                    debugLogging: nil
                )

                do {
                    try await LogSessionManager.shared.beginLoggingSessionIfNeeded(
                        metadata: metadata,
                        logger: Logger.shared
                    )
                } catch {
                    Logger.shared.error("❌ Failed to start logging session: \(error.localizedDescription)")
                }
            }
        }

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
        retriedProtocol = false

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
    private func stopBLEScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
    }

    func stopScan() {
        stopBLEScan()
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
        stopBLEScan()
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
        Task {
            if LogSessionManager.shared.isSessionStarted {
                await closeLoggingSession()
            }
        }
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
        Logger.shared.verbose("TX UUID = \(tx.uuid.uuidString)")
        Logger.shared.verbose("TX Props = \(tx.properties)")
        lastSendTime = Date()
        let type: CBCharacteristicWriteType =
        tx.properties.contains(.write)
        ? .withResponse
        : .withoutResponse
        
        let hex = data.map {
            String(format: "%02X", $0)
        }.joined(separator: " ")
        
        Logger.shared.verbose("TX HEX = \(hex)")
        
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
        ELMResponseAssembler.shared.clear()

        return try await withCheckedThrowingContinuation { continuation in
            Logger.shared.verbose("📌 Registering continuation")
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
                Logger.shared.verbose("📤 Command sent successfully")
            } catch {
                timeoutTask.cancel()
                clearPendingRequest()
                continuation.resume(throwing: error)
                return
            }
        }
    }
    @MainActor
    private func initializeELM() async {
        status = .initializingELM

        guard await ELM327.shared.initializeELM() else {
            Logger.shared.error("ELM initialization failed")
            return
        }

        status = .connected

        ECUInfo.shared.header = ELM327.shared.currentHeader
        ECUInfo.shared.status = "Connected"
        ECUInfo.shared.lastConnected = Date()
        ELM327.shared.identifyECU()

        Logger.shared.success("ELM initialization finished")
    }
    
    @MainActor
    func resetTrafficCounters() {
        txCount = 0
        rxCount = 0
    }

    // MARK: - Private helpers
    private func closeLoggingSession() async {
        await Logger.shared.finishSessionImpl()
        LogSessionManager.shared.endLoggingSession()
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
                        stopBLEScan()
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
            stopBLEScan()
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

            self.stopBLEScan()
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
                
                Logger.shared.verbose("SERVICE: \(service.uuid.uuidString)")
                Logger.shared.verbose("CHAR: \(c.uuid.uuidString)")
                Logger.shared.verbose("PROPS: \(c.properties)")
                
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
                _ = try? await sendAndWait("ATZ", timeout: .seconds(3))

                guard self.isConnected else {
                    return
                }

                _ = try? await sendAndWait("ATSP5", timeout: .seconds(2))
                retriedProtocol = false
            }
        }
    }

    private func analyzeResponse(_ response: ELMResponse) {
        switch response.type {
        case .positive:
            retriedProtocol = false
            status = .connected
            Logger.shared.success("🎉 Service 0x\(String(format: "%02X", response.service ?? 0)) Supported")
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
            clearPendingRequest(resumingWith: BluetoothError.disconnected)

        case .unableToConnect:
            status = .unableToConnect
            Logger.shared.error("💀 UNABLE TO CONNECT")

        case .searching:
            status = .searching

        case .stopped,
             .atResponse,
             .unknown:
            break
        case .partialFrame:
            ScanStatistics.shared.recordPartialFrame()
            Logger.shared.warning("🟡 Partial ECU frame")
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

        if let vin = response.vin {
            ECUInfo.shared.ecuIdentifier = vin
        }

        if let calibration = response.calibrationID {
            ECUInfo.shared.calibrationIdentifier = calibration
        }

        if let ecuName = response.ecuName {
            ECUInfo.shared.ecuName = ecuName
        }
    }

    private func logResponse(_ raw: String) {
        Logger.shared.rx(raw)

        let hex = Array(raw.utf8)
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")

        Logger.shared.console("<< TEXT: \(raw)")
        Logger.shared.console("<< HEX : \(hex)")
        Logger.shared.verbose("RX HEX = \(hex)")
    }

    private func completePendingRequest(with response: ELMResponse, latency: TimeInterval) {
        guard let pending = pendingRequest else {
            Logger.shared.verbose("No pending request. Dropping response.")
            return
        }

        Logger.shared.verbose("Completing pending request \(pending.id)")
        pending.timeoutTask?.cancel()

        pendingRequest = nil
        ELMResponseAssembler.shared.clear()
        
        pending.continuation.resume(returning: (response, latency))

        Logger.shared.verbose("🟢 Continuation RESUMED: \(response.type)")
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
                Logger.shared.verbose("RX Chunk (\(value.count) bytes)")
                return
            }
            for response in responses {
                let raw = response.raw

                updateECUInfo(from: response)

                Logger.shared.verbose("""
🔵 RX COMPLETE
RAW      = \(raw)
TYPE     = \(response.type)
SERVICE  = \(response.service.map { String(format: "%02X", $0) } ?? "-")
PID      = \(response.pid.map { String(format: "%04X", $0) } ?? "-")
PAYLOAD  = \(response.payload.map { String(format: "%02X", $0) }.joined(separator: " "))
""")

                Logger.shared.verbose("RX Complete (\(responses.count) response(s))")
                logResponse(raw)

                rxCount += 1
                if !raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    lastResponse = raw
                }

                // removed guard response.type != .unknown block


                // Do not complete a pending request on informational or unparsed
                // responses. Some ELM327 adapters prepend BUS INIT / SEARCHING
                // before the actual ECU frame.
                if case .unknown = response.type {
                    let compact = response.raw
                        .uppercased()
                        .replacingOccurrences(of: " ", with: "")
                    let containsFrame = Self.ecuFramePrefixes.contains {
                        compact.contains($0)
                    }
                    if !containsFrame {
                        Logger.shared.verbose("Ignoring transient response: \(response.raw)")
                        continue
                    }
                }

                guard response.type.canResumeContinuation else {
                    Logger.shared.warning("Ignoring response type: \(response.type)")
                    continue
                }

                Logger.shared.verbose("Attempting to complete pending request with response type: \(response.type)")
                completePendingRequest(with: response, latency: latency)
                analyzeResponse(response)
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

            Logger.shared.verbose(
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
        case .positive,
             .negative,
             .noData,
             .atResponse,
             .unknown,
             .unableToConnect,
             .busError:
            return true
        case .searching,
             .stopped:
            return false
        case .partialFrame:
            return true
        }
    }
}


