import Foundation

@MainActor
final class ECUReset {

    static let shared = ECUReset()

    private let bt = BluetoothManager.shared
    private let defaultHeader = "80F111"

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


    func reset() async {
        Logger.shared.info("===== Restarting ECU =====")

        let headerToRestore = ELM327.shared.currentHeader.isEmpty
            ? defaultHeader
            : ELM327.shared.currentHeader

        guard await ELM327.shared.initializeELM() else {            Logger.shared.error("ELM initialization failed")
            Logger.shared.info("===== Restart ECU Failed =====")
            return
        }
        await ELM327.shared.identifyECU()

        guard await runCommand("ATSH\(headerToRestore)", timeout: .seconds(2)) else {
            Logger.shared.error("Failed to restore header \(headerToRestore)")
            Logger.shared.info("===== Restart ECU Failed =====")
            return
        }

        Logger.shared.info("Restored header: \(headerToRestore)")

        guard let result = try? await bt.sendAndWait("0100", timeout: .seconds(2)) else {
            Logger.shared.error("ECU test: no response from ECU")
            Logger.shared.info("===== Restart ECU Failed =====")
            return
        }

        let response = result.response

        Logger.shared.info("ECU response: \(response.raw)")
        Logger.shared.info("Latency: \(Int(result.latency * 1000)) ms")

        Logger.shared.info("===== ECU Restarted & Tested =====")
    }
}
