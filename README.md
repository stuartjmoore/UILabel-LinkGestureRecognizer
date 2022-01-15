# LinkGestureRecognizer

Respond to taps on `UILabel` where the text range is marked as `NSAttributedString.Key.inlineLink` with an underlying URL.

On touch down, the link text color will be set to the corresponding `NSAttributedString.Key.highlightColor` or fade its original color by 40%.

## Usage

```
let label = UILabel()
label.attributedText = // An attributed string with inline link ranges

let linkGestureRecognizer = LinkGestureRecognizer(target: self, action: #selector(handleLinkTap))
label.addGestureRecognizer(linkGestureRecognizer)

@objc func handleLinkTap(_ gestureRecognizer: LinkGestureRecognizer) {
    // handle gestureRecognizer.url in gestureRecognizer.range (UTF-16)
}
```

The label’s `attributedText` can either be an `NSAttributedString` marked with an `inlineLink` key set as the `URL` and `highlightColor` set as the `UIColor` for decorating the link when tapped:

```
let mutableString = NSMutableAttributedString(string: "This is a ", attributes: [
    .foregroundColor: UIColor.label,
])

mutableString.append(NSAttributedString(string: "Link", attributes: [
    .foregroundColor: UIColor.link,
    .underlineStyle: NSUnderlineStyle.single,
    .inlineLink: URL(string: "http://www.example.com")!, // Does _not_ need to be a web URL
    .highlightColor: UIColor.systemRed,
]))

mutableString.append(NSAttributedString(string: ".", attributes: [
    .foregroundColor: UIColor.label,
]))

label.attributedText = mutableString
```

Or one built using `AttributedString` (iOS 15+) with the same keys scoped to `\.linkGesture`:

```
var attributedString = AttributedString("This is a ")
attributedString.foregroundColor = .label

var attributedLinkString = AttributedString("Link")
attributedLinkString.foregroundColor = .link
attributedLinkString.underlineStyle = .single
attributedLinkString.inlineLink = URL(string: "http://www.example.com")
attributedLinkString.highlightColor = .systemRed

var attributedTerminationString = AttributedString(".")
attributedTerminationString.foregroundColor = .label

label.attributedText = try? NSAttributedString(attributedString + attributedLinkString + attributedTerminationString, including: \.linkGesture)
```

## How it works

The method is similar to the one used by the game “Duck Hunt”. When we want to find what links exist where, we temporarily change the attributed string’s foreground and background colors’ RGB values to the index of the link it covers; the rest is set to white. From that rendered layer, we extract the color of the pixel where the touch happened, lookup the index in a table, and retrieve the UTF-16 range of the link. To speed up later touches, the rendered layer is cached until the string is modified or the label’s size changes.

### Accessibility

Since accessibility doesn’t touch the screen, we have to search the _entire_ rendered layer—pixel by pixel—for each link’s bounding box. There are some assumptions made to speed things up, such as skipping the minimum line height while traversing down, and searching doesn’t even happen until Voice Over highlights the label.

If you want to implement your own accessibility label, `overridesAccessibility` can be toggled off.

## Screenshots

A basic link:

!(Link Screenshot)[/Images/demo-link.png]

When tapped:

!(Tapped Link Screenshot)[/Images/demo-link-highlight.png]

The internal “Duck Hunt” rendered layer:

!(Rendered Layer)[/Images/demo-link-render.png]

## FAQ

_Why not use UIKit’s `link` key?_

Because as far as I can tell, `UILabel` won’t allow us to modify the style of a native `link`.

_What if the device’s colorspace is different? Won’t the color be slightly off?_

No, we’re rendering the image internally with our own settings. We know the exact pixel alignment and color ranges. In fact, we only render at 1x, speeding things up a little more.
