//
//  DynamicScanner.swift
//  PIDHunter
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
    
    var delay: UInt64 = 200_000_000
    
    private var stopFlag = false
    
    private let maxSamplesPerPID = 100
    
    func stop() {
        stopFlag = true
        running = false
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
                    
                    // غيّر الهيدر لو مشروعك بيستخدم Header مختلف
                    RequestResponseMatcher.shared.enqueue(
                        command: req,
                        header: "81F111"
                    )
                    
                    Logger.shared.tx(req)
                    
                    ELM327.shared.send(req)
                    
                    try? await Task.sleep(
                        nanoseconds: delay
                    )
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
        
        guard !cleaned.isEmpty else {
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
