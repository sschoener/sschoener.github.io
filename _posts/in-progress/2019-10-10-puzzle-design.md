---
layout: post
title: Thoughts on Puzzle Game Design
excerpt: 
tags: [games, computer science]
---

* TOC
{:toc}

I have been thinking a lot about the design of puzzle games lately. 

# An Intro to Computational Complexity
In order to follow my thoughts below, you will need a very basic understanding of a wonderful branch of theoretical computer science, namely *Computational Complexity*. The goal of this field is to understand the inherent complexity of solving specific problems. A few examples of such problems are 

> **Primes**: Given a number, is it prime (has no other divisors than 1 and itself)?

> **Sudoku**: Given a Sudoku board, is it solvable?

> **Sorted**: Given a list of numbers, is it sorted in ascending order?

> **ShortPath**: Given a map, a number \\(k\\), and two cities on the map, is there a connection of the two cities on the map of length at most \\(k\\) kilometers?

> **RoundTrip**: Given a list of cities, their distances to each other, and a number \\(k\\), is there a route that visits all cities and has length at most \\(k\\)?

As you may have noticed, these problems have a specific structure: They consist of a specification of the input (the number, the Sudoku board, the list of numbers, the map with the number and cities) called the *instance of the problem* and expect either a *yes* or a *no* as an answer. Such problems are called *decision problems*. It turns out that this restriction to yes/no questions is irrelevant, since there is usually a clever way to convert arbitrary problems like *what is the solution of this Sudoku board?* into a series of such yes/no questions.

## Solving a Problem
This explains what we mean by *problem*. Now on to what *solving a problem* means: Solving a problem comes down to giving an *algorithm*, that is, a recipe, that calculates the correct answer. For the **Primes** problem, an algorithm could be as follows:

> Let \\(k\\) be the input number. If \\(k = 0\\) or \\(k = 1\\), answer *no*. Otherwise, for each number \\(n\\) smaller than \\(k\\), starting from 2, check whether \\(n\\) divides \\(k\\). If it does, answer *no*. If no divisor was found, answer *yes*.

Note the following: The algorithm will always only take finitely many steps to reach a conclusion. Additionally, it uses only finitely many additional information. These are two crucial properties of algorithms: They are effective and can therefore be implemented on a computer. One could imagine a simpler 'algorithm' for **Primes** that simply says:

> Let \\(k\\) be the input number as \\(p\\) the list of all primes. Answer *yes* if \\(k\\) is in \\(p\\).

This algorithm is not effective, since it assumes that we already *have* a list of all primes lying around here somewhere and can use that. Unfortunately, such a list is infinite, so we cannot simply precompute it and store it. If this all sounds to vague, rest assured that complexity theorists use a more formal definition of what is a valid algorithm an what is not.

## Resource Usage of Algorithms
A reasonable definition of *difficult problem* might then be that there is no *good* algorithm solving it. Of course, this needs to be more precise, since we lack a notion of what makes an algorithm *good*. One approach is to measure the *resources* that an algorithm requires to solve a problem. The two primary resources under consideration are usually *time* and *memory space*. We will focus on the first.

The runtime of an algorithm is *not* measured by implementing it on a computer and running it, measuring the time it takes to reach its conclusion. This measure would be far to volatile and unstable to compare algorithms. Besides that, the runtime will probably depend heavily on the input to the algorithm, so if we wanted to measure it, we would first need to come up with a number of inputs that are representative of all instances that we want to solve.

### Runtime Analysis
Instead, the runtime of an algorithm is measured in the abstract by counting the number of abstract steps that it will take, relative to the size of the input[^time-complexity]. If this sounds quite abstract, here is an example. Take the problem **Sorted**. An algorithm for this problem could be as follows:

> Let \\(l\\) be the input list of numbers. Starting with the second number, compare each number to its predecessor in the list. If it is smaller than its predecessor, answer *no*. When you reach the end of the list, answer *yes*.

The runtime of the algorithm is *linear* in the size of the instance, meaning that when you have \\(n\\) numbers in your input list, then you will take approximately \\(n\\) steps. We don't really care about the exact number of steps (is it \\(2n\\)? or \\(4n+1\\)?), but only about the rough ballpark. So it does not really matter whether your algorithm traverses the list twice (that would be about \\(2n\\) steps, which we treat as equivalent to \\(n\\)), but if you traverse the list once for every element in the list, you have a relevant difference in runtime, since that would involve \\(n^2\\) steps. Additionally, we only care for the behavior of the algorithm for large inputs. The technical term for this is *asymptotic runtime analysis* and to communicate that our runtime is a rough estimate to for large estimates that ignores all kinds of constants and scaling, we usually wrap it in an \\(O(\cdot)\\)[^landau]. Our algorithm from above therefore has a runtime of \\(O(n)\\).

Note here that we do consider the *average runtime* of the algorithm, but the worst case. The algorithm for **Sorted** above does not always need to look at the full list; if the first two numbers of the list are already in the wrong order, we immediately know that the list is not sorted. This, however, is irrelevant for its worst-case runtime, since there are still plenty of lists that we need to traverse in full to determine whether they are sorted (any list that is sorted, for example).

In general, we care especially about asymptotic runtimes of the following form, where \\(n\\) always denotes the size of the input:

 * \\(O(n^k)\\) for some number \\(k\\) (*polynomial runtime*),
 * \\(O(2^n)\\) (*exponential runtime*).

I have swept a lot of details under the rug here. Just remember that *polynomial runtime* is generally fast.

## The Time-Complexity of a Problem
Now that we have a measure for the resource usage of an algorithm, let's use that to define the *time-complexity* of a problem:

> The *time-complexity* of a problem is the minimum asymptotic runtime of any algorithm that solves it.

This is essentially a quantitative version of saying that a problem is complex if there is no straight-forward way to solve it.

Our discussion above for example established that the time-complexity of **Sorted** is at most \\(O(n)\\). The fact that we have an algorithm that runs in \\(O(n)\\) tells us that the minimum asymptotic runtime must be less or equal than \\(O(n)\\). We have not established that there is no algorithm that runs in, say, \\(O(\sqrt{n})\\) (or some other asymptotic bound below \\(O(n)\\)), so cannot reasonably claim that our bound is tight[^landau-tight].

### Determining the Time-Complexity of a Problem
In general, it turns out to be very difficult to determine the *exact* time-complexity of problems, because this requires us to rule out entire classes of algorithms, whereas an upper bound on the complexity of a problem can be established by presenting just a single algorithm that solves this problem. There are next to no problems for which non-trivial lower bounds on the complexity are known.

On the bright side, it turns out that there are meaningful ways to compare the complexities of different problems without knowing them. This central idea here is that of a *reduction*: A problem \\(A\\) is said to *reduce* to a problem \\(B\\) if there is an algorithm that transforms *yes*-instances of problem \\(A\\) into *yes*-instances of problem \\(B\\) (and the same for *no*-instances). Solving \\(A\\) then amounts to transforming the given instance of \\(A\\) into a \\(B\\)-instance and running an algorithm solving \\(B\\) on that instance. If the algorithm that performs the reduction is efficient (i.e. has polynomial runtime), then we can say that \\(A\\) is at most as difficult as \\(B\\).

## Complexity Classes
Now we are ready to see some of the most popular definitions in all of computer science: The complexity classes \\(\mathbf{P}\\) and \\(\mathbf{NP}\\). A *complexity class* is simply a collection of problems. For example, \\(\mathbf{P}\\) is the class of all problems of polynomial time-complexity. The letter *P* in its name literally means *polynomial*.

In constrast to this, there is the class \\(\mathbf{NP}\\). Its *not* an abbrevation for *non-polynomial*, but for *non-deterministic polynomial*. Let me elaborate. \\(\mathbf{NP}\\) is defined as the class of problems whose solutions can be check efficiently. For example, no efficient algorithm is known for the problem **RoundTrip** from above, but if someone claims to have found a round trip, then it is really easy to check that it a) visits all cities in the list and b) has a length of at most \\(k\\). Hence, this problem is in \\(\mathbf{NP}\\). Formally, a problem is in \\(\mathbf{NP}\\) if: For each *yes*-instance of the problem there is a short (polynomial in the length of the instance) proof that certifies that it is truly a *yes*-instance .

It is not difficult to see that \\(\mathbf{P} \subseteq \mathbf{NP}\\), so every problem with polynomial time-complexity has efficiently checkable solutions. Whether \\(\mathbf{P} = \mathbf{NP}\\) is true is still an open question.

Another class of interest is \\(\mathbf{coNP}\\) -- essentially, these are negated \\(\mathbf{NP}\\) problems, defined by the property that *no*-instances have efficiently checkable, short certificates.

### Complete Problems
One amazing fact about the class \\(\mathbf{NP}\\) is that the \\(\mathbf{P} = \mathbf{NP}\\) question can be made much more concrete by considering *\\(\mathbf{NP}\\)-complete* problems. These are \\(\mathbf{NP}\\)-problems that are among the most difficult to solve. Formally, a problem is \\(\mathbf{NP}\\)-complete, if it is in \\(\mathbf{NP}\\) and *every* other problem in \\(\mathbf{NP}\\) reduces to it. Problems with just the latter property are \\(\mathbf{NP}\\)-hard. That is, if any \\(\mathbf{NP}\\)-complete problem has at most polynomial time-complexity, then *all* problems in \\(\mathbf{NP}\\) have polynomial time-complexity. The surprising part is that \\(\mathbf{NP}\\)-complete problems actually exists and that there are *plenty* of them -- **RoundTrip** for example is one of them, better known as the *Traveling Salesperson* problem. 

# Puzzle Games and Computational Complexity
My perspective on puzzle games is certainly a biased ones, as I see games mostly as formal systems -- like good board games[^board-games]. I usually do not care so much about the intricate stories and worlds that the designers of the game have built. Furthermore, I have a hard time with games that use a physical world that is not meant to be understood as discrete. As such, I mostly think about *abstract* games, or as I like to call them: *explicit games*. Here, I would like to focus on logic games.

Games that I have in mind are (for example) [Sudoku](https://en.wikipedia.org/wiki/Sudoku), [MineSweeper](https://en.wikipedia.org/wiki/Minesweeper_(video_game)), [Patterna](http://store.steampowered.com/app/503860/Patterna/), [Nonogram](https://en.wikipedia.org/wiki/Nonogram), [Sokoban](https://en.wikipedia.org/wiki/Sokoban), or [Numberlink](https://en.wikipedia.org/wiki/Numberlink).

## The Computational Complexity of Puzzle Games
Games such as the games above are often known to be computationally difficult, i.e. \\(\mathbf{NP}\\)-hard or \\(\mathbf{coNP}\\)-hard (*Sokoban* is apparently \\(\mathbf{PSPACE}\\)-hard). Claims such as

> MineSweeper is \\(\mathbf{NP}\\)-complete

come up in every discussion on such puzzles and I cannot help but notice that this is often simply not true. The keypoint here is that *MineSweeper* denotes a *game*, not a problem! And I can definitely see more than a single problem that arises from this game. A naive first formulation might be:

> **MineSweeperConsistency** (MSC): Given a MineSweeper board with some revealed cells and some hints, is there a way to distribute mines on the unknown cells such that all hints are satisfied?

This problem is \\(\mathbf{NP}\\)-complete. I am not going to go through the whole proof, but it is at least easy to see that it is \\(\mathbf{NP}\\): Given an arrangement of mines, it is just a matter of counting to see whether all constraints are satisfied.

### Misconceptions about the Complexity of Puzzle Games
But is this really what MineSweeper is about? Is it a game about placing mines on a grid to satisfy constraints, about solving MSC? No, of course not! We *know* that the board we are given is consistent What we are interested in is the following: Given a consistent MineSweeper board, is it solvable? Because MineSweeper is a game in which you are given new information from time to time, it is formally much easier to think of this problem instead:

> **MineSweeperProgress** (MSP): Given a consistent MineSweeper board with some revealed cells and some hints, is there at least one cell whose state you can deduce?

If there is an efficient way to solve this problem, we can surely also determine whether a cell is solvable. It turns out that this problem is \\(\mathbf{coNP}\\)-complete ([see here](http://link.springer.com/article/10.1007%2Fs00283-011-9256-x)). Again, I will not go into the proof, but it is easy to see that is in \\(\mathbf{coNP}\\): If there is no way to determine the state of a specific cell, this means that there are two assignments of states to cells that do not agree on this cell (once it is a mine, once it is clear) but are both compatible with the constraints on the board. This is efficiently checkable and specifying two such assignments for each cells is still polynomial in the size of the board, so its also short. Let's call these assignment *blocking configurations*.

That alone should at least convince you that this problem is probably *not* \\(\mathbf{coNP}\\)-complete, since if it is, [terrible things happen](https://www.scottaaronson.com/writings/phcollapse.pdf).
Note at this point that I am not claiming that the question whether a MineSweeper board has a unique solution is in \\(\mathbf{coNP}\\). That is a different beast entirely, because here we are in a way trying to solve both questions at once. Uniqueness problems are not as well studied as other problems, so if you have any pointers on this specific problem, do get in touch.

### A Common Theme
There is something very similar going on with Sudoku. First of all, Sudoku has to be generalized to allow arbitrarily large boards to make sense of asymptotic complexity. It does not take you long to find that [Sudoku's Wikipedia entry](https://en.wikipedia.org/wiki/Sudoku) claims that it is \\(\mathbf{NP}\\)-complete, with the problem that it *again* does not spell out what problem is considered. Yes, the question of *consistency* (whether there is *a* solution) is certainly in \\(\mathbf{NP}\\) and I am willing to believe that it is also \\(\mathbf{NP}\\)-hard. But that's not the point of the game. If it was, then an empty grid would make a perfectly fine Sudoku because apparently it is about finding just some way to fill in the numbers, adhering to the the rules of Sudoku.

Its basically the same story: The problem of *progress*, of actually *solving* a Sudoku board, is a \\(\mathbf{coNP}\\) problem. The same argument of blocking configurations works out just as well. Nonograms also has this property, as do Patterna and Numberlink.

I would argue that this is unsurprising: Logic puzzle games are inherently about that which cannot be different, about proofs that show what is strictly necessary.

## Generating Puzzles

[^time-complexity]: This is often called the *time-complexity* of the algorithm, but that is utter nonsense. Complexity theory is about measuring the complexity of *problems*, not whether it is difficult to understand multiple nested `for`-loops or other algorithmic techniques.

[^landau]: Needless to say, this notation has a very specific meaning that can be formally defined. [See here.](https://en.wikipedia.org/wiki/Big_O_notation)

[^landau-tight]: Saying *at most \\(O(n)\\)* is a bit redundant. With a big O, you are *by definition* always giving upper bounds. The whole paragraph is a bit sloppy, I know.

[^board-games]: Incidentally, I think that the best part of any board game is reading the rules and explaining them to the other players.