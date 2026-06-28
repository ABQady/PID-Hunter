//
//  CSVExporter.swift
//  PID Hunter By Ahmed AlQady

import Foundation

final class CSVExporter {
    
    private static func escapeCSV(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }
    
    static func export(
        _ results: [ScanResult]
    ) throws -> URL {
        
        var csv =
        "Header,Mode,PID,Request,Response\n"
        
        for row in results {
            
            csv +=
            "\"\(escapeCSV(row.header))\","
            
            csv +=
            "\"\(escapeCSV(row.mode))\","
            
            csv +=
            "\"\(escapeCSV(row.pid))\","
            
            csv +=
            "\"\(escapeCSV(row.request))\","
            
            csv +=
            "\"\(escapeCSV(row.response))\"\n"
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
            csv += "\"\(escapeCSV(row.request))\","
            csv += "\"\(String(row.hasChanged))\","
            csv += "\"\(escapeCSV(row.uniqueValues.joined(separator: " | ")))\"\n"
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
