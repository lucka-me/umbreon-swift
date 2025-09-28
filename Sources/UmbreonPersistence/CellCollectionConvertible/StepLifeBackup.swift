//
//  StepLifeBackup.swift
//  UmbreonPersistence
//
//  Created by Lucka on 27/8/2025.
//

import Foundation
import SphereGeometry
import Turf
import UmbreonCore

public actor StepLifeBackup : CellCollectionConvertible {
    public let progress: Progress
    
    private let handle: FileHandle
    private let progressStride: Int64
    
    private let distanceThreshold: Double
    
    fileprivate init(url: URL, distanceThreshold: Double) throws {
        self.handle = try .init(forReadingFrom: url)
        self.progress = .init(totalUnitCount: .init(try self.handle.seekToEnd()))
        try self.handle.seek(toOffset: 0)
        self.progressStride = self.progress.totalUnitCount / 200
        
        self.distanceThreshold = distanceThreshold
    }
    
    public func convert() async throws -> CellCollection {
        try await handle.bytes.lines
            .map { line -> LocationCoordinate2D? in
                let offset = Int64(try self.handle.offset())
                if offset - self.progress.completedUnitCount >= self.progressStride {
                    self.progress.completedUnitCount = offset
                }
                
                let columns = line.split(separator: ",")
                return if
                    columns.count > 3,
                    let longitude = LocationDegrees(columns[2]),
                    let latitude = LocationDegrees(columns[3])
                {
                    .init(latitude: latitude, longitude: longitude)
                } else {
                    nil
                }
            }
            .strideCells(
                at: PartialCellCollection.detailedLevel,
                breakWhenFurtherThan: distanceThreshold
            )
    }
}

public extension CellCollectionConvertible where Self == StepLifeBackup {
    static func stepLifeBackup(url: URL, distanceThreshold: Double) throws -> StepLifeBackup {
        try .init(url: url, distanceThreshold: distanceThreshold)
    }
}
