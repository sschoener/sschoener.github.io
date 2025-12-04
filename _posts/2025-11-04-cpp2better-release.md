---
layout: post
title: cpp2better, an il2cpp postprocessor
excerpt:
tags: []
---

It's been a while since I last talked about cpp2better. Time for an official "here it is" post.

## What is `cpp2better`?
`cpp2better` is a tool that hooks into your build pipeline for Unity to achieve better CPU performance in `il2cpp` builds. `cpp2better` achieves this by post-processing the C++ code that `il2cpp` produces and by systematically addressing inefficiencies in the generated code. It does this without affecting the semantics of the code in ways meaningful for final builds.

`cpp2better` is aimed at teams that have enough technical expertise to run their own build machines. The global optimizations it applies are incompatible with incremental `il2cpp` usage, so you usually only turn on `cpp2better` when you make builds on your build machine. You can of course also use it locally, as long as you follow the instructions for how to make clean, non-incremental `il2cpp` builds of your project (this applies only for code; there is no need to reimport assets or similar).

## Do I need to change my code for this to work?
No! It is not necessary to change your code at all.

## How do I get `cpp2better`?
You contact me for licensing: mail@s-schoener.com. The concrete details of licensing depend on the projects you work on.

## Can I try `cpp2better` before obtaining a license?
Yes! Get in touch: mail@s-schoener.com

## What performance gains can I expect from using `cpp2better`?
The performance gains depend highly on the platform and your specific project. I have seen everything from "`cpp2better` makes the game 2ms per frame faster" (from 16ms down to 14ms) to "no impact". The projects that tend to benefit the most from `cpp2better` are projects with large codebases that try to do everything right (e.g. using DOTS and Burst where it makes sense), usually built by experienced teams that have already rooted out their algorithmic inefficencies. Games that actively try to minimize their binary sizes are usually also a good fit. Before we get to any licensing agreement, you will have a chance to test `cpp2better` in your specific project on the platforms you care about and see whether it makes sense for you. 

I have also writtena few more words about the situations in which cpp2better helps [here]({% post_url 2025-12-04-when-does-cpp2better-help %}).

## What do I need to do to apply `cpp2better` to a project?
`cpp2better` comes with documentation that explains how to set it up, in general. The integration into a project itself is minimal: you just create a configuration file in your project root to opt-in to `cpp2better`.

## Can I stop using `cpp2better`?
Yes! You can still perform regular builds by just deleting the configuration file. You can at any point just remove `cpp2better` from your build pipeline.

## What Unity versions are supported?
`cpp2better` supports Unity 2022 LTS and later versions.

## What platforms are supported?
`cpp2better` officially supports PC, PS5, XBox, Switch (2), Android, iOS as build targets. For all of these platforms, there are games that run `cpp2better` in active production or in released titles. Other platforms may work, but I have not put any large efforts into making them work.

## Is there more information?
You are always welcome to reach out: mail@s-schoener.com. There are also two previous posts [here]({% post_url 2025-04-07-cpp2better %}) and [here]({% post_url 2025-04-17-kilo-fredriksson %}).