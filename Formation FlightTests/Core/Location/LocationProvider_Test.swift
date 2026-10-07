import XCTest
import CoreLocation
@testable import Formation_Flight

class MockCLLocationManager: CLLocationManager {
    private var authorizationStatusOverride: CLAuthorizationStatus?

    private(set) var didStartUpdatingLocation = false
    private(set) var didStopUpdatingLocation = false
    private(set) var didStartUpdatingHeading = false
    private(set) var didStopUpdatingHeading = false
    private(set) var didRequestWhenInUseAuthorization = false
    private(set) var didRequestLocation = false

    weak var testDelegate: CLLocationManagerDelegate?

    override var delegate: CLLocationManagerDelegate? {
        get { testDelegate }
        set { testDelegate = newValue }
    }

    override class func authorizationStatus() -> CLAuthorizationStatus {
        // We cannot override a class var here, so we rely on instance property below.
        return .notDetermined
    }

    override var authorizationStatus: CLAuthorizationStatus {
        // Never fall through to the real service: an un-simulated mock reports `.notDetermined`.
        authorizationStatusOverride ?? .notDetermined
    }

    func simulateAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatusOverride = status
        testDelegate?.locationManagerDidChangeAuthorization?(self)
    }

    override func requestWhenInUseAuthorization() {
        // The provider calls this on `.notDetermined`; the real implementation would present
        // the system prompt. Record it instead of touching CoreLocation.
        didRequestWhenInUseAuthorization = true
    }

    override func requestLocation() {
        didRequestLocation = true
        // Simulate delivering a single location update to the delegate
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: -1,
            speed: -1,
            timestamp: Date()
        )
        testDelegate?.locationManager?(self, didUpdateLocations: [location])
    }

    override func startUpdatingLocation() {
        didStartUpdatingLocation = true
    }

    override func stopUpdatingLocation() {
        didStopUpdatingLocation = true
    }

    override func startUpdatingHeading() {
        didStartUpdatingHeading = true
    }

    override func stopUpdatingHeading() {
        didStopUpdatingHeading = true
    }

    func simulateLocations(_ locations: [CLLocation]) {
        testDelegate?.locationManager?(self, didUpdateLocations: locations)
    }

    func simulateError(_ error: Error) {
        testDelegate?.locationManager?(self, didFailWithError: error)
    }
}

/// `LocationProvider` is MainActor-isolated (B-27). XCTest runs every test method on the main
/// thread, so isolating the whole case lets the tests touch the provider's state directly and
/// lets the mock's synchronous delegate call-backs land on the actor the provider expects.
@MainActor
final class LocationProvider_Test: XCTestCase {
    /// Every test injects a `MockCLLocationManager` so no test constructs the default
    /// `CLLocationManager()` argument or reaches the real location service.
    private func makeProvider() -> (LocationProvider, MockCLLocationManager) {
        let mockManager = MockCLLocationManager()
        let provider = LocationProvider(clManager: mockManager)
        mockManager.testDelegate = provider
        return (provider, mockManager)
    }

    func testInitialState() {
        let (provider, mockManager) = makeProvider()
        XCTAssertEqual(provider.speed.value, -1)
        XCTAssertEqual(provider.altitude.value, -1)
        XCTAssertEqual(provider.course.value, -1)
        XCTAssertNil(provider.authroizationStatus)
        XCTAssertNil(provider.currentLocation)
        XCTAssertFalse(provider.computedSpeedAndCourse)
        // Construction alone must not start the location service.
        XCTAssertFalse(mockManager.didStartUpdatingLocation)
        XCTAssertFalse(mockManager.didStartUpdatingHeading)
    }

    func testAuthorizationFlow_NotDeterminedToAuthorizedWhenInUse() {
        let (provider, mockManager) = makeProvider()

        mockManager.simulateAuthorization(.notDetermined)
        XCTAssertNil(provider.authroizationStatus)
        XCTAssertTrue(mockManager.didRequestWhenInUseAuthorization)

        mockManager.simulateAuthorization(.authorizedWhenInUse)
        XCTAssertEqual(provider.authroizationStatus, .authorizedWhenInUse)
        XCTAssertTrue(mockManager.didRequestLocation)
    }

    func testStartAndStopMonitoring() {
        let (provider, mockManager) = makeProvider()

        provider.startMonitoring()
        XCTAssertTrue(mockManager.didStartUpdatingLocation)
        XCTAssertTrue(mockManager.didStartUpdatingHeading)

        provider.stopMonitoring()
        XCTAssertTrue(mockManager.didStopUpdatingLocation)
        XCTAssertTrue(mockManager.didStopUpdatingHeading)
    }

    func testDidUpdateLocationsUpdatesMeasurementsAndCallsDelegate() {
        let (provider, mockManager) = makeProvider()

        var updateCount = 0
        provider.updateDelegate = {
            updateCount += 1
        }

        let location = CLLocation.make(
            latitude: 0,
            longitude: 0,
            altitude: 123,
            course: 45,
            speed: 67
        )
        mockManager.simulateLocations([location])

        XCTAssertEqual(provider.speed.value, 67)
        XCTAssertEqual(provider.altitude.value, 123)
        XCTAssertEqual(provider.course.value, 45)
        XCTAssertEqual(updateCount, 1)
    }

    // MARK: - Altitude validity (B-39)

    /// Death Valley, the Dead Sea, and plenty of airfields sit below sea level. A negative
    /// altitude with a non-negative `verticalAccuracy` is a perfectly valid fix and must be
    /// published, not dropped by a sign check.
    func testDidUpdateLocationsAcceptsBelowSeaLevelAltitudeWhenVerticalAccuracyIsValid() {
        let (provider, mockManager) = makeProvider()

        let belowSeaLevel = CLLocation.make(
            latitude: 36.2, longitude: -116.8,
            altitude: -50,
            verticalAccuracy: 5,
            course: 0, speed: 0
        )
        mockManager.simulateLocations([belowSeaLevel])

        XCTAssertEqual(provider.altitude.value, -50)
    }

    /// Core Location signals "no altitude available" with a negative `verticalAccuracy`.
    /// Such a fix must leave the previously published altitude untouched.
    func testDidUpdateLocationsIgnoresAltitudeWhenVerticalAccuracyIsNegative() {
        let (provider, mockManager) = makeProvider()

        let validFix = CLLocation.make(
            latitude: 0, longitude: 0,
            altitude: 300,
            verticalAccuracy: 5,
            course: 0, speed: 0
        )
        mockManager.simulateLocations([validFix])
        XCTAssertEqual(provider.altitude.value, 300)

        let noAltitudeFix = CLLocation.make(
            latitude: 0, longitude: 0,
            altitude: 999,
            verticalAccuracy: -1,
            course: 0, speed: 0
        )
        mockManager.simulateLocations([noAltitudeFix])

        XCTAssertEqual(provider.altitude.value, 300, "Altitude must not change when verticalAccuracy < 0")
    }

    func testDidFailWithErrorLeavesStateUntouchedAndDoesNotNotify() {
        let (provider, mockManager) = makeProvider()

        var updateCount = 0
        provider.updateDelegate = {
            updateCount += 1
        }

        let error = NSError(domain: "test", code: 1, userInfo: nil)
        mockManager.simulateError(error)

        // A CoreLocation failure is logged only: no measurement changes, no delegate callback.
        XCTAssertEqual(provider.speed.value, -1)
        XCTAssertEqual(provider.altitude.value, -1)
        XCTAssertEqual(provider.course.value, -1)
        XCTAssertNil(provider.currentLocation)
        XCTAssertEqual(updateCount, 0, "updateDelegate must not fire on didFailWithError")
    }
}

private extension CLLocation {
    /// Builds a fix with sensible defaults. Both accuracies default to a valid (non-negative)
    /// value so that callers only have to spell out the field a test is actually about.
    static func make(latitude: CLLocationDegrees,
                     longitude: CLLocationDegrees,
                     altitude: CLLocationDistance,
                     horizontalAccuracy: CLLocationAccuracy = 5,
                     verticalAccuracy: CLLocationAccuracy = 5,
                     course: CLLocationDirection,
                     speed: CLLocationSpeed) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                   altitude: altitude,
                   horizontalAccuracy: horizontalAccuracy,
                   verticalAccuracy: verticalAccuracy,
                   course: course,
                   speed: speed,
                   timestamp: Date())
    }
}
