import XCTest
import Bow

class TaglessFinalMainTest: XCTestCase {
    
    func testTaglessFinalMainIO() {
        try! TaglessFinalMain.mainIO().unsafePerformIO()
    }
    
    func testTaglessFinalMainState() {
        let data = TestData(input: [ "Tomás", "1", "n" ], output: [], numbers: [0])
        let result = TaglessFinalMain.mainTest().run(data, Id<()>.monad()).fix()
        print(result.value.0.output)
    }
}
