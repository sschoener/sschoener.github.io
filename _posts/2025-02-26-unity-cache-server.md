---
layout: post
title: A non-exhaustive list of faults in Unity's Cache Server
excerpt:
tags: []
---

I recently looked into setting up a Unity cache server ("Accelerator"). It is quickly becoming clear that the accelerator is not, in fact, accelerating Unity. Here is a list of shortcomings:
 * Some of the most expensive asset types are not even cached. In particular, neither shader graph assets nor VFX graph assets support caching. Burst isn't cached either.
 * The "Accelerator" actively slows down parallel imports. Unity hands out assets to import to background workers as usual, but as soon as an asset has been imported it will try to upload it and then not start importing any other assets until that upload is done. It will also only upload a single import result at a time. In practice, this means that 4 parallel import workers build up a huge backlog of uploads, and you get a repeating pattern of "4 imports are running for 250ms" and then "1 upload is running for 800ms."

![Bubbles in importing.](/assets/img/2025-02-26-unity-cache-server/upload-bubbles.png)

 * On that note, if I don't specifically override the idle time (`idleWorkerShutdownDelay`) this aforementioned bubble means that the asset import worker processes constantly shutdown and restart.
 * Downloading assets has very similar problems: There is a thread called `AssetDatabase.IOService`. All requests seem to funnel through that one. The asset import is grouped by asset type, i.e. we first seem to collect all textures, then query the cache server for them, import what is necessary, then proceed with models etc.. Within those types, we query the cache server in batches. There is an option to control batch size. This is well-intended but not very effective: For a batch size of 128, Unity first requests the metadata for all the 128 asset imports. When all of the metadata is there, it downloads all the artifacts for the 128 asset imports. When all the 128 asset import artifacts have been downloaded, it copies them into the right place. Serially! Then it goes to query for the next 128 asset imports. That's not exactly how you maximize bandwidth usage.
 * Accelerator also supports caching compiled shaders. This is a great idea in theory. In practice, this happens lazily during shader compilation but ends up blocking the calling thread. Shader compilation happens on job threads. Depending on the machine, there might only be a few of those threads. It would be much better to run the same operation either asynchronously or on a separate thread pool that scales beyond the number of cores of the system, because those threads will mostly be blocked and we can have many threads block in parallel without any issues.

I'm sure there are explanations for all of these issues. "We want to avoid X. This is to safeguard against Y." I get that, but if your "Accelerator" makes my import process 4x slower, then it is not doing its job.
 