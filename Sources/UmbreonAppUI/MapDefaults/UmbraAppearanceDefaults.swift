//
//  UmbraAppearanceDefaults.swift
//  UmbreonAppUI
//
//  Created by Lucka on 22/3/2025.
//

import SwiftUI

#if canImport(MapboxMaps)
import MapboxMaps
#endif

final class UmbraAppearanceDefaults : ObservableObject {
    @AppStorage("UmbraAppearance.FillStyle")
    var fillStyle = FillStyle.umbra
    
    @AppStorage("UmbraAppearance.Opacity")
    var opacity: Double = 0.6
    
    private init() {
    }
}

extension UmbraAppearanceDefaults {
    @MainActor
    static let shared = UmbraAppearanceDefaults()
}

extension UmbraAppearanceDefaults {
#if canImport(MapboxMaps)
    func color(in colorScheme: ColorScheme) -> UIColor {
        switch fillStyle {
        case .automatic:
            switch colorScheme {
            case .light: .white
            case .dark: .black
            default: .black
            }
        case .umbra: .black
        case .mist: .white
        }
    }
#else
    func color(in colorScheme: ColorScheme) -> Color {
        let resolvedColor: Color = switch fillStyle {
        case .automatic:
            switch colorScheme {
            case .light: .white
            case .dark: .black
            default: .black
            }
        case .umbra: .black
        case .mist: .white
        }
        
        return resolvedColor.opacity(opacity)
    }
#endif
}

extension UmbraAppearanceDefaults {
    enum FillStyle : Int, CaseIterable, Identifiable {
        case automatic = 0
        case umbra = 1
        case mist = 2
        
        var id: RawValue {
            rawValue
        }
        
        var titleKey: LocalizedStringKey {
            switch self {
            case .automatic:
                "UmbraAppearanceDefaults.FillStyle.Automatic"
            case .umbra:
                "UmbraAppearanceDefaults.FillStyle.Umbra"
            case .mist:
                "UmbraAppearanceDefaults.FillStyle.Mist"
            }
        }
    }
}
