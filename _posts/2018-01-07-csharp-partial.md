---
layout: post
title: Partial Methods in C#
subtitle: A Feature You Most Likely Didn't Know About
excerpt: In which I give a brief overview of partial methods in C#, but fail to come up with a good use case.
tags: [computer science, c#, programming]
---

When I need a break, I often look what is on the horizon for my favorite programming languages to get excited about: Concepts in C++, better value-type support in C#. But sometimes I also get to learn something new about a language I thought I knew inside out. Today was such a day: I learned about partial methods in C#.

### Partial Classes
We are all familiar with partial classes in C#:

```csharp
// in file X_1.cs
partial class X {
    // whatever you want in your class
}

// in file X_2.cs
partial class X {
    // whatever else you want in your class
}
```

At compile time, the two declarations are merged. All fields, properties, methods, etc. from each of the two declarations are present in the final definition of `X`.
If you have ever worked with WinForms and the designer for that in VisualStudio, then you have probably been using a lot of `partial` classes: The WinForms editor generated most of the UI code and you merely implemented a few handlers.
Less known is that you can actually vary the class declaration for partial classes (in some places). For example:

```csharp
// in file X.cs
partial class X {
    // whatever you want in your class
}

// in file X_IWhatever.cs
partial class X : IWhatever {
    // define how X implements the IWhatever interface
}
```

The interfaces that `X` implements are simply collected from all declarations of a partial class. I have never used it, but I am sure that there are places where you can put this to good use to put the implementation of an interface into another file.

### Partial Methods
Within a partial class, you can define a partial method like this:
```csharp
partial class X {
    // declare the method in on place
    partial void myPartialMethod();
}

partial class X {
    // define it in another
    partial void myPartialMethod() {

    }
}
```

This seems to only split the declaration of the method from its definition (as is common practice in C++), but there is more to it. The main feature is that you don't *have* to provide a definition. You can simply forgo the implementation. In that case, whenever a call to the undefined-but-declared partial method is made, the compiler will silently drop it. Due to this behavior, there are strict restrictions on what methods can be marked partial:

 * its return type must be `void`,
 * it cannot declare an access modifier and is automatically `private`,
 * it cannot have `out` parameters (but `ref` is fine),
 * it cannot be `extern`.

For more information, see the [C# programming guide](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/partial-classes-and-methods#partial-methods).
In the context of GUI development and WinForms, this behavior of partial methods makes perfect sense. The programming guide mentions that `partial` methods are to be treated like events (think `OnButtonClicked` etc.), and there is no need to respond to every single event.

Is there another good usecase for partial methods? I am not sure whether I would really advise making use of this feature. If you want a quick way to disable a call to a method without changing each callsite, you should rather use the [Conditional attribute](https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.conditionalattribute?view=netframework-4.7.1). The particularly nasty thing about partial methods is that *by design* the compiler won't complain if the implementation is missing, and that by itself almost entirely rules out using this feature.