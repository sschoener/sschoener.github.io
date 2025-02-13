---
layout: post
title: A Short Introduction to Computational Complexity Theory
tags: [computer science]
---
\\(\newcommand{\NP}{\mathsf{NP}}\\)
\\(\newcommand{\P}{\mathsf{P}}\\)

Today, I’d like to talk about the computational complexity of solving Patterna puzzles. This first the post gives a short (mostly informal) introduction to computational complexity (feel free to skip this part if you are familiar with this field). I will then talk about HexCells and Patterna in the context of computational complexity in the next post and will show you why the commonly heard claim that HexCells (or MineSweeper, for that matter) is NP-complete is either wrong or at least very misleading.

## What is Computational Complexity?
Let me digress for a moment and talk about computational complexity (CC). CC is a subfield of theoretical computer science (TCS), which studies theoretical aspects of computation in a mathematically rigid way. Nowadays, there are more subfields in TCS than I could reasonably enumerate, but I would like to shortly talk about two classical subfields: *Computability theory* (or *recursion theory*, which emphasizes the subfield’s origin) and *computational complexity* (which itself has spawned a multitude of sub-subfields). Both of these fields have a common goal:

> For a given function, how difficult is it to compute said function?

## Functions And Computation
This of course poses several questions:

 * What is a *function*?
 * What does it mean to *compute* such a function?
 * How is *difficulty* measured?

A *function* \\(f\\) is a mapping from a collection of inputs \\(A\\) to a collection of outputs \\(B\\). This \\(f\\) thus associates to each input \\(x\\) from the set of inputs an output \\(f(x)\\) from the set of valid outputs. We write \\(f \colon A \to B\\). Being able to *compute* a function \\(f\\) means that there is a (finite) sequence of steps that tells you how to effectively[^churchturing] construct the output \\(f(x)\\) from the input \\(x\\) (i.e., an algorithm). Here are some examples:

 * \\(A\\) could be the collection of all finite lists of natural numbers, \\(B\\) is the same as \\(A\\), and \\(f\\) takes a list and sorts it. There are plenty of algorithms available for sorting lists[^sortingalg], so \\(f\\) is computable.
 * \\(A\\) could be the collection of all road networks with two marked points in the network, B the set of all sequences of directions, and f the function that computes a the directions for a shortest path between the two marked points in the road network. This is basically what the navigation system in your car does[^pathfinding].
 * \\(A\\) could be a the set of all possible Patterna (or HexCells) levels, B the set consisting of the elements 0 and 1, and f maps a level to 1 if it has a solution and to 0 if it does not have a solution. We will talk about what a solution to a level in Patterna (or HexCells) is below.

As a first approximation to the *difficulty of computing* a function, we might call a function difficult to compute if there is no algorithm for computing it (such functions exist; in fact, almost no function can be implemented by an algorithm). We’ll say more about difficulty shortly.

There are some subtleties to this definition, and I have simplified some matters a bit, but this is the general idea[^encoding].

## Using decision problems instead of functions
For the purpose of the theory, it is sufficient to consider functions such as the one in the third example: Namely functions that output either 0 or 1, *yes* or *no*, *good* or *bad*, etc. Such a function \\(f\\) partitions its input set into two halves, namely the half \\(A_+\\) that contains all inputs \\(x\\) such that \\(f(x) = 1\\) and \\(A_−\\) that contains all inputs \\(x\\) such that \\(f(x) = 0\\). Such a partition of \\(A\\) gives rise to a so called decision problem: Given an input \\(x\\) from \\(A\\), decide whether \\(x \in A_+\\) or \\(x \in A_-\\) – which is just saying that we want to compute \\(f(x)\\). Often we will only specify \\(A\\) and \\(A_+\\) since this then completely determines \\(A_−\\). A *problem* in the following is then just a decision problem. Solving the problem means computing whether \\(x \in A_+\\) for any input \\(x \in A\\). Here are some examples:

 * Let \\(A\\) be the set of all 0-1 finite sequences. The problem **Parity** is the set of all finite sequences that have an even number of 1’s in them.
 * Let \\(A\\) be the set of all finite sequences of natural numbers. The problem **Sorted** is the set of all sorted finite sequences of natural numbers.
 * Let \\(A\\) be the set of all Patterna (HexCells) levels. The problem **Patterna** (or **HexCells**, respectively) is the set of all solvable Patterna (HexCells) levels.

Using a few clever arguments, one can show that the computation of any function can be replaced with repeatedly solving a decision problem[^bitbybit].

## What is a *difficult* problem?
From what I said in the beginning, we could now say that a problem is *difficult* if there is no algorithm that solves it. This perspective is a bit harsh: There are certain problems for which there *are* algorithms, but these algorithms are so slow that running them on larger inputs is not feasible.

Can we make that more formal? Yes, yes, we surely can. We already said that an algorithm consists of certain elementary steps. Given some input for the algorithm, we can count the number of steps that are needed to compute the output. For example, determining whether a list of \\(n\\) numbers is sorted will take roughly \\(n\\) steps: Start at the beginning of the list and compare each number to its successor. If it is smaller, continue, else stop. This means if we run the algorithm on an input of size 100 it will take roughly twice as long as on an input of size 50[^worstcase]. Note that this does not at all say anything about how long an actual implementation of the algorithm would need to run on such inputs. It merely describes how the length of the running time is expected to grow with the size of the input.

Given an algorithm we can thus speak of its *runtime* as the number of steps performed by the algorithm as a function of the size of the input. The *time complexity* of a problem is then the minimum runtime of an algorithm that solves this problem[^complexity]. Therefore, each algorithm for a problem gives an upper bound on its time complexity. For example, the time complexity of **Sorted** is at most linear. Similarly, to decide **Parity** we only need to traverse the input once, which means that the time complexity of **Parity** is at most linear[^parallel]. Using time complexity, we can find a better definition of difficult that is closer to the actual reality of things:

> A problem is **efficiently solvable**[^efficient] if its time complexity is polynomial. All other problems are referred to as **difficult**.

This means that a problem is efficiently solvable if there is an algorithm for it whose runtime is bounded by \\(n^k\\) for some number k, where \\(n\\) is the size of the input[^inputsize]. The existence of such an algorithm usually means that there is some insight into the problem that can be used (and we are not simply testing all possible solutions). This is in stark contrast to problems where the best known algorithms have exponential runtime[^exponential], that is their runtime grows as \\(k^n\\) for some number \\(k\\). For example, if the input is a list and the algorithm has runtime in the order of \\(2^n\\), then a list with 10 elements will take \\(2^10=1024\\) times as long as a list with a single element. A list with 20 elements will take about a million times longer to process than a list with a single element, and a list with 50 entries will take more than \\(10^15\\) times longer than a singleton list. It should be clear that this means that solving the problem for larger inputs gets infeasible very quickly.

## The classes \\(\P\\) and \\(\NP\\)
The class of all efficiently solvable problems is called \\(\P\\) for *polynomial time*. There is another class that turns out to be very useful for discussing the time complexity of many problems that come up in real life, namely the class \\(\NP\\) (*non-deterministic polynomial time*). A problem \\(A\\) is in \\(\NP\\) if a positive solution to it can be efficiently verified, where efficiently means in polynomial time[^nondeterministic]. That is, if an input \\(x\\) is a yes-instance (i.e., \\(x \in A_+\\)), then there is a short (polynomial in the size of \\(x\\) proof for it, and we can check the correctness of that proof in polynomial time. Here are some examples:

 * The problem **Clique** is defined as follows: Given a natural number \\(k\\) and a social network represented by a collection of people \\(P\\) and their friendships (where we assume that friendships are mutual, i.e. if you are my friend, I am also your friend), does there exists a clique of size \\(k\\)? That is, are there \\(k\\) people who are all friends with each other? This is a problem for which no efficient algorithm is currently known, but if there is such a clique and we know who is part of it, we can efficiently check that it really is a clique: Just check whether everyone who is part of the claimed clique is friends with everyone else from the claimed clique.
 * The problem **TravelingSalesPerson** is defined as follows: Given a positive number \\(d\\), a road network, and a list of cities, is there a path through the network of total length at most \\(d\\) that visits all the cities from the list? Again, in general we do not know of an efficient way to compute such a path[^tsp] – but if someone were to give us a path, we can easily check whether it visits all the cities from the list and whether its total length is at most \\(d\\).
 * Any problem \\(A\\) in \\(\P\\) is also in \\(\NP\\): The proof for an input \\(x\\) is then simply a trace of the run of our efficient algorithm for \\(A\\) on \\(x\\). (Do not worry if this is not immediately clear. Just remember: \\(\P\\) is a part of \\(\NP\\), since if you can solve a problem efficiently, this implies that you can check a solution for that problem efficiently.)

One of the most famous problems in mathematics and computer science asks

> Is \\(\P = \NP\\)?

This can be stated as:

> Is finding a solution harder than verifying it?

That would imply \\(\P \neq \NP\\)!
A lot of people simply say *duh, of course it is harder to find a solution than to verify it*, but we lack a mathematical proof. For a proof of \\(\P = \NP\\), we would need to find a fast algorithm for some very difficult problem (thus showing that all problems in \\(\NP\\) are also in \\(\P\\), see below). While there have certainly been advances in the time since the definition of the classes \\(\P\\) and \\(\NP\\), we have still no idea whether such efficient algorithms are possible for \\(\NP\\)-problems that are not known to be in \\(\P\\). Conversely, if we wanted to proof \\(\P \neq \NP\\), we would need to find a problem in \\(\NP\\) that is not efficiently solvable and prove that this is actually the case – that is, there *does not exists* any efficient algorithm for that problem. An upper bound to the time complexity of a problem can be established by exhibiting a single efficient algorithm for that problem. But here we are looking for a *lower bound*, saying that any algorithm whats-o-ever will take a certain amount of time, so instead of a single algorithm, we now have to consider *all algorithms at once*. Which is a tall order.
I think it is fair to say that most people in the field believe that \\(\P \neq \NP\\), but there are also prominent voices that explicitly don't rule out the opposite.

## Comparing Problems
Since it seems to be very hard to come up with *absolute* lower bounds for the time complexity of problems, it is reasonable to look for *relative* lower bounds: We would like to be able to at least say how the difficulties of problems relate to each other. Are there any hardest problems? In the context of \\(\P\\) and \\(\NP\\), the right tool for this is the so-called polynomial time reduction[^reduction]. The idea here is that if we can transform a problem \\(L\\) efficiently into a problem \\(M\\), and we can solve \\(M\\) efficiently, then we can also solve \\(L\\) efficiently. We say that \\(L\\) *efficiently reduces to* \\(M\\). To restate this: If \\(L\\) reduces efficiently to \\(M\\), then any efficient solution to \\(M\\) translates to an efficient solution for \\(L\\): To solve \\(L\\), simply translate inputs for \\(L\\) into inputs for \\(M\\) (which is efficient by assumption) and solve \\(M\\) (which again is efficient by assumption). 
Here is an example:

The problem **IndependentSet** reduces efficiently to Clique: The input for the problem is a social network and some number \\(k\\). We are searching for at least \\(k\\) people, such that none of the \\(k\\) people are friends of each other (they form an *independent set* of people). Assuming we have an efficient algorithm for **Clique**, we can do the following to build an efficient algorithm for **IndependentSet**: Take the social network that was given as an input and modify it by removing all existing friendships and inserting friendships between all people who were not friends of each other before. Now run the efficient algorithm for **Clique**. Clearly, if there existed \\(k\\) people in the original network such that none of them were friends of each other, these \\(k\\) people will form a clique in the modified network. Furthermore, this modification of the network can be done efficiently by looking at every friendship (and the size of the network is at least the number of friendships, since it needs to store the friendships somehow), so it takes at least a polynomial number of steps (relative to the size of the input network).

Amazingly, there are problems to which *all* problems from \\(\NP\\) can be reduced. That is, there are problems for which an efficient solution would immediately yield an efficient solution for *every* problem in \\(\NP\\). These problems are called \\(\NP\\)-*hard*. If an \\(\NP\\)-hard problem is also in \\(\NP\\), it is \\(\NP\\)-*complete*. 
Here are some problems from the surprisingly long list of \\(\NP\\)-complete problems:

 * **Clique** is \\(\NP\\)-complete
 * **IndependentSet** is \\(\NP\\)-complete
 * **TravelingSalesPerson** is \\(\NP\\)-complete

Proving a problem \\(\NP\\)-complete is generally seen as good evidence that there most likely is no efficient algorithm solving the problem.

## Recap
Here is the TL;DR version of everything above:

 * \\(\P\\) is the class of efficiently solvable problems
 * \\(\NP\\) is the class of problems for which positive instances can be efficiently verified
 * If a problem \\(L\\) efficiently reduces to a problem \\(M\\) and \\(M\\) is efficiently solvable, then \\(L\\) is efficiently solvable.
 * A problem is \\(\NP\\)-hard if all problems in \\(\NP\\) efficiently reduce to it.
 * A problem is \\(\NP\\)-complete if it is \\(\NP\\)-hard and in \\(\NP\\).
 * \\(\NP\\)-complete problems are the most difficult problems in \\(\NP\\).
 * Finding an efficient algorithm for an \\(\NP\\)-complete problem is improbable since that would prove \\(\P = \NP\\) and [earn you a million dollars](http://www.claymath.org/millennium-problems/millennium-prize-problems).

[^churchturing]: What *effective* means is of course up for debate (well, most people do accept the Church-Turing thesis), but for simplicity let’s say that *effective* simply means that it can be implemented on a computer such as the one you are using to read this.

[^sortingalg]: [Here is a popular one.](https://en.wikipedia.org/wiki/Quicksort)

[^pathfinding]: Except that the system in your car does not have the road network as an input but built into it. It simply takes two locations and computes the shortest path in the fixed map it comes with. This is of course a [well studied problem](https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm). To be quite honest, it is unlikely that your car is actually giving you the shortest way in all cases. Even though we know how to solve that problem efficiently, the road networks found in reality are much too big to use this "efficient" solution, so your navigation system likely implements a few simplifications like leading you to a highway first.

[^encoding]: Here is a first thing to think about: How is the input from \\(A\\) given to the algorithm? For example, how does the algorithm access the information in the map (from the 2nd example)? In other words, we have to deal with encoding. For all intents and purposes, we can assume that inputs are *always* finite sequences consisting of 0s and 1s. I hopefully do not have to convince you that any kind of finite information can be encoded in this fashion (the computer you are using right now does exactly that). This of course excludes cases where e.g. \\(A=\mathbb{R}\\), since we would then have to manipulate infinite objects. There are ways and ideas around that, e.g. working with approximations to infinite objects, but this is getting too far from the actual point I am trying to make.
 
[^bitbybit]: The main idea is simple: Assuming \\(f \colon A \to B\\) maps 0-1 sequences to 0-1 sequences (i.e. sequences of bits), we can replace the computation of f with computing the single bits of the output sequentially.

[^worstcase]: This of course only holds for the worst case of a sorted list. If the first two elements of a list are not in sorted order, then surely we can already determine the output of the function without going through the rest of the list -- it is not sorted. We will always consider the worst-case, which may not be realistic, but simplifies things a lot (and still leaves us with a theory that has more open problems than questions answered).

[^parallel]: Such upper bounds of course depend on the specific mode of computation. We are restricting ourselves to sequential computation. In a [parallel world](https://en.wikipedia.org/wiki/Circuit_complexity), **Parity** can be solved more quickly.

[^efficient]: This is a term that a lot of people are offended by, since a runtime of \\(n^20\\) is hardly efficient. They are not wrong, but we will ignore this issue here. Also note that this terminology is rather sloppy and does not completely reflect the nuances that are distinguished within Computation Complexity Theory.

[^inputsize]: The *size* of the input is of course a measure to be defined carefully (and not without [its quirks](https://en.wikipedia.org/wiki/Padding_argument)). We will usually mean the length of the input encoded in bytes in some sensible form, which for lists is linear in the length of the list. This becomes more tricky when numbers are part of the input, since people always tend to first think of the runtime in terms of the number in the input, not the length of its encoding (which is usually logarithmic in the number, unless you are going for unary codings – which is one of these quirks mentioned above). [Pseudopolynomial algorithms](https://en.wikipedia.org/wiki/Pseudo-polynomial_time) are what you end up with.

[^exponential]: There are of course plenty of functions that are super-polynomial but sub-exponential. We will ignore them here.

[^nondeterministic]: The original definition is in terms of *non-deterministic Turing machines*, but this is taking us a bit too far off and also (in my opinion) not that helpful. Our definition can be made [more formal](https://en.wikipedia.org/wiki/NP_%28complexity%29#Verifier-based_definition). In a very precise way, \\(\NP\\) is simply \\(\P\\) with an existential quantifier ranging over a polynomial number of bits. 

[^tsp]: The classical definition is not taking a road network (i.e. a map) as its input but simply a list of distances between the cities. For an actual road network, [we can do a bit better](https://en.wikipedia.org/wiki/Travelling_salesman_problem#Euclidean_TSP) than for the general case.

[^reduction]: [Formal definition here](https://en.wikipedia.org/wiki/Polynomial-time_reduction).