---
layout: post
title: Fast A* for a special case
subtitle: How two stacks sometimes make a priority queue
excerpt: In which I discuss a neat trick that helps when implementing A* on grids with a Manhattan heuristic
tags: [computer science, programming]
---

Lately I have been thinking about the following problem:

> Given a rectangular map with a grid topology where some cells of the grid are impassable, find the shortest path between two nodes.

Here, *grid topology* means that you can only move north, east, south, and west. Each step is assumed to have the same cost (call it 1). The question then is, how efficient and performant can you solve this problem? By *efficiency* I mean the asymptotic runtime of your algorithm expressed in terms of the input size (some people call this the *complexity*, but I consider this a grossly wrong misnomer) and by *performant* I mean the actually observed runtime (or in other words, how bad is the solution w.r.t. CPU caches :) ).

This is of course a toy problem, but I enjoyed the process of arriving at a nice solution.

## A First Solution
My first shot at this problem was an implementation of classic A* with a Manhattan heuristic. For completeness sake, the *Manhattan metric* is defined as

$$
    M(x, y) = |x_1 - y_1| + |x_2 - y_2|
$$

and the A* algorithm works as follows:

1. Maintain a set of nodes $n$ to visit (the *open set*) along with the putative cost $c(n)$ of reaching the target node $t$ by pathing through that node. Additionally, for each node $n$ maintain its distance $d(n)$ from the starting node and its parent on the shortest path. Initially, $d(n) = \infty$ for all nodes $n$.
2. Add the source node $s$ to that list with a putative cost given by $c(s) = d(s) + M(s, t) = 0 + M(s, t)$, reflecting the fact that we have taken $0$ steps and it likely takes $M(s, t)$ more steps to reach the target.
3. While the open set is not empty:
    1. Select a minimum cost node $n$ from the open set and remove it.
    2. For each neighbor $m$ of $n$:
        1. Check whether $d(n) + 1 < d(m)$. If this is the case, set $d(m) = d(n) + 1$, then add it to the open set with a putative cost of $d(m) + M(m, t)$.
        2. If $m = t$, return $d(m)$.

If that didn't help, check out Amit Patel's [fantastic page](https://www.redblobgames.com/pathfinding/a-star/introduction.html) on the topic.

The usual implementation of this algorithm is to use a heap as a priority-queue to implement the open set. In my case, distances are stored in a separate copy of the map which itself is stored as an array of bytes with either the values $0$ or $1$ to mark impassable and passable cells[^array]. Operations on the heap are all $O(\log n)$ and essentially cause a logarithmic number of cache misses (though a careful analysis of the problem shows that dequeuing is the real offender here; insertions are constant in our special case). Removing nodes from the open set when we visit them for a second time with a reduced cost is expensive, so we don't do it (turns out we need not care about this anyway).

With a bit of careful programming, you can implement this such that it is essentially bottlenecked by the operations on the heap.

---

## A More Careful Analysis
At this point, I started wondering how I can improve the heap performance. As a first step, I tried to dynamically choose the size of the datatypes used for costs and node coordinates according to the map size by making the whole algorithm templatized. This reduces copying and (more importantly) means that more elements fit into a cache line. It actually improved the peformance quite a bit.

A person I take a lot of inspiration from is [Mike Acton](https://twitter.com/mike_acton). There is certainly *a lot* to learn from him (and not just about programming), but I want to call out his emphasis of *looking at the data for your particular problem* because that is just what helped me here.

---

### What happens in a single step?
Let $n$ be the node that was just taken from the open set; it has minimal cost $c(n)$ by assumption. I claim that for each of its neighbors $m$ the cost $c'$ computed from this node is either $c(n)$ or $c(n)+2$: Note that 

$$
    c' = d(m) + M(m, t) = d(n) + 1 + M(m, t).
$$

If we have taken a step towards $t$ from $n$ to reach $m$, then $M(m, t) = M(n, t) - 1$ and thus $c' = c(n)$. Otherwise, $M(m, t) = M(n, t) + 1$ and hence $c' = c(n) + 2$.

This shows that using a heap is absolute overkill: It is completely sufficient to maintain two stacks of nodes, *near* and *far*. During the search, take the top element $n$ from *near* and expand it. Push all its neighbors of cost $c(n)$ to *near* and all neighbors with cost $c(n) + 2$ to *far*. Repeat until *near* is empty, then swap *near* and *far*.

The stack operations are constant time, but more importantly we are now always touching memory in the same place and have stopped jumping around as would be required for a binary heap. Note that we not only eliminated the priority queue, but also the need to store any costs: Where a node is pushed depends only on whether we took a step towards the target or away from it, and this can be computed on the fly.

---

Effectively, this turns A* in this special case into a two-stack DFS where a node is pushed to the second stack when it is believed to have a single misstep more in its optimal path than nodes that are currently on the *near* stack.

There is no completely faithful translation of this solution to other topologies (even adding in the diagonals causes the number of required stacks to grow indefinitely), but it might be interesting to see where $k$-stack searches are applicable. Another perspective on this is that we are now looking for an easily computed heuristic that tells us which stack to put a node on.

Now please link me to a source for this particular trick so I can stop feeling clever about it :)

---

[^array]: This is of course terribly wasteful. When only 1 out of 8 bits contains actual data, your memory layout could use some work. I didn't make that choice here because the problem required me to adhere to a specific interface.