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
        let continuation: CheckedContinuation<ELMResponse, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var pendingRequest: PendingRequest?
    
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

        while !isConnected {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
    
    // MARK: Scan
        func startScan() {
            ELMResponseAssembler.shared.clear()
            RequestResponseMatcher.shared.clear()
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self else { return }
                
                if self.isScanning {
                    self.status = .timeout
                    self.stopScan()
                    Logger.shared.warning("Scan timed out")
                }
            }
        print("Scanning...")
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
        print("TX UUID =", tx.uuid.uuidString)
        print("TX Props =", tx.properties)
        print(">> \(command)")
        Logger.shared.tx(command)
        Logger.shared.info("TX UUID = \(tx.uuid.uuidString)")
        Logger.shared.info("TX Props = \(tx.properties)")
        lastSendTime = Date()
        let type: CBCharacteristicWriteType =
        tx.properties.contains(.write)
        ? .withResponse
        : .withoutResponse
        
        let hex = data.map {
            String(format: "%02X", $0)
        }.joined(separator: " ")
        
        Logger.shared.info("TX HEX = \(hex)")
        
        status = .waitingResponse
        peripheral.writeValue(
            data,
            for: tx,
            type: type
        )
        txCount += 1
        if !command.uppercased().hasPrefix("AT") {
            ScanStatistics.shared.requestsSent += 1
        }
    }
    
    // MARK: Send & Wait
    
    func sendAndWait(
        _ command: String,
        timeout: Duration = .seconds(1)
    ) async throws -> ELMResponse {
        guard pendingRequest == nil else {
            throw BluetoothError.busy
        }

        return try await withCheckedThrowingContinuation { continuation in
            Logger.shared.warning("📌 Registering continuation")
            let requestID = UUID()
            if !command.uppercased().hasPrefix("AT") {
                RequestResponseMatcher.shared.enqueue(
                    command: command,
                    header: ELM327.shared.currentHeader
                )
            }
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
                self.pendingRequest = nil
                pending.continuation.resume(throwing: BluetoothError.timeout)
            }
            // Update the timeoutTask in the pending request
            pendingRequest?.timeoutTask = timeoutTask
            do {
                try send(command)
                Logger.shared.warning("📤 Command sent successfully")
            } catch {
                if !command.uppercased().hasPrefix("AT") {
                    _ = RequestResponseMatcher.shared.dequeue()
                }
                timeoutTask.cancel()
                pendingRequest = nil
                continuation.resume(throwing: error)
                return
            }
        }
    }
    @MainActor
    private func initializeELM() async {
        status = .initializingELM

        try? send("ATZ")
        try? await Task.sleep(for: .milliseconds(1500))
        guard isConnected else {  status = .disconnected
            return }

        do {
            _ = try await sendAndWait("ATE0", timeout: .seconds(2))
        } catch {
            return
        }
        guard isConnected else { status = .disconnected
            return }

        do {
            _ = try await sendAndWait("ATL0", timeout: .seconds(2))
        } catch {
            return
        }
        guard isConnected else { status = .disconnected
            return }

        do {
            _ = try await sendAndWait("ATS0", timeout: .seconds(2))
        } catch {
            return
        }
        guard isConnected else { status = .disconnected
            return }

        do {
            _ = try await sendAndWait("ATH1", timeout: .seconds(2))
        } catch {
            return
        }
        guard isConnected else { status = .disconnected
            return }
        ECUInfo.shared.header = ELM327.shared.currentHeader

        status = .settingProtocol
        do {
            _ = try await sendAndWait("ATSP5", timeout: .seconds(2))
        } catch {
            return
        }
        guard isConnected else { status = .disconnected
            return }

        status = .checkingProtocol
        do {
            _ = try await sendAndWait("ATDP", timeout: .seconds(2))
        } catch {
            return
        }
        guard isConnected else { status = .disconnected
            return }

        do {
            _ = try await sendAndWait("ATI", timeout: .seconds(2))
        } catch {
            return
        }
        guard isConnected else { status = .disconnected
            return }

        status = .testingECU
        do {
            let response = try await sendAndWait(
                "0100",
                timeout: .seconds(2)
            )
            Logger.shared.success("ECU Test Response: \(response.raw)")
        } catch {
            Logger.shared.error("ECU test failed: \(error)")
            return
        }

        Logger.shared.success("ELM initialization finished")

        guard isConnected else { status = .disconnected
            return }
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
                print("Bluetooth Ready")
                Logger.shared.success("Bluetooth Ready")
            case .poweredOff:
                print("Bluetooth Off")
                Logger.shared.error("Bluetooth Off")
            case .resetting:
                print("Bluetooth Resetting")
                Logger.shared.warning("Bluetooth Restarting")
            case .unsupported:
                print("Bluetooth Unsupported")
                Logger.shared.error("Bluetooth Unsupported")
            case .unauthorized:
                print("Bluetooth Unauthorized")
                Logger.shared.error("Bluetooth Unauthorized")
            default:
                print("Bluetooth Unknown")
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
                    print("Found:", name)
                }
                if let name = peripheral.name?.lowercased() {
                    Logger.shared.success("Found: \(name)")
                    
                    if elmPeripheral == nil &&
                        (name.contains("elm") || name.contains("obd")) {
                        
                        print("🚀 Auto connecting to \(name)")
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
            print("Connected to \(peripheral.name ?? "Unknown")")
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
            
            self.discoveredDevices.removeAll()
            
            self.stopScan()
            RequestResponseMatcher.shared.clear()
            ECUInfo.shared.clear()
            
            print("Disconnected")
            if let error {
                Logger.shared.error("Disconnected: \(error.localizedDescription)")
            } else {
                Logger.shared.error("Disconnected")
            }
            
            if let pending = pendingRequest {
                pending.timeoutTask?.cancel()
                pending.continuation.resume(throwing: BluetoothError.disconnected)
                pendingRequest = nil
            }
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
                print("===== SERVICE =====")
                print(service.uuid.uuidString)
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
                print("SERVICE :", service.uuid.uuidString)
                print("CHAR    :", c.uuid.uuidString)
                print("PROPS   :", c.properties)
                
                Logger.shared.info("SERVICE: \(service.uuid.uuidString)")
                Logger.shared.info("CHAR: \(c.uuid.uuidString)")
                Logger.shared.info("PROPS: \(c.properties)")
                
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
    
    private func analyzeResponse(_ response: ELMResponse) {
        ScanStatistics.shared.responses += 1
        switch response.type {

        case .mode01:
            retriedProtocol = false
            status = .mode01OK
            Logger.shared.success("🎉 Mode 01 Supported")
            ECUInfo.shared.addService(response.service)
            ScanStatistics.shared.positiveResponses += 1

        case .mode21:
            retriedProtocol = false
            status = .mode21OK
            Logger.shared.success("🎉 Mode 21 Supported")
            ECUInfo.shared.addService(response.service)
            ScanStatistics.shared.positiveResponses += 1

        case .mode22:
            retriedProtocol = false
            status = .mode22OK
            Logger.shared.success("🎉 Mode 22 Supported")
            ECUInfo.shared.addService(response.service)
            ScanStatistics.shared.positiveResponses += 1

        case .negative:
            ScanStatistics.shared.negativeResponses += 1
            Logger.shared.warning("Negative Response")
            
        case .noData:
            Logger.shared.error("❌ NO DATA")
            ScanStatistics.shared.noData += 1

        case .busError:

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

        case .unableToConnect:
            status = .unableToConnect
            Logger.shared.error("💀 UNABLE TO CONNECT")

        case .searching:
            status = .searching

        default:
            break
        }

        
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
            
            let ms = Date().timeIntervalSince(lastSendTime) * 1000
            Logger.shared.info("Response Time: \(Int(ms)) ms")

            let chunk = String(data: value, encoding: .utf8) ?? "<non-utf8>"
            
            let responses = ELMResponseAssembler.shared.append(chunk)
            guard !responses.isEmpty else {
                
                Logger.shared.info("RX Chunk (\(value.count) bytes)")
                return
            }
            for response in responses {
                Logger.shared.warning("🔵 ENTER didUpdateValueFor loop")
                Logger.shared.warning("🔵 Parsed type = \(response.type)")
                let raw = response.raw
                
                let upper = raw.uppercased()

                if upper.hasPrefix("ELM") {
                    ECUInfo.shared.elmVersion = raw
                }

                if upper.contains("ISO") ||
                   upper.contains("KWP") ||
                   upper.contains("CAN") ||
                   upper.contains("J1850") {
                    ECUInfo.shared.protocolName = raw
                }

                Logger.shared.success("RX Complete (\(responses.count) response(s))")
                Logger.shared.rx(raw)

                rxCount += 1
                if !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lastResponse = raw
                }

                let hex = Array(raw.utf8)
                    .map { String(format: "%02X", $0) }
                    .joined(separator: " ")

                print("<< TEXT:", raw)
                print("<< HEX :", hex)
                Logger.shared.success("RX HEX = \(hex)")
                                
                // removed guard response.type != .unknown block

                analyzeResponse(response)
                
                guard response.type.canResumeContinuation else {
                    if response.type == .unknown {
                        Logger.shared.error("⚠️ UNKNOWN RESPONSE: \(response.raw)")
                    } else {
                        Logger.shared.warning("Ignoring response type: \(response.type)")
                    }
                    continue
                }
                
                Logger.shared.warning("🔵 Response Type = \(response.type)")
                Logger.shared.warning(
                    "🔵 Continuation = \(pendingRequest == nil ? "nil" : "exists")"
                )

                guard let pending = pendingRequest else {
                    continue
                }
                if response.type != .atResponse {
                    _ = RequestResponseMatcher.shared.dequeue()
                }
                pending.timeoutTask?.cancel()
                pendingRequest = nil
                pending.continuation.resume(returning: response)
                Logger.shared.success("🟢 Continuation RESUMED")
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

            Logger.shared.info(
                "Notify \(characteristic.uuid.uuidString): \(characteristic.isNotifying)"
            )

            print(
                "Notify \(characteristic.uuid.uuidString): \(characteristic.isNotifying)"
            )
            
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
             .atResponse:
            return true

        default:
            return false
        }
    }
}

