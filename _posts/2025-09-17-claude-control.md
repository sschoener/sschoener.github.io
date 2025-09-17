---
layout: post
title: How I became the control group in an AI experiment
excerpt:
tags: []
---

At the risk of alienating almost everyone reading this blog, I wanted to report some first hand experience of interacting with AI for programming. I specifically want to talk about how I accidentally served as a control group for an experiment with an AI agent.

Here is the setup: Recently, I have been working with a compiler for a specific niche use-case. I was completely unfamiliar with the compiler and its source code, how any part of it actually works, and I was using it for a thing outside of its intended usage. The goal was to produce native dynamic libraries, for both MacOS ARM64 (my friend's local machine) and Windows X64 (my local machine). Unfortunately, the compiler was only really meant to produce executables, not libraries, and it would screw up exports from libraries and imports between libraries. Libraries apparently worked at some point in the distant past.

My friend decided to use Claude Code to solve the issue for ARM64. At first glance, it sounds unlikely that an AI agent would be able to solve this issue. However, it turns out that agents benefit greatly from a feedback loop ("here is the code to compile to check whether it works") and local tool usage gives the agent plenty of options ("I am using LLVM tooling to inspect the malformed libraries"). Combine this with a generous budget in both money and time, and it stands a chance.

Claude got a little bit of a head start. To my surprise, it came back with a working solution. The next day, I started to look at the issue for x64, by hand. I was able to work in the same branch that Claude's code lived in. I was able to benefit from some of the higher-level codegen fixes that Claude had made, but the Windows x64 specifics were still up to me. The ARM64 fixes that Claude made were unfortunately unhelpful for me, so I had to take most things from scratch.

It took a little bit longer than a regular working day (10h, if my memory serves me well), which is about the time that Claude needed for its changes. Yes, that's a long time for an agent. I have not personally controlled that side, and my assumption is that it required occasional intervention (or even restarts).

Once I had my solution in place, I inevitably realized that Claude had made multiple unnecessary changes on its piece of the puzzle. I only realized this because I had just spent a day in that codebase.

A few days later we noticed that data imports/exports (as opposed to function imports/exports) did not work and failed in obscure ways. I was able to fix it for Windows x64 in a few hours, since I now knew the relevant bits of the codebase, learned all the details of imports and exports on my platform, and had acquired familiarity with a collection of tools to investigate broken binaries. I do not have an MacOS ARM64 machine here, so I did not try to fix that side. Claude however _did_ try to fix MacOS ARM64 for days, yet to this date data imports/exports are broken for us on ARM64.

There is a mixed bag of learnings here, none of them novel. First, it is surprising that Claude even managed to come up with a solution to this rather bespoke problem in the first place. Second, this is obviously useful. And third, if you use an agent to solve a problem you do not understand, you will learn absolutely nothing and you will be just as puzzled by the inevitable next problem.
