import UIKit
import XCTest

final class SnapshotDiffTests: XCTestCase {
    private func image(width: Int, height: Int, red: [(Int, Int)] = []) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.red.setFill()
            for (x, y) in red { context.fill(CGRect(x: x, y: y, width: 1, height: 1)) }
        }
    }

    func testIdenticalImagesDifferByZero() {
        XCTAssertEqual(SnapshotDiff.summary(reference: image(width: 10, height: 10), actual: image(width: 10, height: 10)),
                       "0.00% of pixels differ")
    }

    func testCountsDifferentPixels() {
        let actual = image(width: 10, height: 10, red: [(0, 0), (5, 5), (9, 9)])
        XCTAssertEqual(SnapshotDiff.summary(reference: image(width: 10, height: 10), actual: actual),
                       "3.00% of pixels differ")
    }

    func testReportsSizeChange() {
        XCTAssertEqual(SnapshotDiff.summary(reference: image(width: 10, height: 10), actual: image(width: 12, height: 10)),
                       "size changed from 10x10 to 12x10 px")
    }
}
