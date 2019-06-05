import Foundation

/// The Selective typeclass represents Selective Applicative Functors, described in [this paper](https://www.staff.ncl.ac.uk/andrey.mokhov/selective-functors.pdf). Selective Applicative Functors enrich Applicative Functors by providing an operation that composes two effectful computations where the second depends on the first.
public protocol Selective: Applicative {
    /// Conditionally applies the second computation based on the result of the first.
    ///
    /// - Parameters:
    ///   - fab: A computation that results in an `Either` value.
    ///   - f: A computation that is executed in case the first computation evaluates to a left value.
    /// - Returns: Composition of the two computations.
    static func select<A, B>(_ fab: Kind<Self, Either<A, B>>, _ f: Kind<Self, (A) -> B>) -> Kind<Self, B>
}

// MARK: Related functions

public extension Selective {
    private static func selector(_ x: Kind<Self, Bool>) -> Kind<Self, Either<(), ()>> {
        return map(x, { flag in flag ? Either.left(()) : Either.right(()) })
    }

    /// Evaluates the second computation when the first evaluates to `true`.
    ///
    /// - Parameters:
    ///   - cond: A computation evaluating to a boolean value.
    ///   - f: A computation that will be evaluated if the first computation evaluates to `true`.
    /// - Returns: Composition of the two computations.
    static func whenS(_ cond: Kind<Self, Bool>, _ f: Kind<Self, ()>) -> Kind<Self, ()> {
        let effect = map(f) { ff in { (_: ()) in } }
        return select(selector(cond), effect)
    }

    /// Evaluates one out of two computations based on the result of another computation.
    ///
    /// - Parameters:
    ///   - fab: Computation producing an `Either` value, to decide which computation is executed afterwards.
    ///   - fa: Computation that will be executed if `fab` evaluates to an `Either.left` value.
    ///   - fb: Computation that will be executed if `fab` evaluates to an `Either.right` value.
    /// - Returns: Composition of the computations.
    static func branch<A, B, C>(_ fab: Kind<Self, Either<A, B>>, _ fa: Kind<Self, (A) -> C>, _ fb: Kind<Self, (B) -> C>) -> Kind<Self, C> {
        let x = map(fab) { eab in Either.fix(eab.map(Either<B, C>.left)) }
        let y = map(fa) { f in { a in Either<B, C>.right(f(a)) } }
        return select(select(x, y), fb)
    }

    /// Evaluates one out of two computations based on the result of another computation.
    ///
    /// - Parameters:
    ///   - x: Computation producing a boolean value to decide which computation is exectured afterwards.
    ///   - t: Computation that will be executed if the first evaluates to `true`.
    ///   - e: Computation that will be executed if the first evaluates to `false`.
    /// - Returns: Composition of the computations.
    static func ifS<A>(_ x: Kind<Self, Bool>, _ t: Kind<Self, A>, _ e: Kind<Self, A>) -> Kind<Self, A> {
        return branch(selector(x), map(t, { tt in constant(tt) }), map(e, { ee in constant(ee) }))
    }

    /// A lifted version of lazy boolean or.
    ///
    /// - Parameters:
    ///   - x: Computation to be or'ed.
    ///   - y: Computation to be or'ed.
    /// - Returns: Result of the or operation on the two computations.
    static func orS(_ x: Kind<Self, Bool>, _ y: Kind<Self, Bool>) -> Kind<Self, Bool> {
        return ifS(x, pure(true), y)
    }

    /// A lifted version of lazy boolean and.
    ///
    /// - Parameters:
    ///   - x: Computation to be and'ed.
    ///   - y: Computation to be and'ed.
    /// - Returns: Result of the and operation on the two computations.
    static func andS(_ x: Kind<Self, Bool>, _ y: Kind<Self, Bool>) -> Kind<Self, Bool> {
        return ifS(x, y, pure(false))
    }

    /// Evaluates an optional computation, providing a default value for the empty case.
    ///
    /// - Parameters:
    ///   - x: Default value for the empty case.
    ///   - mx: A computation resulting in an optional value.
    /// - Returns: Composition of the two computations.
    static func fromOptionS<A>(_ x: Kind<Self, A>, _ mx: Kind<Self, Option<A>>) -> Kind<Self, A> {
        let s = map(mx) { a in Option.fix(a.map(Either<(), A>.right)).getOrElse(Either.left(())) }
        return select(s, map(x, { xx in constant(xx) }))
    }

    /// A lifted version of `any`. Retains the short-circuiting behavior.
    ///
    /// - Parameters:
    ///   - p: A lifted predicate to find any element of the `array` that matches it.
    ///   - array: An array to look for an element that matches the predicate in.
    /// - Returns: A boolean computation describing if any element of the array matches the predicate.
    static func anyS<A>(_ p: @escaping (A) -> Kind<Self, Bool>, _ array: ArrayK<A>) -> Kind<Self, Bool> {
        return array.foldRight(Eval.now(pure(false))) { a, b in Eval.later { orS(p(a), b.value()) } }.value()
    }

    /// A lifted version of `all`. Retains the short-circuiting behavior.
    ///
    /// - Parameters:
    ///   - p: A lifted predicate to check all elements of the `array` match it.
    ///   - array: An array to check if all elements match the predicate.
    /// - Returns: A boolean computation describing if all elements of the array match the predicate.
    static func allS<A>(_ p: @escaping (A) -> Kind<Self, Bool>, _ array: ArrayK<A>) -> Kind<Self, Bool> {
        return array.foldRight(Eval.now(pure(true))) { a, b in Eval.later { andS(p(a), b.value()) } }.value()
    }

    /// Evaluates a computation as long as it evaluates to `true`.
    ///
    /// - Parameter x: A computation.
    /// - Returns: A potentially lazy computation.
    static func whileS(_ x: Kind<Self, Bool>) -> Eval<Kind<Self, ()>> {
        return Eval.later { whenS(x, whileS(x).value()) }
    }
}

// MARK: Syntax for Selective

public extension Kind where F: Selective {
    /// Conditionally applies a computation based on the result of this computation.
    ///
    /// - Parameters:
    ///   - f: A computation that is executed in case the receiving computation evaluates to a left value.
    /// - Returns: Composition of the two computations.
    func select<AA, B>(_ f: Kind<F, (AA) -> B>) -> Kind<F, B> where A == Either<AA, B> {
        return F.select(self, f)
    }

    /// Evaluates one out of two computations based on the result of this computation.
    ///
    /// - Parameters:
    ///   - fa: Computation that will be executed if this computation evaluates to an `Either.left` value.
    ///   - fb: Computation that will be executed if this computation evaluates to an `Either.right` value.
    /// - Returns: Composition of the computations.
    func branch<AA, B, C>(_ fa: Kind<F, (AA) -> C>, _ fb: Kind<F, (B) -> C>) -> Kind<F, C> where A == Either<AA, B> {
        return F.branch(self, fa, fb)
    }

    // Evaluates an optional computation, providing a default value for the empty case.
    ///
    /// - Parameters:
    ///   - x: Default value for the empty case.
    ///   - mx: A computation resulting in an optional value.
    /// - Returns: Composition of the two computations.
    static func fromOptionS(_ x: Kind<F, A>, _ mx: Kind<F, Option<A>>) -> Kind<F, A> {
        return F.fromOptionS(x, mx)
    }
}

public extension Kind where F: Selective, A == Bool {
    /// Evaluates the second computation when the first evaluates to `true`.
    ///
    /// - Parameters:
    ///   - cond: A computation evaluating to a boolean value.
    ///   - f: A computation that will be evaluated if the first computation evaluates to `true`.
    /// - Returns: Composition of the two computations.
    static func whenS(_ cond: Kind<F, Bool>, _ f: Kind<F, ()>) -> Kind<F, ()> {
        return F.whenS(cond, f)
    }

    /// Evaluates one out of two computations based on the result of another computation.
    ///
    /// - Parameters:
    ///   - x: Computation producing a boolean value to decide which computation is exectured afterwards.
    ///   - t: Computation that will be executed if the first evaluates to `true`.
    ///   - e: Computation that will be executed if the first evaluates to `false`.
    /// - Returns: Composition of the computations.
    static func ifS<A>(_ x: Kind<F, Bool>, _ t: Kind<F, A>, _ e: Kind<F, A>) -> Kind<F, A> {
        return F.ifS(x, t, e)
    }

    /// A lifted version of lazy boolean or.
    ///
    /// - Parameters:
    ///   - x: Computation to be or'ed.
    ///   - y: Computation to be or'ed.
    /// - Returns: Result of the or operation on the two computations.
    static func orS(_ x: Kind<F, Bool>, _ y: Kind<F, Bool>) -> Kind<F, Bool> {
        return F.orS(x, y)
    }

    /// A lifted version of lazy boolean and.
    ///
    /// - Parameters:
    ///   - x: Computation to be and'ed.
    ///   - y: Computation to be and'ed.
    /// - Returns: Result of the and operation on the two computations.
    static func andS(_ x: Kind<F, Bool>, _ y: Kind<F, Bool>) -> Kind<F, Bool> {
        return F.andS(x, y)
    }

    /// Evaluates a computation as long as it evaluates to `true`.
    ///
    /// - Parameter x: A computation.
    /// - Returns: A potentially lazy computation.
    static func whileS(_ x: Kind<F, Bool>) -> Eval<Kind<F, ()>> {
        return F.whileS(x)
    }
}

public extension ArrayK {
    /// A lifted version of `any`. Retains the short-circuiting behavior.
    ///
    /// - Parameters:
    ///   - p: A lifted predicate to find any element of this array that matches it.
    /// - Returns: A boolean computation describing if any element of the array matches the predicate.
    func anyS<F: Selective>(_ p: @escaping (A) -> Kind<F, Bool>) -> Kind<F, Bool> {
        return F.anyS(p, self)
    }

    /// A lifted version of `all`. Retains the short-circuiting behavior.
    ///
    /// - Parameters:
    ///   - p: A lifted predicate to check all elements of this array match it.
    /// - Returns: A boolean computation describing if all elements of the array match the predicate.
    func allS<F: Selective>(_ p: @escaping (A) -> Kind<F, Bool>) -> Kind<F, Bool> {
        return F.anyS(p, self)
    }
}
