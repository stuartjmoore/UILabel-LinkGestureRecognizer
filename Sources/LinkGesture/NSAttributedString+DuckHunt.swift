//
//  File.swift
//  
//
//  Created by Stuart Moore on 1/12/22.
//

import UIKit

internal extension NSAttributedString {

    /// Creates a “Duck Hunt” attributed string.
    ///
    /// That is, set all of the `attribute` ranges to blocks of color corresponding to
    /// their indexes, while whiting out the rest of the text.
    ///
    /// Doing so allows us to read each pixel and determine if there is a link
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
