import XCTest
import CoreLocation
@testable import Formation_Flight

class MockCLLocationManager: CLLocationManager {
    private var authorizationStatusOverride: CLAuthorizationStatus?
    
    private(set) var didStartUpdatingLocation = false
    private(set) var didStopUpdatingLocation = false
    private(set) var didStartUpdatingHeading = false
    private(set) var didStopUpdatingHeading = false
    
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
        if let override = authorizationStatusOverride {
            return override
        } else {
            return super.authorizationStatus
        }
    }
    
    func simulateAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatusOverride = status
        testDelegate?.locationManagerDidChangeAuthorization?(self)
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

final class LocationProvider_Test: XCTestCase {
    func testInitialState() {
        let provider = LocationProvider()
        XCTAssertEqual(provider.speed, -1)
        XCTAssertEqual(provider.altitude, -1)
        XCTAssertEqual(provider.course, -1)
        XCTAssertNil(provider.authroizationStatus)
    }
    
    func testAuthorizationFlow_NotDeterminedToAuthorizedWhenInUse() {
        let mockManager = MockCLLocationManager()
        let provider = LocationProvider(locationManager: mockManager)
        mockManager.testDelegate = provider
        
        mockManager.simulateAuthorization(.notDetermined)
        XCTAssertNil(provider.authroizationStatus)
        
        mockManager.simulateAuthorization(.authorizedWhenInUse)
        XCTAssertEqual(provider.authroizationStatus, .authorizedWhenInUse)
    }
    
    func testStartAndStopMonitoring() {
        let mockManager = MockCLLocationManager()
        let provider = LocationProvider(locationManager: mockManager)
        mockManager.testDelegate = provider
        
        provider.startMonitoring()
        XCTAssertTrue(mockManager.didStartUpdatingLocation)
        XCTAssertTrue(mockManager.didStartUpdatingHeading)
        
        provider.stopMonitoring()
        XCTAssertTrue(mockManager.didStopUpdatingLocation)
        XCTAssertTrue(mockManager.didStopUpdatingHeading)
    }
    
    func testDidUpdateLocationsUpdatesMeasurementsAndCallsDelegate() {
        let mockManager = MockCLLocationManager()
        let provider = LocationProvider(locationManager: mockManager)
        mockManager.testDelegate = provider
        
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
        
        XCTAssertEqual(provider.speed, 67)
        XCTAssertEqual(provider.altitude, 123)
        XCTAssertEqual(provider.course, 45)
        XCTAssertEqual(updateCount, 1)
    }
    
    func testDidFailWithErrorDoesNotCrash() {
        let mockManager = MockCLLocationManager()
        let provider = LocationProvider(locationManager: mockManager)
        mockManager.testDelegate = provider
        
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        mockManager.simulateError(error)
        
        // No assertion, just ensure no crash.
    }
}

private extension CLLocation {
    static func make(latitude: CLLocationDegrees,
                     longitude: CLLocationDegrees,
                     altitude: CLLocationDistance,
                     course: CLLocationDirection,
                     speed: CLLocationSpeed) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                   altitude: altitude,
                   horizontalAccuracy: 0,
                   verticalAccuracy: 0,
                   course: course,
                   speed: speed,
                   timestamp: Date())
    }
}
