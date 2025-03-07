---
layout: post
title: Improving Unity's shader graph performance, pt. 2
excerpt:
tags: [unity]
---



[Last time]({% post_url 2024-08-15-more-callstacks %}), I promised to look at shader graph undo next because we still see annoying stalls there. I have 3h of time today, let's see how far we get.

A word on methodology: I am measuring on Unity 6000.27f1 (latest as of writing), Win11. I have imported Unity's "Production Ready" shader graph samples into a new, empty HDRP project. The machine I'm using is a high-end Laptop built 3 weeks ago. I have reverted all of my previous changes to avoid any claims that I introduced any of the problems here. As a first note, importing the "Production Ready" samples in Unity generates a lot of interesting errors. Most of them are irrelevant here.

Second, I noticed while measuring this that once I put Unity into the background, CPU usage goes up sharply. Something about rendering changes, which probably makes the number of GPU fences grow wildly, and we're getting slower every frame.

![Unity getting slower in the background](/assets/img/2024-11-20-unity-shader-graph-perf-2/01-background.png)

I accidentally left Unity running in the background with shadergraph open, and when I tried to switch back, Unity froze: the frames had reached a duration of 31s. You can see where it went back to the foreground again and unfroze (red marker). But I digress.

![Unity being very slow in the background](/assets/img/2024-11-20-unity-shader-graph-perf-2/02-long-background.png)

Now to the actual thing I want to measure. Here is me undoing adding an edge divider in the HDRP Lit graph. Takes 2.4s. Roughly 500ms were previously discussed (red box). And then there's ~500ms of GUI update that comes on top (right side).

![Before state](/assets/img/2024-11-20-unity-shader-graph-perf-2/03-before.png)

Let's embed the package and fix some of that. The first low-hanging fruit is to look at the ~480ms in `ReplaceWith`, which throws out the old graph and puts in the newly de-serialized graph. It removes everything, then re-adds it. We remove edges one-by-one, and every edge removal walks the graph.

![Cost of walking the graph](/assets/img/2024-11-20-unity-shader-graph-perf-2/04-edge-walk.png)

Let's stop doing that. It's unnecessary in this case because it "reevaluates activity", but we're ripping the entire graph out anyway. There's already a flag for that, and changing 7 characters (add `, false`) makes this thing disappear:

![No longer walking the graph](/assets/img/2024-11-20-unity-shader-graph-perf-2/05-no-edge-walk.png)

Now for the second worst part: re-adding the nodes. It spends 660ms doing that, of which 430ms are going into enumerating some UI stuff.

![Adding nodes walks the graph a lot](/assets/img/2024-11-20-unity-shader-graph-perf-2/06-add-nodes-groups.png)

Why is this so expensive? Well, it turns out that for every single node in a "group", we go through the entire graph and look for that group. Again, there is a simple fix: we can precompute that info if needed. Note that there is already an option for that!

![Computing groups by walking the graph is bad](/assets/img/2024-11-20-unity-shader-graph-perf-2/07-precompute-groups.png)

The problem again immediately disappears and we saved 400ms. Nice.

![Precompute groups to save time](/assets/img/2024-11-20-unity-shader-graph-perf-2/08-precompute-groups-time-saved.png)

So what are we going to do about the remaining ~750ms? Most of this is UI rebuilding, and we can make that faster as well.

We spend some time re-creating the inspector UI for every single node in the graph because it was decided that this should happen on every undo to fix an edge-case bug. (We throw that GUI away after that.) It turns out to be unnecessary.

![Refreshing the inspector](/assets/img/2024-11-20-unity-shader-graph-perf-2/09-refresh-inspector.png)

Now for the rest outside of the inspector: We first remove existing nodes, then we add new ones, then we add edges, and then we again re-create some node UI (to react to the changes to edges).

I conceptually like that we rebuild everything from scratch: it's a simple solution. In another (non-Mono) environment, this would likely work for a long time, but here it doesn't scale. Maybe this is a place where we need to add a little bit of complexity.

What's the common case? The common case is that we're undoing a change we did manually. These are often small changes where the vast majority of things isn't changing. Why is rebuilding that so costly? GC allocations, lots of them.

This again is not news for any Unity users: They have been pooling everything for the last decade or so because reallocating is too costly. UI Toolkit itself recommends you use a pool ([Unity Manual](https://docs.unity3d.com/6000.0/Documentation/Manual/UIE-best-practices-for-managing-elements.html)).

So what are we going to pool? The most common element in our graph is the "slot" - the connection point for an edge - and its associated view. Let's pool that. There's more we could reasonably pool, but the 3h I set as a time box is up.

We're at 1s now (vs. 2.4s) and a large chunk of that is a codepath (`RenderPreviews`) that I have looked at last time, and those optimizations aren't included here yet.

![Final measurement](/assets/img/2024-11-20-unity-shader-graph-perf-2/10-final-measurement.png)

Now to address some questions I got from last time:

 * "What is this wondrous profiler you are using there? It looks so smooth and responsive." That's [Superluminal](https://superluminal.eu/). It has mixed-callstack support (C#/native) for Unity. It's very good.
 * "Will all of this go away once Unity is on CoreCLR?" I hope it's going to be better! CoreCLR has much better codegen, but quadratic stuff always explodes eventually. Also, I am not willing to wait for that. But I'm interested to see where it goes :)
 * "When is this going to get fixed in Unity?" I don't know, I don't work there. If you want this or something else improved, get in touch and we can figure out the terms. Unity are free to do that and reach out as well, if they want to.

