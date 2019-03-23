---
layout: post
title: Words, A Game, and Specifications
subtitle: An introduction to Stone Duality
excerpt: In which I begin a short series on Stone Duality in the context of formal language theory.
tags: [mathematics, computer science, logic]
---
\\(\newcommand{\mc}[1]{\mathcal{\#1}}\\)
# Preface
This post assumes that you have some degree of familarity with regular languages (ways to define them, properties) and a general mathematical maturity.
Furthermore, let's get some notation straight. My alphabets are \\(\Sigma, \Gamma\\) and they are assumed to be finite. Languages are generally denoted by \\(L\\) and variants thereof, similarly for automata and the letter \\(A\\). For a language \\(L\\), its complement \\(\Sigma^\* \setminus L\\) is written as \\(
\newcommand{\comp}[1]{\#1^{\mathsf{c}}}
   \comp{L}
\\).
Unless a notation is specifically named or pointed out, assume that all variables are declared in the scopes that naturally arise from the headings.

# A Guessing Game
Everybody loves a good game, so here is a one-vs-the-rest game that will surely get your party started: Since it could reasonably be a two player game, I will call the involved parties player 1 (P1) and player 2 (P2). At the start of the game, P1 picks any word \\(w \in \Sigma^*\\). P2's goal is to guess the word \\(w\\) by only asking a restricted set of yes/no questions. More specifically, the game proceeds in rounds, each of which is played as follows:
 * P2 picks any finite automaton \\(A\\) on \\(\Sigma\\) and hands its description to P1,
 * P1 takes \\(A\\) and answers 'yes' if \\(w \in L(A)\\) and 'no' otherwise.

At any point in the game P2 may stop asking and announce a word \\(v \in \Sigma^\*\\). P2 wins if \\(v = w\\) and loses otherwise.

## Who will win?
If you think about it for a second, this game immensely favors P2, since P2 will always win *eventually*. To see this, fix an ordering \\( w\_1, w\_2, w\_3, \ldots \\) of the words of \\(\Sigma^{\*}\\). Then P2 can simply proceed by building automata for the sets \\(\\{w\_i\\}\\) and hand them to P1. This will naturally lead much frustration to P1 who notices that it is maybe simply best to turn this into a war of attrition: After all, P2 does not have a bound on the number of questions she has to ask to get to \\(w\\) (and it is not hard to convince yourself that there is no way to get any upper-bound on it, no matter what strategy is used). It is completely sufficient for P1 to outrun P2 until she simply gives up (should that ever happen). This may sound like cheating (and it *is* cheating), but one way for P1 to achieve this is to 1) *not choose a word*, 2) *avoid finite languages* and 3) *stay consistent*. More formally, P1 should play as follows:

In the first round of the game, if \\(L(A)\\) is finite, answer 'no', otherwise 'yes'.

Now assume that this is the \\(n\\)-th round of play and let \\(L\_1, L\_2, \ldots, L\_{n-1}\\) be the regular languages that P2 enquired about in the previous rounds. Without loss of generality, we can assume that \\(L := \bigcap L\_i \neq \emptyset\\), i.e. that P1 always answered 'yes' to the queries, for if P1 answered 'no' to a language \\(L(A)\\), we can simply pretend that he was asked about the set \\(\comp{L(A)}\\) and note that down in our list.
If \\(L(A) \cap L\\) is finite, answer 'no' and add \\(L\_n = \comp{L(A)}\\) to the list. Otherwise, answer 'yes' and add \\(L\_n = L(A)\\) to the list.

This will force an infinite number of rounds, since P2 is never given the information that P1's putative word is in a finite set (which would require only a finite number of rounds to reduce it to a single word). Additionally, P2 cannot reasonably be suspicious, because P1's answers are *consistent*. P1 is careful to never claim that his (non-existent) word is inside an empty set (i.e. the empty intersection of multiple queries) and that if he answered 'yes' to a set \\(L\\), then he will also answer 'yes' to every super-set of \\(L\\).

# Objects and their Specification
Let's take a step back and take a more abstracted look at the game. Fundamentally, it is about describing objects (words) by certain properties (regular languages). To illustrate the latter, take the set \\(\\{w \in \Sigma^\* \mid |w| = 3n \text{ for some } n \in \mathbb{N}\\}\\) of all words with a length that is evenly divisible by three. It describes a *property* of words (namely the property of having a length that is evenly divisible by three). Instead of giving a word by a sequence of characters, we could try to describe it by its properties alone. 
Before we do this, it is time to make some definitions. Some of them may seem pointless, but bear with me.

## Properties and Algebras
A *\\(\Sigma\\)-property* or *property of \\(\Sigma\\)-words* is a language \\(L \subseteq \Sigma^\*\\). Qualifiers on the property are understood to restrict the languages (e.g., a regular property is one described by a regular language). We should briefly talk about kind of qualifiers are appropriate for properties. Any qualifier like *regular* restricts the set of properties that we can talk about. We would like this set \\(B\\) of properties to have certain algebraic properties, i.e. form an *algebra of properties*:
 * \\(B\\) is not empty,
 * if \\(L\_1, L\_2\\) are properties, so are \\(L\_1 \cap L\_2\\) and \\(L\_1 \cup L\_2\\) (we can combine questions in the game above with 'and' and 'or'),
 * if \\(L\\) is a property, so is \\(\comp{L}\\) (we can invert questions in the game above with a 'not'),

It follows that \\(B\\) forms a Boolean algebra of sets with the standard operations, also known as a *field of sets*, since \\(\Sigma^\*, \emptyset \in B\\) follow quickly from the above requirements.

Now, a word \\(w \in \Sigma^\*\\) satisfies a property \\(P\\) if \\(w \in P\\), written as \\(w \models P\\). For a property \\(Q\\), \\(P\\) entails \\(Q\\), written \\(P \models Q\\), if \\(w \models P\\) implies \\(w \models Q\\) for all words \\(w\in \Sigma^\*\\). In otherwords, \\(P \subseteq Q\\).

## Specifications
If we plan to specify a word by its properties, we should certainly find that the mapping a word to the set of its properties (relative to the algebra of properties we care about) is of help. The properties of \\(w \in \Sigma^\*\\) are just \\(\\{L \subseteq \Sigma^\* \mid w \models L\\}\\), hence this could be its specification. Note that this specification is *consistent* (it specifies something, namely \\(w\\), and hence none of the properties contradict each other) and *complete* (foreach property \\(L \in B\\), either \\(w \models L\\) or \\(w \models \comp{L}\\)). Let's make that formal:
A set \\(S \subseteq B\\) of properties is
 * *consistent* if \\(\emptyset \notin S\\) and \\(S\\) is closed under intersections,
 * *complete* if for every \\(L \in B\\), either \\(L \in S\\) or \\(\comp{L} \in S\\).

We call \\(S\\) a *specification* if it is non-empty and consistent and call it a *full specification* if it is also complete.

Full specifications are just what player 1 from above needs to play the game: A clear way to answer every question without getting caught in a contradiction. If player 1 plays fair-minded, the initial choice of \\(w \in \Sigma^\*\\) completely determines a specification that is (necessarily) consistent and complete. Perhaps surprisingly, there are usually *plenty* of ways for player 1 to cheat, because there are indeed many specifcations that do not correspond to a real word. The existence of these can be proven using Zorn's lemma[^zfc].


# Conclusion
This is enough for now, we will continue next time. For now, remember:
 * languages can be seen as *properties* of words,
 * collections of such properties that have the form of a Boolean algebra with intersection, union, and complement can be used to form *specifications*,
 * *full specifications* are consistent and complete descriptions of words,
 * full specifications can also describe non-existing words.

In the next post, we will explore how specifications relate to topology and what Stone Duality actually is.

[^zfc]: The existence is not provable in ZF alone, but doesn't require the full power of the axiom of choice. The intermediate axiom you need is the [Boolean prime ideal theorem](https://en.wikipedia.org/wiki/Boolean_prime_ideal_theorem) which is basically just stating outright that these specifications exist.