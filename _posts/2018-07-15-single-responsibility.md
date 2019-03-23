---
layout: post
title: Single Responsibility
subtitle: "You had one job"
excerpt: In which I talk about doing one thing at a time
tags: [computer science, programming]
---

This article aims to present my idea of what single responsibility means and why it is a good idea to keep it in mind while designing for your codebase. I will try to describe what kinds of problems it solves, because at the end of the day, I believe it is more important to understand why something is a problem rather than learning about one specific way to solve it -- this only leads to cargo-cult behavior where a pattern is needlessly applied without any understanding as to why.

# Single Responsibility
*Single responsibility* is the idea that each unit of abstraction in your design should do one thing *only*. The units of abstraction depend heavily on your language of choice, but common notions are *functions*, *classes*, and *packages*.

---

## What are responsibilities?
The term *single responsibility* hinges on the definition of what a *responsibility* is. This is sometimes obvious but hard to pin down in general. I find helpful to think of the smallest unit of abstraction that still makes sense on its own. If what you are creating has a hierarchical structre (like a GUI, for example), this might be one way to delineate responsibilities.
In the end, *single responsibility* is not always about breaking down a problem domain into its atoms but about being able to point at a piece of code and say: *This is doing precisely that one well-defined thing*. After all, a package will of course have to be split into smaller parts like functions, classes etc. but you should still have a clear idea of what your package *is* doing and what it *should not* be doing.

---

### Commonly Ignored Responsibilities
Instead of giving a full taxonomy of responsibilities, I'd rather like to point out a few responsibilities that are too often glossed often:

**Lifetime management is a responsibility.** Controlling the lifetime of data should be regarded as a responsibility. In unmanaged environments this is hopefully no big news (`std::unique_ptr` is a prime example of a class that does nothing but lifetime management!). When garbage collection comes into play, this should still be at the back of your mind - pooling and similar mechanism are useful from time to time to avoid too much pressure on the GC.

**Transforming data is a responsibility.** Yes, your GUI code *could* read the data it should display from a database or deserialize all the network packages, but we both know that it shouldn't. This will make it awkward to test the code with mocked data or reuse it once you realize that the data could also come from somewhere else entirely.

**Data and state itself is a responsibility.** Plain data often takes on a life of its own. I found that especially with GUI code, you start with storing e.g. the currently selected item in a list locally in one class that is responsible for displaying said list plus its selection, but later on you notice that you might want to support hitting `ESC` to deselect it. Then you try to awkwardly add selection setters to the class that was originally just about displaying a list (the alternative is to add input handling to that class, *which is even worse*). Furthermore, the input handling code now depends on the class displaying the list and we both know that this is going to get worse.
Long story short: When to pieces of code access some piece of data, that data probably does not belong to *any* of them and you should acknowledge that the data (in this case, the list plus selection) may have taken on a life of their own and should be treated as such. In this case, it might be a good idea to let both the list and the input handler watch and modify the selection itself.

---

## "I'll just add it over here" mentality
One thing that single responsibility is meant to discourage is a mentality of *"Oh, this class does almost what I need, I'll just add my new feature over here."* This is of course the essential way in which new responsibilities are added to one unit of abstraction. Here are a few thoughts for why this is bad (and [here]({% post_url 2018-06-20-progress-bar-api %}) is another post of mine that is all about this):

Whenever you add a new feature to a, say, a class, you might introduce invalid configurations, inconsistent behavior and unintuitive interfaces. For example, just by adding a boolean you double the number of states that this class can be in. You now need to check that *all* functionality provided by the class works with all those new configurations. Similarly, adding specialised functionality to a class without taking the whole thing into account can have pretty bad consequences.

As an example, take a class representing a progress bar that fills a rectangle and sets a label in the progress bar by automatically adding a suffix to the progress value. It could look something like this (C#):
```csharp
public class ProgressBar {

    // The suffix that should be added to the progress value for the label,
    // e.g. 0.85 progress is translated to "85%" if suffix == "%"
    public string Suffix { get; private set; }

    public ProgressBar(string suffix) { ... }

    // currentProgress must be in [0, maxProgress], maxProgress > 0.
    // Internally, it will normalize the progress value and do some formatting with the value as
    // a percentage, e.g.:
    //   SetProgress(50, 100)
    // will produce the label "50" + suffix.
    public void SetProgress(float currentProgress, float maxProgress) { ... }
}
```
(Whether it is a good decision to automatically add a suffix is another story entirely; but this is an example that I have seen in a code base, so I will roll with it.)

After some time, someone notices that they would also like to display the time remaining for an operation in a progress bar, but the default formatting of adding `%` plus a suffix is not helpful. So they add a function such as the following:
```csharp
public void SetTimeProgress(float currentSeconds, float maxSeconds) { ... }
```
Now, a call like `SetTimeProgress(5, 120)` might produce the label `115s` because this seemed like a sensible way to display the time remaining in seconds. Unfortunately, this method completely ignores the `Suffix` property of the progress bar, which is quite counter-intuitive and very much inconsistent.

The worst part is that without proper code-review such it is very easy to introduce such inconsistencies, because when multiple people edit this class at the same time, they can essentially break each others' code without any merge conflicts.
In the example above, imagine that two people (A and B) are working on this class: A is adding a `SetTimeProgress` method, while B is adding a `CountDown` property to the class that makes the progress bar fill down instead of filling up (again, this is a real example). At some point, both merge their code back into their common branch and are happy to not see any conflicts in `ProgressBar.cs` - yet B's code is arguably broken: Even if it does properly incorporate the suffix, it was not written with `CountDown` in mind and will simply ignore it.

---

## Naming Units of Abstraction
I noticed that is is much easier to stick to *single responsibility* if you take great care of how you name your units of abstractions. I find it helpful to think about the names of parts of a program on a spectrum reaching from `named by purpose` to `named by function`. Names describing the purpose often describe *where* and *what for* something is used, but not *what* it is doing. On the other hand, names describing the function are ideally a very short synopsis of the things's behavior - they describe what it *does*.

Here are a few examples:
 * the `main` function of a program is named by purpose: Without external knowledge, the functions signature or name is completely useless, its purpose is to kick-off the program,
 * a function `int Sum(int[] array)` is very much named by function: It is completely described by its names and parameters and the fact that we all know what it means to sum numbers,
 * a class called `StartupWindow` is also named by purpose: What belongs in this class requires outside knowledge of the purpose of the window.

What exactly is *by purpose* and what *by function* depends on context and there is often no clear answer to what a name is (hence the spectrum). The third example, `StartupWindow`, is already quite difficult: It could in theory be defined very formally in some design document (but we all know how fast changing requirements make those obsolete).

My point is that if a name is a very clear description of what something *does* (*named by function*) instead of what it is for (*named by purpose*) then people will be less likely to just add stuff to it and extend its responsibilities. It will be impossible to name everything by its function, but in an ideal world that would be limited to your actual business logic which is only using things that are named by function.
Single responsibility is very much about finding names that describe function, not purpose, and then structuring your program around that.

---

## Benefits of Single Responsibility
I believe that the most important benefits that single responsibility provides are as follows:

First, parts of your codebase will essentially become read-only: They solve specific, well-defined problems that are independent of changing requirements and hence need to be changed.

Secondly, single responsibility makes reacting to changing requirements much easier: Ideally, your business logic is just glue code and you only have to plug your smaller problem solutions together in a new way.

{% capture comment %}

---

## Granularity
One part of single responsibility is divide-and-conquer: Break things down into smaller problems that are meaningful by themselves, solve them, and combine the solutions to solve the actual problem. I found that some people find it hard to identify the smaller problems and while I do not believe that I know how to fix that, here are some things to make it easier:

 * Do not be afraid to write functions, type or packages that are very short or simple; especially for functions there is no *too short*[^short],
 * Try to take a bottom-up approach instead of a top-down approach; 
 

[^short]: Usually the compiler will inline small functions anyway and if your language has proper support for value-semantics as in C++, classes can be quite cheap, too. Of course, profile it and ignore my advice if you have reason to think that this is causing you issues. As an interesting side note, the design of languages like C# punishes single responsibility on a type-level because  class-type fields will always cost you a dereference and a potential cache miss.

{% endcapture %}