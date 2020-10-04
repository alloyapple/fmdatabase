import XCTest
import fmdatabaseTests

var tests = [XCTestCaseEntry]()
tests += fmdatabaseTests.allTests()
XCTMain(tests)
