---
layout: post
title: Improving Unity's shader graph performance
excerpt:
tags: [unity]
---



A tech artist came to me and said "whenever we touch anything in a Unity shader graph, the editor stalls. It's painfully annoying." And yes, any meaningful change to the graph stalls the editor. Sometimes a bit, sometimes long. So I decided to improve this a bit. Time-boxed to two days (with some interruptions) and see how far I get. The goal is not to do clever optimizations but to stop doing silly things and see where that leads. Here is what I have found.

As an example, take a modestly sized shader. I clicked to insert a "line breaker" into an edge, which doesn't change the functionality of the graph at all.

![A line breaker in shader graph](/assets/img/2024-11-17-unity-shader-graph-perf/01-line-breaker.png)

This takes anywhere between 1s and 2s per click, depending on how many GC runs we provoke. Note in particular that there is a 200ms call into the shader compiler to preprocess the shader. Foreshadowing!

![Measurement of the before state in Superluminal](/assets/img/2024-11-17-unity-shader-graph-perf/02-before.png)

On bigger graphs, this gets worse. Imagine this every day, constantly, for every click. I've found this annoying after just a minute.

Here is what happens: Any change updates the shader previews. We generate the shader (from scratch, regardless of the change, seemingly), then we preprocess the shader and kickoff async compilation. I have no deep understanding of shader graph. But I can tell you a few things: of all the C# things Unity has, the graphs are the most sharp and the least C. When you look at the profile, we're spending a noteworthy amount of time just allocating things. Things like LINQ allocate, and there are tons of small temporary lists. The code makes the reasonable assumption that it is running on a reasonable runtime, with a reasonable optimizing compiler. On Mono, that assumption is unfortunately false, [as we have seen previously]({% post_url 2024-11-12-unity-mono-perf %})!

This by the way is something that most serious Unity users know: everything is slow, GC is bad, and good C# on Mono essentially looks like C. But Unity doesn't apply that logic to its own code, apparently.

As a first step, I have replaced all bad things (LINQ, repeated allocations) with the less bad alternatives (raw loops, reuse or better yet avoid allocations). That is not a lot of work. This already resolves a large number of bottlenecks. Second, I did some small algorithmic improvements; none of them more than a few lines of changes. The number of dimensions in which this codepath scales at least quadratically was surprising, and all of them were unnecessarily bad.

Then I found a thing that just made emit a deep "oh no." Really, going over all permutations and doing a graph search? Reality is a bit more nuanced but also more absurd yet, as I will explain:

```csharp
            // Evaluate all Keyword permutations
            if (keywordCollector.permutations.Count > 0)
            {
                for (int i = 0; i < keywordCollector.permutations.Count; i++)
                {
                    // Get active nodes for this permutation
                    var localVertexNodes = Pool.HashSetPool<AbstractMaterialNode>.Get();
                    var localPixelNodes = Pool.HashSetPool<AbstractMaterialNode>.Get();

                    localVertexNodes.EnsureCapacity(vertexNodes.Count);
                    localPixelNodes.EnsureCapacity(pixelNodes.Count);

                    foreach (var vertexNode in vertexNodes)
                    {
                        NodeUtils.DepthFirstCollectNodesFromNode(localVertexNodes, vertexNode, NodeUtils.IncludeSelf.Include, keywordCollector.permutations[i]);
                    }

                    foreach (var pixelNode in pixelNodes)
                    {
                        NodeUtils.DepthFirstCollectNodesFromNode(localPixelNodes, pixelNode, NodeUtils.IncludeSelf.Include, keywordCollector.permutations[i]);
                    }
```

Keyword permutations grow exponentially in the number of keywords. Shadergraph collects the keywords used in your graph (just your graph, not the underlying infrastructure). It also places a restriction on the number of keywords you can use. Additionally, there is an option to limit the number of permutations for the preview codepath specifically. You can find it in the project settings and preferences, and it's going up into the hundreds of variants at most as far as I can tell.

Now, for every permutation in the preview, we do a DFS of the shadergraph and collect all nodes that are reachable with this permutation. Once for vertex, once for fragment. Then collect all nodes and compute their requirements. I'm pretty sure you can do this better, algorithmically, but the main problem is that their code is just wrong: The loop is pointless, every iteration is computing the same thing. Not on purpose, probably unintentionally, but wrong nonetheless. Concretely, for each permutations it will just return the list of all "active" nodes in the graph, where "active" is some concept independent of permutations.

I have validated this experimentally against all shader graph samples and other graphs I have on stock shadergraph.

Here is the argument for why this is always computing the same thing for every permutation: [This is the loop](https://github.com/Unity-Technologies/Graphics/blob/ba62a59864270b82f88d9396878da2926f69b353/Packages/com.unity.shadergraph/Editor/Generation/Processors/GenerationUtils.cs#L502) we're talking about. When I say "pixel nodes" below, the same applies to "vertex nodes."

We are first going to "prove" that all active nodes in `pixelNodes` are in `localPixelNodes`, and then we are going to  "prove" by way of contradiction that all nodes in `localPixelNodes` must already be contained in `pixelNodes`, otherwise this entire process would have already failed earlier. By that argument we then know that `localPixelNodes` is exactly `pixelNodes` with all the in-active nodes removed (where "in-active" is a concept unrelated to permutations that doesn't change during this calculation). In particular, all of this is independent of the current permutation.

The first part: establish that all active nodes in `pixelNodes` are in `localPixelNodes`:
 * Note that we go over all nodes in `pixelNodes` and start a search, collecting the results in `localPixelNodes`.
 * The call to `DepthFirstCollectNodesFromNode` has `NodeUtils.IncludeSelf.Include` set. Therefore, the node we pass in gets added to the output [unless it is inactive](https://github.com/Unity-Technologies/Graphics/blob/ba62a59864270b82f88d9396878da2926f69b353/Packages/com.unity.shadergraph/Editor/Data/Implementation/NodeUtils.cs#L141).

The second part: show that if a node in `localPixelNodes` wasn't in `pixelNodes`, the original code would already fail:
 * [The code](https://github.com/Unity-Technologies/Graphics/blob/ba62a59864270b82f88d9396878da2926f69b353/Packages/com.unity.shadergraph/Editor/Generation/Processors/GenerationUtils.cs#L533) goes over all nodes in `localPixelNodes`, finds their index in the input `pixelNodes`, and then use that to index  `nodeIndex` to access `pixelNodePermutations[nodeIndex]`.
 * But [just before](https://github.com/Unity-Technologies/Graphics/blob/ba62a59864270b82f88d9396878da2926f69b353/Packages/com.unity.shadergraph/Editor/Generation/Processors/Generator.cs#L664) we call this entire function, we set up `pixelNodePermutations` to have _exactly_ the size of `pixelNodes`.
 * In other words, if `localPixelNodes` were to ever contain a node that is not in `vertexNodes`, then `nodeIndex` would be `-1`, and the access to `pixelNodePermutations[nodeIndex]` would fail with an exception and terminate the entire calculation.
 * But the code doesn't fail (and there's no exception handler hiding it). So `localPixelNodes` only contains nodes in `pixelNodes`.

Here is the shader that is generated for the "HDRP Lit" graph from the samples (opened in Unity 6 without changes). Note that all the checks for permutations are identical and cover all 32 permutations found in this graph. That's exactly the problem.

![The generated shader with many redundant preprocessor checks](/assets/img/2024-11-17-unity-shader-graph-perf/03-generated-shader.png)

Note that this doesn't mean that shader variants are completely broken with shader graph. In the picture above, we still check `_EMISSIVE_COLOR_MAP`. We could have just stopped wasting work on all the `KEYWORD_PERMUTATION_X` stuff.

I have tried to look at the compiled shader code to see if this affects codegen, but Unity's button for that just crashes things: Instead of 102 variants, it compiles tens of thousands of them and then runs out of memory while loading them all into memory. Sigh.

![The compile and show code button that crashes the editor](/assets/img/2024-11-17-unity-shader-graph-perf/04-button-crash.png)

I'd hope that dead-code-elimination would ensure that the unused calculations get purged, but this still leaves the question of shader compile times and struct fields. That's a question for another day, and not what I set out to do this time.

![Structs and field with redundant preprocessor checks](/assets/img/2024-11-17-unity-shader-graph-perf/05-struct-fields.png)

Equipped with this knowledge and no intention to properly fix this for now, we can just replace that loop over all variants with a loop that just checks for active nodes in the input. It computes the same incorrect result, except faster. But why stop there? Let's detect if a node is present for all permutations (with this wrong calculation, this will always be the case), and don't emit those preprocessor checks then. The shader compiler would just have to figure out to ignore them otherwise. I'm no shader compiler myself, so my empathy here might be limited, but I think I would rather compile 4MB instead of 16MB of source. (4MB still feels like a lot!) Sure enough, this makes the shader compiler preprocessing about 4x faster.

![Size comparison of generated shaders](/assets/img/2024-11-17-unity-shader-graph-perf/06-shader-sizes.png)

Obviously there are more intelligent things you could do here: caches! incremental updates! timeslicing! multithreading! async updates! But it's a bad idea to reach for even a slightly clever solution when you haven't yet addressed the obviously silly. Clever solutions have a tendency to make everything more complex. Complexity is bad. Additionally, complex solutions are still going to be worse when they are held back by a lot of silly problems. For example, in the context of Mono trying to (say) multithread heavily GC-allocating code is pointless, because there's a lock around GC allocations. So it's pointless to multithread this before reducing the number of allocations.

Where does this leave us after 2 days? We're at ~185ms now (~170ms for the graph update) vs. 1.3s. Still bad (it's still Mono), but noticeably faster. Other operations are still painfully slow (undo! - next week?) and it at least feels much better in comparison.

![/assets/img/2024-11-17-unity-shader-graph-perf/07-after.png](Measurement of the improved state in Superluminal)
