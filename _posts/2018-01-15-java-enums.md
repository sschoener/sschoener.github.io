---
layout: post
title: A Few Thoughts on Java Enums
subtitle: Java enums vs. C# enums
excerpt: In which I talk about why I like Java's enums and stumble upon a nice application of C#'s partial classes.
tags: [computer science, c#, java, programming]
---

I have a confession to make: *I feel that there is one thing that Java does better than C#.* There. I said it. Please don't judge me.

### C# Enumerations

The (one, single) Java feature that I personally am fond of is *enums*. Now, C# *also* has enums, but they are quite different from the ones you find in Java. In C#, an enumeration is simply a set of named integer values (with a few bells and whistles). An example would be

```csharp
public enum Color {
    Red,
    Green,
    Blue
}
```

In C#, a good way to expand on enums and make them feel more like proper types is to use extension methods. Say, for example, that you would like to convert colors to their RGB values represented as RGB with 8 bits per channel packed as an integer (with BGR from LSB to MSB). In C#, this could be achieved as follows:

```csharp
public static class ColorHelper {
    public static uint ToRGB(this Color c) {
        switch(c) {
            case Color.Red:
                return 0xFF0000;
            case Color.Green:
                return 0x00FF00;
            case Color.Blue:
                return 0x0000FF;
            default:
                // the fact that we have to add a default case here is actually
                // due to the fact that the following is perfectly valid and
                // doesn't throw:
                // Color c = (Color) 1238;
                throw new System.ArgumentException("Unknown color value: " + c);
        }
    }
}
```

Calling code would then look like this:
```csharp
Color c;
// code assigning a value to c
uint rgb = c.ToRGB();
```

This is all nice, but it quickly gets out of hand when you have multiple values associated to each enum value. For example, you might want to add a function that converts the `Color` to its HSL representation. That's another function with hardcoded constants instead of nicely named values.


### Java Enumerations
Java handles this use case nicely. In Java, an enumeration is inhabited by objects (*of course it is*, it's Java) and these can of course have many properties and methods. Here's a Java version:

```java
public enum Color {
    // Here we declare the enum values...
    Red(0xFF0000),
    Green(0x00FF00),
    Blue(0x0000FF); // note the semicolon here

    // ...and here the class that the enum values implement
    private final int rgb;

    Color(int rgb) {
        this.rgb = rgb;
    }

    private int rgb() { return rgb; }
}
```

This is *much* more pleasant to look at. As an added bonus, you can even make the class underlying `Color` abstract and have each object specialize *that*! This is useful when you need a set of objects that are essentially all singletons but have a common interface. For example, in many of my processing sketches, I have different coloring modes that the user can select. I usually know that this is a pretty fixed selection and that I am not going to add new ones to them, or in short: I have some interface that I could declare via an abstract base class, but I explicitly want to restrict the actual implementations of that interface to my classes. Here is how that would look with an enum:

```java
public enum ColoringMode {
    Mode1 {
        @override
        public void applyColor(Entity entity) {...}
    },
    Mode2 {
        @override
        public void applyColor(Entity entity) {...}
    },
    Mode3 {
        @override
        public void applyColor(Entity entity) {...}
    };

    public abstract void applyColor(Entity entity);
}
```

This approach to enum of course also has its downsides, since C#'s implementation arguably has a much smaller overhead than Java's. But I have yet to see a program where that really matters. Also, restricting inheritance like this is quickly becomes a non-feature once your interface grows beyond a small number of functions and a small number of implementations, since they will all sit in the same file.


### Emulating Java's enums in C\# 
We are now at the point where we will restore the world order and show that this is of course also possible in C#, clearly making it the superior language ;) because Java is missing plain enums that are present in C#. The following solution makes use of the fact that nested classes can access members of the host class (and are private by default):

```csharp
public abstract class ColoringMode {

    public static readonly ColoringMode Mode1 = new ColorMode1();
    public static readonly ColoringMode Mode2 = new ColorMode2();
    public static readonly ColoringMode Mode3 = new ColorMode3();

    public abstract void ApplyColor(Entity entity);

    private ColoringMode() {}

    class ColorMode1 : ColoringMode {
        public override void ApplyColor(Entity entity) { /* ... */ }
    }
    class ColorMode2 : ColoringMode {
        public override void ApplyColor(Entity entity) { /* ... */ }
    }
    class ColorMode3 : ColoringMode {
        public override void ApplyColor(Entity entity) { /* ... */ }
    }
}
```

If you are providing your code as a library and merely want to prevent users from subclassing, you could use the newly introduced access modifier `private protected` (C# 7.2) on the constructor. This allows only subclasses declared in the same assembly to access the constructor, allowing you to distribute the implementations of the different enum values across different files. Admittedly, I think in that case it would be more apt to declare the outer class `partial`, especially since it is in the language for exactly that purpose[^partial].

### Conclusion
There you have it -- Java enums are cool, but ultimately there is a cleaner solution available in C#.


[^partial]: It is always a pleasure to find a good use case for an underused feature such as `partial`.