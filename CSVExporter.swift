//
//  CSVExporter.swift
//

import Foundation

final class CSVExporter {
    
    static func export(
        _ results: [ScanResult]
    ) throws -> URL {
        
        var csv =
        "Header,Mode,PID,Request,Response\n"
        
        for row in results {
            
            csv +=
            "\"\(row.header)\","
            
            csv +=
            "\"\(row.mode)\","
            
            csv +=
            "\"\(row.pid)\","
            
            csv +=
            "\"\(row.request)\","
            
            csv +=
            "\"\(row.response)\"\n"
        }
        
        let url =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "found_pids.csv"
            )
        
        try csv.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        
        return url
    }
    
    static func exportDynamic(
        _ rows: [DynamicPID]
    ) throws -> URL {
        
        var csv =
        "Request,Changed,UniqueValues\n"
        
        for row in rows {
            
            csv +=
            "\"\(row.request)\","
            
            csv +=
            "\"\(row.hasChanged)\","
            
            csv +=
            "\"\(row.uniqueValues.joined(separator: " | "))\"\n"
        }
        
        let url =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "dynamic_scan.csv"
            )
        
        try csv.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        
        return url
    }
}
