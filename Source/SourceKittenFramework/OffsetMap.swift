//
//  OffsetMap.swift
//  SourceKitten
//
//  Created by JP Simard on 2015-01-05.
//  Copyright (c) 2015 SourceKitten. All rights reserved.
//

import SwiftXPC

/// Type that maps potentially documented declaration offsets to its closest parent offset.
public typealias OffsetMap = [Int: Int]

/// File methods to generate and manipulate OffsetMap's.
extension File {
    /**
    Creates an OffsetMap containing offset locations at which there are declarations that likely
    have documentation comments, but haven't been documented by SourceKitten yet.

    :param: documentedTokenOffsets Offsets where there are declarations that likely
                                   have documentation comments.
    :param: dictionary             Docs dictionary to check for which offsets are already
                                   documented.

    :returns: OffsetMap containing offset locations at which there are declarations that likely
              have documentation comments, but haven't been documented by SourceKitten yet.
    */
    public func generateOffsetMap(documentedTokenOffsets: [Int], dictionary: XPCDictionary) -> OffsetMap {
        var offsetMap = OffsetMap()
        for offset in documentedTokenOffsets {
            offsetMap[offset] = 0
        }
        offsetMap = mapOffsets(dictionary, offsetMap: offsetMap)
        let alreadyDocumentedOffsets = offsetMap.keys.filter { $0 == offsetMap[$0] }
        for alreadyDocumentedOffset in alreadyDocumentedOffsets {
            offsetMap.removeValueForKey(alreadyDocumentedOffset)
        }
        return offsetMap
    }

    /**
    Creates a new OffsetMap that matches all offsets in the offsetMap parameter's keys to its
    nearest, currently documented parent offset.

    :param: dictionary Already documented dictionary.
    :param: offsetMap  Dictionary mapping potentially documented offsets to its nearest parent
                       offset.

    :returns: OffsetMap of potentially documented declaration offsets to its nearest parent offset.
    */
    private func mapOffsets(dictionary: XPCDictionary, var offsetMap: OffsetMap) -> OffsetMap {
        // Only map if we're in the correct file
        if shouldTreatAsSameFile(dictionary) {
            if let rangeStart = SwiftDocKey.getNameOffset(dictionary),
                rangeLength = SwiftDocKey.getNameLength(dictionary) {
                    let bodyLength = SwiftDocKey.getBodyLength(dictionary)
                    let offsetsInRange = offsetMap.keys.filter {
                        $0 >= Int(rangeStart) && $0 <= Int(rangeStart + rangeLength + (bodyLength ?? 0))
                    }
                    for offset in offsetsInRange {
                        offsetMap[offset] = Int(rangeStart)
                    }
            }
        }
        // Recurse!
        if let substructure = SwiftDocKey.getSubstructure(dictionary) {
            for subDict in substructure {
                offsetMap = mapOffsets(subDict as! XPCDictionary, offsetMap: offsetMap)
            }
        }
        return offsetMap
    }
}
