---
layout: post
title: Getting people to do the right thing
excerpt:
tags: []
---

A useful guiding idea for my work at various companies has always been this: When you want to get people in a sizeable company to change their behavior, it is more effective to change the environment than to (ex)change the people. "Behavior" here might mean "the way that people write code", for example. This is something that programmers at larger companies do all of the time, and most of the choices we make in that process do not happen super-consciuously. There is just not enough energy for everyone to think deeply about their choices all of the time: we mostly act out of habit and move in the ways that the terrain suggests. Sure, there are people who work with an agenda, with some conviction, but the larger the company gets, the less likely you are going to have these people everywhere.

Getting someone to work against the terrain, to go uphill, is inherently difficult. You can give them incentives to work in a specific way (bonus payments?). You can set expectations, but then you need to enforce those expectations (e.g. performance reviews). Ideally of course everyone would already have the same values and would intrinsically behave in accordance with these expectations ("we don't allocate memory dynamically here", "everything here is in TypeScript" etc.), but when a company grows the values will inevitably shift and dilute a little bit. This may also be for the better because different parts of a product may benefit from different values, so the overaching culture needs to broaden and become less specific. -- Shaping values then becomes incredibly difficult and at best you will manage to maintain the current values as the "dominant culture."

Setting expectations _should_ work better in practice ("do this or you fail at your job") but requires significant force, might go against other values, and is again hamstrung by values: You can set expectations on _your_ reports, but what about the level below? Or the three levels below? Unless you have been incredible at hiring and training engineering managers that share your values all the way down, there is some loss in this chain.

It may be tempting to assume that you can educate people to do the right thing. This is true if education is actually the problem. If they however do not share your values already, education either needs to imprint those values (hard! people already have values!) or is unlikely to work.

Instead, ask what can be done so the terrain is to your advantage. What can you do such that if people take a thousand random actions, they are, on average, more likely to do the right thing?[^simple] You can either make the right thing _easier_, or the wrongs things _harder_. Easy and hard are synonyms for "more likely" and "less likely", respectively.

An example of making the right thing easier is to set reasonable defaults: If you do not make choices, things should just work _for the common case_.[^stacktraces]

An example of making the wrong thing harder is to deliberately hide options: You insert friction, so reaching for the (usually) incorrect answers is hard and needs to be done intentionally. Extreme friction might be introduced via linting tools that actually forbid certain code patterns.

It is still vital to telegraph explicitly what is right or wrong, even when just shaping the terrain. If you don't, someone will see the friction you carefully inserted into workflows and starts to remove them! "This used to be hard, but with my PR this workflow is vastly simplified!" (Please give them at least partial credit because at least they wrote a PR description.) It's still a useful signal to get this sort of PR, because now you at least know who actually uses the intentionally hard workflow.

Finally -- if something is vitally important to get right, maybe try all of the above (incentives, expectation, education, environment)[^badpun].

[^stacktraces]: Even then the question of _which_ values you want to enforce in the common case remains.
[^simple]: This is definitely at odds with my recent musings on [simplicity and ease of use]({% post_url 2024-06-03-simplicity %}). Ease of use _always_ has a price. Use it wisely, where it matters.
[^badpun]: This is also known as setting an "IEEE standard" for some behavior.
