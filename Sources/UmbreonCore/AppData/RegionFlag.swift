//
//  RegionFlag.swift
//  UmbreonCore
//
//  Created by Lucka on 11/8/2025.
//

import Foundation
import SwiftData

#if canImport(SwiftUI)
import SwiftUI
#endif

@Model
final class RegionFlag {
    private(set) var imageData: Data
    
    private init(imageData: Data) {
        self.imageData = imageData
    }
}

#if canImport(SwiftUI)
extension RegionFlag {
    var image: Image? {
        
    #if canImport(AppKit)
        typealias UnderlyingImage = NSImage
    #elseif canImport(UIKit)
        typealias UnderlyingImage = UIImage
    #endif
        
        guard let underlyingImage = UnderlyingImage(data: imageData) else {
            return nil
        }
    #if canImport(AppKit)
        return .init(nsImage: underlyingImage)
    #elseif canImport(UIKit)
        return .init(uiImage: underlyingImage)
    #endif
    }
}
#endif // canImport(SwiftUI)
