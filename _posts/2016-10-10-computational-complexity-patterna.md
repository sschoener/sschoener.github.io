---
layout: post
title: The Computational Complexity of Patterna
tags: [computer science]
---
\\(\newcommand{\NP}{\mathsf{NP}}\\)
\\(\newcommand{\coNP}{\mathsf{coNP}}\\)
\\(\newcommand{\P}{\mathsf{P}}\\)

In this post I am going to talk about the computational complexity of solving Patterna puzzles, and why the solvability problem is not \\(\NP\\)-complete. If you have no idea of computational complexity, have a look at [this blog post]({% post_url 2016-10-03-intro-to-computational-complexity %}) in which I give a short introduction to computational complexity. 
Everything in this post also applies to HexCells, and also shows that the popular opinion that HexCells (or even MineSweeper) is \\(\NP\\)-complete is either wrong or at the very least misleading.

## Minesweeper is \\(\NP\\)-complete, thus so is Patterna?
There is a [famous article by Richard Kaye](http://web.mat.bham.ac.uk/R.W.Kaye/minesw/) in which he proves that the **Minesweeper Consistency Problem** (MCP from here on) is \\(\NP\\)-complete. 
The **MCP** problem is defined as followed:

> Given a Minesweeper board (possibly with some grid cells already cleared or marked as mines), is there a way to label the unknown grid cells in a way consistent with the information on the grid cells?

I will not go into the details of the proof. We will instead quickly establish such a result for Patterna (which is much easier since we can skip all the geometrical considerations that are involved in creating wires [in HexCells](https://www.youtube.com/watch?v=3yHEYy0LpRk&feature=youtu.be&t=426) or Minesweeper). Here is **the Patterna Consistency Problem (PatPC)**:

> Given an Patterna board, is there are way to mark the unknown nodes as pattern or non-pattern consistent with the known constraints given by the nodes on the board?

Here, *Patterna board* means the board as seen by the player.

Proving \\(\NP\\)-hardness for **PatPC** is almost trivial: We will reduce **3CNF-SAT** to PatPC. **3CNF-SAT** has as input a formula of propositional logic in 3-conjuctive normal form, that is, the formula has the form 
\\[
 \bigwedge_{i=1}^n (x_{i,1} \vee x_{i,2} \vee x_{i,3})
\\]
where each \\(x_{i,j}\\) is either a variable or a negated variable. The problem is to decide whether there exists and assignemnet of truth-values to the variables that makes the formula evaluate to true.

We will turn any such 3CNF formula into a Patterna board: For each variable \\(A\\), we introduce three nodes to the board, two unknown nodes corresponding to \\(A\\) and \\(\lnot A\\), and a non-pattern node; like this:

![Variable Encoding](/assets/img/2016-10-10-computational-complexity-patterna/variable-input.png){: .center-image}

This ensures that each variable is either *true* or *false*, where *pattern* is interpreted to mean *true*.
A clause \\((X \vee Y \vee Z)\\) is then translated by creating three more nodes like this:

![Or Consistency](/assets/img/2016-10-10-computational-complexity-patterna/or-consistency.png){: .center-image}

Here, the nodes \\(X, Y, Z\\) refer to the nodes created for these literals in the first step. 
This setup ensures that at least one of the literals is set to true. (We could also do it with one additional node by using the fact that Patterna technically supports inequalities.)

This is all there is to it. Since this reduction is efficient, PatPC is \\(\NP\\)-hard. Since the constraints given by the different information types are all efficiently checkable, PatPC is in \\(\NP\\) and therefore \\(\NP\\)-complete. We are done! Yay!

...except this is not really connected to actually playing Patterna *at all*. For starters, we are completely ignoring the fact that in Patterna you always know the number of pattern nodes that are left. This means that we would have to integrate this constraint into the problem statement, too (read it again to see what I did to ignore it). But this is not the main problem here either: The main problem is that in the actual game *we do not care for whether there is **some way** to satisfy the constraints*. That is not the point of the game, and neither is it the point in HexCells (or even Minesweeper for that matter!).

## The Computational Complexity of Solving Patterna Levels

Let’s step back and contemplate what solving Patterna levels actually involves:

 * Patterna, just like HexCells, is a game about logic, or rather: *proofs*. In a level, your task is to *deduce* the states of the unknown nodes (and *not* to find a way of marking the unknown nodes that is consistent with the current constraints given by the available information).
 * Revealing nodes in the level may reveal more information about the states of the nodes in the level (i.e., add more constraints).
 * The essential question in each moment is whether there is any node whose state is completely determined by the constraints on the board. If we can solve this question, we can settle the problem of solving a Patterna level by repeatedly applying it.

Based on these considerations, I am proposing the **Patterna Progress Problem (PatProg)**:

> Given a consistent Patterna board, is there any unknown node whose state is completely determined by the constraints?

Consistency here may be assumed because the level editor does not allow to build inconsistent levels (it computes the constraints on a node with information automatically so that it is consistent).

Here is a way to find out whether the state of a node \\(n\\) is fully determined by the current constraints: Consider all possible assignments of states to unknown nodes. If all assignments that are consistent with the current constraints agree on the state of \\(n\\), then the state of \\(n\\) is fully determined by the constraints. Using the language of model theory: A formula is *logically valid* if it is true in all models. So in effect, we are performing validity checking for certain formulas[^semantic].

## The class \\(\coNP\\)
An important complexity class that receives much less popular attention than \\(\NP\\) is the class of problems whose complement is in \\(\NP\\): The class \\(\coNP\\). As said, a problem \\(L\\) is in \\(\coNP\\) if and only if its complement \\(L^c\\) is in \\(\NP\\).
*Warning*: This does not mean that \\(\coNP\\) is the complement of \\(\NP\\)[^coNP].

What is the complement of **PatProg**? It is **PatStuck**:

> Given a consistent Patterna board, is it stuck? That is, is it the case that no unknown node’s state is completely determined by the constraints?

Here is a simple argument that shows that this problem is in \\(\NP\\), using a verifier. As a reminder: We have to prove that for any level that is stuck, there is short proof that certifies this (where short means polynomial in the size of the level).

Suppose that we are given a level that is stuck. Then for every unknown node *n*, there must be an assignment (of pattern/non-pattern to each node) that is consistent with the constraints on the level and marks *n* as a pattern node, and one such consistent assignment that marks *n* as a non-pattern node. An *assignment* here is simply a list of states (pattern/non-pattern). This yields a certificate whose size is in the order of \\(m^2\\), where \\(m\\) is the number of unknown nodes. Checking this certificate is of course very easy, since this simply means ensuring that all these assignments are actually consistent with the constraints – and this is easily done in polynomial time.

## Proving \\(\coNP\\)-completeness
Thus **PatStuck** is in \\(\NP\\), and **PatProg** therefore is in \\(\coNP\\). The next natural question to ask is what kind of lower-bound we can get on **PatProg**. Unsurprisingly, PatProg is \\(\coNP\\)-complete. Unfortunately (?) for us, someone else already noticed the same problems with Kaye’s model: Scott, Stege, and van Rooij improved upon Kaye’s work in their paper [Minesweeper May Not Be NP-Complete but Is Hard Nonetheless](http://link.springer.com/article/10.1007%2Fs00283-011-9256-x) where they prove that actually inferring the state of a cell of a Minesweeper board is \\(\coNP\\)-complete. Since their article is paywalled, I will have to give you my own proof: We reduce **3CNF-UNSAT** to **PatProg** thus proving \\(\NP\\)-hardness, since the formar is \\(coNP\\)-hard. Here, **3CNF-UNSAT** is the complement of **3CNF-SAT**. It is asking whether a given a 3CNF formula has *no* satisfying truth assignments.

The idea here is the following: We encode a 3CNF-formula \\(\varphi\\) as a Patterna board in the form of a circuit with the variables as inputs and a final node that has the property that, for any assignment, this final node is a pattern node if and only if the assignment makes the formula true. In other words, we build a Patterna board that evaluates the formula on a variable assignment. The constraints on the board will ensure that the assignment and its evaluation are correct (e.g., we are not assigning true to both \\(A\\) and its negation \\(\lnot A\\)). The consistent ways of assigning nodes to states will then correspond one-to-one to the assignments of variables from the formula \\(\varphi\\). We need to pay special attention to the fact that in Patterna, the number of remaining pattern nodes is always known.

As a first step in the reduction, check that \\(\varphi\\) is no tautology and remove all tautological clauses. This is easily done: (\\varphi\\) is only a tautology if all clauses are tautologies. A clause is a tautology if and only if it contains the literals \\(A\\) and \\(\lnot A\\) for any variable \\(A\\). In this case, the formula is certainly satisfiable, so we have to map it to a Patterna level that is stuck. There are plenty of those, for example two unknown nodes with the information that there is exactly one pattern node among them. This transformation of \\(\varphi\\) is sound, since \\(\varphi\\) is unsatisfiable and only if we remove all its tautological clauses.

Otherwise, if the formula is not a tautology, proceed with the translation of the formula into a level: Each variable \\(A\\) from the formula is converted to two nodes with a third node to ensure consistency:

![Variable Encoding](/assets/img/2016-10-10-computational-complexity-patterna/variable-input.png){: .center-image}

Note that no matter whether \\(A\\) is true or false, exactly one of the nodes will be in the pattern.

Next, we turn to translating clauses \\(X \vee Y \vee Z\\), where \\(X, Y, Z\\) are literals. We can use the following gadget to emulate an OR:

![Or Gadget](/assets/img/2016-10-10-computational-complexity-patterna/or-gadget.png){: .center-image}

The nodes marked \\(X, Y, Z\\) correspond to the nodes that were created in the first step (so if \\(X = \lnot x_{1,1}\\), we use the corresponding node for the node marked \\(X\\)). The node with the label OR is a pattern node if and only if one of \\(X, Y, Z\\) is a pattern node. NOR is pattern node if and only if OR is a non-pattern node. This can easily be seen by considering the two cases: Suppose that at least one of \\(X, Y, Z\\) is a pattern node. Since these nodes have no outgoing edges, and we know that there must be exactly 4 connected nodes, the OR node must be a pattern node. Conversely, if OR is a pattern node, then NOR is a non-pattern node. Which means that we can only use the nodes 1, 2, and \\(X, Y, Z\\) to make a connected group of 4 pattern nodes. Thus at least one of \\(X, Y, Z\\) is a pattern node. The nodes 1, 2, 3 ensure that it is possible to have the OR-gadget evaluate to false.

The nodes \\(X, Y, Z\\) are, as said before, not really part of the OR-gadget. The nodes 1, 1’, 2, 2’, 3, 3’ and OR, NOR are owned by the OR-gadget. Note that any consistent assignment of states to these owned nodes makes exactly 4 of these nodes pattern nodes (this is why we include the nodes 1’, 2’, 3’).

It is easily seen that this construction generalizes to more than 3 arguments: Simply introduce more inputs, increase the number of connected nodes, and insert more nodes between 1 and 2, each with a corresponding alternative node that ensures that the total number of marked nodes is \\(k+1\\), where \\(k\\) is the number of inputs. Therefore, we can also use this gadget to implement the conjunction by exploiting DeMorgan’s equivalence 
\\[
    \bigwedge_{i=1}^n (x_{i, 1} \vee x_{i, 2} \vee x_{i, 3})
    = \lnot \bigvee_{i=1}^n \lnot (x_{i, 1} \vee x_{i, 2} \vee x_{i, 3})
\\]
We only need to construct an OR-gadget with the right number of inputs and connect the NOR outputs of the clauses to the inputs. The NOR output of that node then is the output node of the circuit. The number of pattern nodes in the resulting Patterna board is completely fixed, and equals \\(2v+4n+n+1\\), where \\(v\\) is the number of variables occuring in the formula: Each clause generates 4 pattern nodes in the OR-gadget, and the final or gadget has all clauses as inputs, yielding \\(n+1\\) pattern nodes in its OR-gadget.

Let us now check that this construction actually constitutes a reduction. First, assume that the input formula φ is indeed unsatisfiable. This means that there is no assignment that makes the formula true. By our construction above, this implies that there is no consistent assignment of nodes to states that makes the output node a pattern node. Thus we can infer that state of this output node as non-pattern.

Conversely, assume that we can infer the state of some node of the Patterna board. Remember that the assignments of nodes to states are in one-to-one correspondence to the assignments of truth values to variables. This means that the node that we can infer cannot be an input node to the circuit, since variables are obviously never fixed by all possible assignments. 
Taking a look at our OR-gadget, the states of all the nodes owned by the gadget are completely determined by whether the OR node is a pattern node. We can therefore focus on these nodes. If we could infer the state of any such OR node for an OR-gadget representing a clause, this would mean that that clause is either tautological (since it is true under all assignments) or unsatisfiable. If it is unsatisfiable, we are done, since then \\(\varphi\\) has an unsatisfiable conjunct. The other case, of course, cannot happen, since we removed tautological clauses in the first step of the reduction. 
This now only leaves the possiblity that we can infer the state of the output node, which we made sure can only happen if the formula is unsatisfiable (since it is not tautological).

Thus \\(\varphi\\) is unsatisfiable if and only if the corresponding Patterna board can make progress. Finally note in passing that building the Patterna board is easily done in polynomial time, which proves this reduction efficient. Therefore, **PatProg** is \\(\coNP\\)-complete. 
This readily implies that **PatProg** is most likely not \\(\NP\\)-complete, since that would imply [unlikely results](http://www.scottaaronson.com/writings/phcollapse.pdf).

## Solving Whole Levels
All this still leaves the question of the complexity of the solvability of a whole level. Clearly, we can repeatedly apply the procedure to a completely specified consistent level (with all the information available and a set of nodes marked as initially visible) to solve it, which gives an upper bound on the complexity. Since neither \\(\NP\\) nor \\(\coNP\\) (assuming they are not equal) is closed under subroutines (polynomial Turing reductions), this is no proof that the solvability of a whole level is still in \\(\coNP\\). On a more technical level, this only proves that the problem of solvability of a whole level is in \\(\Delta_2^P = \P^\NP\\). But we can adapt the argument slightly and make it easy to see that solving whole levels is in \\(\coNP\\). The problem **PatSolv** is defined as:

> Given a fully specified Patterna level, is it solvable? That is, is progress always possible until the nodes are all revealed?

By *fully specified level* we mean a directed graph with the following data for each node: Whether it is a pattern node, what kind of information it carries (if any), and whether it is initially revealed. The *initial board state* for that level has all non-initially revealed nodes hidden. An *extension* of such a board state \\(S\\) is another board state \\(S′\\) that agrees with \\(S\\) on all revealed nodes of \\(S\\) (but may have additional nodes revealed, in accordance with the underlying level). We say that an extension is *incomplete* if there are still unknown nodes, and it is an *obstruction* if it is incomplete and stuck.

Here is an argument showing that the question of *un*solvability is in \\(\NP\\): A certificate for unsolvability is an obstruction with a proof that it is stuck. Verifying this data is clearly possible in polynomial time: Verifying that it is indeed an extension can be done by mere comparison, incompleteness is also trivial to verify. We already know that a proof for being stuck can be verified in polynomial time, as we proved the question of being stuck \\(\NP\\)-complete. 
Why is this certificate sufficient? Well, by definition any extension contains all the constraints from the initial state (and probably some more). Note that additional constraints only reduce the number of consistent assignments of nodes to states. We can thus conclude that from the initial configuration we cannot deduce the state of any node that is unknown in this obstruction. This means that *even* if we can deduce the states of some nodes (those which are revealed in the obstruction) from the initial state, we will get stuck eventually. 
On the other hand, such an obstruction clearly exists whenever the level is unsolvable: Simply take the state in which a node is revealed if and only if its state is deducible.

This together now implies that **PatSolv** is in \\(\coNP\\). One would hope that \\(\coNP\\)-completeness follows from something we already talked about, but that is actually not the case: We cannot simply take the reduction from above and adapt it to **PatSolv**, since **PatSolv** requires a fully specified level as its input whereas the reduction we have used before only requires a consistent board. Turning that consistent board into a fully specified one is most likely not possible in polynomial time, which means that another approach might be right.

[^semantic]: Ironically, this method is purely semantic, and thus less about proof theory than about model theory.

[^coNP]: Where \\(\NP\\) is basically \\(\P\\) with polynomially many existentially quantified bits, \\(\coNP\\) corresponds to \\(\P\\) with polynomially many universally quantified bits.