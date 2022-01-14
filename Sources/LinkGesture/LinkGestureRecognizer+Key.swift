//
//  LinkGestureRecognizer+Key.swift
//
//
//  Created by Stuart Moore on 1/12/22.
//

import Foundation

public extension NSAttributedString.Key {

    /// A `Key` to specify the url used by an `inlineLink`.
    static let inlineLink = Self(rawValue: "link-gesture.attributed-string.key.inline-link")

    /// A `Key` to specify the highlight color used by an `inlineLink`.
    static let highlightColor = Self(rawValue: "link-gesture.attributed-string.key.highlight-color")

}
