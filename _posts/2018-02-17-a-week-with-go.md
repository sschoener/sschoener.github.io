---
layout: post
title: A Week With Go
subtitle: It's going to be a difficult relationship.
excerpt: In which I talk about my first experience with the Go language.
tags: [computer science, programming, golang]
---

On Monday, I started working on a project that is heavily using the Go language (it's a [multiplayer game](http://www.goodcompanygame.com/) with the backend written in Go, currently in very early development). I started working on it on a short notice: I basically had three days to prepare and learn Go. Thankfully, Go is a rather simple language and you can pick it up in a day and get the details on the other two (for reading, I recommend the *The Go Programming Language* but neither of *Go Design Patterns* nor *Mastering Concurrency in Go*).

---

# The Go Programming Language
Go is an imperative language in the tradition of C without any of the fancy C++ features (no classes, no templates, no references, no exceptions, but closures) and a language level notion of coroutines to enable concurrency. It compiles to native machine code, embraces value types (but uses garbage collection), and compiles blazingly fast. Go is also an object oriented language, but without classes and inheritance. Polymorphism in Go is achieved through *interfaces* that structs implement implicitly. It is reminiscent of type classes as used in Haskell, but with structural typing (that is, you don't explicitly specify what interfaces you implement or what type classes your type belongs to -- it simply checks whether the required functions are there).

There is a [wonderful little tour of Go](https://tour.golang.org/) available that you can complete in your browser. The following sometimes assumes that you have at least a passing idea of the Go programming language.

---

# My Favorite Features
There are a few things that I like (a lot) about Go:

---

##### The Ecosystem
Go not only comes with a compiler, but with a Swiss Army knife of a tool. It will automatically format and lint your files for you, which means that you will never again have to fight about what line to place a bracket on or whether a single line `if`-consequent needs braces. Go simply enforces these things according to their rules, making all code seem very uniform. I like it. (This is probably only possible because the syntax is so light.) In the same vein, It is also an error to have unused variables or unused imports in your program. The only thing I do not understand is why unused return values are not flagged as errors.

Even more importantly, building Go programs works without hassles or `make`-file magic and is blazingly fast. The most amazing feature is `go get`: It scans your projects for dependencies, downloads them from GitHub, and compiles and installs them! It took me less than 10 minutes to get from a fresh install of Go to a completely working build of a project I had never seen before. Impressive! `go get` works because of the specific workspace structure that Go imposes and clearly shows the benefits of a tightly controlled ecosystem.

There are also tools available for profiling, heuristic detection of race conditions, generating documentation with examples extracted from ordinary source files (they still have to be marked as examples), and automatically running tests and benchmaks from specifically marked functions in your package. Those are just the tools that come with the official Go installation and I am sure there are plenty more from the community.

---

##### The Clean Syntax
This is mainly in contrast to C++. I like that Go has a very simple syntax, dropping a lot of the noise that comes from strings like `->, (, ), <, >` and the like. Go still has `->` (and even `<-`), but they are used for channels only, a concurrency feature. In Go, when you have a pointer value like `p *myStruct`, you can access its member with `p.member` -- no `->` required! Similarly, Go's `for`, `if`, and `switch` do not used parentheses. This takes merely a few minutes to get used to and you will quickly see that it makes the code more readable.

As a more controversial change, there is no `while` or `do ... while` in the language, `for` is all you get. But there are different forms of `for`: With three statements `for i := 0; i < 10; i++` you get the familiar for loop, with one expression `for condition` you get a while loop, and without anything, you get an infinite loop `for { <loop body> }`, since `for` is simply a shorthand for `for true`.

---

##### Goroutines
Goroutines are Go's primary abstraction to support concurrency. These coroutines communicate among each other mostly with *channels* which are also built into the language. This language level support makes it incredibly simple to deal with concurrency. There are no threads: Just start goroutines, they will be multiplexed to threads by the runtime. You can actually have thousands of goroutines, because they start off with a rather small stack (2kb or so) and grow as needed. On the negative side this means that each function starts with a branch checking whether the stack has enough space to run it, so you are paying a little there.

---

##### Go's `switch`
Go has an interesting take on switch, treating it like pattern matching but in a very uniform way. As most control structures in Go, `switch` takes an initializing expression, optionally preceded by a statement (also works for `if`s, pretty neat). For example `switch i, err := f(); i { case 1: ... }` matches the value of `i` against the different cases. The clever part is that `switch {...}` is short hand for `switch true { ... }` and every case takes an expression instead of a constant. Therefore, a long sequence of if-then-elseif can be converted into
```golang
switch {
  case <condition_1>: ...
  case <condition_2>: ...
  ...
}
```
You could also invert all of these conditions by using `switch false { ... }` instead. Not something I'd recommend, but I like the uniformity of Go's switch.

---

##### No Implicit Conversions
One of my main gripes with C++ is the fact that single-argument constructors that are not marked as explicit are automatically used as implicit conversions between types (I would much rather mark constructors explicitly as implicit). Go does away with this nonsense and has (almost) no implicit conversions. The only time that conversions happen implicitly is when a value is assigned to an interface object, arguably one of the worst implicit casts: see the rants about interfaces below. This means that `int`s are not automatically converted to `float`s, which might be counter-intuitive, but this prevents common bugs that arise when the result of a integer division is assigned to a float in the expectation that the division already used floats.

You may think that this lack of implicit conversions leads to excessive casting, but this is actually not the case. Literals in Go are essentially untyped values and the types deduced depend on the operands used in the (sub)expression it occurs in, so `var f float32 = 1.41 + 1` will create a 32bit floating point value with value `2.41`, even though `1.41` is usually treated as a double precision value and `1` as an integer. On the other hand, `f := 1.41 + (1 / 2)` will define a `float64` with value `1.41`, because the expression `1 / 2` only uses integer value.

I also like the syntax for casting: `i := int(3.141592)` -- it just looks like a constructor call in other languages. 

---

# ...and what I hate about Go
Besides some obvious pain-points that a lot of people have with Go, I also have a few minor details that just annoy me greatly. Let's start with the obvious:

---
##### No Generic Programming
Yes, you read that right: Go does not support generic programming in any capacity. Want to write a generic linked list? You can't. The only generic types in Go are built directly into the language: Arrays, slices, channels, and hashmaps. One common advice is to simply write your Generic code against an interface, possibly the empty interface (`interface{}`) which is trivially implemented by any type. As such, it acts like `object` in C# or Java, `Any` in Scala, or simply a worse version of `void*` from C (in this specific context at least).

The problem with `interface{}` as a datatype is that it takes more space than a type that implements that interface.. If a language has explicit support for value types, then I don't want to spend half (or more!) of my cache-lines on redundant type information: When an integer assigned to an `interface{}`-object, it will be enlarged by another pointer to its type information (plus maybe some padding, assuming 64bit architectures and 32bit integers). That just hurts. And I probably do not have to point out that besides efficiency, a list of `interface{}` is also a completely different beast than a list of `T`, where `T` implements `interface{}`, which means that you have to do runtime type checking whenever you extract an element from your list.
One of the books I read on Go tried to put a positive spin on it, telling me that *this makes Go feel more dynamic*, as if that was a good thing.

I think that there are reasonable arguments against generics: They may make the syntax more difficult to understand. Compile times might suffer. Depending on how you deal with type-erasure, executable size could blow up. The language might get more difficult to understand. But none of these arguments strike me as a convincing reason *not* to include generic types for all their benefits. I can imagine that one of the reasons to not have generics is to actively *prevent* code-reuse to force people to solve the specific problem at hand instead of every problem ever, and maybe that is a way to operate when you are mostly writing simple webservices.

Maybe I am just not in the target demographic for Go: If your alternative to Go is Python, then Go looks pretty good! Indeed there seem to be a lot of people that originally come from dynamic languages such as Ruby, Python, or even JavsScript (*shudder*). For them, Go must seem like a language with an overly pedantic type system. In a way, Go is a restriction for people from dynamic languages, because they are not used to static typing, but *also* a restriction to people coming from C++ or Haskell, because they are used to much more expressive type systems. I am definitely in the latter camp and I can welcome Go as a good introductory drug for people that grew up with dynamic languages ;), but it probably won't become my go-to language (no pun intended).

With [Good Company](http://www.goodcompanygame.com/), we are using an entity-component-system for the backend and you can already imagine that there is a lot of code duplication across components and their associated systems. Instead of generics, we will probably look into code generation to solve that problem.

---
##### The Inbuilt Data Structures
Go comes with 3 kinds of generic data structures with language-level support: *Arrays*, *slices*, and *hash maps*. Arrays are not all that noteworthy, except that they always have a fixed size (the size is part of their type) and are passed by value (!). Hash maps are, well, hash maps. Finally, slices are an odd case; they have a bit of a split personality: A slice can either be seen as a view into an array (that is, a pointer into the array plus a length) or as a vector (that is, an array the grows automatically). Unfortunately, these two roles are not properly separated. Here is an example ([run it in Go's playground](https://play.golang.org/p/C_wktd30Q49)):
```golang
array := [5]int{
  1, 2, 3, 4, 5,
} // create 5 element array
slice := array[1:3] // look at elements 1 and 2 as a slice
slice = append(slice, 0) // append to the slice seen as a vector
slice = append(slice, 1)
slice = append(slice, 2) // this will allocate a new array
fmt.Println(array)
fmt.Println(slice)
```
This prints
```
[1, 2, 3, 0, 1]
[2, 3, 0, 1, 2]
```
meaning that the slice turned from a view into the array (which is usually expected to be `const`, but that concept does not exist in Go) into a vector that was using part of the underlying array as its storage. At some point it runs out of capacity in the original array and allocates a new backing array, but the original array has already been changed.

I do not think that this is a huge problem in practice (I have not really felt the need to use real arrays in Go code yet), yet I still think that slices are pretty schizophrenic. Also, is it not a little inconsistent that appending to a slice requires me to reassign the result, but inserting something into a map does not? I understand the technical justification for it perfectly fine, yet it is still inconsistent.

---
##### Assignment vs. Reassignment and Shadowing
In the code-snippet above, there are two forms of assignment: `:=` and `=`. The first means: Declare the left-hand side using the value and type of the right-hand side. The second means: Assign to a declared variable. Go allows functions to return multiple values (often used for returning a value plus an error). You will commonly see code such as 
```golang
a, err := OperationA(...)
b, err := OperationA(...)
```
In this context, `:=` can be used because there is at least one variable one the left that needs to be declared. The `err` in this case is *not* redeclared, but reassigned, because the second occurence of `err` appears in the same block as the first. But if you do this:
```golang
a, err := OperationA(...)
if err == nil {
  b, err := OperationA(...)
}
```
then the inner `err` is a *new* variable that shadows the outer variable. It is *so so so* easy to fall into this trap when you are refactoring code from above into something akin to the code below. If your code assumed that the value of `err` was always set to the last assigned value, then you just introduced a bug into your program[^error]. In general, I find it hard to believe that the language allows shadowing at all. There is not even a warning for it as far as I know!

---

##### The `defer` statement
Go does not have constructors or destructors, and RAII is hence unknown of. But there is help: The `defer` statement. It defers a function call to the return of a function. Or rather, it keeps a stack of all deferred function calls and pops them off the stack as soon as the function returns. For example:

```golang
func test() {
  defer func() {
    fmt.Println("Function returned")
  }
  fmt.Println("Function begins")
}
```
print
```
Function begins
Function returned
```
Defer can also look like this:
```golang
func expensiveFunc() {
  defer profiler.Start("expensiveFunc").End("expensiveFunc")
  // expensive operation here
}
```
When you look at it for the first time, it will likely make no sense, but it is actually doing the right thing: Starting the profiling when the function is called and ending it when it returns. The key point is that `defer` only defers its last function *call*, but not the evaluation of its parameters. A function call like `profiler.Start(...)` is equivalent to `Start(profiler, ...)`, if `Start` is declared as a method of profiler. Therefore, the above call evaluates
`p := profiler.Start("expensiveFunc")` when the function is called, and `End(p, "expensiveFunc")` when the function terminates.

It is not hard to get used to it, but for a language that takes great lengths to ensure that it is simple and intuitive, this behavior is certainly surprising.

---

##### Go's Documentation on Allocations
When I learn a language, I usually want to know pretty specifically what it is doing. As in: I want to be able to emulate the compiler by hand, at least morally. For Go, I wanted to know specifically when objects are allocated on the stack and when they are allocated on the heap. The [official FAQ](https://golang.org/doc/faq#stack_or_heap) basically says that I shouldn't ask that question and that it really is none of my business because it doesn't affect the program's semantics. That is not what I call a helpful answer. Now before you slap me around with your favorite overused Donald Knuth quote, please look up the paper that it originates from and read it as a whole: There is nothing wrong with trying to write good, performant code by default or simply trying to have an idea what your code is actually doing under the hood.

It was surprisingly difficult to find anything useful on this topic until I stumbled over [Dave Cheney's excellent blog](https://dave.cheney.net/2014/06/07/five-things-that-make-go-fast) and lost a whole afternoon reading all of his posts. They are great. He outlines more specifically how Go's escape analysis works and shows you that it is actually quite simple to get the compiler to give you the information you need. From my experience, it seems like the compiler is pretty competent at detecting whether a pointer to a value will escape from the current scope, and I am pretty confident that I can generally predict whether something will generally end up on the heap (whether it really will be allocated for a specific call of a function will also depend on inlining decisions made by the compiler). If in doubt, use [compiler explorer](https://godbolt.org/) and check the assembly for allocations yourself or use Go's compiler flags to get a log on the escape analysis.

---

##### Go's Support for Values
I like programming languages the support programming with values instead of references only. But I am convinced that a lot of the complexity of languages such as C++ come from the fact that they want to do values *the right way* -- and I believe that *must* include move semantics, custom assignment operators, and copy constructors. Needless to say, Go has neither of these features. Arguably, this is not as bad as in C++ because you are much more restricted in declaring you own types, but it brings enough problems to warrant an entry in Go's page on [code review comments](https://github.com/golang/go/wiki/CodeReviewComments#copying). Go's focus on concurrency also means that you will often copy structs with Mutexes in them, which may yield surprising results. Their documentation points this problem out quite glaringly, but I still think that there should be a better way to enforce it.

Similarly, Go lacks in features when you need to pass something by reference. There are only bare pointers[^dumb-pointers] in the language and certainly no const-references, which makes it hard to see from a functions signature what its arguments are used for. In general, I will never quite understand why so few languages adopt keywords like `const` (C/C++), `immutable` (D, Pony), `val` (Scala), or `readonly` (C#) and implement them in a consistent way (I am looking at you, C#). It might be naivity on my side, but it doesn't seem so difficult to get that right.

The fact that interfaces are implemented separately for the same type as a value and as a pointer makes it often quite difficult to see whether a call to a function will actually copy a large struct or simply take a pointer under the hood. In general, the way Go's interface work is counter-intuitive at first. Can you see why the following doesn't work?
```golang
func v(p *interface{}) {}
func main() {
  i := 1 // i is deduced as int, trivially implementing interface{}
  v(&i)
}
```
The problem is that even though `int` satisfies `interface{}`, a pointer to `int` is not a pointer to `interface{}`. This is because a value of type `int` is *not* a value of type `interface{}`. As said before, a value of type `interface{}` is a value that satisfies the interface plus some type information. Again: not hard too understand, but definitely not what you would expect at first sight. Of course it makes sense once you take into account that without `const` you will have to be able to assign to a pointer to `interface{}`, so you cannot possibly use a pointer to an int. 
All this also leads to the common pitfall of comparing an interface value to `nil` (Go's null value) and not getting the [right answer](https://golang.org/doc/faq#nil_error).
I guess in the end I just object to calling Go's interfaces `interface`s. They do mimick interfaces from Java and C#, but the fact that you have value semantics turns them into something else entirely.

---

# Noteworthy Go Features
Go has plenty of features that I do not have a strong opinion on yet, but I still find them noteworthy:
 * Go's `select` statement for goroutines explicitly says that if multiple communication actions are ready, a random one is chosen. I am not sure whether I have seen a control-structure before that was specified as doing something random. (It makes sense in the context of concurrency.)
 * Go has support for inline assembler.
 * Go's channels are first class. You can have a channel that sends channels.
 * Go has `break <label>` and `continue <label>` to break out of nested loops.
 * Go has named return values. I find this very helpful to automatically document their intended usage.
 * In Go, neither increment nor decrement are expressions -- they are merely statements. I like this and would applaud them if they went the Scala way and ditched them for `+= 1` and `-= 1`.
 * Go has the equivalent of Haskell's `newtype`: Just write `type <NewType> <OldType>` (this will not just create an alias, but a new type -- as in Haskell). This is actually a crucial feature because you can only define methods (not functions) on types on the same package, but sometimes you want to implement an interface on someone else's type -- in which case you just create a new type and implement it on that.
 * Go allows to embed values into structs, which is a concept similar to inheritance but without the polymorphism, if that makes sense. It basically allows you to automatically forward method calls to values in your structs, thus making your struct implement all interfaces that the embedded value's type implements.

I will spend plenty of time with Go over the next few weeks and I hope to appreciate its qualities a bit more and learn to live with its defects. If you have any favorite Go features or articles to read, feel free to post them in the comments below :)

---
---
---

[^error]: Before anyone jumps at me and tells me that you should handle errors directly anyway, note that this has *nothing* todo with errors at all. They are just the most common example.

[^dumb-pointers]: Or as Scott Meyers calls them: [dumb pointers](http://www.aristeia.com/Papers/C++ReportColumns/apr96.pdf)