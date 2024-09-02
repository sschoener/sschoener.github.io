---
layout: post
title: Fourier Transforms via dot products
excerpt:
tags: []
---

In June, Juan Linietsky (of Godot fame) [recommended](https://x.com/reduzio/status/1810229759701291379) "The Scientist and Engineer's Guide to Digital Signal Processing" by Steven W. Smith ([book website](https://www.dspguide.com/)) as a good introduction to digital signal processing for audio. I have dabbled with writing filters but never rigorously, and while I had used the Fourier transform a few times I would not have claimed to have any appreciation for how Fourier transforms actually work -- typing in a fast Fourier Transform (FFT) does not really help your understanding, I think. My most prominent experience probably came from implementing an FFT for a game for Global GameJam 2017 (theme "Waves"): we analyzed ocean waves to determine just how nauseous exactly the main character should be.

The book itself is very approachable, and I enjoyed it a lot. I found it refreshing that the author put so much weight on the discrete Fourier transform (the thing you actually compute numerically). I had learned and used the "proper" Fourier transform in university, and I had typed off algorithms for the discrete case a few times, but seeing the equations for the discrete case written out gave me a new perspective: It's just a bit of canned Linear Algebra! It is probably obvious to everyone else, which is maybe why the book does not really make the connection explicit: they refer to this process as "the correlation method." I find it to be the most useful piece of the entire book, so I'd like to dwell on it a bit here.

The discrete fourier transform (DFT) takes a signal $x$ to its spectrum $S$, which tells you which frequencies are present in your signal (where "frequency" is relative to the length of the signal). For the DFT of real numbers, $x$ is an $N$-dimensional vector of real numbers and $S$ is a $N/2+1$-dimensional vector of complex numbers.

What are those $N/2+1$ entries of the spectrum $S$? The real part $Re(S_k)$ of the k-th complex number $S_k$ is the amplitude[^constant-factor] of a cosine wave that completes $k$ full cycles over the course of the signal, and the imaginary part $Im(S_k)$ does the same for the corresponding sine, where $0 \leq k \leq N / 2$. If you don't know anything about complex numbers, pretend that they are a tuple of real numbers and the "real part" is the first number in the tuple, whereas the imaginary part is the second.

How do we calculate these numbers? We project our signal onto those cosines and sines!

$$
Re(S_k) = \sum_{i=0}^{N-1} x[i] \cos(2 \pi k i / N)
$$

$$
Im(S_k) = \sum_{i=0}^{N-1} x[i] \sin(2 \pi k i / N)
$$

Or in pseudo-code:

```
double DotProduct(double* x, double* y, int N)
{
    double result = 0;
    for (int i = 0; i < N; i++) {
        result += x[i] * y[i];
    }
    return result;
}

// Re(S_k) = Real(x, N, k)
double Real(double* x, int N, int k)
{
    double cosine[N];
    for (int i = 0; i < N; i++) {
        cosine[i] = cos((2 * PI * k * i) / N);
    }
    return DotProduct(x, cosine, N);
}
```

This is neat and satisfying, because dot products are familiar, intuitive, and just make sense here for quantifying how much two things are alike. Putting all of the cosine and sine vectors (`cosine[N]` in code, and the corresponding `sine[N]`) as rows into a matrix then allows you to express the entire transformation as a matrix multiplication. Using these $N+2$ rows you get a $(N+2) \times N$ matrix. This can be cleaned up by noticing that two of those rows we have added are actually zero, and we can just drop them: For $k = 0$ we get a constant 0 vector because $\sin(0) = 0$:

$$
\sin(2 \pi k i / N) = \sin(2 \pi 0 i / N) = \sin(0) = 0
$$

Similarly, for $k = N/2$ we get a constant 0 vector because the sine passes through 0 at all multiples of $\pi$:

$$
\sin(2 \pi k i / N) = \sin(2 \pi i / 2) = \sin(\pi i) = \sin(\pi) = 0
$$

This leaves us with an invertible $N \times N$ matrix that expresses a change-of-basis into a Fourier basis. I find this neat because this is how I naively always _wanted_ to think about Fourier transforms in the first place: it's called a basis function for a reason. Furthermore, for the purpose of talking to a computer programmer, "project your data onto some vectors" is much more appealing than "here are some integrals involving roots of unity" -- even when you then go and implement a different algorithm (like a FFT).

None of the things here are specific to the real DFT, the complex one works just as well and yields [a yet more beautiful matrix](https://en.wikipedia.org/wiki/DFT_matrix) (they have a helpful illustration for this matrix further down on that page). I'd like to manually derive a version of the Fast Fourier Transform from this matrix some time and see what I learn in the process.

For the future, I am going to take a mental note to check for every integral with a product in it whether it helps to look at it as a projection. (Or read a book on functional analysis, who knows what I missed!)

[^constant-factor]: There are some constant factors that I'm glossing over here. They are discussed in chapter 8, page 153 of the book, or alternatively [here](https://www.dspguide.com/ch8/5.htm). These annoying constant factors only affect the real DFT.
