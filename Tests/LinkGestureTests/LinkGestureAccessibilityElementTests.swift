//
//  LinkGestureAccessibilityElementTests.swift
//  
//
//  Created by Stuart Moore on 1/12/22.
//

import UIKit
import XCTest
@testable import LinkGesture

private let mockBounds = CGRect(x: 0, y: 0, width: 400, height: 400)
private let mockRect = CGRect(x: 1, y: 2, width: 3, height: 4)

private class MockAccessibilityContainer: UILabel {
    //
}

private class MockLinkFinder: LinkFinder {

    var callCount = 0

    func findLinkRect(for: Int) -> CGRect? {
        callCount += 1
        return mockRect
    }
}

class LinkGestureAccessibilityElementTests: XCTestCase {

    private let mockAccessibilityContainer = MockAccessibilityContainer(frame: mockBounds)
    private let mockLinkFinder = MockLinkFinder()

    func testMainElement() throws {
        let accessibilityElement = LinkGestureAccessibilityElement(accessibilityContainer: mockAccessibilityContainer)
        accessibilityElement.linkFinder = mockLinkFinder
        accessibilityElement.linkIndex = nil

        XCTAssertEqual(mockLinkFinder.callCount, 0)
        XCTAssertEqual(accessibilityElement.accessibilityFrameInContainerSpace, mockBounds)
        XCTAssertEqual(mockLinkFinder.callCount, 0)
        XCTAssertEqual(accessibilityElement.accessibilityFrameInContainerSpace, mockBounds)
        XCTAssertEqual(mockLinkFinder.callCount, 0)
    }

    func testIndexedElement() throws {
        let accessibilityElement = LinkGestureAccessibilityElement(accessibilityContainer: mockAccessibilityContainer)
        accessibilityElement.linkFinder = mockLinkFinder
        accessibilityElement.linkIndex = 0

        XCTAssertEqual(mockLinkFinder.callCount, 0)
        XCTAssertEqual(accessibilityElement.accessibilityFrameInContainerSpace, mockRect)
        XCTAssertEqual(mockLinkFinder.callCount, 1)
        XCTAssertEqual(accessibilityElement.accessibilityFrameInContainerSpace, mockRect)
        XCTAssertEqual(mockLinkFinder.callCount, 1)
    }

}
