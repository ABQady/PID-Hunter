//
//  StorageItem+UI.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 15/07/2026.
//

import SwiftUI

extension StorageItem.Kind {

    var tintColor: Color {
        switch self {
        case .folder:
            return .blue

        case .file:
            switch self.icon {
            case "doc.text":
                return .orange

            case "doc.richtext":
                return .indigo

            case "doc.zipper":
                return .brown

            case "photo":
                return .green

            case "doc.plaintext":
                return .mint

            default:
                return .secondary
            }
        }
    }
}
