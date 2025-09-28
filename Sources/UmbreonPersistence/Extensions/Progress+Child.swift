//
//  Progress+Child.swift
//  UmbreonPersistence
//
//  Created by Lucka on 25/8/2025.
//

import Foundation

extension Progress {
    func addChild(for unitCount: Int64, as pendingUnitCount: Int64) -> Progress {
        let child = Progress(totalUnitCount: unitCount)
        self.addChild(child, withPendingUnitCount: pendingUnitCount)
        return child
    }
    
    func addChild(as pendingUnitCount: Int64) -> Progress {
        let child = Progress()
        self.addChild(child, withPendingUnitCount: pendingUnitCount)
        return child
    }
}
