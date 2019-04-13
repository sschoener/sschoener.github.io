---
layout: post
title: I want Results!
excerpt: In which I describe a useful error handling class that I miss in C#
tags: [computer science, programming, c#]
---

Functional programming languages frequently contain a data type that is either an error or some useful result, like `Either<Error, T>` or just `Error<T>` (assuming C#-style generics). Focusing on the error is one way, but I'm more optimistic and call this `Result<T>`. As so often, I miss this data type from the functional world in C#, so here is my take on it. I do not often feel the need to use something like `Result` but right now I am working on a highly concurrent piece of software that is using a database as its datastore and for business reasons that database needs to have a global lock (sorry). It was originally meant to be a quick-and-dirty project, but this lock means that any kind of error reporting should only happen once the lock has been released again in order to keep the lock-times per operation as low as possible. Given that the database will likely be small enough to fit into RAM in its entirety, sending out error messages would wreck the performance of an otherwise innocent operation. `Result` here is used to collect errors and return them to a handler than can operate when the lock has been released[^exception].

We will need two different versions of `Result`: A generic version `Result<T>` and a non-generic version `Result` for situations where you just want to return success or an error. They should be light-weight and easy to use, ideally without adding any explicit types whenever they are used. Errors are just error messages as a string, not exceptions.

I'm not actually that interested in giving you the whole code (you can find it [here](https://gist.github.com/sschoener/95eb0a532e210c822b2f55e90b07b1a9)), I would rather explain some of the decisions I made when designing these types.

1. There are three types `Result`, `Result<T>` and `Failure`. All of them are structs to avoid unnecessary allocations. This means among other things that `Result<T>` cannot inherit from `Result` and I consider this a good thing. This unfortunately means that you cannot use C#'s pattern matching on it without using `where` clauses.
2. Whenever you need to express a failure of type `Result` or `Result<T>`, you can simply call `Result.Fail(string msg)`. There is no need to specify the actual type `T` that you want to get a result for. This is achieved by using the `Failure` type (containing only the error message) and adding implicit casts from `Failure` to `Result` and `Result<T>`.
3. Similarly, when combining functions that return `Result`s, you often need to convert a failure `Result<S> s` to a failure `Result<T> t`. This is cumbersome, so there is a property `Failure` that simply returns a `Failure` object with the same error message. Implicit casting does the rest: `Result<T> t = s.Failure;`.
4. Constructing a success of any type `T` works via `Result.Success(T value)`. You never have to write something like `Result<T>.Success(T value)`.
5. There is no implicit cast from `Result<T>` to `Result`. This is on purpose. I found that other developers often wanted to return `Result<string>` in a method that had return type `Result`. Implicit casts that lose information should be avoided whenever possible (= always). If you *want* to downcast, you can use the `ToResult()` method.

I'm torn on whether to put the various overloads for `Bind` into its own static class and make them extensions (as it is) or to have them defined in the structs themselves. I find the extensions approach much more readable, but there is a semantic difference: Methods defined within the struct however are taking `this` by refence, but with extensions, the structs are passed by value, which is potentially worrisome if `Result<T>` is used with large value-types `T`.

---

[^exception]: Some people might think that this is a good use-case for exceptions, but I disagree: These errors are down to invalid requests sent by the user and we just happen to need data from the database to validate them. It is by no means an *exceptional* situation but rather a case that is expected to occur frequently.