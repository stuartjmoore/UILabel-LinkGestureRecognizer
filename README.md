# LinkGesture

Allow consumers to respond to taps on `UILabel` where the text range is
marked as `NSAttributedString.Key.link` with an underlying URL.

On touch down, the link text color will be set to the corresponding
`NSAttributedString.Key.highlightColor` or fade its original
color by 40%.

## Usage

```
let linkGestureRecognizer = LinkGestureRecognizer(target: self, action: #selector(handleLinkTap))
label.addGestureRecognizer(linkGestureRecognizer)

label.attributedText = // An attributed string with link ranges

@objc func handleLinkTap(_ gestureRecognizer: LinkGestureRecognizer) {
    // handle gestureRecognizer.url in gestureRecognizer.range (UTF-16)
}
```
