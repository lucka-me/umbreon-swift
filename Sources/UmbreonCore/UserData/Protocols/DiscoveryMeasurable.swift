//
//  DiscoveryMeasurable.swift
//  UmbreonCore
//
//  Created by Lucka on 22/8/2025.
//

import Foundation

public protocol DiscoveryMeasurable {
    var discoveredArea: Double { get }
}

public extension DiscoveryMeasurable {
    var currentDiscoveryLevelAreaRange: ClosedRange<Double> {
        Self.discoveryLevelAreaRange(of: discoveredArea)
    }
    
    var discoveredAreaMeasurement: Measurement<UnitArea> {
        .init(value: discoveredArea, unit: .squareMeters).converted(to: .squareKilometers)
    }
    
    var discoveryLevel: Int {
        Self.discoveryLevel(of: discoveredArea)
    }
    
    var discoveryLevelProgress: Double {
        let range = currentDiscoveryLevelAreaRange
        return (discoveredArea - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

fileprivate extension DiscoveryMeasurable {
    static func discoveryLevel(of area: Double) -> Int {
        .init(sqrt(area / levelRatio))
    }
    
    static func discoveryLevelAreaRange(of area: Double) -> ClosedRange<Double> {
        let level = discoveryLevel(of: area)
        return Self.upgradeRequirement(for: level) ... Self.upgradeRequirement(for: level + 1)
    }
    
    static func upgradeRequirement(for level: Int) -> Double {
        Double(level) * Double(level) * levelRatio
    }
}

fileprivate let levelRatio: Double = 1E6 / 250
