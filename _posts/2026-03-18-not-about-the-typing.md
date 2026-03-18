---
layout: post
title: It has never been about the typing
excerpt:
tags: []
---

My friend Stefan Reinalter [is asking](https://x.com/molecularmusing/status/2034029712343728329?s=20):
> I find this extremely worrying, with many of people I respect saying things like "I no longer write code" or "let LLMs do it".
>
> Why did you start programming? Was it never the journey for you, but only the goal?
>
> I genuinely want to understand this, I seem to be the odd one out.

I am definitely in the camp of "the amount of code I still write myself has gone down massively" and want to provide some answers.

I started programming because it was the only way to poke at video games. I continued programming because all of the interactiosn that come with programming (debugging, profiling, reading, understanding, being-puzzled-when-you-go-to-bed) allow me to feed my inner introvert, indulge in a world that is ultimately very understandable (computers), and have a constant source of weird problems to engage my mind. And yes, ultimately I also really care about the outcome of creating software that I can give to other people so they can do awesome things with them.

Programming as the act of typing letters on a keyboard has never been what I aspired to do with my life. I enjoy programming as in "thinking about and interacting with abstract systems." This could also happen purely in mathematics, I think, except without job security... if that's still a thing for programmers.

As a crude analogy, I have spent orders of magnitude more time reading disassembly than I have actually spent writing out assembly instructions. I would say I am quite fond of working with disassemby, yet it is very rare that I actually feel the need to manually write something out. However, I use compilers all of the time and look at their outputs. Good times!

Here is another example: I know a performance sensitive slice of a big codebase that would really benefit from someone going in and inlining variable loads so that the compiler finally understands that it doesn't have to constantly reload these variables. There are hundreds of places where you'd have to do that. I have no love for doing this by hand. Been there, done that.

The fun part is conjecturing what might help and using your understanding of how various cursed pieces of technology work together to improve the performance of this code. The act of manipulating text files by itself is not where the fun is for me. An LLM can speed up the parts that were never all that interesting in the first place.

I do understand the desire for control of how and what code is written, though in my experience the amount of control that I can exert on the output of an LLM is way more direct than the control I can exert on coworkers. While it might not ultimately be about the code that we write, I do have a lot of opinions of how that code should be written to achieve the outcomes I care about.

What I do miss are the now-defunct ways that you could spit into the universe's disgusting face: many things are now much simpler than they ever were before (e.g. reverse engineering code), and it is sad that these challenges die. You can still do it all by hand, but the playing field has shifted and I find that it provides much less of an identity. Identity requires some sort of "what makes me different from everyone else", and a lot of these differentiators have been obliterated lately.