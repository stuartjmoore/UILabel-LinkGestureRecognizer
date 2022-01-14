//  Copyright © 2021 Capital One. All rights reserved.

import UIKit

/// Allow consumers to respond to taps on `UILabel` where the text range is
/// marked as `NSAttributedString.Key.link` with an underlying URL.
///
/// On touch down, the link text color will be set to the corresponding
/// `NSAttributedString.Key.highlightColor` or fade its original
/// color by 40%.
///
/// # Usage
///
/// ```
/// let linkGestureRecognizer = LinkGestureRecognizer(target: self, action: #selector(handleInlineLinkTap))
/// label.addGestureRecognizer(linkGestureRecognizer)
///
/// guard let url1 = URL(string: "gravity://test/1"),
///       let url2 = URL(string: "gravity://test/2") else {
///     return
/// }
///
/// label.attributedText = MarkupString(format: "Example %@ and %@.", arguments: [
///     (string: "Link 1", modifier: .link(url: url1)),
///     (string: "Link 2", modifier: .link(url: url2)),
/// ]).attributedString(for: .body)
///
/// @objc func handleInlineLinkTap(_ gestureRecognizer: LinkGestureRecognizer) {
///     // handle gestureRecognizer.url in gestureRecognizer.range (UTF-16)
/// }
/// ```
public final class LinkGestureRecognizer: UIGestureRecognizer {

    /// Whether or not this class should set the accessibility elements of the attached label.
    public var overridesAccessibility: Bool = true

    /// Whether or not we should search for the full extent of a link.
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

    /// The range of the tapped text.
    public private(set) var utf16Range: NSRange?

    /// The `foregroundColor` set over the link range as touches began.
    private var originalColor: UIColor?

    /// The `inlineLinkHighlightColor` set over the link range as touches began.
    private var highlightColor: UIColor?

    // MARK: Cache

    /// The “Duck Hunt” data of the drawn label.
    ///
    /// See `duckHuntAttributedString(for:lookupTable:)` below.
    private var imageData: [NSAttributedString.Key: CFData] = [:]

    /// A table of inline link index to UTF-16 range provided by the “Duck Hunt” image.
    private var rangeLookupTable: [NSRange] = []

    // MARK: -

    /// An observation to update `label` when `view` is set.
    ///
    /// # Note
    /// Overriding `view` directly in iOS 15 causes this gesture to stop recognizing.
    private var viewObservation: NSKeyValueObservation!

    /// A set of label observations to bust the cache on text or size changes.
    private var labelObservations: Set<NSKeyValueObservation> = []

    // MARK: -

    /// The label this gesture was added to.
    ///
    /// On add, the label’s `isUserInteractionEnabled` is set to `true`
    /// and its `accessibilityElements` are set to an array of
    /// `InlineLinkAccessibilityElement` for each inline link (if
    /// `overridesAccessibility` is `true`).
    ///
    /// Same object as `view`, but typed to `UILabel`.
    private weak var label: UILabel? {
        didSet {
            if let label = label {
                label.isUserInteractionEnabled = true

                let attributedTextObservation = label.observe(\.attributedText) { [unowned self] (_, _) in
                    guard !holdCache, numberOfTouches == 0 else {
                        return
                    }

                    resetCache()
                }

                let boundsObservation = label.observe(\.bounds) { [unowned self] (_, _) in
                    guard !holdCache, numberOfTouches == 0 else {
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
    /// This flag will break early in the observations to maintain the cache.
    private var holdCache: Bool = false

    /// A small convenience to maintain the cache. Useful to reset text color outside of touches.
    private func performWithoutClearingCache(_ closure: () -> Void) {
        let previousHoldCache = holdCache

        holdCache = true
        closure()

        holdCache = previousHoldCache
    }

    /// When the label’s text or size changes, delete the image cache & parallel lookup table
    /// and regenerate the accessibility elements.
    private func resetCache() {
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

        guard let linkRange = utf16Range(of: .link, atPoint: touchLocation, index: nil),
              let linkURL = attributedString.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL else {
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
        let linkRange = utf16Range(of: .link, atPoint: touchLocation, index: nil)

        let previousTouchLocation = touch.previousLocation(in: view)
        let previousLinkRange = utf16Range(of: .link, atPoint: previousTouchLocation, index: nil)

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
        let linkRange = utf16Range(of: .link, atPoint: touchLocation, index: nil)

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
    private func index(of attribute: NSAttributedString.Key, atPoint point: CGPoint) -> Int? {
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

    /// Return the UTF-16 range start location of the `attribute` at `point` if present.
    ///
    /// This is done by drawing a “Duck Hunt Attributed String” (see `duckHuntAttributedString(for:lookupTable:)` below)
    /// using the same `UILabel` instance being touched. Doing so renders all of the scaling and wrapping
    /// that `UILabel` does internally. `UILabel` doesn’t give us access to the layout manager, and trying to
    /// mimic our own won’t always line up one-to-one.
    private func utf16Range(of attribute: NSAttributedString.Key,
                            atPoint point: CGPoint,
                            index indexPointer: UnsafeMutablePointer<Int>?) -> NSRange? {
        guard let foundIndex = index(of: attribute, atPoint: point) else {
            return nil
        }

        indexPointer?.initialize(to: foundIndex)
        return rangeLookupTable[foundIndex]
    }

}

// MARK: - Accessibility

extension LinkGestureRecognizer: InlineLinkFinder {

    /// Loop through the inline links and append a new `LinkGestureAccessibilityElement`
    /// for each one, as well as the overall static text, if `overridesAccessibility` is `true`.
    ///
    /// The rect of the element won’t be generated until the system calls upon them.
    private func generateAccessibilityElements() {
        guard overridesAccessibility,
              let label = label,
              let attributedText = label.attributedText else {
            return
        }

        var accessibilityElements: [LinkGestureAccessibilityElement] = []

        let fullRange = NSRange(location: 0, length: attributedText.length)

        attributedText.enumerateAttribute(.link, in: fullRange, options: .longestEffectiveRangeNotRequired) { (value, range, _) in
            guard value != nil else {
                return
            }

            let linkAccessibilityElement = LinkGestureAccessibilityElement(accessibilityContainer: label)
            linkAccessibilityElement.inlineLinkIndex = accessibilityElements.count
            linkAccessibilityElement.inlineLinkFinder = self
            linkAccessibilityElement.isAccessibilityElement = true
            linkAccessibilityElement.accessibilityTraits = .link
            linkAccessibilityElement.accessibilityAttributedLabel = attributedText.attributedSubstring(from: range)
            linkAccessibilityElement.accessibilityIdentifier = "gravity.inline-link.index-\(accessibilityElements.count)"
            accessibilityElements.append(linkAccessibilityElement)
        }

        let staticTextAccessibilityElement = LinkGestureAccessibilityElement(accessibilityContainer: label)
        staticTextAccessibilityElement.inlineLinkIndex = nil
        staticTextAccessibilityElement.inlineLinkFinder = self
        staticTextAccessibilityElement.isAccessibilityElement = true
        staticTextAccessibilityElement.accessibilityTraits = .staticText
        staticTextAccessibilityElement.accessibilityAttributedLabel = label.attributedText
        staticTextAccessibilityElement.accessibilityIdentifier = "gravity.inline-link.static-text"
        accessibilityElements.insert(staticTextAccessibilityElement, at: 0)

        label.isAccessibilityElement = false
        label.accessibilityElements = accessibilityElements
    }

    /// Loop through every pixel to find the full extent of each link’s rect.
    ///
    /// Obviously this is not the fastest way to find links, but in order to outline the accessibility
    /// elements, we need the full rects. Because of that, this will only be called by Voice Over once
    /// per cache at the time the label is highlighted.
    internal func findInlineLinkRect(for searchIndex: Int) -> CGRect? {
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

                guard let foundIndex = index(of: .link, atPoint: point) else {
                    continue
                }

                guard foundIndex == searchIndex else {
                    continue
                }

                return scanInlineLinkRect(startingFrom: point, through: label.bounds.size, for: searchIndex)
            }
        }

        return nil
    }

    /// Scan the rect extent of link at `searchIndex` starting from `origin` up through `size`.
    private func scanInlineLinkRect(startingFrom origin: CGPoint, through size: CGSize, for searchIndex: Int) -> CGRect? {
        guard let leadingWidth = scanInlineLinkExtent(startingFrom: origin, through: size, on: \.x, by: -1, for: searchIndex),
              let topHeight = scanInlineLinkExtent(startingFrom: origin, through: size, on: \.y, by: -1, for: searchIndex),
              let trailingWidth = scanInlineLinkExtent(startingFrom: origin, through: size, on: \.x, by: 1, for: searchIndex),
              let bottomHeight = scanInlineLinkExtent(startingFrom: origin, through: size, on: \.y, by: 1, for: searchIndex) else {
            return nil
        }

        return CGRect(x: origin.x - leadingWidth, y: origin.y - topHeight,
                      width: leadingWidth + trailingWidth, height: topHeight + bottomHeight)
    }

    /// Scan the `axis` (x or y) extent in `direction` (leading or trailing) of link at `searchIndex` starting from `origin` up through `size`.
    private func scanInlineLinkExtent(startingFrom origin: CGPoint,
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

            guard index(of: .link, atPoint: point) == searchIndex else {
                return (next - origin[keyPath: axis] - direction) * direction
            }
        }

        return nil
    }

}

// MARK: -

private extension NSAttributedString {

    /// Creates a “Duck Hunt” attributed string.
    ///
    /// That is, set all of the `attribute` ranges to blocks of color corresponding to
    /// their indexes, while whiting out the rest of the text.
    ///
    /// Doing so allows us to read each pixel and determine if there is an `link`
    /// at that visual location. If there is, the color value is the index that can be
    /// found in the `lookupTable` for the UTF-16 range in the original attributed string.
    func duckHuntAttributedString(for attribute: NSAttributedString.Key, lookupTable: inout [NSRange]) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: self)

        let fullRange = NSRange(location: 0, length: mutableString.length)
        mutableString.addAttributes([.foregroundColor: UIColor.white, .backgroundColor: UIColor.white], range: fullRange)

        lookupTable = []

        mutableString.enumerateAttribute(attribute, in: fullRange, options: .longestEffectiveRangeNotRequired) { (value, range, _) in
            guard value != nil else {
                return
            }

            let rangeEncodedColor = UIColor(red: CGFloat(lookupTable.count) / 255,
                                            green: CGFloat(lookupTable.count) / 255,
                                            blue: CGFloat(lookupTable.count) / 255,
                                            alpha: 1)

            mutableString.addAttributes([.foregroundColor: rangeEncodedColor, .backgroundColor: rangeEncodedColor], range: range)
            lookupTable.append(range)
        }

        return NSAttributedString(attributedString: mutableString)
    }

}

// MARK: -

private extension UILabel {

    /// Each color component is a byte (or 8 bits).
    var _bitsPerComponent: Int { 8 }

    /// One byte per color component (Red, Green, Blue, & Alpha).
    var _bytesPerPixel: Int { 4 }

    /// Each row is the number of pixels times the width of the label.
    var _bytesPerRow: Int { _bytesPerPixel * Int(bounds.width) }

    /// Draws the label with each `attribute` as blocks of grayscale representing the index of that attribute.
    /// The rest of the text is draw as pure white.
    func drawDuckHuntImage(for attribute: NSAttributedString.Key, lookupTable: inout [NSRange]) -> CFData? {
        guard let attributedString = attributedText else {
            return nil
        }

        let width = Int(bounds.width)
        let height = Int(bounds.height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: _bitsPerComponent, bytesPerRow: _bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }

        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)

        attributedText = attributedString.duckHuntAttributedString(for: attribute, lookupTable: &lookupTable)
        layer.draw(in: context)
        attributedText = attributedString

        return context.makeImage()?.dataProvider?.data
    }

    /// Extracts the color from the rendered label’s `memoryPointer` at `point`.
    ///
    /// Assuming we rendered the image using `drawDuckHuntImage(for:lookupTable:)` above, we are
    /// certain of the pixel layout.
    func color(at point: CGPoint, in memoryPointer: UnsafePointer<UInt8>) -> (red: Int, green: Int, blue: Int, alpha: Int) {
        let pixelLocation = _bytesPerRow * Int(point.y) + _bytesPerPixel * Int(point.x)

        let red = memoryPointer[pixelLocation]
        let green = memoryPointer[pixelLocation + 1]
        let blue = memoryPointer[pixelLocation + 2]
        let alpha = memoryPointer[pixelLocation + 3]

        return (red: Int(red), green: Int(green), blue: Int(blue), alpha: Int(alpha))
    }

}
