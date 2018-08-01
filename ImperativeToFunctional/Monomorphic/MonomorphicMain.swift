import Foundation
import Bow

class MonomorphicMain {
    static func put(line: String) -> IO<()> {
        return IO.invoke{ print(line) }
    }
    
    static func getLine() -> IO<String> {
        return IO.invoke({ Maybe.fromOption(readLine()).getOrElse("") })
    }
    
    static func parseInt(_ line : String) -> Maybe<Int> {
        return Maybe.fromOption(Int(line))
    }
    
    static func random(upTo n : Int) -> IO<Int> {
        return IO.invoke { Int(arc4random_uniform(UInt32(n))) }
    }
    
    static func check(guess : Maybe<Int>, number : Int, name : String) -> IO<()> {
        return guess.fold(
            { put(line: "You didn't enter a number!") },
            { guess in
                if guess == number {
                    return put(line: "You guessed right, \(name)")
                } else {
                    return put(line: "You guessed wrong, \(name)! The number was \(number).")
                }
            })
    }
    
    static func checkExit(name : String) -> IO<()> {
        return IO<()>.monad().binding(
            { put(line: "Do you want to continue, \(name)?") },
            { _ in getLine() },
            { _, answer in
                switch answer.lowercased() {
                case "y": return gameLoop(name)
                case "n": return IO.pure(())
                default: return checkExit(name: name)
                }
            }
        ).fix()
    }
    
    static func gameLoop(_ name : String) -> IO<()> {
        return IO<Int>.monad().binding(
            { random(upTo: 5).map{ $0 + 1 } },
            { _ in put(line: "Dear \(name), please guess a number from 1 to 5:") },
            { _, _ in getLine().map(parseInt) },
            { number, _, guess in check(guess: guess, number: number, name: name) },
            { _, _, _, _ in checkExit(name: name) }
        ).fix()
    }
    
    static func main() -> IO<()> {
        return IO<()>.monad().binding(
            { put(line: "What is your name?") },
            { _ in getLine() },
            { _, name in put(line: "Hello, \(name), welcome to the game!") },
            { _, name, _ in gameLoop(name) }
        ).fix()
    }
}
