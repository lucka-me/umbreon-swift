//
//  AreaMeasurable.swift
//  UmbreonCore
//
//  Created by Lucka on 24/8/2025.
//

import Foundation

public protocol AreaMeasurable {
    var area: Double { get }
}

public extension AreaMeasurable {
    var areaMeasurement: Measurement<UnitArea> {
        .init(value: area, unit: .squareMeters).converted(to: .squareKilometers)
    }
}
