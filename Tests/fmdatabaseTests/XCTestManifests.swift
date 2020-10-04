import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        return [
            testCase(fmdatabaseTests.allTests)
        ]
    }
#endif
