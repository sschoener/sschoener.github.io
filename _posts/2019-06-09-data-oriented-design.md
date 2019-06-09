---
layout: post
title: Data Oriented Design - An Interpretation
tags: [computer science, programming]
---

_Data Oriented Design_ (DOD) is one of those buzzwords that seems to come up frequently in discussions with my co-workers, especially since Unity has gone all-in on what they refer to as _DOTS_ - their _data oriented technology stack_. This, for all I know, mostly encompasses their Burst compiler, a job system, and the Entity-Component-System (ECS) architecture. Find more information [here](https://unity.com/dots); it's all pretty cool stuff and definitely worth your time.

Now I have to admit that I don't like buzzwords. They usually have the side effect that people start using tools they don't understand to solve problems they don't have. This is especially unfortunate in the context of DOD for reasons that I will try to make somewhat clearer in my interpretation of DOD below.

Let me get some stuff out of the way: I am in no way claiming that I have any authority on this whole topic and I do not believe to have any privileged access to what people like Mike Acton _really_ think. This is merely my interpretation of what is said and I will attempt to provide references for some of the claims I make.

## Data-Oriented Design is not just ECS
The typical story of data-oriented design that you are bound to stumble over when you start looking into DOD goes like this:
 * You are using an object-oriented design.
 * Object-oriented design causes cache misses.
 * Cache misses are bad for performance.
 * ECS gives you nice memory access patterns, reducing cache misses.
 * That's DOD for you! Apply this pattern _everywhere_ for great profit!

The original source for the term data-oriented design seems to be [this article](http://gamesfromwithin.com/data-oriented-design) by Noel Llopis, published in 2009, and it is very to easy to read that, stop half-way through it, and then conclude that data oriented design is all about ECS and hence that should be used all over the place. Similarly, some of the more recent material on DOD that is coming from Unity is released under the DOTS label, which one could almost consider a misnomer: The _technology_ is not what makes it data-oriented, it just happens that tech such as the ECS architecture makes it easier to design around data. The fact of the matter is that it's probably very much necessary for Unity to focus on communicating how to work with ECS and advertise it as a step forward, a broad solution to all kinds of problem. After all, programmers are going to be exposed to working with the ECS architecture, even if they don't really design around their data. Still, I frequently run into the problem at work that it is hard to point people to something that is neither a [full-blown book](http://www.dataorienteddesign.com/site.php) on DOD nor an introductory video on how to use ECS and how great that is at reducing cache misses.

Now this is not what I think DOD is, certainly not. To drive this point home, the people that argue for DOD will happily tell you that you should *not* just go ahead and do whatever they are doing (i.e. build an ECS framework). [Here is a nice interview](https://youtu.be/qWJpI2adCcs?t=2776) (watch until 51:39 for this bit) with Mike Acton from HandmadeCon 2015 where part of the message is that (obviously) the 'big guys' (Unity, Insomniac, Naughty Dog) are solving _their_ problems and those are probably very different from _your_ problems. You are not playing to your strengths by trying to just blindly replicate whatever they are doing. You probably do not need a full-blown ECS in your custom engine, because that is most likely not the problem that you are solving.

## Some perspectives on Data-Oriented Design
So what is data-oriented design? Unsurprisingly, it is pretty hard to come up with a short definition of what data-oriented design _is_, and even if it were not, I would be the wrong person to do so. So instead I want to present some ideas and statements that relate to data-oriented design, each time with some references to back that up (video quotes usually come with some context, so it might take a minute to get up to the exact quote). This is my interpretation of DOD, so to speak. Inevitably, I will in the process make myself guilty of the sin that I was pointing out above and conflate the issue of DOD with other statements about software, so use your best judgement and continue exploring the references. Do not trust me.


---


DOD is an approach to solving problems. It just so happens that we're using computer programs to do so. Those programs are very clearly to be considered as a means to an end, not an end in themselves. DOD does not tell you how to write your code because that is firmly besides the point. It asks you to first and foremost realize that you _want to solve an actual problem_ which in our case means transforming some sort of input data into some sort of output data:

> The purpose of all programs, and all parts of those programs, is to transform data from one form to another.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=753), _CppCon_, 2014

> Lie #3: Code is more important than data. [...] Code is ephemeral and has no real intrinsic value.  
> -- [Mike Acton](https://cellperformance.beyond3d.com/articles/2008/03/three-big-lies.html), _CellPerformance blog_, 2008

> In DOD, the goal of writing code is not itself writing code - the code exists only as a byproduct of an underlying process.  
> -- [Richard Mitton](http://www.codersnotes.com/notes/explaining-data-oriented-design/), _personal blog_, 2015

> Programming, by definition, is about transforming data: It’s the act of creating a sequence of machine instructions describing how to process the input data and create some specific output data.  
> -- [Noel Llopis](http://gamesfromwithin.com/data-oriented-design), _Game Developer magazine_, Sept. 2009

> [A] programmer's job is not to write code; [a] programmer's job is to solve (data transformation) problems.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=1419), _CppCon_, 2014



The claim that DOD is about solving problems in general is mainly supported by statements such as these:

> Everything is a data problem, including usability, maintenance, debug-ability, etc.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=837), _CppCon_, 2014

> NUMA extends to I/O and pre-build data all the way back through time to original source creation. [...] You have to understand the cost of accessing data over the entire pipeline.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=911), _CppCon_, 2014

This last point makes it clear that the problem that is under consideration is not that of merely building software, but about shipping it, maintaining it, and having a business around it. It's not just about loading assets from memory, it's also about "loading assets from artists."


---


DOD is about realizing that a problem does not exist in a vacuum. You have context information. Understand the distribution of the input data, what the output data will actually be used for, and what dependencies in the data this implies. It is the distribution of the data (and not just the _set_ of data) and what to do with it that determines the problem. There is little point to start with any solution if it does not put the data in the center because this is the sole purpose of the program.

> If you don't understand the data, you don't understand the problem. Understand the problem by understanding the data. Different problems require different solutions. If you have different data, you have a different problem.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=780), _CppCon_, 2014

> Code-driven design is about trying to express in source-code form what you wish the computer to do - it's a forward-based planning method. The motivation behind data-oriented design is to consider what the ultimate result you want is, and then work backwards to discover the best way to get those bytes in that place.  
> -- [Richard Mitton](http://www.codersnotes.com/notes/explaining-data-oriented-design/), _personal blog_, 2015

> The more context you have, the better you can make the solution. Don't throw away data you need.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=893), _CppCon_, 2014

> In order to effectively design and optimize a system for a console game, both the data and how it is used must be known. This is the most obvious, most crucial and most neglected principle in software architecture.  
> -- [Mike Acton](https://cellperformance.beyond3d.com/articles/2006/04/performance-and-good-data-design.html), _CellPerformance blog_, 2006

> The key to data-oriented practice is data transparency. Understanding what's there is how you solve a problem.  
> -- [Mike Acton](https://youtu.be/k_ORJXmPu9M?t=1720), _Unite LA_, 2018

> Here's is part of how I define data oriented programming: [...] The actual global energy that you use to make a transformation should be proportional to the amount of surprise in the data.  
> -- [Mike Acton](https://youtu.be/p65Yt20pw0g?t=3413), _GDC_, 2018

That last quote highlights how the distribution of the data is a key point; it is straight about the entropy in the input distribution. To make this a bit clearer: If you know the inputs perfectly well and the surprise is literally zero, then you are actually creating a movie. Not even an interactive one, just a plain old movie. The runtime cost of this should be that of, well, _playing a movie_ and not that of running an interactive simulation.

Here is a fitting example of being aware of both your input data and what the output is used for: In [this talk](https://youtu.be/uK87jZmeT7Y?t=1465), Andreas Fredriksson highlights a specific optimization they performed for their MegaCity demo. The crucial bits here are that a) they know exactly what kinds of inputs to expect and b) know what the output data is going to be used for and can thus get pretty hefty savings by replacing `sin` and `cos` with suitable approximations. (This is of course a very local example only and everything is obvious in retrospective.)


---


DOD is not necessarily, fundamentally about performance. When solving a problem, you need to understand the cost of the solution and what your requirements are (context!). In the case of software, this is mainly the resources required to build, maintain, and run it, which is where performance comes in. You are not _forced_ to write code that runs well on your hardware, you are just not particularly resource-savy and actually hinder yourself if you do not use your tools for the job they were designed for. But at least make it a conscious decision that you are making, say, a trade-off between runtime and engineering time. Note thus how this first quote is not about minimizing the cost, but about understanding it:

> If you don't understand the cost of solving the problem, you don't understand the problem. If you don't understand the hardware, you can't reason about the cost of solving the problem.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=807), _CppCon_, 2014

> HARDWARE is the platform. Different hardware, different solutions. [...] Reality is not a hack you're forced to deal with to solve your abstract, theoretical problem. Reality is the actual problem.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=1063), _CppCon_, 2014


---


DOD is not about modeling your domain with an ECS architecture. In fact, DOD is not about modeling anything. Let data be data. Creating a model will typically make your problem _harder_ to solve, not easier. You already _have_ the data and know how to transform it, so why add metaphysics? Abstracting away details means throwing away helpful information and replacing it with an abstraction that is leaky at best because you are still tied to the reality of solving your problem on actual hardware.

> I say this is the opposite of a modelling approach, because modelling implies that you are abstracting or not dealing with the actual data, but in DOD we do the opposite, we focus on the actual data, to such a degree that we redefine its actual layout to serve the transformation. DOD is, in essence, anti-abstraction (and therefore not-modelling).  
> -- [Christer Ericson](https://sites.google.com/site/macton/home/onwhydodisntamodellingapproachatall), _via Mike Acton's website_, 2016

> Lie #2: Code should be designed around a model of the world.  
> -- [Mike Acton](https://cellperformance.beyond3d.com/articles/2008/03/three-big-lies.html), _CellPerformance blog_, 2008

> [World modeling leads to] all kind of other problems that you shouldn't have in the first place. [...] World modeling tries to idealize the problem, but you can't make a problem simpler than it is. [...] World modeling is the equivalent of [...] 'engineer by analogy' and 'engineer by storytelling' instead of 'engineer by engineering'.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=1300), _CppCon_, 2014

> The main thing [...] we accomplished here is immediately _not_ adding stuff that is unnecessary to solve the problem.  
> -- [Mike Acton](https://youtu.be/k_ORJXmPu9M?t=1020), _Unite LA_, 2018

> [...] it is simpler, ultimately, because what we have done is removed things other than the thing that actually solves the problem. So everything else that you invented to put into it, all that extra complexity, that's all just gone.  
> -- [Mike Acton](https://youtu.be/p65Yt20pw0g?t=3509), _GDC_, 2018

> Solving problems you probably don't have creates more problems you definitely do.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=847), _CppCon_, 2014



This next quote is not framed as relating to DOD, but it very much reflects how at least I sometimes feel about modeling approaches:
> I don't want to solve problems of analytical philosophy and Platonic essentialism to write code.  
> -- [Brian Will](https://youtu.be/IRTfhkiAqPw?t=166), _Object-Oriented Programming is Embarrassing_, 2016, while trying to figure out what should go into a `Chair` class

---

So how does the whole ECS architecture fit into this? My argument would be that ECS is one solution you might find using DOD when your requirements look as follows:

 * you need to build a flexible architecture that you can tool for because you are building a highly flexible engine that will be used in multiple (many) projects,
 * you want to ensure that this architecture makes it easy to leverage the hardware that your customers are targeting (because you know that they care about it),
 * you want to make it easy for them to reason about what data they have, how it is used, etc. and hence need an architecture that makes data very explicit.

I guess my point here is that ECS is something that you can arrive at when using DOD with a specific set of requirements in mind. It's a consequence of, not a prerequisite for DOD.

## Working With DOD
Assuming you are sold on DOD, where do you start? That is, short of building a custom ECS framework for your engine which has already been pointed out to probably be overkill? Well, both [Mike Acton at CppCon](https://youtu.be/rX0ItVEVjHc?t=4470) and [Noel Llopis on his blog](http://gamesfromwithin.com/data-oriented-design) (scroll down to _Applying Data-Oriented Design_) have a few suggestions that you should definitely read. They are actually quite spot on, I think.

Here are some thoughts and ideas that I think might be helpful to get started:

 * Implement some easy mechanism to write out data from your software so you can actually look at what is there. Even something as simple as exporting it to a CSV and playing around with it in Google Sheets can be very telling. I am not talking about performance data exclusively, but just the raw data you are working on. How many widgets are there? What is the distribution of string lengths? How often is this value actually recomputed? Of course it is more useful to have an actual question to answer, but it will be helpful to have an idea of the actual data that you are working with. Knowing whether there are 10, 1000, or 100,000 widgets _does_ make a difference. Try to understand how your data is used. Is this static data? Is it readonly? How often is it written? Do the writes actually change it?
 * Learn to differentiate between _generic_ and _common_: It might be _generic_ to operate on a single object, but it is certainly not the most _common_ thing. Why should your procedure always take a _single object_ as an argument if that doesn't ever happen? This is merely hiding information that you could be using the implement the operation more efficiently.
 * Learn about your target hardware. It is a tool and you should be aware of how to use it. Reading [Intel's manuals](https://software.intel.com/en-us/articles/intel-sdm) is a big ask, so maybe start by regularly looking at the assembly produced by your compiler using [Compiler Explorer](https://godbolt.org/) or whatever tools you have. Personally, I also enjoy [Agner's writing](https://www.agner.org/optimize/).
 * If you are optimizing for performance, take a look at these parts of Mike Acton's CppCon 2014 talk about [bools in structs](https://youtu.be/rX0ItVEVjHc?t=2508) and [states](https://youtu.be/rX0ItVEVjHc?t=3477) (make sure to also watch the segment about the transform function after that). Note how the _goal_ is performance (and hence cache-line usage), but the method is to look at the data, figure out what is needed, what is probable, and what is frequent or common.
 * Look for places in your codebase where adding booleans or enums to a struct forces you to deal with combinations of these flags that are actually never set. Can you get rid of them by sorting the data instead? Quoting [Pitfalls of OOP](http://harmful.cat-v.org/software/OO_programming/_pdf/Pitfalls_of_Object_Oriented_Programming_GCAP_09.pdf): `Don't test for exceptions - sort by them.`
 * Question your choices: Do you _really_ need a quad-tree? Is the added complexity necessary or are you imposing a mental model on the data when that really does not require it?

## Wrapping up
Actually, looking back over the quotes above, my interpretation of DOD might be summarized by: "Realize that your problem is actually about transforming data and apply engineering principles to solve these data transformation problems." After all, gathering the requirements (_knowing the data_), understanding the problem, and evaluating the costs associated with it (_understanding the hardware_) to arrive at a design (_a conscious trade-off_, that is) that solves the problem is the minimum expectation in all other engineering disciplines. But maybe I'm painting too broad strokes here?

> "I don't wanna know all of this stuff, the capacity of my [cache] lines [...] and what my finite set of hardware actually is." [...] The reality is: Ignoring facts that are inconvenient is not engineering. It's dogma.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=2474), _CppCon_, 2014

Another thing that I would like to point out is that there is this idea that you should now start to use the same design principles to solve _all_ problems. While you should look at the data for all kinds of problems, it is important to recognize that optimizing for pure performance is a means to an end once you have understood that the metric you are optimizing for is runtime performance. If you instead work on a public API then your design goal might be vastly different - e.g. ensuring that your API is stable (see [this comment](https://dinodini.wordpress.com/2010/12/03/beam-me-up-scotty/#comment-7665) for example). It is a case of being reasonable and not subscribing to some ideology.

> In practice, we find a balance between the anti-abstraction of pure DOD and code architecture component needs.  
> -- [Christer Ericson](https://sites.google.com/site/macton/home/onwhydodisntamodellingapproachatall), _via Mike Acton's website_, 2016

Oh, and if you are wondering why most of the quotes come from Mike Acton -- he just happens to be very outspoken on this topic and [everyone looks moderate compared to him](https://youtu.be/qWJpI2adCcs?t=360), so he seems like a good point of reference. Also, they're catchy:

> Reason must prevail.  
> -- [Mike Acton](https://youtu.be/rX0ItVEVjHc?t=984), _CppCon_, 2014

## Further Reading
Here is some further reading/watching around this general topic. I have tried to exclude pure _use ECS and nothing else_ posts. I really recommend digging into some of this stuff:

 * [This post](https://www.gamedev.net/blogs/entry/2265481-oop-is-dead-long-live-oop/) is an excellent piece to remind people that there is a difference between OOP, OOD principles, and using it to model the world. Note how this also shows that when you do not need the flexibility that you get from ECS (like adding components at runtime; probably because you are not building Unity or some other general purpose engine), you are probably better off just writing the code to solve the actual problem. Note that the author admits there is still plenty of potential for optimization. Also make sure to read the comments to find gems such as [this perspective](https://www.gamedev.net/blogs/entry/2265481-oop-is-dead-long-live-oop/?do=findComment&comment=2266724) on OOP or [this surprisingly reasonable discussion](https://www.gamedev.net/blogs/entry/2265481-oop-is-dead-long-live-oop/?tab=comments#comment-2266738) with someone called snake5.
 * Some more pointers about the whole _OOP is bad_ story that is often coming up when you are actually looking for some constructive discussion around DOD. [This](https://tomforsyth1000.github.io/blog.wiki.html#%5B%5BData%20Oriented%20Luddites%5D%5D) points out this confusion of issues (though I don't necessarily agree with their notion of DOD). [Pitfalls of Object Oriented Programming](http://harmful.cat-v.org/software/OO_programming/_pdf/Pitfalls_of_Object_Oriented_Programming_GCAP_09.pdf) is often quoted and actually has a lot of nuance (`OO is not necessarily EVIL` is a slide title) plus a very reasonable [follow up](https://docs.google.com/presentation/d/1ST3mZgxmxqlpCFkdDhtgw116MQdCr2Fax2yjd8Az6zM/edit#slide=id.p) from 2017 that ends by saying that OOP has to be considered more carefully. If you are looking for some more nuanced critique of OOP, try [this](http://skipoleschris.blogspot.com/2012/04/life-without-objects.html).
 * Stoyan Nikolov's [CppCon 2018 talk](https://youtu.be/yy8jQgmhbAU) has a very click-baity title (`OOP Is Dead, Long Live Data-oriented Design`) but is actually pretty down to earth and worth watching. [This question](https://youtu.be/yy8jQgmhbAU?t=2923) and its follow-up in the end (`What part of OOP is dead, exactly?`) relativize the title a bit. The one downside of this talk might be that it focusses very much on the result of using DOD and not so much on actually doing it.
 * Mike Acton's [Unity LA 2018 talk](https://youtu.be/k_ORJXmPu9M) about LOD and Culling Systems to me is an excellent example of DOD that does not simply focus on _make it fit a cache line, use ECS_.
 * Noel Llopis has [another entry](http://gamesfromwithin.com/data-oriented-design-now-and-in-the-future) on his blog that shows a nice use-case for DOD applied to something where the initial structure is not as inviting and uniform. I disagree with his opening statement about DOD, but each to their own :)
 * Mike Acton's [slides on concurrency and quicksort](http://macton.smugmug.com/gallery/9114809_C9awM#607513208_xqWYf) are a great example of considering a problem in context and using knowledge about what the output data is used for to actually build a good solution for a problem. This hopefully illuminates the throughput vs. latency comments from his CppCon 2014 talk (and elsewhere). Really, this deck of slides is worth your time and a good practice in DOD.
 * Dangling Pointer's [write up](http://danglingpointers.com/post/mike-actons-dod-workshop-2015/) on a DOD workshop with Mike Acton is an excellent short read about how getting to know your input data and the usage of your output data can enable you to be much smarter.
 * The [CellPerformance blog](https://cellperformance.beyond3d.com/) by Mike Acton has plenty of material. Personally, I like [the sketches](https://cellperformance.beyond3d.com/articles/2009/08/roundup-recent-sketches-on-concurrency-data-design-and-performance.html) the most.
 * Somewhat related to not modeling the world and not creating problems for yourself, I recommend digging through the old alt.dev.blog posts to find gems such as [this one about simplicity](http://jahej.com/alt/2011_07_16_simplicity-oriented-programming.html); it is an illustrative example of how to avoid building problems by avoiding abstractions you don't need.
 * There is the [Data-Oriented Design book](http://dataorienteddesign.com/dodbook/), it's free and not too long so it doesn't hurt to read it. Do take anything in it that sounds like a recipe with a pinch of salt (pun intended). I personally like the fuzzy chapters much more (the first one and the last two).


## Acknowledgments
Thanks to my friend & colleague [Jesper Stefansson](https://twitter.com/grousejst) for fruitful discussions and feedback on the writing.