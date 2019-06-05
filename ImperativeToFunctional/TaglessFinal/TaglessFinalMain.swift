import Foundation
import Bow
import BowEffects

protocol Console {
    static func write(line: String) -> Kind<Self, ()>
    static func getLine() -> Kind<Self, String>
}

protocol Randomness {
    static func nextInt(upTo n: Int) -> Kind<Self, Int>
}

extension IOPartial: Console {
    static func write(line: String) -> Kind<IOPartial<E>, ()> {
        return IO.invoke { print(line) }
    }
    
    static func getLine() -> Kind<IOPartial<E>, String> {
        return IO.invoke { Option.fromOptional(readLine()).getOrElse("") }
    }
}

extension IOPartial: Randomness {
    static func nextInt(upTo n: Int) -> Kind<IOPartial<E>, Int> {
        return IO.invoke{ Int(arc4random_uniform(UInt32(n))) }
    }
}

struct TestData {
    let input : [String]
    let output : [String]
    let numbers : [Int]
    
    func copy(input : [String]? = nil, output : [String]? = nil, numbers : [Int]? = nil) -> TestData {
        return TestData(input: input ?? self.input,
                        output: output ?? self.output,
                        numbers: numbers ?? self.numbers)
    }
}

typealias Test<A> = State<TestData, A>
typealias ForTest = StatePartial<TestData>

extension ForTest: Console {
    static func write(line: String) -> Kind<StateTPartial<F, S>, ()> {
        return Test<()>({ data in
            (data.copy(output: data.output + [line]), ())
        })
    }
    
    static func getLine() -> Kind<StateTPartial<F, S>, String> {
        return Test<String>({ data in
            let newData = data.copy(input: Array<String>(data.input.dropFirst()))
            let nextInput = data.input.first!
            return (newData, nextInput)
        })
    }
}

extension ForTest: Randomness {
    static func nextInt(upTo n: Int) -> Kind<StateTPartial<F, S>, Int> {
        return Test<Int>({ data in
            (data.copy(numbers: Array<Int>(data.numbers.dropFirst())), data.numbers.first!)
        })
    }
}

class TaglessFinalMain {
    static func parseInt(_ line: String) -> Option<Int> {
        return Option.fromOptional(Int(line))
    }
    
    static func check<F: Console>(guess: Option<Int>, number: Int, name: String) -> Kind<F, ()> {
        return guess.fold(
            { F.write(line: "You didn't enter a number!") },
            { guess in
                if guess == number {
                    return F.write(line: "You guessed right, \(name)")
                } else {
                    return F.write(line: "You guessed wrong, \(name)! The number was \(number).")
                }
        })
    }
    
    static func checkExit<F: Monad & Console & Randomness>(name: String) -> Kind<F, ()> {
        return F.binding(
            { F.write(line: "Do you want to continue, \(name)?") },
            { _ in F.getLine() },
            { _, answer in
                switch answer.lowercased() {
                case "y": return gameLoop(name)
                case "n": return F.pure(())
                default: return checkExit(name: name)
                }
            })
    }
    
    static func gameLoop<F: Monad & Console & Randomness>(_ name: String) -> Kind<F, ()> {
        return F.binding(
            { F.map(F.nextInt(upTo: 5), { $0 + 1 }) },
            { _ in F.write(line: "Dear \(name), please guess a number from 1 to 5:") },
            { _, _ in F.map(F.getLine(), parseInt) },
            { number, _, guess in check(guess: guess, number: number, name: name) },
            { _, _, _, _ in checkExit(name: name) }
            )
    }
    
    static func main<F: Monad & Console & Randomness>() -> Kind<F, ()> {
        return F.binding(
            { F.write(line: "What is your name?") },
            { _ in F.getLine() },
            { _, name in F.write(line: "Hello, \(name), welcome to the game!") },
            { _, name, _ in gameLoop(name) })
    }
    
    static func mainIO() -> IO<Never, ()> {
        return main()^
    }
    
    static func mainTest() -> State<TestData, ()> {
        return main() as! State<TestData, ()>
    }
}
