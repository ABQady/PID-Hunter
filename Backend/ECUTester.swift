import Foundation

@MainActor
final class ECUTester {

    static let shared = ECUTester()

    private let bt = BluetoothManager.shared

    func run(header: String) async {
        Logger.shared.info("===== ECU TEST START =====")

        _ = try? await bt.sendAndWait("ATZ", timeout: .seconds(2))

        _ = try? await bt.sendAndWait("ATE0", timeout: .seconds(1))

        _ = try? await bt.sendAndWait("ATL0", timeout: .seconds(1))

        _ = try? await bt.sendAndWait("ATS0", timeout: .seconds(1))

        _ = try? await bt.sendAndWait("ATH1", timeout: .seconds(1))

        _ = try? await bt.sendAndWait("ATSP5", timeout: .seconds(2))

        _ = try? await bt.sendAndWait("ATDP", timeout: .seconds(2))

        Logger.shared.info("Testing header \(header)")
        guard (try? await bt.sendAndWait("ATSH\(header)", timeout: .seconds(2))) != nil else {
            Logger.shared.error("Failed to set header \(header)")
            Logger.shared.info("===== ECU TEST END =====")
            return
        }

        guard let response = try? await bt.sendAndWait("0100", timeout: .seconds(2)) else {
            Logger.shared.error("ECU test failed: no response from ECU")
            Logger.shared.info("===== ECU TEST END =====")
            return
        }

        Logger.shared.success("ECU response: \(response.raw)")

        Logger.shared.info("===== ECU TEST END =====")
    }
}
