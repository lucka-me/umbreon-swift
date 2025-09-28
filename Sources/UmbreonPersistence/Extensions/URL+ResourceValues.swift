//
//  URL+ResourceValues.swift
//  UmbreonPersistence
//
//  Created by Lucka on 17/3/2025.
//

import Foundation

extension URL {
    var isDirectory: Bool {
        get throws {
            try resourceValues(forKeys: [ .isDirectoryKey ]).isDirectory == true
        }
    }
}
