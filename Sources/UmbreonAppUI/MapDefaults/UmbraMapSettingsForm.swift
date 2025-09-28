//
//  UmbraMapSettingsForm.swift
//  UmbreonAppUI
//
//  Created by Lucka on 16/11/2024.
//

import SwiftUI

public struct UmbraMapSettingsForm : View {
    public init() {
    }
    
    public var body: some View {
        Form {
            Section(.init("UmbraMapSettingsForm.BaseMap.Title", bundle: #bundle)) {
                BaseMapSectionContent()
            }
            
            Section(.init("UmbraMapSettingsForm.Umbra.Title", bundle: #bundle)) {
                UmbraSectionContent()
            }
            
#if os(iOS)
            Section(.init("UmbraMapSettingsForm.Preview.Title", bundle: #bundle)) {
                // TODO: Generate some example cells
                UmbraMap(dataset: .cached(cells: [ ]))
                    .frame(height: 240)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
#endif
        }
        .navigationTitle(Self.titleResource)
    }
}

public extension UmbraMapSettingsForm {
    static var systemImageName: String { "wand.and.sparkles" }
    
    static var titleResource: LocalizedStringResource {
        .init("UmbraMapSettingsForm.Title", bundle: #bundle)
    }
}

fileprivate struct BaseMapSectionContent : View {
    private typealias Defaults = BaseMapAppearanceDefaults
    
    @StateObject private var defaults = Defaults.shared
    
    var body: some View {
        Picker(
            .init("UmbraMapSettingsForm.BaseMap.Style", bundle: #bundle),
            systemImage: "map",
            selection: $defaults.style
        ) {
            ForEach(Defaults.Style.allCases) { item in
                Text(item.titleKey, bundle: #bundle)
                    .tag(item)
            }
        }
        
#if os(iOS)
        Picker(
            .init("UmbraMapSettingsForm.BaseMap.Light", bundle: #bundle),
            systemImage: "rays",
            selection: $defaults.lightPreset
        ) {
            ForEach(Defaults.LightPreset.allCases) { item in
                Text(item.titleKey, bundle: #bundle)
                    .tag(item)
            }
        }
#endif
    }
}

fileprivate struct UmbraSectionContent : View {
    private typealias Defaults = UmbraAppearanceDefaults
    
    @State private var isOpacityPopoverPresented = false
    
    @StateObject private var defaults = Defaults.shared
    
    var body: some View {
        Picker(
            .init("UmbraMapSettingsForm.Umbra.FillStyle", bundle: #bundle),
            systemImage: "circle.lefthalf.filled",
            selection: $defaults.fillStyle
        ) {
            ForEach(Defaults.FillStyle.allCases) { item in
                Text(item.titleKey, bundle: #bundle)
                    .tag(item)
            }
        }
        
#if os(iOS)
        LabeledContent {
            opacitySlider
        } label: {
            opacityLabel
        }
#else
        opacitySlider
#endif
    }
    
    @ViewBuilder
    var opacitySlider: some View {
        if #available(iOS 26, macOS 26, *) {
            Slider(value: $defaults.opacity, in: 0 ... 1, step: 0.05) {
                opacityLabel
            } tick: { value in
                SliderTick(value)
            }
        } else {
            Slider(value: $defaults.opacity, in: 0 ... 1, step: 0.05) {
                opacityLabel
            }
        }
    }
    
    @ViewBuilder
    var opacityLabel: some View {
        Label(
            .init("UmbraMapSettingsForm.Umbra.Opacity", bundle: #bundle),
            systemImage: "slider.horizontal.below.square.and.square.filled"
        )
    }
}

