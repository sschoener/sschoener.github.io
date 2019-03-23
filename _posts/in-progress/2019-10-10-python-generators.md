---
layout: post
title: The Awesomness of Python Generators
excerpt: In which I give a short overview of the features of Python generators.
tags: [programming, computer science, python]
---

I believe it was Haskell that first made me aware of how useful implicit data structures are. By implicit data structures I mean data that does not physically exist in memory, but is still accessible. Thanks to its non-strict evaluation, you can for example define the list (or rather stream) of all natural numbers as follows:
```haskell
nats : Num a => [a]
nats = 0 : fmap (+1) nats
-- The naturals are 0, followed by 0 + 1, 0 + 1 + 1, etc.
-- And yes, in any universe that knows any good natural numbers should start with 0, not 1.
```
This definition by itself does *not* create an infinite collection of numbers somewhere in memory, but merely describes how that collection comes to be. In Haskell, you can then go on and create more collections from what you have defined, like all even numbers:
```haskell
evens = fmap (*2) nats
```

# Delayed Computation in Imperative Languages, C\#
This style of describing computations while delaying their execution has spilled over into imperative languages in the last 15 years or so. A good example of this is C# with its `yield` keyword to define enumerators (which are C#'s version of iterators). Here is how you would define the above in C#:
```csharp
public static IEnumerable<int> Naturals() {
    for (int i = 0; ; i++)
        yield return i;
}
```
Behind the scenes, the C# compiler will translate this into an anonymous class implementing the `IEnumerator<int>` interface with a member field for `i`. You can then use this method as follows to define the even numbers:
```csharp
public static IEnumerable<int> Evens() {
    foreach (int n in Naturals())
        yield return 2 * n;
}
```
Alternatively, you can use C#'s Linq extension methods:
```csharp
public static IEnumerable<int> Evens() => Naturals().Select(n => 2 * n);
```
Here, `Select` corresponds to `fmap` in Haskell. Note again that no actual computation happens when defining the `Evens` function. It is only evaluated when the collection defined by `Evens` is actually traversed.
```csharp
int counter = 0;
foreach (int n in Evens()) {
    counter++;
    if (counter >= 3)
        break;
}
```
This piece of code for example will cause the first three elements of `Evens` to be computed, but nothing more. This has both benefits and downsides: The benefit is that only computation that is really required is performed, the downsides are a) that multiple accesses to the conceptual list represented by `Evens` all cause a recomputation of the data (unlike in Haskell) and b) that it can lead to performance that is hard to keep track of.

I should point out that C# implementation really only works well for linear collections. In Haskell, it is very easy to define trees with such lazy behavior (it is the default behavior in Haskell after all!), but `yield` will be of little help when you attempt to do this in C#. Anyway, this wasn't what I was planning to write about, so back to topic.

# Delayed Computation in Imperative Languages, Python
One of my favorite implementations of this style of programming is from Python. All the C# examples work as expected:
```python
def nats():
    i = 0
    while True:
        yield i
        i += 1

def evens():
    for n in nats():
        yield 2 * n
```
Functions defined with `yield` are called *generators* in Python.
Here is the twist: Whereas `yield` is a statement in C#, Python's `yield` is an expression -- meaning that it can be used as a value! If we were to inspect the value of the yield expressions above, we would find that they are `None`, because we did not pass anything into the generator. So how do we do that? Fortunately, this is quite simple:
```python
def generator():
    value = 0
    while True:
        # this line causes the generator to pause its execution, return the current value plus 1
        # to the caller, and (when the caller resumes) store the value passed in by the caller
        # in the value variable
        value = (yield value + 1)
        print(value)

def use_generator():
    # initialize the generator
    g = generator()
    # we use `send(None)` to advance the generator to the yield statement and get its initial value
    x = g.send(None)
    while True:
        # we pass in the current value of x and get the new value for x
        x = g.send(x)
```
The `generator` begins by returning a value of 1. It then repeatedly takes an input value from the outside, prints it out, and returns the input value plus one the next time it yields. In `use_generator` the genrator is first fed a value of `None` using `send(None)` to advance it to the first `yield` in its body, and then it is repeatedly advanced with the value of the `yield`-expression. The first call to `send` *must* have an argument of `None`, because at this point the generator is not waiting for any value (it has not started its execution yet).