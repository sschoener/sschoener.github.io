---
layout: post
title: What are applicable functors?
excerpt: 
tags: [computer science, programming, haskell]
---

One of the first concepts that you run into when learning Haskell is that of a *functor*. The corresponding type class is this:
```haskell
class Functor f where
    fmap :: (a -> b) -> f a -> f b
```
Haskell is unable to explicitly encode the additional requirements that this class must fulfill. They are (in Haskell notation):
```haskell
fmap id = id
fmap (f . g) = (fmap f) . (fmap g)
```

On of the next type classes on the list for a Haskell newcomer is the *applicable functor*. It is defined as

```haskell
class Applicative f where
    pure :: a -> f a
    (<*>) :: f (a -> b) -> f a -> f b
```

plus a bunch of identities. It is not hard to see that you can define an instance of `Functor` for every `Applicative` and with the additional requirements on `Applicative` you will also see that the equations for `Functor` are satisfied.

Unfortunately, all of this seems besides the point. If something is called an *applicative functor*, it better be given as a functor plus some extra structure. So let's get to that. A common way to look at it is that 