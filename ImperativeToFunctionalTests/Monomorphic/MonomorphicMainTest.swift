import XCTest
import Bow

class MonomorphicMainTest: XCTestCase {
    
    func testMonomorphicMain() {
        try! MonomorphicMain.main().unsafePerformIO()
    }
    
}
