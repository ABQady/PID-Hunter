import Foundation

@MainActor
final class ECUTester {

    static let shared = ECUTester()

    private let bt = BluetoothManager.shared

    func run(header: String) async {
        RequestResponseMatcher.shared.clear()

        Logger.shared.info("===== ECU TEST START =====")

        bt.send("ATZ")
        try? await Task.sleep(for: .seconds(2))

        bt.send("ATE0")
        try? await Task.sleep(for: .milliseconds(300))

        bt.send("ATL0")
        try? await Task.sleep(for: .milliseconds(300))

        bt.send("ATS0")
        try? await Task.sleep(for: .milliseconds(300))

        bt.send("ATH1")
        try? await Task.sleep(for: .milliseconds(300))

        bt.send("ATSP5")
        try? await Task.sleep(for: .seconds(1))

        bt.send("ATDP")
        try? await Task.sleep(for: .milliseconds(500))

        Logger.shared.info("Testing header \(header)")
        bt.send("ATSH\(header)")
        try? await Task.sleep(for: .milliseconds(800))

        bt.send("0100")
        
        let start = Date()

        while !RequestResponseMatcher.shared.pending.isEmpty {

            if Date().timeIntervalSince(start) > 2.0 {
                RequestResponseMatcher.shared.clear()
                break
            }

            try? await Task.sleep(for: .milliseconds(10))
        }
        
        Logger.shared.info("===== ECU TEST END =====")
    }
}
