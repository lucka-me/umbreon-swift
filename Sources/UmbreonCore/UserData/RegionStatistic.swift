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
    
    public private(set) var countryCode: String
    public private(set) var subdivisionCode: String?
    
    public private(set) var area: Double = 0
    public private(set) var discoveredArea: Double
    public private(set) var discoveredProportion: Double = 0
    
    public init(region: Region, discoveredArea: Double) {
        let code = region.code
        self.countryCode = code.countryCode
        self.subdivisionCode = code.subdivisionCode
        
        self.area = region.area
        self.discoveredArea = discoveredArea
        self.discoveredProportion = discoveredArea / region.area
    }
}

public extension RegionStatistic {
    convenience init?(regionCode: RegionCode, discoveredArea: Double) throws {
        guard let region = try RegionProvider.shared.region(of: regionCode) else {
            return nil
        }
        
        self.init(region: region, discoveredArea: discoveredArea)
    }
}

public extension RegionStatistic {
    func addDiscoveredArea(_ addedArea: Double) {
        self.discoveredArea += addedArea
        self.discoveredProportion = self.discoveredArea / self.area
    }
    
    func resetDiscoveredArea() {
        self.discoveredArea = 0
        self.discoveredProportion = 0
        self.area = self.region.area
    }
}

extension RegionStatistic : AreaMeasurable, DiscoveryMeasurable {
}

extension RegionStatistic : RegionReferencable {
    public var regionCode: RegionCode {
        .init(countryCode: countryCode, subdivisionCode: subdivisionCode)
    }
}
