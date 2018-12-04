import Foundation
import Bow
import BowEffects

protocol Console : Typeclass {
    associatedtype F
    
    func write(line: String) -> Kind<F, ()>
    func getLine() -> Kind<F, String>
}

protocol Randomness : Typeclass {
    associatedtype F
    
    func nextInt(upTo n : Int) -> Kind<F, Int>
}

class ConsoleIO : Console {
    func write(line: String) -> Kind<ForIO, ()> {
        return IO.invoke { print(line) }
    }
    
    func getLine() -> Kind<ForIO, String> {
        return IO.invoke { Option.fromOption(readLine()).getOrElse("") }
    }
}

class RandomnessIO : Randomness {
    func nextInt(upTo n : Int) -> Kind<ForIO, Int> {
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

class ConsoleTest : Console {
    func write(line: String) -> Kind<ForTest, ()> {
        return Test<()>({ data in
            (data.copy(output: data.output + [line]), ())
        })
    }
    
    func getLine() -> Kind<StatePartial<TestData>, String> {
        return Test<String>({ data in
            let newData = data.copy(input: Array<String>(data.input.dropFirst()))
            let nextInput = data.input.first!
            return (newData, nextInput)
        })
    }
}

class RandomnessTest : Randomness {
    func nextInt(upTo n : Int) -> Kind<ForTest, Int> {
        return Test<Int>({ data in
            (data.copy(numbers: Array<Int>(data.numbers.dropFirst())), data.numbers.first!)
        })
    }
}

class TaglessFinalMain {
    static func parseInt(_ line : String) -> Option<Int> {
        return Option.fromOption(Int(line))
    }
    
    static func check<F, Cons>(guess : Option<Int>, number : Int, name : String, console : Cons) -> Kind<F, ()>
        where Cons : Console, Cons.F == F {
        return guess.fold(
            { console.write(line: "You didn't enter a number!") },
            { guess in
                if guess == number {
                    return console.write(line: "You guessed right, \(name)")
                } else {
                    return console.write(line: "You guessed wrong, \(name)! The number was \(number).")
                }
        })
    }
    
    static func checkExit<F, Mon, Cons, Rand>(name : String, monad : Mon, console : Cons, randomness : Rand) -> Kind<F, ()>
        where Mon : Monad, Mon.F == F,
        Cons : Console, Cons.F == F,
        Rand : Randomness, Rand.F == F {
        return monad.binding(
            { console.write(line: "Do you want to continue, \(name)?") },
            { _ in console.getLine() },
            { _, answer in
                switch answer.lowercased() {
                case "y": return gameLoop(name, monad: monad, console: console, randomness: randomness)
                case "n": return monad.pure(())
                default: return checkExit(name: name, monad: monad, console: console, randomness: randomness)
                }
            })
    }
    
    static func gameLoop<F, Mon, Cons, Rand>(_ name : String, monad : Mon, console : Cons, randomness : Rand) -> Kind<F, ()>
        where Mon : Monad, Mon.F == F,
            Cons : Console, Cons.F == F,
            Rand : Randomness, Rand.F == F {
        return monad.binding(
            { monad.map(randomness.nextInt(upTo: 5), { $0 + 1 }) },
            { _ in console.write(line: "Dear \(name), please guess a number from 1 to 5:") },
            { _, _ in monad.map(console.getLine(), parseInt) },
            { number, _, guess in check(guess: guess, number: number, name: name, console: console) },
            { _, _, _, _ in checkExit(name: name, monad: monad, console: console, randomness: randomness) }
            )
    }
    
    static func main<F, Mon, Cons, Rand>(monad : Mon, console : Cons, randomness : Rand) -> Kind<F, ()>
        where Mon : Monad, Mon.F == F,
            Cons : Console, Cons.F == F,
            Rand : Randomness, Rand.F == F {
        return monad.binding(
            { console.write(line: "What is your name?") },
            { _ in console.getLine() },
            { _, name in console.write(line: "Hello, \(name), welcome to the game!") },
            { _, name, _ in gameLoop(name, monad: monad, console: console, randomness: randomness) })
    }
    
    static func mainIO() -> IO<()> {
        return main(monad: IO<()>.monad(), console: ConsoleIO(), randomness: RandomnessIO()).fix()
    }
    
    static func mainTest() -> State<TestData, ()> {
        return State<TestData, ()>.fix(main(monad: Test<()>.monad(), console: ConsoleTest(), randomness: RandomnessTest())) as! State<TestData, ()>
    }
}

