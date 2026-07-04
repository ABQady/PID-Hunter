//
//  LogLineDisplay.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 04/07/2026.
//
extension LogLine {

    var timestamp: Substring {
        text.prefix { $0 != " " }
    }

    var message: Substring {
        guard let space = text.firstIndex(of: " ")
        else { return text[...] }

        return text[text.index(after: space)...]
    }
}
