//
//  DynamicScanner.swift
//  PIDHunter by Ahmed AlQady
//

import Foundation

struct DynamicPID: Identifiable {
    let id = UUID()
    
    let request: String
    
    var samples: [String] = []
    
    var uniqueValues: Set<String> = []
    
    var hasChanged: Bool {
        uniqueValues.count > 1
    }
}

@MainActor
final class DynamicScanner: ObservableObject {
    
    static let shared = DynamicScanner()
    
    @Published var running = false
    
    @Published var pids: [DynamicPID] = []
        
    private var stopFlag = false
    
    private let maxSamplesPerPID = 100
    
    private let requestTimeout: TimeInterval = 2.0
    
    func stop() {
        stopFlag = true
        running = false
        RequestResponseMatcher.shared.clear()
    }
    
    func monitor(requests: [String]) {
        
        guard !running else {
            print("DynamicScanner already running.")
            return
        }
        
        stopFlag = false
        running = true
        
        pids.removeAll()
        
        for req in requests {
            pids.append(
                DynamicPID(
                    request: req
                )
            )
        }
        
        Task {
            
            defer {
                running = false
            }
            
            while !stopFlag {
                
                for index in pids.indices {
                    
                    if stopFlag {
                        break
                    }
                    
                    let req = pids[index].request
                                    
                    ELM327.shared.send(req)

                    let startWait = Date()

                    while !RequestResponseMatcher.shared.pending.isEmpty {

                        if Date().timeIntervalSince(startWait) > requestTimeout {
                            RequestResponseMatcher.shared.clear()
                            break
                        }

                        try? await Task.sleep(for: .milliseconds(10))
                    }
                }
            }
        }
    }
    
    func processResponse(
        request: String,
        response: String
    ) {
        
        guard let index = pids.firstIndex(
            where: {
                $0.request == request
            }
        ) else {
            return
        }
        
        let cleaned = response
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        
        let upper = cleaned.uppercased()

        guard
            upper != ">",
            !upper.contains("NO DATA"),
            !upper.contains("OK"),
            !upper.contains("ERROR"),
            !upper.contains("SEARCHING"),
            !upper.contains("BUS ERROR"),
            !upper.contains("BUFFER FULL"),
            !upper.contains("STOPPED"),
            !upper.contains("?")
        else {
            return
        }
        
        pids[index].samples.append(cleaned)
        
        if pids[index].samples.count > maxSamplesPerPID {
            pids[index].samples.removeFirst()
        }
        
        pids[index].uniqueValues.insert(cleaned)
    }
    
    func changedOnly() -> [DynamicPID] {
        
        pids.filter {
            $0.hasChanged
        }
    }
    
    func printSummary() {
        
        print("")
        print("==========")
        print("Dynamic PID Summary")
        print("==========")
        
        for item in changedOnly() {
            
            print(
                item.request,
                "changed:",
                item.uniqueValues.count,
                "states"
            )
        }
        
        print("==========")
    }
}
