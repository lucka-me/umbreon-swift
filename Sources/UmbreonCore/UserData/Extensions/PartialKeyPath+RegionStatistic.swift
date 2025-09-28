//
//  PartialKeyPath+RegionStatistic.swift
//  UmbreonCore
//
//  Created by Lucka on 2/9/2025.
//

import Foundation

public extension PartialKeyPath<RegionStatistic> {
    static var regionCode: [ PartialKeyPath<RegionStatistic> ] {
        [ \.countryCode, \.subdivisionCode ]
    }
}
