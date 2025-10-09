//
//  BaseMapAppearanceDefaults.swift
//  UmbreonAppUI
//
//  Created by Lucka on 16/11/2024.
//

import SwiftUI

#if canImport(MapboxMaps)
import MapboxMaps
#else
import MapKit
#endif

final class BaseMapAppearanceDefaults : ObservableObject {
    @AppStorage("BaseMapAppearance.Style")
    var style = Style.satellite
    
#if canImport(MapboxMaps)
    @AppStorage("BaseMapAppearance.LightPreset")
    var lightPreset = LightPreset.automatic
#endif
    
    private init() {
    }
}

extension BaseMapAppearanceDefaults {
    @MainActor
    static let shared = BaseMapAppearanceDefaults()
    
    enum Style : Int {
        case standard = 0
        case satellite = 1
        case hybrid = 2
    }
    
#if canImport(MapboxMaps)
    enum LightPreset : Int {
        case automatic = 0
        case light = 1
        case dark = 2
    }
#endif
}

extension BaseMapAppearanceDefaults {
    func resolvedMapStyle(in colorScheme: ColorScheme) -> MapStyle {
#if canImport(MapboxMaps)
        switch style {
        case .standard:
            .standard(lightPreset: maplLightPreset(in: colorScheme))
        case .satellite:
            .standardSatellite(
                lightPreset: maplLightPreset(in: colorScheme),
                showPointOfInterestLabels: false,
                showTransitLabels: false,
                showPlaceLabels: false,
                showRoadLabels: false,
                showRoadsAndTransit: false,
                showPedestrianRoads: false
            )
        case .hybrid:
            .standardSatellite(
                lightPreset: maplLightPreset(in: colorScheme),
                showPointOfInterestLabels: true,
                showTransitLabels: true,
                showPlaceLabels: true,
                showRoadLabels: true,
                showRoadsAndTransit: true,
                showPedestrianRoads: true
            )
        }
#else
        switch style {
        case .standard: .standard(elevation: .realistic)
        case .satellite: .imagery(elevation: .realistic)
        case .hybrid: .hybrid(elevation: .realistic)
        }
#endif
    }
}

extension BaseMapAppearanceDefaults.Style : CaseIterable, Identifiable {
    var id: RawValue {
        rawValue
    }
    
    var titleKey: LocalizedStringKey {
        switch self {
        case .standard:
            "MapAppearanceDefaults.Style.Standard"
        case .satellite:
            "MapAppearanceDefaults.Style.Satellite"
        case .hybrid:
            "MapAppearanceDefaults.Style.Hybrid"
        }
    }
}

#if canImport(MapboxMaps)
extension BaseMapAppearanceDefaults.LightPreset : CaseIterable, Identifiable {
    var id: RawValue {
        rawValue
    }
    
    var titleKey: LocalizedStringKey {
        switch self {
        case .automatic:
            "MapAppearanceDefaults.LightPreset.Automatic"
        case .light:
            "MapAppearanceDefaults.LightPreset.Light"
        case .dark:
            "MapAppearanceDefaults.LightPreset.Dark"
        }
    }
}
#endif

#if canImport(MapboxMaps)
fileprivate extension BaseMapAppearanceDefaults {
    private func maplLightPreset(in colorScheme: ColorScheme) -> StandardLightPreset {
        switch lightPreset {
        case .automatic:
            switch colorScheme {
            case .dark: .night
            default: .day
            }
        case .light:
            .day
        case .dark:
            .night
        }
    }
}
#endif
