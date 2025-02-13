---
layout: post
title: Unity Commander - A Pre-Natal Post-Mortem
excerpt: 
tags: [unity, programming, c#]
---

Last year I briefly worked on a prototypical implementation of a quick search for Unity 2018.3 because I felt that with every update of Unity I had trouble finding tools like the profiler. I have now [uploaded the sources](https://github.com/sschoener/unity-commander) to GitHub because I do not have the time to work on it anymore and maybe, just maybe, it will be helpful for someone. Also, Unity have now released their [own version](https://docs.unity3d.com/Packages/com.unity.quicksearch@1.0/manual/index.html) of such a tool and that one looks to be just fine.
Please note that the tool is not compatible with Unity 2019.1 because the UI Elements API changed from the experimental preview included in 2018.3.

![Commander in action](/img/2019-04-22-unity-finder-post-mortem/commander.gif){: .center-image}

The Commander supports three different kinds of searches (and is easily extendable):
 * searching for assets,
 * searching within a scene,
 * and searching for commands (which includes menu items).

What went right:
 * The Commander is snappy, fast, and a joy to use. I like to say that _a bad tool is just as good as no tool at all_ (not entirely true, of course) and there are so many ways in which such a tool can be annoying. My favorite pet peeve: When you start typing into a textbox, _nothing_ should _ever_ block that. It is terribly annoying when you start searching for `GameObject` and just when you have typed `G` a long search process starts and it will start listing all of the million things that start with a `G`, wasting considerable amounts of time because that is not what I was searching for. The commander of course does not exhibit that behavior :)
 * The Commander does not block. This is a continuation of the last point, mainly. It starts of with this observation: _When do you need a quick search?_ - Well, mostly when you have a huge project. I know projects with 300k+ asset files and this is really what a tool like this should be helping with. Alas, you cannot asynchronously list all of the assets in Unity and if you want to search for a filtered subset of them, there is only a [blocking call](https://docs.unity3d.com/ScriptReference/AssetDatabase.FindAssets.html) with a very restrictive set of filtering options available. The commander uses a class called `HierarchyProperty` that is technically public, but not documented or supported. This allows it to walk the asset tree a few steps every frame within a tight-time budget. The downside is that, for all I know, any operation on the asset database probably invalidates the `HierarchyProperty` iterator -- but at least the tool lets you smoothly search 300k files.
 * Using Unity's UI Elements makes developing editor tools an absolute breeze. I would consider myself generally a proponent of immediate mode GUIs, but it really feels like they got a lot of things right with the UI Elements package.
 * It is somewhat easy to add your own finder-like tools but you still have almost full control. You can specify the looks of entries, what happens when they are selected etc. - all without any real compromises about performance.
 * It looks neat. I actually prefer it over Unity's new quick search because that feels very heavy-weight and clunky (just visually).

What went wrong:
 * Doing anything asychronous in the Unity Editor is always a bit wonky. Up until very recently (so only after I worked on the tool), there were no editor coroutines. Using multi-threading is hard when the whole point is to use Unity's non-threadsafe API functions to locate files. I ended up hooking into the Editor's update loop and providing the search routine with a time-budget that it can query to see whether it should continue the search. This is very much a cross-cutting concern because it means that you have to be able to stop the computation anywhere. Using `IEnumerable` to essentially emulate coroutines makes that somewhat OK to write.
 * Reading the code now, 6 months later, it feels arcane in parts. I'm sure there are good reasons for many of the decisions, but I disagree with some of the naming and abstractions chosen by past-me (well of course I do, it's 6 months later!). Some stuff simply seems a bit over-engineered. There's a weird setup of using `Consumer` and `Producer` interfaces that could probably be simplified greatly. I like the approach taken by Unity's new quick search that simply allows you to add results when using an asynchronous search provider.
 * It's really difficult to follow the control flow of the program. Yes, the subject matter itself is complicated: There is an asynchronous search that needs to be able to react to the user changing the input string without having to recompute the entire search (e.g. when you go from `Ga` to `GameObject` you should be able to reuse whatever search results you have been able to compute for `Ga` before the user types `GameObject`). But I do believe that it could be simplified and that I could do a better job on it now.
 