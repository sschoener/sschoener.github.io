---
layout: post
title: Reading Review
excerpt: In which I try to recap what I read recently
tags: [computer science, programming]
---

This post is mostly directed at me. I want to keep track of what I am reading and ensure that I don't just forget it all.
Last week, I was mostly trying to learn about `async/await` in C#. In Unity, I usually work with an ancient C# version, but I started working on a Discord bot using [Discord.Net](https://github.com/RogueException/Discord.Net) which is a nice excuse to finally try out C# 7.3

# C# in Depth, 3rd edition
Ok, I didn't read it in full. I only read the sections on Linq (I was familiar with it before, but only recently started to look into expression trees) and asynchronous programming. I greatly enjoyed Jon Skeet's writing style but didn't learn as many new things as I had hoped to learn. The compiler transformations for `async/await` are explained nicely in there, but I think that he should have dedicated a few more paragraphs to synchronization contexts. If like me you want to have a clear understanding of what will happen at runtime, you will have to learn about them anyway; it will clear up most of the questions you will have about asynchronous programming in C#.

Find it [here](http://csharpindepth.com/Contents.aspx). You can already get a first version of the 4th edition over at Manning.

# Concurrency in C# Cookbook
I generally dislike cookbooks. I don't want to learn recipes to solve common problems, I want to understand the problems themselves in depth. That's much more valuable than learning a solution by-heart and just blindly applying it; it just leads to cargo-cult coding. The book itself isn't bad and if you have a specific problem you might find the solution in there, but with most of the problems in the book the solution didn't surprise me in any way and it felt more like an elaboration of the official docs. I don't feel like I learned a lot from this book, unfortunately.

Find it [here](https://stephencleary.com/book/).

# Exploring .NET Core with Micorservices, ASP.NET Core, and Entity Framework Core
This is not really a whole book, but more a selection of articles from various other books. The best part is that you can get it for free from Manning (one of my favorite publishers!). The first chapter is taken from `Re-Engineering Legacy Software` (more below) and is the star of the show. It manages to be hilarious and informative at the same time. I makes explicit a lot of common patterns that occur when refactoring code and convinced me to buy the whole book, so good job! :) The `Avoiding the Macbeth Syndrome` section is a wonderful description of how refactoring often goes wrong. In the chapter `Creating and Communicating with Web Services`, you can find a helpful example for when you want to get started quickly with a webservice. Unfortunately, the author has a tendency to use contractions of the forms `it is -> it's` in the weirdest ways, making the text quite hard to read at times. Some instances of them are just plain wrong, I think.

Find it [here](https://www.manning.com/books/exploring-dot-net-core). It's free!

# Re-Engineering Legacy Software
What a book. It's a breeze to read, well-written, funny, eloquent, and packed with useful advice. I, for one, like refactoring and improving code an awful lot and I think I already had plenty ideas on that topic before reading this gem. But the way the author makes them all explicit is quite helpful. The advice you'll find is twofold: First, it contains a lot of information on how to improve your organization and workflow, specifically:

 * how to get management on board to proceed with refactoring,
 * how to improve communication in the team,
 * what are the benefits of continuous integration,
 * how to deal with your constant urge to refactor everything all of the time,
 * how to deal with frustration and despair when it comes to legacy code bases,
 * how to measure code quality,
 * how to make onboarding easy and enjoyable for new team members.

Second, there is technical advice such as how to perform database migrations when you perform a complete rewrite of your codebase or what tools there are to measure the quality of code. It's mostly focused on Java and I consider it the least helpful part of the book. But the general points he makes are very valuable, like encouraging you to collect data that proves that your refactorings actually improve the code or point you to areas of the codebase where a refactoring might have the biggest impact. His emphasis on automation and optimizing workflows and onboarding are spot-on and something I haven't thought about that much before (...even though I was the one to finally set up a proper build system at my current company and am usually writing a ReadMe file for later reference whenever I have to work with a new codebase).

The best books leave you with new ideas on what you could try next. I want to see how much work it would be to setup Jenkins or some other automated build system for our codebase and maybe find or write a tool that suggests places for refactorings for a codebase (by e.g. counting the number of changes to a file committed to the git repo over time or finding some other metric to find problematic areas of code).

Find it [here](https://www.manning.com/books/re-engineering-legacy-software). I highly recommend it.

# Building Microservices with ASP.NET
I'm still on this, about a third through it. I like it a lot thus far, the author also puts in a lot of work to introduce you to technologies like Docker and get you started with continuous integration. This is a very practical book, but not in the cookbook style: It doesn't take your hand and shows you around, it requires you do actually think along and do some coding on the side. I enjoy it very much. I'm totally not in the target demographic for this book; it kinda expects you to already know what RESTful APIs are and what acronyms such as SOA (service oriented architecture, *you are welcome*) mean, so be prepared to learn more than just what the book is actually teaching you. And for the record, a web-API is *RESTful* if it uses HTTP requests the way they were intended to: A `GET` never changes anything, `PUT` actually replaces content, `POST` creates new content etc. and the responses to each HTTP query contain all the information a machine might need to take the next steps; this creates many opportunities for caching and is usually used in conjunction with nice and simple URLs. There is obviously much more to it, but that could easily fill a blogpost of its own.

Find it [here](http://shop.oreilly.com/product/0636920052074.do).