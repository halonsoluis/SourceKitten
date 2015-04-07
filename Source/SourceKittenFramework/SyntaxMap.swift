//
//  SyntaxMap.swift
//  SourceKitten
//
//  Created by JP Simard on 2015-01-03.
//  Copyright (c) 2015 SourceKitten. All rights reserved.
//

import Foundation
import SwiftXPC

/// Represents a Swift file's syntax information.
public struct SyntaxMap {
    /// Array of SyntaxToken's.
    public let tokens: [SyntaxToken]

    /**
    Create a SyntaxMap by passing in tokens directly.

    :param: tokens Array of SyntaxToken's.
    */
    public init(tokens: [SyntaxToken]) {
        self.tokens = tokens
    }

    /**
    Create a SyntaxMap by passing in NSData from a SourceKit `editor.open` response to be parsed.

    :param: data NSData from a SourceKit `editor.open` response
    */
    public init(data: NSData) {
        var numberOfTokens = 0
        data.getBytes(&numberOfTokens, range: NSRange(location: 8, length: 8))
        numberOfTokens = numberOfTokens >> 4

        var tmpTokens = [SyntaxToken]()

        for parserOffset in stride(from: 16, through: numberOfTokens * 16, by: 16) {
            var uid = UInt64(0), offset = 0, length = 0
            data.getBytes(&uid, range: NSRange(location: parserOffset, length: 8))
            data.getBytes(&offset, range: NSRange(location: 8 + parserOffset, length: 4))
            data.getBytes(&length, range: NSRange(location: 12 + parserOffset, length: 4))

            tmpTokens.append(
                SyntaxToken(
                    type: stringForSourceKitUID(uid) ?? "unknown",
                    offset: offset,
                    length: length >> 1
                )
            )
        }
        tokens = tmpTokens
    }

    /**
    Create a SyntaxMap from a SourceKit `editor.open` response.

    :param: sourceKitResponse SourceKit `editor.open` response.
    */
    public init(sourceKitResponse: XPCDictionary) {
        self.init(data: SwiftDocKey.getSyntaxMap(sourceKitResponse)!)
    }

    /**
    Create a SyntaxMap from a File to be parsed.

    :param: file File to be parsed.
    */
    public init(file: File) {
        self.init(sourceKitResponse: Request.EditorOpen(file).send())
    }

    /**
    Returns the range of the last contiguous comment-like block from the tokens in `self` prior to
    `offset`.
    
    :param: offset Last possible byte offset of the range's start.
    */
    public func commentRangeBeforeOffset(offset: Int) -> (start: Int, length: Int)? {
        let tokensBeforeOffset = tokens.filter { $0.offset < offset }
        let commentTokensImmediatelyPrecedingOffset = filterLastContiguous(tokensBeforeOffset) {
            SyntaxKind.isCommentLike($0.type)
        }
        return flatMap(commentTokensImmediatelyPrecedingOffset.first) { firstToken in
            return flatMap(commentTokensImmediatelyPrecedingOffset.last) { lastToken in
                return (firstToken.offset, lastToken.offset + lastToken.length - firstToken.offset)
            }
        }
    }
}

// MARK: Printable

extension SyntaxMap: Printable {
    /// A textual JSON representation of `SyntaxMap`.
    public var description: String {
        if let jsonData = NSJSONSerialization.dataWithJSONObject(tokens.map { $0.dictionaryValue },
            options: .PrettyPrinted,
            error: nil) {
            if let jsonString = NSString(data: jsonData, encoding: NSUTF8StringEncoding) as String? {
                return jsonString
            }
        }
        return "[\n\n]" // Empty JSON Array
    }
}

// MARK: Equatable

extension SyntaxMap: Equatable {}

/**
Returns true if `lhs` SyntaxMap is equal to `rhs` SyntaxMap.

:param: lhs SyntaxMap to compare to `rhs`.
:param: rhs SyntaxMap to compare to `lhs`.

:returns: True if `lhs` SyntaxMap is equal to `rhs` SyntaxMap.
*/
public func ==(lhs: SyntaxMap, rhs: SyntaxMap) -> Bool {
    for (index, value) in enumerate(lhs.tokens) {
        if rhs.tokens[index] != value {
            return false
        }
    }
    return true
}
