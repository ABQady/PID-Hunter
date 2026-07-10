////
////  CSVExporter.swift
////  PID Hunter By Ahmed AlQady
//
//import Foundation
//
//final class CSVExporter {
//    
//    private static func escapeCSV(_ value: String) -> String {
//        value.replacingOccurrences(of: "\"", with: "\"\"")
//    }
//    
//    private static func csvField(_ value: String) -> String {
//        "\"\(escapeCSV(value))\""
//    }
//    
//    // MARK: - Scan Results
//    static func export(
//        _ results: [ScanResult]
//    ) throws -> URL {
//        
//        let sortedResults = results.sorted {
//            ($0.header, $0.mode, $0.pid) < ($1.header, $1.mode, $1.pid)
//        }
//        
//        var csv =
//        "Header,Mode,PID,Request,Response,ResponseLength\n"
//        
//        for row in sortedResults {
//            csv += [
//                csvField(row.header),
//                csvField(row.mode),
//                csvField(row.pid),
//                csvField(row.request),
//                csvField(row.response),
//                csvField(String(row.response.count))
//            ].joined(separator: ",") + "\n"
//        }
//        
//        return try Exporter.write(
//            csv,
//            filename: "found_pids.csv"
//        )
//    }
//    
//    // MARK: - Dynamic Scan
//    static func exportDynamic(
//        _ rows: [DynamicPID]
//    ) throws -> URL {
//        
//        var csv =
//        "Request,Changed,UniqueValues\n"
//        
//        for row in rows {
//            csv += [
//                csvField(row.request),
//                csvField(String(row.hasChanged)),
//                csvField(row.uniqueValues.joined(separator: " | "))
//            ].joined(separator: ",") + "\n"
//        }
//        
//        return try Exporter.write(
//            csv,
//            filename: "dynamic_scan.csv"
//        )
//    }
//}
