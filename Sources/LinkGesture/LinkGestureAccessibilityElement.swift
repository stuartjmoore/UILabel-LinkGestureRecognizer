//
//  LinkGestureAccessibilityElement.swift
//
//
//  Created by Stuart Moore on 1/12/22.
//

import UIKit

/// A simple protocol to mask the full gesture recognizer from `LinkGestureAccessibilityElement`.
internal protocol LinkFinder: AnyObject {
    func findLinkRect(for: Int) -> CGRect?
}

/// An accessibility element capturing the link’s index in order to defer the rect calculation until called upon.
internal class LinkGestureAccessibilityElement: UIAccessibilityElement {

    /// The parent object that can find the link’s rect.
    weak var linkFinder: LinkFinder?

    /// The index of the link this element represents.
    var linkIndex: Int?

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

            if let linkIndex = linkIndex {
                newValue = linkFinder?.findLinkRect(for: linkIndex) ?? .null
            } else {
                newValue = (accessibilityContainer as? UILabel)?.bounds ?? .null
            }

            return newValue
        } set {
            super.accessibilityFrameInContainerSpace = newValue
        }
    }

}
