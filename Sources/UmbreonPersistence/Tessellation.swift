//
//  Tessellation.swift
//  UmbreonPersistence
//
//  Created by Lucka on 11/10/2024.
//

import Compression
import Foundation
import SphereGeometry
import UmbreonCore

public actor Tessellation {
    private let cache = NSCache<RegionCode.CacheKey, CellCollection.CacheObject>()
    
    public init(cachePolicy: CachePolicy = .init()) {
        self.cache.totalCostLimit = cachePolicy.costLimit
        self.cache.countLimit = cachePolicy.countLimit
    }
}

public extension Tessellation {
    struct CachePolicy {
        fileprivate let costLimit: Int
        fileprivate let countLimit: Int
        
        public init(sizeLimit: Int = 10 * 1024 * 1024, countLimit: Int = 0) {
            self.costLimit = sizeLimit / MemoryLayout<CellIdentifier.RawValue>.size
            self.countLimit = countLimit
        }
    }
    
    func group(
        cells: CellCollection,
        reporting progress: Progress? = nil
    ) -> [ RegionCode : CellCollection ] {
        progress?.totalUnitCount = .init(cells.count)
        progress?.completedUnitCount = 0
        
        var queue = cells
        var result: [ RegionCode : CellCollection ] = [ : ]
        
        while let cell = queue.first {
            guard let indexCell = cell.parent(at: Self.indexCellLevel) else {
                // TODO: Query the whole...
                continue
            }
            
            defer {
                progress?.completedUnitCount = .init(cells.count - queue.count)
            }
            
            if let candidates = Self.cellIndex[indexCell] {
                // Split to available regions
                for candidate in candidates where !queue.isEmpty {
                    let object = load(region: candidate)
                    let partition = queue.partition(by: object.object)
                    if !partition.intersection.isEmpty {
                        result
                            .updateValue(
                                result[candidate, default: .init()]
                                    .union(partition.intersection),
                                forKey: candidate
                            )
                    }
                    queue = partition.difference
                }
            }
            
            if !queue.isEmpty {
                // The rest cells are in ocean
                let partition = queue.partition(by: [ indexCell ])
                if !partition.intersection.isEmpty {
                    result
                        .updateValue(
                            result[.ocean, default: .init()]
                                .union(partition.intersection),
                            forKey: .ocean
                        )
                }
                queue = partition.difference
            }
        }
        
        return result
    }
}

fileprivate extension Tessellation {
    static let indexCellLevel = Level.at.5
    
    static let cellIndex = try! JSONDecoder().decode(
        [ CellIdentifier : [ RegionCode ] ].self,
        from: .init(
            contentsOf: #bundle.url(forResource: "cover-index", withExtension: "json")!
        )
    )
    
    func load(region code: RegionCode) -> CellCollection.CacheObject {
        let key = code.cacheKey
        if let object = cache.object(forKey: key) {
            return object
        }
        
        let sourceHandle = try! FileHandle(
            forReadingFrom: #bundle
                .url(
                    forResource: code.rawValue,
                    withExtension: "cells-lzfse",
                    subdirectory: "covers"
                )!
        )
        let inputFilter = try! InputFilter(.decompress, using: .lzfse) { length in
            try sourceHandle.read(upToCount: length)
        }
        var data = Data()
        while let page = try! inputFilter.readData(ofLength: 1024 * 1024) {
            data.append(page)
        }
        let object = CellCollection
            .guaranteed(
                cells: data.withUnsafeBytes { .init($0.bindMemory(to: CellIdentifier.self)) }
            )
            .cacheObject
        cache.setObject(object, forKey: key, cost: object.object.count)
        return object
    }
}

fileprivate class NSCacheKey<T: Hashable> : NSObject {
    let key: T
    
    init(_ key: T) {
        self.key = key
    }
    
    override var hash: Int {
        key.hashValue
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Self else {
            return false
        }
        return self.key == other.key
    }
}

fileprivate class NSCacheObject<T> {
    let object: T
    
    init(_ object: T) {
        self.object = object
    }
}

fileprivate extension RegionCode {
    typealias CacheKey = NSCacheKey<Self>
    
    var cacheKey: CacheKey {
        .init(self)
    }
}

fileprivate extension CellCollection {
    typealias CacheObject = NSCacheObject<Self>
    
    var cacheObject: CacheObject {
        .init(self)
    }
}

