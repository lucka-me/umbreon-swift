//
//  RegionStatistic.swift
//  UmbreonCore
//
//  Created by Lucka on 14/10/2024.
//

import Foundation
import SwiftData

@Model
public class RegionStatistic {
    public var visible: Bool = true
    
    public private(set) var discoveredArea: Double
    
    private(set) var countryCode: String = ""
    private(set) var subdivisionCode: String? = nil
    
    public init(regionCode: RegionCode, discoveredArea: Double) {
        self.discoveredArea = discoveredArea
        self.countryCode = regionCode.countryCode
        self.subdivisionCode = regionCode.subdivisionCode
    }
}

public extension RegionStatistic {
    func addDiscoveredArea(_ addedArea: Double) {
        self.discoveredArea += addedArea
    }
    
    func resetDiscoveredArea() {
        self.discoveredArea = 0
    }
}

extension RegionStatistic : DiscoveryMeasurable {
}

extension RegionStatistic : RegionReferencable {
    public var regionCode: RegionCode {
        .init(countryCode: countryCode, subdivisionCode: subdivisionCode)
    }
}
