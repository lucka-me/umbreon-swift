//
//  FogOfWorldSnapshot.swift
//  UmbreonPersistence
//
//  Created by Lucka on 5/9/2024.
//

import Foundation
import SphereGeometry
import ZIPFoundation

public actor FogOfWorldSnapshot : CellCollectionConvertible {
    public let progress: Progress
    
    private let archive: Archive
    private let entries: [ Entry ]
    
    fileprivate init(url: URL) throws {
        self.archive = try .init(url: url, accessMode: .read)
        self.entries = archive.filter {
            $0.path.starts(with: "Model/*/")
        }
        // extract + parse
        self.progress = .init(totalUnitCount: .init(entries.count * 2))
    }
    
    public func convert() async throws -> CellCollection {
        let extractedEntries = try entries.map { entry in
            let path = entry.path
            guard let url = URL(string: path) else {
                throw CocoaError(.fileReadInvalidFileName, userInfo: [ NSFilePathErrorKey : path ])
            }
            var data = Data()
            let _ = try archive.extract(entry) { data.append($0) }
            
            progress.completedUnitCount += 1
            return CompressedEntry(url: url, content: data)
        }
        
        return try await withThrowingTaskGroup(of: CellCollection.self) { @Sendable group in
            for entry in extractedEntries {
                group.addTask {
                    try FogOfWorldSyncs.convert(compressed: entry.content, from: entry.url)
                }
            }
            
            return try await group.reduce(into: .init()) { result, element in
                result.formUnion(element)
                progress.completedUnitCount += 1
            }
        }
    }
}

public extension CellCollectionConvertible where Self == FogOfWorldSnapshot {
    static func fogOfWorldSnapshot(url: URL) throws -> FogOfWorldSnapshot {
        try .init(url: url)
    }
}

fileprivate struct CompressedEntry: Sendable {
    let url: URL
    let content: Data
}
