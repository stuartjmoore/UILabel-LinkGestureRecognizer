//
//  File.swift
//  
//
//  Created by Stuart Moore on 1/13/22.
//

import UIKit

@available(iOS 15, *)
public extension AttributeScopes {

    var linkGesture: LinkGestureAttributes.Type { LinkGestureAttributes.self }

    struct LinkGestureAttributes: AttributeScope {
        /// A `AttributedStringKey` to specify the url used by an `inlineLink`.
        public let inlineLink: InlineLinkAttribute

        /// A `AttributedStringKey` to specify the highlight color used by an `inlineLink`.
        public let highlightColor: HighlightColorAttribute

        let uiKit: AttributeScopes.UIKitAttributes

        public enum InlineLinkAttribute: AttributedStringKey {
            public typealias Value = URL
            public static let name = NSAttributedString.Key.inlineLink.rawValue
        }

        public enum HighlightColorAttribute: AttributedStringKey {
            public typealias Value = UIColor
            public static let name = NSAttributedString.Key.highlightColor.rawValue
        }
    }

}

@available(iOS 15, *)
public extension AttributeDynamicLookup {

    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.LinkGestureAttributes, T>) -> T {
        return self[T.self]
    }

}
