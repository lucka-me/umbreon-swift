//
//  CompressedCells.swift
//  UmbreonPersistence
//
//  Created by Lucka on 22/9/2024.
//

import Compression
import Foundation
import SphereGeometry

public actor CompressedCells : CellCollectionConvertible {
    public let progress: Progress
    
    let handle: FileHandle
    
    fileprivate init(url: URL) throws {
        self.handle = try .init(forReadingFrom: url)
        self.progress = .init(totalUnitCount: .init(try self.handle.seekToEnd()))
        try self.handle.seek(toOffset: 0)
    }
    
    public func convert() async throws -> CellCollection {
        let filter = try InputFilter(.decompress, using: .lzma) { length in
            let data = try self.handle.read(upToCount: length)
            if let count = data?.count {
                self.progress.completedUnitCount = .init(count)
            }
            return data
        }
        var cells: [ CellIdentifier ] = [ ]
        
        while let page = try filter.readData(ofLength: Self.pageSize) {
            guard page.count == Self.pageSize else {
                throw ConvertError.invalidPageSize(size: page.count)
            }
            let value = page.withUnsafeBytes {
                CellIdentifier.RawValue(bigEndian: $0.load(as: CellIdentifier.RawValue.self))
            }
            guard let cell = CellIdentifier(rawValue: value) else {
                throw ConvertError.invalidCellIdentifier(value: value)
            }
            cells.append(cell)
        }
        
        return .init(cells)
    }
}

public extension CellCollectionConvertible where Self == CompressedCells {
    static func compressedCells(url: URL) throws -> CompressedCells {
        try .init(url: url)
    }
}

fileprivate extension CompressedCells {
    enum ConvertError: LocalizedError {
        case invalidPageSize(size: Int)
        case invalidCellIdentifier(value: CellIdentifier.RawValue)
    }
    
    static let pageSize = MemoryLayout<CellIdentifier.RawValue>.size
}
