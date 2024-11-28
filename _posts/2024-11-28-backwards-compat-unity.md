---
layout: post
title: Backwards Compatibility (in Unity)
excerpt: What is it, and why do people care?
tags: [unity]
---

This note is inspired by some conversations with Unity users, who ask "why is backwards compatibility important?" I wanted to reflect on that for a bit.

First, what does backwards compatibility even mean? In the broadest sense, it means that someone that depends on your code can update the version of your code that they are using without their product breaking in the process.

The entire notion of backwards compatibility is of course flawed: If you make a change to your software, you probably make it to achieve some sort of change in behavior. If your change does not affect program behavior, then why even make it?

Sometimes the change in behavior is painfully obvious ("I changed an API, your program no longer compiles and you get a very nice error message from the compiler"), in which case we have somehow collectively agreed to call that change a "breaking change" and be extra careful about those.

Sometimes the change in behavior is more subtle ("I fixed a bug in this API, because it didn't do what I thought it should do, but it's impossible to write down a spec for this anyway so your mileage may vary") and the consequent breakage is slightly more cursed, but you are free to introduce those in minor versions.

Finally, sometimes the change in behavior is in a dimension that people don't think about until it explodes ("I refactored a system to be 'more maintainable' and now it is 3% slower, which pushed you over your frame budget", "I made this code faster and now your race condition in your code is more likely to happen" or "I added a new internal API, so binary sizes went up, and now you cannot ship on Platform X anymore").

All of this is to say that backwards compatibility is not really a well-defined thing but more a commitment to your community along the lines of "we do our best to not break you, and if we do, we try to make it up to you."

For different companies, backwards compatibility has different implications. For example, Microsoft needs to deal with the fact that you _will not_ recompile all of your software just because they released a new Windows update. When companies say that they want to be the "3D operating system of the world", this is what this entails, and that is incredibly difficult.

At face value, Unity does not require that level of compatibility: people can seemingly just recompile their code, fix the errors, and then be done with it. That unfortunately disregards a large part of what Unity does. In my mind, Unity does not primarily sell a production-grade tool for professional game developers that can just upgrade their stuff. No, Unity sells the lifestyle of being a game developer, the dream of making games, to people that previously could not make games. It is important that _someone_ succeeds in making big, impressive games with Unity to keep that dream alive, but it is likely not what the majority of people do when they use Unity. The user funnel starts with that: with a dream and a community.

Yes, a real production would decide to upgrade (or not) and that is why Unity provides platform updates for a long time in LTS versions. You pick your version, you stick to it. If you upgrade, you fix all of your stuff. Those professional users maybe do not mind breaking changes as much -- but they still mind breaking changes done badly: "The new system is still in beta but you already deprecated the old one?" -- "Shouldn't the new system be _better_ than the previous one?" etc.

So let us assume that breaking changes are executed perfectly, and that there is an upgrade path, and that the new systems are an improvement. I do not believe that this is what is likely going to happen, because the most effective way I know to make something good is to first make something bad and then improve it over time, which requires that you actively use it and fix it up. But let us just pretend that all of this is solved.

Making breaking changes then still affects two other groups of users: First, people that make middleware on top of Unity (asset store publishers, mostly). Second, non-professional users -- or in other words, what I believe to be the vast majority of Unity users and its community.

Asset store publishers often support a plethora of different versions. Their code breaks when you making breaking changes. No, not just the obvious API breaking changes, but also everything else ("oh, did shaders change again in this release?"). I do not know what chunk of Unity's revenue is coming from the asset store: I would guess it is not much. But the function of the asset store is probably not to make money for Unity, but to provide an ecosystem around Unity (and get people invested in it). If I were to guess who is using code from the asset store I would assume it skews towards non-professional users and small commercial games, purely because a lot of asset store code isn't good and you will naturally hit a wall at some point. (Not all of it is bad, of course.) So breakage will affect those users more.

Which brings us to that majority of users: making breaking changes invalidates knowledge, fractures communities, and gives people an opportunity to try out something else. If there is a big breaking change and all of your stuff is broken, and all of the tools that you bought from the asset store are broken, then maybe the pastures are greener elsewhere. Maybe you already have a reason to be on the fence.

That is why people care about breaking changes. There are many things that can be fixed in Unity without breaking changes, and there are some large, important things that are hard to fix without breakage. Clearly, both of these need addressing, and there is no future without making breaking changes. Yet ultimately this is not a conversation about technology, but about trust -- which is where I am going to leave this for now.