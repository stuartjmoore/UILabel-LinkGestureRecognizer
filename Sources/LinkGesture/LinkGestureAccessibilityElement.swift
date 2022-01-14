//  Copyright © 2022 CapitalOne. All rights reserved.

import UIKit

/// A simple protocol to mask the full gesture recognizer from `LinkGestureAccessibilityElement`.
internal protocol InlineLinkFinder: AnyObject {
    func findInlineLinkRect(for: Int) -> CGRect?
}

/// An accessibility element capturing the link’s index in order to defer the rect calculation until called upon.
internal class LinkGestureAccessibilityElement: UIAccessibilityElement {

    /// The parent object that can find the inline link’s rect.
    weak var inlineLinkFinder: InlineLinkFinder?

    /// The index of the inline link this element represents.
    var inlineLinkIndex: Int?

    /// If `null` (the default), calling this will calculate the rect of the represented link.
    override var accessibilityFrameInContainerSpace: CGRect {
        get {
            guard super.accessibilityFrameInContainerSpace == .null else {
                return super.accessibilityFrameInContainerSpace
            }

            let newValue: CGRect

            defer {
                super.accessibilityFrameInContainerSpace = newValue
            }

            if let inlineLinkIndex = inlineLinkIndex {
                newValue = inlineLinkFinder?.findInlineLinkRect(for: inlineLinkIndex) ?? .null
            } else {
                newValue = (accessibilityContainer as? UILabel)?.bounds ?? .null
            }

            return newValue
        } set {
            super.accessibilityFrameInContainerSpace = newValue
        }
    }

}
