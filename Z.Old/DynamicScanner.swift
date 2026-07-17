////
////  DynamicScanner.swift
////  PIDHunter by Ahmed AlQady
////
//
//import Foundation
//
//struct DynamicPID: Identifiable {
//    let id = UUID()
//    
//    let request: String
//
//    var sampleCount: Int {
//        samples.count
//    }
//    
//    var samples: [String] = []
//    
//    var uniqueValues: Set<String> = []
//    
//    var hasChanged: Bool {
//        uniqueValues.count > 1
//    }
//}
//
//@MainActor
//final class DynamicScanner: ObservableObject {
//    
//    static let shared = DynamicScanner()
//    
//    @Published var running = false
//    
//    @Published var pids: [DynamicPID] = []
//        
//    private var stopFlag = false
//    
//    private let maxSamplesPerPID = 100
//    
//    private let requestTimeout: TimeInterval = 2.0
//    
//    func stop() {
//        stopFlag = true
//        running = false
//    }
//    
//    func monitor(requests: [String]) {
//        
//        guard !running else {
//            print("DynamicScanner already running.")
//            return
//        }
//        
//        stopFlag = false
//        running = true
//        
//        pids.removeAll(keepingCapacity: true)
//        
//        pids = requests.map {
//            DynamicPID(request: $0)
//        }
//        
//        Task {
//            
//            defer {
//                running = false
//            }
//            
//            while !stopFlag {
//                
//                for index in pids.indices {
//                    
//                    if stopFlag {
//                        break
//                    }
//                    
//                    let req = pids[index].request
//
//                    if stopFlag {
//                        break
//                    }
//
//                    do {
//                        let result = try await ELM327.shared.request(
//                            command: req,
//                            timeout: .seconds(requestTimeout)
//                        )
//
//                        processResponse(
//                            request: req,
//                            response: result.response.raw
//                        )
//                    } catch BluetoothManager.BluetoothError.timeout {
//                        // Ignore timeout and continue scanning.
//                    } catch {
//                        Logger.shared.debug("DynamicScanner request failed: \(error.localizedDescription)")
//                    }
//                }
//            }
//        }
//    }
//    
//    func processResponse(
//        request: String,
//        response: String
//    ) {
//        
//        guard let index = pids.firstIndex(
//            where: {
//                $0.request == request
//            }
//        ) else {
//            return
//        }
//        
//        let cleaned = response
//            .trimmingCharacters(
//                in: .whitespacesAndNewlines
//            )
//
//        guard !cleaned.isEmpty else {
//            return
//        }
//        
//        let upper = cleaned.uppercased()
//
//        guard
//            upper != ">",
//            !upper.contains("NO DATA"),
//            !upper.contains("OK"),
//            !upper.contains("ERROR"),
//            !upper.contains("SEARCHING"),
//            !upper.contains("BUS ERROR"),
//            !upper.contains("BUFFER FULL"),
//            !upper.contains("STOPPED"),
//            !upper.contains("?")
//        else {
//            return
//        }
//        
//        var pid = pids[index]
//
//        pid.samples.append(cleaned)
//
//        if pid.samples.count > maxSamplesPerPID {
//            pid.samples.removeFirst()
//        }
//
//        pid.uniqueValues.insert(cleaned)
//
//        pids[index] = pid
//    }
//    
//    func changedOnly() -> [DynamicPID] {
//        
//        pids.filter {
//            $0.hasChanged
//        }
//    }
//    
//    func printSummary() {
//        
//        print("")
//        print("==========")
//        print("Dynamic PID Summary")
//        print("==========")
//        
//        for item in changedOnly() {
//            
//            print(
//                item.request,
//                "changed:",
//                item.uniqueValues.count,
//                "states"
//            )
//        }
//        
//        print("==========")
//    }
//}
