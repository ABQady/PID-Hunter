import Foundation

@MainActor
final class ECUTester {

    static let shared = ECUTester()

    private let bt = BluetoothManager.shared

    @discardableResult
    private func runCommand(
        _ command: String,
        timeout: Duration
    ) async -> Bool {
        guard (try? await bt.sendAndWait(command, timeout: timeout)) != nil else {
            Logger.shared.error("Failed command: \(command)")
            return false
        }
        return true
    }


    func run(header: String) async {
        Logger.shared.info("===== ECU TEST START =====")

        guard await ELM327.shared.initializeELM() else {            Logger.shared.error("ELM initialization failed")
            Logger.shared.info("===== ECU TEST END =====")
            return
        }

        Logger.shared.info("Testing header \(header)")
        guard await runCommand("ATSH\(header)", timeout: .seconds(2)) else {
            Logger.shared.error("Failed to set header \(header)")
            Logger.shared.info("===== ECU TEST END =====")
            return
        }

        guard let result = try? await bt.sendAndWait("0100", timeout: .seconds(2)) else {
            Logger.shared.error("ECU test failed: no response from ECU")
            Logger.shared.info("===== ECU TEST END =====")
            return
        }

        let response = result.response

        Logger.shared.info("ECU response: \(response.raw)")
        Logger.shared.info("Latency: \(Int(result.latency * 1000)) ms")

        Logger.shared.info("===== ECU TEST END =====")
    }
}
