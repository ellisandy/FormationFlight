import Foundation
import Testing

@Suite("Double+Extensions Tests")
struct DoubleExtensionsTests {
    // Tolerance for floating point comparisons
    let tolerance = 1e-12

    func assertAlmostEqual(_ a: Double, _ b: Double) {
        #expect(abs(a - b) < tolerance)
    }

    @Test("Convert standard angles to radians")
    func testStandardAngles() {
        assertAlmostEqual(0.0.degreesToRadians, 0.0)
        assertAlmostEqual(90.0.degreesToRadians, .pi / 2)
        assertAlmostEqual(180.0.degreesToRadians, .pi)
        assertAlmostEqual(270.0.degreesToRadians, 3 * .pi / 2)
        assertAlmostEqual(360.0.degreesToRadians, 2 * .pi)
    }

    @Test("Convert negative angles to radians")
    func testNegativeAngles() {
        assertAlmostEqual((-45.0).degreesToRadians, -(.pi / 4))
        assertAlmostEqual((-90.0).degreesToRadians, -(.pi / 2))
    }

    @Test("Convert random angle to radians using formula")
    func testRandomAngle() {
        let angle = 123.456
        let expected = angle * .pi / 180.0
        assertAlmostEqual(angle.degreesToRadians, expected)
    }
}
