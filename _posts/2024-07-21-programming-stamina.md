---
layout: post
title: Programming Stamina
excerpt:
tags: []
---

Whenever I look back at "proper" software I have created by myself (my solo-games, or some larger tools) I am in disbelief that I ever managed to build them at all. Of course, the trick to building something like that is to take one step at a time: Nobody builds an entire game at once. They build five terrible prototypes, and then add a small thing every day, and then they repeat that many times.

For me, the prime reason for that is not that "taking small steps allows me to make better choices" or that "I don't know what to build until I have built it." No, when my free-time programming projects fail, it is usually because I ran out of "programming stamina." I build in small steps because there is no alternative that works for me.

It's a bit like what I imagine bouldering to be like: Every stone is a working version of your program, however imperfect it is. You find the first stone you can quickly reach, and then you jump upwards from stone to stone. You can only jump so far, so pick wisely what stones you can reach: Experience shows that when you miss a jump you usually fall so far down that the entire project is dead. It is a high-stakes game, and the distance you can realistically jump is what I call "programming stamina."

In order to help me not to miss stones, I do these things:

- _I first think about what I want to build._ This is not going to be the final product that I am envisioning here, but just the first interesting thing I can imagine. The most important thing about this first goal is that it's not about technology but about the concrete user-workflow or the concrete gameplay-loop I want to implement. It needs to be something that I can use, in whatever way. You need to start with the actual thing you want to solve, not with "infrastructure" or "setting up the build system." The most common reason why my projects died in the past is because I did not know what I wanted and I instead spent my valuable stamina on writing code that was overly generic, did not actually solve real problems, and was just generally afraid to close any doors because I fundamentally had no clue what I was even trying to accomplish.
- _Then I bootstrap the minimum thing that solves my problem_ in the technology I want to use. The choice of technology often dictates what your first step can be with your experience. Having to figure out a CMake setup is the antithesis of what you want to spend time on here, so either copy it from somewhere else or choose a tech where friction is minimal. You want to get to a working program that you have personal interest in as soon as possible.
- _Then I write down how this could be improved_, with each improvement going into a separate note. I also note down when I want to investigate something. I keep all my notes in code or a text file close by, with two unordered lists ("TODO" and "DONE") and sometimes a separate callout for "DOING". I have tried online solutions like Trello, but they tend to add too much ceremony ("should I add categories to my tickets? Do I need a background picture for my board? Oh look, there are 16 old boards I left because I didn't make a jump somewhere"). I only very rarely need to add more categorization. My notes look like this, except much longer (hundreds of lines):

```
TODO
[ ] clean up indexing queue mess
---[ ] get rid of std::deque

DOING
[ ] deal with long windows filenames (add "\\?\" prefix)

DONE
[x] think more deeply about what needs for synchronization exist
---[x] not a lot, I think? we can actually mostly get away with a little copying
---[x] we only use a fixed number of indexing jobs, and for those we can just preallocate
```

- _Then I repeatedly pick an item from the list, break it down into yet-smaller-steps, and implement them_. Again, no rocket science here. Some items do not need to be subdivided further at all, others turn out to be more complicated and actually get spun our into multiple new items. I usually indent the steps I note down with `---`, which is also how I keep track of any notes or investigation results. More than two levels of indentation indicate that I need a new note somewhere. When I pick up an item, I move it to "DOING", and then it gets a `[x]` when it moves to "DONE." It's always a little satisfying to cross things off, and it gives you the opportunity to breathe, maybe take a break, do something else, and decide that it is good enough.

Naturally, even with this system in place I sometimes misjudge and try to make jumps that I do not have the stamina for. This happens particularly often at the beginning of a project, because often the first step towards the "minimum interesting thing" is bigger than the average step I am willing to take. Here are some examples:

- I wanted to redirect std-out asynchronously using Win32. It turned out to be way more involved than I had hoped because I had just never done any of that. I caught pretty early that I was not going to make the jump. I decided to skip the "async" part and do it synchronously. Then I took a note to figure out async pipes separately in an isolated project, and then use that later on. To give me additional motivation to look into async pipes, I also decided to write a blog post on the topic (and it ultimately turned out to be a very benign investigation).
- I wanted to do some web development, but I couldn't get off the ground at all for what I wanted to do and ran out of stamina on the project; the first step was just too big already. I reset my expectation and decided to accept that I was not going to "produce" something but should rather find 3-4 online courses to watch first. I did that for a week or two, learned a ton, and then decided to stop worrying about "the right way" to start and just roll with Vite. Can always revisit that later anyway, and my first few projects are not going to be of any relevance anyway.
- I wanted to implement some data caching in a multi-threaded multi-step statemachine setup. Half-way through (so I thought!) I realized that even implementing the cache was much more involved than I thought and I should have figured this out properly before starting to programming. I decided to invest a little time to figure out what I was actually going to do and to then push on. I again grossly misjudged how much thought I had put into the caching: with the project on the verge of death by lack of stamina I made the judgement call to disable multi-threading for now (which simplified the implementation greatly) and take a new note to clean this up later. Two steps forward, one step back. But at least the patient is still alive.

Most of what I said here is probably not big news to most people, at all: The only way to good software is by writing a terrible first version and then iterating. But for me this is not just because that's what the market incentivizes (I think it does incentivize that, except for the "and then iterating" part) or some other external reason, but because that's what I am capable of when I program all by myself.
