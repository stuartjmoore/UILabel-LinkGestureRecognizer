//
//  LinkGestureRecognizer.swift
//
//
//  Created by Stuart Moore on 1/12/22.
//

import UIKit

/// Allow consumers to respond to taps on `UILabel` where the text range is
/// marked as `NSAttributedString.Key.inlineLink` with an underlying URL.
///
/// On touch down, the link text color will be set to the corresponding
/// `NSAttributedString.Key.highlightColor` or fade its original
/// color by 40%.
///
/// # Usage
///
/// ```
/// let linkGestureRecognizer = LinkGestureRecognizer(target: self, action: #selector(handleLinkTap))
/// label.addGestureRecognizer(linkGestureRecognizer)
///
/// label.attributedText = // An attributed string with `inlineLink` ranges
///
/// @objc func handleLinkTap(_ gestureRecognizer: LinkGestureRecognizer) {
///     // handle gestureRecognizer.url in gestureRecognizer.range (UTF-16)
/// }
/// ```
public final class LinkGestureRecognizer: UIGestureRecognizer {

    /// Whether or not this class should set the accessibility elements of the attached label. Defaults to `true`.
    public var overridesAccessibility: Bool = true

    /// Whether we should skip searching for the full extent of a link or not. Defaults to `true`.
    ///
    /// This can come in handy when links use multiple fonts or colors in their text,
    /// but skipping the longest range may speed things up slightly.
    public var longestEffectiveRangeNotRequired: Bool = true {
        didSet {
            assertionFailure("Not yet implemented")
        }
    }

    // MARK: Touched Link Properties

    /// The tapped URL.
    public private(set) var url: URL?

    /// The range of the tapped text. Measured in UTF-16.
    public private(set) var utf16Range: NSRange?

    /// The captured `foregroundColor` set over the link range as touches began.
    private var originalColor: UIColor?

    /// The captured `highlightColor` set over the link range as touches began.
    private var highlightColor: UIColor?

    // MARK: Cache

    /// The “Duck Hunt” data of the drawn label.
    ///
    /// See `duckHuntAttributedString(for:lookupTable:)` below.
    private var imageData: [NSAttributedString.Key: CFData] = [:]

    /// A table of link indexes to UTF-16 ranges provided by the “Duck Hunt” image.
    private var rangeLookupTable: [NSRange] = []

    // MARK: -

    /// An observation to update `label` when `view` is set.
    ///
    /// # Note
    /// Overriding `view` directly in iOS 15 causes this gesture to stop recognizing.
    private var viewObservation: NSKeyValueObservation!

    /// A set of label observations to clear the cache on text or size changes.
    private var labelObservations: Set<NSKeyValueObservation> = []

    // MARK: -

    /// The label this gesture was added to.
    ///
    /// On add, the label’s `isUserInteractionEnabled` is set to `true`
    /// and its `accessibilityElements` is set to an array of
    /// `LinkGestureAccessibilityElement` objects for each link
    /// (if `overridesAccessibility` is `true`).
    ///
    /// Same instance as `view`, but typed as `UILabel`.
    internal weak var label: UILabel? {
        didSet {
            if let label = label {
                label.isUserInteractionEnabled = true

                let attributedTextObservation = label.observe(\.attributedText) { [unowned self] (_, _) in
                    guard numberOfTouches == 0 else {
                        return
                    }

                    resetCache()
                }

                let boundsObservation = label.observe(\.bounds) { [unowned self] (_, _) in
                    guard numberOfTouches == 0 else {
                        return
                    }

                    resetCache()
                }

                labelObservations = [attributedTextObservation, boundsObservation]
            } else {
                labelObservations = []
            }

            resetCache()
        }
    }

    // MARK: -

    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)

        viewObservation = observe(\.view) { [unowned self] (_, _) in
            if let newLabel = view as? UILabel {
                label = newLabel
            } else if view == nil {
                label = nil
            } else {
                preconditionFailure("`LinkGestureRecognizer` may only be used on a `UILabel`")
            }
        }
    }

    // MARK: - Cache

    /// The label’s attributed string may be toggled back and forth, potentially busting the cache.
    /// This flag will break early to maintain the cache.
    internal var holdCache: Bool = false

    /// A small convenience to maintain the cache. Useful to reset text color outside of touches.
    private func performWithoutClearingCache(_ closure: () -> Void) {
        let previousHoldCache = holdCache

        holdCache = true
        closure()

        holdCache = previousHoldCache
    }

    /// When the label’s text or size changes, delete the image data, matching lookup table,
    /// and regenerate the accessibility elements.
    private func resetCache() {
        guard !holdCache else {
            return
        }

        imageData = [:]
        rangeLookupTable = []

        generateAccessibilityElements()
    }

    // MARK: - Touches

    /// On touch down, inspect only that point for a link. If so, highlight it.
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        guard touches.count == 1,
              let touch = touches.first,
              let label = label,
              let attributedString = label.attributedText else {
            return (state = .failed)
        }

        let touchLocation = touch.location(in: label)

        guard let linkRange = utf16Range(of: .inlineLink, atPoint: touchLocation),
              let linkURL = attributedString.attribute(.inlineLink, at: linkRange.location, effectiveRange: nil) as? URL else {
            return (state = .failed)
        }

        self.url = linkURL
        self.utf16Range = linkRange

        let otherAttributes = attributedString.attributes(at: linkRange.location, effectiveRange: nil)
        self.originalColor = otherAttributes[.foregroundColor] as? UIColor
        self.highlightColor = otherAttributes[.highlightColor] as? UIColor ?? originalColor?.withAlphaComponent(0.4)

        applyHighlightColor()
    }

    /// On pan, update the highlight color as the touch enters and exits the link.
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        guard touches.count == 1,
              let touch = touches.first else {
            return (state = .failed)
        }

        let touchLocation = touch.location(in: view)
        let linkRange = utf16Range(of: .inlineLink, atPoint: touchLocation)

        let previousTouchLocation = touch.previousLocation(in: view)
        let previousLinkRange = utf16Range(of: .inlineLink, atPoint: previousTouchLocation)

        if linkRange == utf16Range, previousLinkRange != utf16Range {
            applyHighlightColor()
        } else if linkRange != utf16Range, previousLinkRange == utf16Range {
            resetTextColor()
        }
    }

    /// On touch up, recognize or fail the touch.
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        guard touches.count == 1, let touch = touches.first else {
            return (state = .failed)
        }

        let touchLocation = touch.location(in: view)
        let linkRange = utf16Range(of: .inlineLink, atPoint: touchLocation)

        if linkRange == utf16Range {
            state = .recognized
        } else {
            state = .failed
        }
    }

    /// On cancel, fail or cancel the touch.
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)

        guard touches.count == 1 else {
            return (state = .failed)
        }

        state = .cancelled
    }

    /// Reset the overall state of the link capture.
    override public func reset() {
        super.reset()

        performWithoutClearingCache {
            resetTextColor()
        }

        url = nil
        utf16Range = nil
        originalColor = nil
        highlightColor = nil
    }

    // MARK: - Color

    /// Set the touched link to the appropriate highlight color.
    private func applyHighlightColor() {
        guard let highlightColor = highlightColor,
              let range = utf16Range,
              let label = label,
              let attributedString = label.attributedText else {
            return
        }

        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        mutableAttributedString.addAttribute(.foregroundColor, value: highlightColor, range: range)
        label.attributedText = NSAttributedString(attributedString: mutableAttributedString)
    }

    /// Reset the previously touched link back to its original color.
    private func resetTextColor() {
        guard let originalColor = originalColor,
              let range = utf16Range,
              let label = label,
              let attributedString = label.attributedText else {
            return
        }

        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        mutableAttributedString.addAttribute(.foregroundColor, value: originalColor, range: range)
        label.attributedText = NSAttributedString(attributedString: mutableAttributedString)
    }

    // MARK: - Lookup

    /// Return the index of the `attribute` at `point` if present.
    ///
    /// This is done by drawing a “Duck Hunt Attributed String” (see `duckHuntAttributedString(for:lookupTable:)` below)
    /// using the same `UILabel` instance being touched. Doing so renders all of the scaling and wrapping
    /// that `UILabel` does internally. `UILabel` doesn’t give us access to the layout manager, and trying to
    /// mimic our own won’t always line up one-to-one.
    internal func index(of attribute: NSAttributedString.Key, atPoint point: CGPoint) -> Int? {
        guard let label = label, label.bounds.contains(point) else {
            return nil
        }

        let memoryPointer: UnsafePointer<UInt8>

        if let cachedImageData = imageData[attribute] {
            memoryPointer = CFDataGetBytePtr(cachedImageData)
        } else if let imageData = label.drawDuckHuntImage(for: attribute, lookupTable: &rangeLookupTable) {
            memoryPointer = CFDataGetBytePtr(imageData)
            self.imageData[attribute] = imageData
        } else {
            return nil
        }

        let (red, green, blue, alpha) = label.color(at: point, in: memoryPointer)

        guard red == green, green == blue, red != 255, alpha != 0, red < rangeLookupTable.count else {
            return nil
        }

        return red
    }

    /// Return the UTF-16 range of the `attribute` at `point` if present.
    ///
    /// This is done by drawing a “Duck Hunt Attributed String” (see `duckHuntAttributedString(for:lookupTable:)` below)
    /// using the same `UILabel` instance being touched. Doing so renders all of the scaling and wrapping
    /// that `UILabel` does internally. `UILabel` doesn’t give us access to the layout manager, and trying to
    /// mimic our own won’t always line up one-to-one.
    internal func utf16Range(of attribute: NSAttributedString.Key, atPoint point: CGPoint) -> NSRange? {
        guard let foundIndex = index(of: attribute, atPoint: point) else {
            return nil
        }

        return rangeLookupTable[foundIndex]
    }

}
