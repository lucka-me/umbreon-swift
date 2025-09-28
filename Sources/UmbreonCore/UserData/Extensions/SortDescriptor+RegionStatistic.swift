//
//  SortDescriptor+RegionStatistic.swift
//  UmbreonCore
//
//  Created by Lucka on 20/8/2025.
//

import Foundation

public extension SortDescriptor<RegionStatistic> {
    static func byCountryCode(order: SortOrder = .forward) -> Self {
        .init(\.countryCode, order: order)
    }
    
    static func bySubdivisionCode(order: SortOrder = .forward) -> Self {
        .init(\.subdivisionCode, order: order)
    }
}

public extension Array<SortDescriptor<RegionStatistic>> {
    static func byRegionCode(order: SortOrder = .forward) -> Self {
        [
            .byCountryCode(order: order),
            .bySubdivisionCode(order: order)
        ]
    }
}
