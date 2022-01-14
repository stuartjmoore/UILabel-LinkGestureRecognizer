//
//  File.swift
//  
//
//  Created by Stuart Moore on 1/12/22.
//

import UIKit

internal extension UILabel {

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
