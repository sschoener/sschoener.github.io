---
layout: post
title: How to waste time optimizing code
excerpt: 
tags: [programming]
---

I had the pleasure of optimizing the load time of a game last week and reduced it on my test-machine by 30s (CPU time). The icing on the cake is that it was literally a one-character change and also my very last commit at that job. It being my last day at the company, I decided to just profile one of our games at random, look at the top results, and see what can be done about it. Doing tools programming, I don't usually get to do that.

One of the top entries in the profiler was some pathfinding code that happened at load time. Intriguing? Irritating? Unexpected? Yes, definitely. It turns out that this pathfinding code is slow, _very_ slow. It's so slow that someone went ahead and wrote a long comment justifying their optimization choices in the body of the loop ("_this code is duplicated because the compiler doesn't reliably inline it_"). That apparently did not help. Only the minimum distance of each node from some initial sets of starting nodes are actually needed, and since the number of nodes is small enough, someone later decided to precompute all the distances at load time for each relevant set of initial nodes. It made the callsites somewhat more complex because the graph changes during runsite and you have to ensure that you invalidate the cached precomputed data at the appropriate times. Since that of course only moved the problem to load time, someone else decided to multi-thread the code across the different initial sets. It was still slow, but at least (?) slow on all threads.

This is a common theme that I have noticed over the last few months: People don't ask why code is slow or whether it should be slow; they only think of ways to make it faster.
The pathing code here is essentially Dijkstra's algorithm. Notice that the graph is _small enough_ to precompute and store some data for every node for about ~250 different sets of initial nodes. That makes it unlikely that the graph is simultaneously _big enough_ to make it take seconds to perform these searches. In this case, it's a graph with 1500 nodes. For this order of magnitude, even a _millisecond_ is way too slow. Yes, you can multi-thread it. Yes, you can unroll that loop or do whatever fancy low-level techniques you think you have mastered. But if your code is a thousand times slower than what you could reasonably expect, then you better go and investigate. You have to _understand_ why it is slow and what you would expect its performance to be: When you profile it, are you surprised by what parts are the slowest? Do you have any measures to compare to? Have you solved a similar problem before? Has someone else solved a similar problem before?

Maybe no-one had ever been given enough time during production to profile it except for the original author who arguably focussed on the wrong issues? How much time have peolpe spent on implementing the caching scheme for the distances? How many bugs has that introduced? How much time was spent multi-threading the calculations? All of this was essentially time wasted, not to mention the 30s of CPU time per start-up: Over the course of multiple games, this has probably wasted days of human lifetime just inside the studio.

I already made my point, but since you're still here: The problem was improper usage of `std::priority_queue`. In Dijkstra and variants, you use a priority queue to sort the nodes according to their current estimated distance and always expand the next unvisited node with minimum distance. For all but the simplest of types, you have to specify how to compare the elements in the queue. When asked to compare things, C++ programmers naturally gravitate to use `lhs.distance < rhs.distance`. That is unfortunate, because `std::priority_queue`'s head is the maximum element according to the order you specified: it is operating on _priority_, not on _cost_. The code will still be correct, but ensures that you always explore all the worst paths first. Given the fact that this code existed in multiple products, has been optimized by multiple people, it's probably fair to say that it qualifies as a proper [reluctant algorithm](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.116.9158).

My commit replaced `<` with `>` and made the offending code disappear from the profile.