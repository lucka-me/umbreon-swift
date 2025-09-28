//
//  CellCollection+Data.swift
//  UmbreonCore
//
//  Created by Lucka on 10/9/2024.
//

import Foundation
import SphereGeometry

public extension CellCollection {
    init(contentOf url: URL) throws {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty, data.count % MemoryLayout<Element>.size == 0 else {
            self.init()
            return
        }
        self = .guaranteed(
            cells: data.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
        )
    }
    
    init?(data: Data) {
        guard data.count % MemoryLayout<Element>.size == 0 else {
            return nil
        }
        self = .guaranteed(
            cells: data.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
        )
    }
    
    var data: Data {
        cells.withUnsafeBufferPointer { .init(buffer: $0) }
    }
}
