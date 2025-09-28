//
//  CellAlgebra.swift
//  UmbreonAppUI
//
//  Created by Lucka on 4/9/2025.
//

import SphereGeometry

protocol CellAlgebra {
    func relation(with cell: Cell) -> CellRelation
}

enum CellRelation {
    case disjoint
    case intersect
    case contain
}

extension CellAlgebra {
    func cells(at level: Level) -> CellCollection {
        var result: Set<CellIdentifier> = [ ]
        var queue: Candidate.Queue = [ ]
        for element in CellCollection.wholeSphere {
            let cell = element.cell
            switch self.relation(with: cell) {
            case .intersect:
                queue.append(.init(cell: cell, for: self))
            case .contain:
                result.insert(element)
            default:
                break
            }
        }
        
        while let candidate = queue.popLast() {
            result.formUnion(candidate.containedChildren)
            if candidate.cell.level.distance(to: level) > 1 {
                for child in candidate.intersectedChildren {
                    queue.append(.init(cell: child, for: self))
                }
            } else {
                for child in candidate.intersectedChildren {
                    result.insert(child.identifier)
                }
            }
        }
        
        return .init(result)
    }
}

fileprivate struct Candidate {
    typealias Queue = [ Candidate ]
    
    let cell: Cell
    let identifier: CellIdentifier
    
    let intersectedChildren: [ Cell ]
    let containedChildren: [ CellIdentifier ]
    
    init(cell: Cell, for geometry: CellAlgebra) {
        self.cell = cell
        self.identifier = cell.identifier
        
        var intersectedChildren: [ Cell ] = [ ]
        var containedChildren: [ CellIdentifier ] = [ ]
        for child in cell.children {
            switch geometry.relation(with: child) {
            case .intersect:
                intersectedChildren.append(child)
            case .contain:
                containedChildren.append(child.identifier)
            default:
                break
            }
        }
        self.intersectedChildren = intersectedChildren
        self.containedChildren = containedChildren
    }
}
