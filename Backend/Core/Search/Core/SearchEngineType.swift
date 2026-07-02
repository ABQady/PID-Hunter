//
//  SearchEngineType.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 02/07/2026.
//
enum SearchEngineType: String, CaseIterable, Codable {
    case sequential
    case smart
    case adaptive
    case ucb
    case thompson
    case heatMap
    case cluster
    case hybrid
}
