---
layout: post
title: Compactness as Completeness via Ultrafilters
excerpt: In which I complain about how compactness is introduced in topology classes
tags: [mathematics]
---

In the typical undergrad curriculum for mathematics, you will find at least these two concepts that often lack motivation and proper intuition: Determinants and compactness. Here is my take on the latter.

# Compactness
The usual definition of a compact space is as follows:

> A space is compact if every open cover contains a finite subcover.

While this may often be a *useful* definition, I would argue that it is in no-way an *intuitive* definition when you first learn about it. Soon after that, you will learn about *sequentially compact spaces*:

> A space is sequentially compact if every infinite sequence has a convergent subsequence.

This is much more relatable: By the time you get to point-set topology, you have seen plenty of arguments involving sequences. You are probably much more familiar with convergence of sequences than the elusive notion of an *open set*.

Now the bad news is that sequential compactness is not generally equivalent to compactness (only in the case of first-countable spaces and metric spaces in particular). This is further proof that there is no god, but also shows us that what we are dealing with is essentially an issue of size: Compactness is not equivalent to sequential compactness because there are some spaces that are just too large to be characterized by their sequences only.

What if there was a nice equivalent notion for general spaces that is just as intuitive? Well, you're in luck: There is.[^nets]

# Ultrafilters
Some topology classes include a section about filters and ultrafilters, but I have yet to find one that puts in some effort to actually explain some intuition for them (references welcome![^qchu]).
In the following, let $(X, \tau)$ be a topological space.

A *filter* on $X$ is a non-empty subset $F \subseteq \tau$ with the following properties for all open sets $U, V \in \tau$:

 1. If $U \subseteq V$ and $U \in F$, then $V \in F$.
 2. If $U, V \in F$, then $U \cap V \in F$.
 3. $\emptyset \notin F$.

Additionally, a filter $F$ is an *ultrafilter* if for every $U \subseteq X$ either $U \in F$ or $X \setminus U \in F$ (this is equivalent to the usual definition that $F$ is maximal w.r.t. inclusion among filters). Establishing the existence of interesting ultrafilters is not difficult, but requires stronger assumptions like the axiom of choice.[^axioms] This statement is usually known as *the ultrafilter lemma* and is mostly used to say that a filter can be extended to an ultrafilter (not necessarily a unique one).

There is also the notion of an *ultrafilter on a set*, which is the same as an ultrafilter on that said equipped with a discrete topology (i.e. all subsets of open). The typical definition for ultrafilters that you will likely find elsewhere is that for sets. You can use that one, too, for the most part, but will notice that all of its properties are defined by the open sets it contains, so we might just as well limit ourselves to them.

## What *are* ultrafilters?
A filter is a way of *zooming in* on a region of the space $X$, starting by looking at the whole space. Let me explain: If $U \in F$, then the region that we are zooming in on is contained in $U$. We may say that we *pass through $U$* while zooming in. The properties of a filter merely ensure that we are zooming somewhere in a consistent fashion:

 1. If we pass through $U$ (i.e. $U \in F$), then we also pass through any superset of $U$.
 2. If we pass through $U$ and through $V$, then we also pass through $U \cap V$.
 3. We cannot pass through $\emptyset$ because it is empty!

Here are some examples:
 * The set $F = \lbrace X \rbrace$ is a filter. It describes the process of zooming in until we see the whole space, i.e. not zooming in at all.
 * For any point $x \in X$, the filter $F_{x} = \lbrace U \subseteq X \mid x \in U \rbrace$ is called the *principal filter at $x$*. It describes the process of zooming in on the point $x$.
 * For any set $V \subseteq X$, the filter $F_{V} = \lbrace U \subseteq X \mid V \subseteq V \rbrace$ describes the process of zooming in on the set $V$ as a whole. Note how $V$ isn't required to be open - the construction still makes sense.

Now, ultrafilters are filters that zoom in as much as possible. The following three subsections present one of my favorite ways to look at ultrafilters in the context of ultrafilters on sets.

### Who Am I?
Are you familiar with the game *Who Am I?* It is a two-player game where player A (she) secretly chooses a person. Now player B (he) repeatedly asks yes/no-questions about the person: "Are you still alive?" - "Are you a mathematician?" etc. and player A keeps answering truthfully until player B figures out who player A thought of.

Now imagine that you have an infinite set $X$ of people for player A to choose from. Call the person chosen by her $p$. Instead of asking of whether the person is a mathematician, player B now asks whether the person is contained in the set $M$ of all mathematicians. In fact, he can ask for each set $U \subset X$ whether or not $x \in U$.[^stone] The set of all sets containing $p$ is an ultrafilter on the set $X$, namely $F_{p}$ - the principal ultrafilter at $X$. By asking questions, player B is *zooming in* on $p$.

Conversely, each ultrafilter $F$ gives rise to a way for player A to answer player B's question: If $U \in F$, then player A should answer "yes" when asked whether her person is in $U$. The properties of ultrafilters make sure that we actually zoom in on something by answering the questions consistently:

 1. If we said that $p \in U$ and are asked about $V \supseteq U$, we must also answer that $p \in V$.
 2. If we said that $p \in U$ and $p \in V$, then we must surely also say that $p \in U \cap V$.
 3. Whatever we thought of surely is not contained in the empty set.

The ultrafilter property of maximality merely ensures that player A has an answer for every set, i.e. question. In fact, in the setting of ultrafilters on a set, a filter $F$ is an ultrafilter if and only if for every $U \subseteq X$ we have either $U \in F$ or $(X \setminus U) \in F$.

### Cheating the game
Luckily for player A, player B does not have all day for playing games, so she can assume that he will not be able to ask her about *every* subset of $X$. But she does not know when player B has his next appointment, so she should be prepared to answer any finite number of questions. This opens up an interesting possibility: Player A does not have to choose a person $p \in X$ at all! It is absolutely sufficient to choose a consistent way of answering any number of finite questions. Consistency is required to prevent player B from catching her while cheating!

Maybe it is a good idea to switch back to ultrafilters for a second: Ultrafilters have the so-called *finite intersection property* (FIP), meaning that any finite number of sets from an ultrafilter have non-empty intersection. As long as the intersection of all answers given so far is non-empty, our player A's person could be in there; if the intersection was empty, she would have answered inconsistently (that is, her answers contradict each other).

The fun part is that for most ultrafilters $F$ we have $\bigcap_{U \in F} U = \emptyset$. Such ultrafilters are known as *free ultrafilters*. In fact, for ultrafilters on a set, only principal ultrafilters are not free. So while player A can answer any finite number of questions truthfully using a free ultrafilter, she did not choose any person at all.

### Ultrafilters as generalized points
Given all that, it is very reasonable to look at ultrafilters as complete and consistent specifications of points of $X$: Each ultrafilter describes a point of $X$ by listing the set-theoretic properties that we want our hypothetical point to have.[^open-sets] Some specifications just happen to not specify actual points.

We can even go a step further and refer to the ultrafilters as *generalized points* of $X$ (not in the categorical sense). For an ultrafilter $F$ and $U \subseteq X$, you should (morally) think that if $U \in F$, then $F \in U$ (I'm absolutely serious about this!), so the ultrafilter is specifying a point contained in $U$. Hence each actual point $x \in X$ is a generalized point by identifying it with the corresponding principal ultrafilter $F_{x}$.

An ultrafilter $F$ is then free if for any finite set $U \subseteq X$ it is the case that $U \notin F$ - which means that $F$ as a generalized point is not in $U$. Coming back to the game of Who Am I, this makes perfect sense: If player B manages to find out that player A's chosen person is one of finitely many, he can just ask about them one after another - meaning that player A can only answer consistently if her (allegedly) chosen person is in that set, meaning that the ultrafilter must be principal (and therefore not free).

All this means that free ultrafilters do not describe actual points and are only contained in infinite sets. They zoom in on a region of space where there could be a point, but there is none.
This is by the way a generalization of how Cauchy-sequences work: They *also* zoom in on a region of space (meaning that all points of a sequence fit into an area of ever decreasing size), but they do not necessarily zoom in on something - there are non-convergent Cauchy-sequences. Ultrafilters and Cauchy-sequences both share the property that they are *going* somewhere, but necessarily *getting* somewhere!

## Convergence for Ultrafilters
Now back to topology. If ultrafilters describe the process of zooming in on something, there should be a notion of convergence. Here it is:

> An filter $F$ converges to a point $x \in X$ if every neighborhood $U$ of $x$ is contained in $F$.

This makes sense: In terms of generalized points, the ultrafilter is closing in on $x$ if it is contained in every neighborhood of $x$. A principal ultrafilter $F_{x}$ therefore converges to $x$.

Ultrafilters on $X$ converge to at most one point if and only if $X$ is Hausdorff. This is immediate from the fact that in a Hausdorff space each two points $x, y \in X$ have disjoint neighborhoods - and an ultrafilter can only contain one of them (or rather: be contained in one of them).


# Compactness via Ultrafilters
What does all of this have to do with compactness? Well, here is a well-known characterization of compactness:
> A space is compact if and only if each ultrafilter on it converges to at least one point.

This is not really surprising once you consider the dual of the usual definition and notice that it looks suspiciously like the finite intersection property.

It would make much more sense to take this as the definition of compactness and regard the usual statement as a technical characterization (unless you are concerned about using somewhat stronger axioms).

With this as a definition, I put forward the following: *Compactness is to topological spaces as completeness is to metric spaces.* Ultrafilters are the purely topological equivalent of Cauchy-sequences: They both zoom in on part of the space, and a space can only be called truly nice if they don't zoom into emptiness. Once again:

> Compactness is topological completeness.

To illustrate this: You know that $\mathbb{R} \; \simeq \; ]0,1[$. Completing the right hand side (in the metric sense) yields $[0,1]$ which is homeomorphic to a special compactification of $\mathbb{R}$: The two point compactification. All non-principal ultrafilters of $\mathbb{R}$ converge to either of the two points, depending on whether they contain the set $\mathbb{R}^{+} = \lbrace x \in \mathbb{R} \mid x > 0 \rbrace$ or the set $\mathbb{R}^{-} = \lbrace x \in \mathbb{R} \mid x < 0 \rbrace$. In $\mathbb{R}$, our left hand side, there are of course no non-convergent Cauchy-sequences left, so completing it as a metric space does not change it -- but that is the beauty of ultrafilters: They characterize gaps in your space *topologically*.

I like to think about compactness by imagining what would happen if I was to pour water into the space. Where would it leak? If it doesn't leak at all, the space is compact. As a topological space, $\mathbb{R}$ leaks water on both ends. For this thought experience, it doesn't matter that the ends of $\mathbb{R}$ are infinitely far away, because topology does not care about it. Something like $Q \cap [0, 1]$ is even worse: It leaks water everywhere and hence is not compact. Non-convergent ultrafilters describe these holes.

---
---
---

[^nets]: You can of course also use nets instead of sequences that solve the sizing issue by using sequences that are indexed by sets larger than $\mathbb{N}$. I prefer to talk about ultrafilters instead because I find them yet more intuitive than even sequences.

[^qchu]: There is of course this [wonderful post](https://qchu.wordpress.com/2010/12/09/ultrafilters-in-topology/), but I believe I can make some helpful additional points on this topic.

[^axioms]: At first I thought that this is a good reason not to teach it in an introductory topology class, but then again people teach Tychonoff's theorem which has the same problem. Also, the existence of ultrafilters is [strictly weaker](https://en.wikipedia.org/wiki/Boolean_prime_ideal_theorem) than the axiom of choice.

[^stone]: Instead of allowing to ask about every set (or rather *property*), you can also restrict the set to some sub Boolean algebra of $\mathcal{P}(X)$. This takes you into the wonderful realm of Stone duality.

[^open-sets]: Ultrafilters only care about open sets. Therefore, the topology specifies which sets are relevant for our specification. There should probably be a reference here to pointfree topology etc. but I'm not too familiar with that, yet.