import XCTest
@testable import fmdatabase

final class fmdatabaseTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(FMDatabase.sqliteLibVersion(), "3.31.1")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
