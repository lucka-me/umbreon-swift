//
//  RegionReferencable.swift
//  UmbreonCore
//
//  Created by Lucka on 23/8/2025.
//

public protocol RegionReferencable {
    var regionCode: RegionCode { get }
}

public extension RegionReferencable {
    var region: Region {
        RegionProvider.shared[regionCode]
    }
}

public extension RegionReferencable where Self : DiscoveryMeasurable {
    var discoveryProgress: Double {
        discoveredArea / region.area
    }
}
