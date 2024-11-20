---
layout: post
title: Improving Unity's shader graph performance, pt. 2
excerpt:
tags: [unity]
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener), [Bluesky](https://bsky.app/profile/sschoener.bsky.social), or [Twitter](https://twitter.com/s4schoener)!_

[Last time]({% post_url 2024-08-15-more-callstacks %}), I promised to look at shader graph undo next because we still see annoying stalls there. I have 3h of time today, let's see how far we get.

A word on methodology: I am measuring on Unity 6000.27f1 (latest as of writing), Win11. I have imported Unity's "Production Ready" shader graph samples into a new, empty HDRP project. The machine I'm using is an expensive high-end Laptop built 3 weeks ago. I have reverted all of my previous changes to avoid any claims that I introduced any of the problems here. As a first note, importing the "Production Ready" samples in Unity generates a lot of interesting errors. Most of them are irrelevant here.

Second, I noticed while measuring this is that once I put Unity into the background, CPU usage goes up sharply. Something about rendering changes, which probably makes the number of GPU fences grow wildly, and we're getting slower every frame.

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/01-background.png" alt="Unity getting slower in the background" />
</p>
![alt text](image.png)

I accidentally left Unity running in the background with shadergraph open, and when I tried to switch back, Unity froze: the frames had reached a duration of 31s. You can see where it went back to the foreground again and unfroze (red marker). But I digress.

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/02-long-background.png" alt="Unity being very slow in the background" />
</p>

Now to the actual thing I want to measure. Here is me undoing adding an edge divider in the HDRP Lit graph. Takes 2.4s. Roughly 500ms were previously discussed (red box). And then there's ~500ms of GUI update that comes on top (right side).

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/03-before.png" alt="Before state" />
</p>

Let's embed the package and fix some of that. The first low-hanging fruit is to look at the ~480ms in `ReplaceWith`, which throws out the old graph and puts in the newly de-serialized graph. It removes everything, then re-adds it. We remove edges one-by-one, and every edge removal walks the graph.

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/04-edge-walk.png" alt="Cost of walking the graph" />
</p>

Let's stop doing that. It's unnecessary in this case because it "reevaluates activity", but we're ripping the entire graph out anyway. There's already a flag for that, and changing 7 characters (add `, false`) makes this thing disappear:

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/05-no-edge-walk.png" alt="No longer walking the graph" />
</p>

Now for the second worst part: re-adding the nodes. It spends 660ms doing that, of which 430ms are going into enumerating some UI stuff.

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/06-add-nodes-groups.png" alt="Adding nodes walks the graph a lot" />
</p>

Why is this so expensive? Well, it turns out that for every single node in a "group", we go through the entire graph and look for that group. Again, there is a simple fix: we can precompute that info if needed. Note that there is already an option for that!

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/07-precompute-groups.png" alt="Computing groups by walking the graph is bad" />
</p>

The problem again immediately disappears and we saved 400ms. Nice.

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/08-precompute-groups-time-saved.png" alt="Precompute groups to save time" />
</p>

So what are we going to do about the remaining ~750ms? Most of this is UI rebuilding, and we can make that faster as well.

We spend some time re-creating the inspector UI for every single node in the graph because it was decided that this should happen on every undo to fix an edge-case bug. (We throw that GUI away after that.) It turns out to be unnecessary.

<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/09-refresh-inspector.png" alt="Refreshing the inspector" />
</p>

Now for the rest outside of the inspector. All of the time spent re-creating UI elements. We first remove existing elements for nodes, then we add new ones, then we add edges, and then we again re-create some node UI.

I conceptually like that we rebuild everything from scratch: it's a simple solution. In another (non-Mono) environment, this would likely work for a long time, but here it doesn't scale. Maybe this is a place where we need to add a little bit of complexity.

What's the common case? The common case is that we're undoing a change we did manually. These are often small changes where the vast majority of things isn't changing. Why is rebuilding that so costly? GC allocations, lots of them.

This again is not news for any Unity users: They have been pooling everything for the last decade or so because reallocating is too costly. UI Toolkit itself recommends you use a pool ([Unity Manual](https://docs.unity3d.com/6000.0/Documentation/Manual/UIE-best-practices-for-managing-elements.html)).

So what are we going to pool? The most common element in our graph is the "slot" - the connection point for an edge - and its associated view. Let's pool that. There's more we could reasonably pool, but the 3h I set as a time box is up.

We're at 1s now (vs. 2.4s) and a large chunk of that is a codepath (`RenderPreviews`) that I have looked at last time, and those optimizations aren't included here yet.
<p align="middle">
  <img src="/img/2024-11-20-unity-shader-graph-perf-2/10-final-measurement.png" alt="Final measurement" />
</p>

Now to address some questions I got from last time:

 * "What is this wondrous profiler you are using there? It looks so smooth and responsive." That's [Superluminal](https://superluminal.eu/). It has mixed-callstack support (C#/native) for Unity. It's very good.
 * "Will all of this go away once Unity is on CoreCLR?" I hope it's going to be better! CoreCLR has much better codegen, but quadratic stuff always explodes eventually. Also, I am not willing to wait for that. But I'm excited to see where it goes :)
 * "When is this going to get fixed in Unity?" I don't know, I don't work there. If you want this or something else fixed, get in touch and we can figure out the terms. That applies to Unity as well.

{% include clickable-image.html %}