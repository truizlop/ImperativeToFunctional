import Foundation

class ImperativeMain {
    
    static func main() {
        print("What is your name?")
        
        let name = readLine()!
        
        print("Hello, \(name)" + ", welcome to the game!")
        
        var exec = true
        
        while(exec) {
            let number = arc4random_uniform(5) + 1
            
            print("Dear \(name), please guess a number from 1 to 5:")
            
            let guess = Int(readLine()!)!
            
            if guess == number {
                print("You guessed right, \(name)!")
            } else {
                print("You guessed wrong, \(name)! The number was \(number).")
            }
            
            print("Do you want to continue, \(name)?")
            
            let answer = readLine()!
            switch answer {
            case "y": exec = true
            case "n": exec = false
            default: exec = true
            }
        }
    }
}
