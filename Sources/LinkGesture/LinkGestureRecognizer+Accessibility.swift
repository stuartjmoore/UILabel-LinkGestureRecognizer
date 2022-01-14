//
//  File.swift
//  
//
//  Created by Stuart Moore on 1/12/22.
//

import UIKit

extension LinkGestureRecognizer: LinkFinder {

    /// Loop through the links and append a new `LinkGestureAccessibilityElement`
    /// for each one, as well as the overall static text, if `overridesAccessibility` is `true`.
    ///
    /// The rect of the element won’t be generated until the system calls upon them.
    internal func generateAccessibilityElements() {
        guard overridesAccessibility,
              let label = label,
              let attributedText = label.attributedText else {
            return
        }

        var accessibilityElements: [LinkGestureAccessibilityElement] = []

        let fullRange = NSRange(location: 0, length: attributedText.length)

        attributedText.enumerateAttribute(.inlineLink, in: fullRange, options: .longestEffectiveRangeNotRequired) { (value, range, _) in
            guard value != nil else {
                return
            }

            let linkAccessibilityElement = LinkGestureAccessibilityElement(accessibilityContainer: label)
            linkAccessibilityElement.linkIndex = accessibilityElements.count
            linkAccessibilityElement.linkFinder = self
            linkAccessibilityElement.isAccessibilityElement = true
            linkAccessibilityElement.accessibilityTraits = .link
            linkAccessibilityElement.accessibilityAttributedLabel = attributedText.attributedSubstring(from: range)
            linkAccessibilityElement.accessibilityIdentifier = "link-gesture.link.index-\(accessibilityElements.count)"
            accessibilityElements.append(linkAccessibilityElement)
        }

        let staticTextAccessibilityElement = LinkGestureAccessibilityElement(accessibilityContainer: label)
        staticTextAccessibilityElement.linkIndex = nil
        staticTextAccessibilityElement.linkFinder = self
        staticTextAccessibilityElement.isAccessibilityElement = true
        staticTextAccessibilityElement.accessibilityTraits = .staticText
        staticTextAccessibilityElement.accessibilityAttributedLabel = label.attributedText
        staticTextAccessibilityElement.accessibilityIdentifier = "link-gesture.link.static-text"
        accessibilityElements.insert(staticTextAccessibilityElement, at: 0)

        label.isAccessibilityElement = false
        label.accessibilityElements = accessibilityElements
    }

    /// Loop through every pixel to find the full extent of each link’s rect.
    ///
    /// Obviously this is not the fastest way to find links, but in order to outline the accessibility
    /// elements, we need the full rects. Because of that, this will only be called by Voice Over once
    /// per cache at the time the label is highlighted.
    internal func findLinkRect(for searchIndex: Int) -> CGRect? {
        guard let label = label, let attributedText = label.attributedText, label.bounds != .zero else {
            return nil
        }

        holdCache = true

        defer {
            holdCache = false
        }

        let startY: CGFloat = 0 // TODO: Start at the top of alpha == 0

        let skipY: CGFloat

        if let font = attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont {
            skipY = font.lineHeight * label.minimumScaleFactor
        } else {
            skipY = 1
        }

        let startX: CGFloat = 0
        let skipX: CGFloat = 1

        for y in stride(from: startY, through: label.bounds.height, by: skipY) {
            for x in stride(from: startX, through: label.bounds.width, by: skipX) {
                let point = CGPoint(x: x, y: y)

                guard let foundIndex = index(of: .inlineLink, atPoint: point) else {
                    continue
                }

                guard foundIndex == searchIndex else {
                    continue
                }

                return scanLinkRect(startingFrom: point, through: label.bounds.size, for: searchIndex)
            }
        }

        return nil
    }

    /// Scan the rect extent of link at `searchIndex` starting from `origin` up through `size`.
    private func scanLinkRect(startingFrom origin: CGPoint, through size: CGSize, for searchIndex: Int) -> CGRect? {
        guard let leadingWidth = scanLinkExtent(startingFrom: origin, through: size, on: \.x, by: -1, for: searchIndex),
              let topHeight = scanLinkExtent(startingFrom: origin, through: size, on: \.y, by: -1, for: searchIndex),
              let trailingWidth = scanLinkExtent(startingFrom: origin, through: size, on: \.x, by: 1, for: searchIndex),
              let bottomHeight = scanLinkExtent(startingFrom: origin, through: size, on: \.y, by: 1, for: searchIndex) else {
            return nil
        }

        return CGRect(x: origin.x - leadingWidth, y: origin.y - topHeight,
                      width: leadingWidth + trailingWidth, height: topHeight + bottomHeight)
    }

    /// Scan the `axis` (x or y) extent in `direction` (leading or trailing) of link at `searchIndex` starting from `origin` up through `size`.
    private func scanLinkExtent(startingFrom origin: CGPoint,
                                through size: CGSize,
                                on axis: WritableKeyPath<CGPoint, CGFloat>,
                                by direction: CGFloat,
                                for searchIndex: Int) -> CGFloat? {
        if origin[keyPath: axis] == 0, direction < 0 {
            return 0
        }

        let strideThrough: StrideThrough<CGFloat>

        if axis == \.x {
            strideThrough = stride(from: origin[keyPath: axis], through: (direction > 0 ? size.width : 0), by: direction)
        } else {
            strideThrough = stride(from: origin[keyPath: axis], through: (direction > 0 ? size.height : 0), by: direction)
        }

        for next in strideThrough {
            var point = origin
            point[keyPath: axis] = next

            guard index(of: .inlineLink, atPoint: point) == searchIndex else {
                return (next - origin[keyPath: axis] - direction) * direction
            }
        }

        return nil
    }

}

