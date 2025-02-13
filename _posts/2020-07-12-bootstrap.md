---
layout: post
title: Implementing the bias-corrected and accelerated (BCa) bootstrap
excerpt: 
tags: [mathematics, programming]
---

I've been dabbling in some non-parametric statistics and came to the point where I needed to implement a bootstrapping test myself. It turns out that it is incredibly annoying to implement because I'm apparently too stupid to google the right words to come up with an implementation that you can just steal. This post also isn't that. However, I'm trying to take the annoying parts out of the implementation.

I'd also recommend reading [this paper here](https://projecteuclid.org/euclid.ss/1032280214) and maybe supplement it by reading [this one as well](https://projecteuclid.org/euclid.ss/1177013815) to get some context. The first paper also has a useful bit of discussion and commentary at the end. Also, there's a book by Efron himself freely available to download for personal use [here](https://web.stanford.edu/~hastie/CASI/order.html). It's a bit lighter than the papers but gives a good overview.

First off, there is an implementation of BCa available in R, and it is open source. You can find it [here](https://gitlab.com/scottkosty/bootstrap/-/blob/master/R/bcanon.R) and read its documentation [here](https://www.rdocumentation.org/packages/bootstrap/versions/2019.6/topics/bcanon). The function actually is just this below; I've added some comments in case you are not used to working with R:

```R
# Takes a vector of observations x, the number of bootstrap samples to take,
# an estimator plus additional parameters for it, and confidence levels for
# the output intervals
"bcanon" <- function(x,nboot,theta,...,alpha =
                     c(.025,.05,.1,.16,.84,.9,.95,.975)) { 
    if (!all(alpha < 1) || !all(alpha > 0))
      stop("All elements of alpha must be in (0,1)")

    # NB. these lines check that nboot > (1 / alpha) and because otherwise
    # you need more samples to get a somewhat useful confidence interval.
    alpha_sorted <- sort(alpha)
    if (nboot <= 1/min(alpha_sorted[1],1-alpha_sorted[length(alpha_sorted)]))
      warning("nboot is not large enough to estimate your chosen alpha.")

    # unrelated to the actual bootstrapping
    call <- match.call()

    # compute theta(x) of the samples and resample the data nboot times
    n <- length(x)
    thetahat <- theta(x,...)
    bootsam<- matrix(sample(x,size=n*nboot,replace=TRUE),nrow=nboot)

    # compute theta for each sample and compute the quartile of the fraction
    # below our original estimate under a normal distribution
    thetastar <- apply(bootsam,1,theta,...)
    z0 <- qnorm(sum(thetastar<thetahat)/nboot)
    
    # get a jackknife estimate for theta to compute the acceleration factor
    u <- rep(0,n)
    for(i in 1:n){
        u[i] <- theta(x[-i],...)
    }
    uu <- mean(u)-u
    acc <- sum(uu*uu*uu)/(6*(sum(uu*uu))^1.5)

    # compute the actual distribution that we are taking the quantiles of to
    # create the confidence interval    
    zalpha <- qnorm(alpha)
    
    tt <- pnorm(z0+ (z0+zalpha)/(1-acc*(z0+zalpha)))
    
    confpoints <- quantile(x=thetastar,probs=tt,type=1)

    # and now just some logic for outputting it
    names(confpoints) <- NULL
    confpoints <- cbind(alpha,confpoints)
    dimnames(confpoints)[[2]] <- c("alpha","bca point")
    return(list(confpoints=confpoints, 
                z0=z0, 
                acc=acc, 
                u=u, 
                call=call))
}
```

With some additional knowledge of R, you can substitute some of the function with their implementation to get a better idea of how you'd compute this in an imperative language.
Here is some pseudo-C# that should be good enough to easily translate into any language. Note that I am using a single alpha value, so `alpha = 0.05` gives you the endpoints that correspond to `0.025` and `0.975`.
```csharp
struct ConfidenceInterval {
    double Low;
    double High;
}

ConfidenceInterval bootstrap<T>(T[] samples, Func<T[], double> theta, int nboot, double alpha)
{
    double thetaHat = theta(samples);
    int numBelowThetaHat = 0;
    // do the actual bootstrapping
    double[] thetaStar = new double[nboot];
    for (int i = 0; i < nboot; i++) {
        // resample the original samples with replacement
        T[] r = resample(samples);
        thetaStar[i] = theta(r);
        if (thetaStar[i] < thetaHat)
            numBelowThetaHat += 1;
    }
    // qnorm implemented below
    double z0 = qnorm(numBelowThetaHat/ (double)nboot, 0, 1);
    
    
    int n = samples.Length;
    T[] buffer = new T[n - 1];
    // copy all but the first element to the buffer
    for (int i = 1; i < n; i++)
        buffer[i - 1] = samples[i];
    double[] u = new double[n];
    for (int i = 0; i < n; i++) {
        u[i] = theta(buffer);

        // these lines have the effect that each iteration we are missing
        // another sample in the buffer, e.g. in the first iteration we
        // are missing sample 0, then in the second it is sample 1 etc.
        if (i != n - 1)
            buffer[i] = samples[i];
    }

    double mean = computeMean(u);
    double sumU2 = 0;
    double sumU3 = 0;
    for (int i = 0; i < n; i++) {
        double tmp = mean - jackKnifeBuffer[i];
        sumU2 += tmp * tmp;
        sumU3 += tmp * tmp * tmp;
    }
    
    double acc = sumU3 / Math.Pow(6 * sumU2, 1.5);
    double zalphaLo = qnorm(alpha);
    double zalphaHi = qnorm(1 - alpha);
    // pnorm implemented below
    double ttLo = pnorm(z0 + (z0 + zalphaLo) / (1 - acc * (z0 + zalphaLo)));
    double ttHi = pnorm(z0 + (z0 + zalphaHi) / (1 - acc * (z0 + zalphaHi)));

    // compute ttLo, ttHi quartiles in thetaStar
    sort(thetaStar);
    return new ConfidenceInterval {
        Low = thetaStar[floor(nboot * ttLo)],
        Hgih = thetaStar[floor(nboot * ttHi)]
    };
}

static double pnorm(double z)
{
    // implementation adapted from here:
    // https://docs.microsoft.com/en-us/archive/msdn-magazine/2015/november/test-run-the-t-test-using-csharp//

    // input = z-value (-inf to +inf)
    // output = p under Standard Normal curve from -inf to z
    // e.g., if z = 0.0, function returns 0.5000
    // ACM Algorithm #209
    if (z == 0.0)
        return 0.5;
    var y = Math.Abs(z) / 2; // 209 scratch variable
    double p; // result. called 'z' in 209
    if (y >= 3.0)
    {
        p = 1.0;
    }
    else if (y < 1.0)
    {
        var w = y * y; // 209 scratch variable
        p = ((((((((0.000124818987 * w
                    - 0.001075204047) * w + 0.005198775019) * w
                    - 0.019198292004) * w + 0.059054035642) * w
                - 0.151968751364) * w + 0.319152932694) * w
                - 0.531923007300) * w + 0.797884560593) * y * 2.0;
    }
    else
    {
        y = y - 2.0;
        p = (((((((((((((-0.000045255659 * y
                            + 0.000152529290) * y - 0.000019538132) * y
                        - 0.000676904986) * y + 0.001390604284) * y
                        - 0.000794620820) * y - 0.002034254874) * y
                    + 0.006549791214) * y - 0.010557625006) * y
                    + 0.011630447319) * y - 0.009279453341) * y
                + 0.005353579108) * y - 0.002141268741) * y
                + 0.000535310849) * y + 0.999936657524;
    }

    if (z < 0.0)
        p = -p;
    return (p + 1.0) / 2;
}


/*
*     Compute the quantile function for the normal distribution.
*
*     For small to moderate probabilities, algorithm referenced
*     below is used to obtain an initial approximation which is
*     polished with a final Newton step.
*
*     For very large arguments, an algorithm of Wichura is used.
*     Adapted from 
*     https://gist.github.com/kmpm/1211922/6b7fcd0155b23c3dc71e6f4969f2c48785371292
*     and
*     https://stackedboxes.org/2017/05/01/acklams-normal-quantile-function/
*
*  REFERENCE
*
*     Beasley, J. D. and S. G. Springer (1977).
*     Algorithm AS 111: The percentage points of the normal distribution,
*     Applied Statistics, 26, 118-121.
*
*      Wichura, M.J. (1988).
*      Algorithm AS 241: The Percentage Points of the Normal Distribution.
*      Applied Statistics, 37, 477-484.
*/
static double qnorm(double p, double mu, double sigma)
{
    if (sigma < 0)
        throw new Exception("The standard deviation sigma must be positive");

    if (p <= 0)
        return -double.NegativeInfinity;
    if (p >= 1)
        return double.PositiveInfinity;
    if (sigma == 0)
        return mu;

    double val;

    var q = p - 0.5;

    /*-- use AS 241 --- */
    /* double ppnd16_(double *p, long *ifault)*/
    /*      ALGORITHM AS241  APPL. STATIST. (1988) VOL. 37, NO. 3
            Produces the normal deviate Z corresponding to a given lower
            tail area of P; Z is accurate to about 1 part in 10**16.
    */
    if (Math.Abs(q) <= .425)
    {
        /* 0.075 <= p <= 0.925 */
        double r = .180625 - q * q;
        val =
            q * (((((((r * 2509.0809287301226727 +
                        33430.575583588128105) * r + 67265.770927008700853) * r +
                        45921.953931549871457) * r + 13731.693765509461125) * r +
                    1971.5909503065514427) * r + 133.14166789178437745) * r +
                    3.387132872796366608)
            / (((((((r * 5226.495278852854561 +
                        28729.085735721942674) * r + 39307.89580009271061) * r +
                    21213.794301586595867) * r + 5394.1960214247511077) * r +
                    687.1870074920579083) * r + 42.313330701600911252) * r + 1);
    }
    else
    {
        /* closer than 0.075 from {0,1} boundary */

        /* r = min(p, 1-p) < 0.075 */
        double r;
        if (q > 0)
            r = 1 - p;
        else
            r = p;

        r = Math.Sqrt(-Math.Log(r));
        /* r = sqrt(-log(r))  <==>  min(p, 1-p) = exp( - r^2 ) */

        if (r <= 5)
        {
            /* <==> min(p,1-p) >= exp(-25) ~= 1.3888e-11 */
            r += -1.6;
            val = (((((((r * 7.7454501427834140764e-4 +
                            .0227238449892691845833) * r + .24178072517745061177) *
                            r + 1.27045825245236838258) * r +
                        3.64784832476320460504) * r + 5.7694972214606914055) *
                        r + 4.6303378461565452959) * r +
                    1.42343711074968357734)
                    / (((((((r *
                                    1.05075007164441684324e-9 + 5.475938084995344946e-4) *
                                r + .0151986665636164571966) * r +
                            .14810397642748007459) * r + .68976733498510000455) *
                            r + 1.6763848301838038494) * r +
                        2.05319162663775882187) * r + 1);
        }
        else
        {
            /* very close to  0 or 1 */
            r += -5;
            val = (((((((r * 2.01033439929228813265e-7 +
                            2.71155556874348757815e-5) * r +
                        .0012426609473880784386) * r + .026532189526576123093) *
                            r + .29656057182850489123) * r +
                        1.7848265399172913358) * r + 5.4637849111641143699) *
                        r + 6.6579046435011037772)
                    / (((((((r *
                                    2.04426310338993978564e-15 + 1.4215117583164458887e-7) *
                                r + 1.8463183175100546818e-5) * r +
                            7.868691311456132591e-4) * r + .0148753612908506148525)
                            * r + .13692988092273580531) * r +
                        .59983220655588793769) * r + 1);
        }

        if (q < 0.0)
        {
            val = -val;
        }
    }

    return mu + sigma * val;
}
```

Some further notes:
 * When you google for estimating CIs for the median, the suggesting to use BCa comes up frequently. I'm not convinced that you can recommend it. I'm _far_ (FAR!) from an expert on this topic, but it is hard to ignore that we're using a jackknife to estimate the acceleration parameter, and the jackknife is inaccurate for non-smooth statistics like the median. There is some more discussion around bootstrapping median values [here](https://stats.stackexchange.com/questions/220018/estimating-quantiles-by-bootstrap), but this is not in the context of BCa specifically (and only BCa uses the jackknife)
 * There is a lot of good discussion around bootstrapping available on StackExchange. I think it is worth reading [this](https://stats.stackexchange.com/questions/355781/is-it-true-that-the-percentile-bootstrap-should-never-be-used/357498#357498) and whatever it links to
 * Here is a particularly readable book on bootstrapping that I'd recommend you take a look at if you are planning on using bootstrapping: [Bootstrap Methods: A Guide for Practitioners and Researches](https://www.wiley.com/en-us/Bootstrap+Methods:+A+Guide+for+Practitioners+and+Researchers,+2nd+Edition-p-9780471756217) (Chernick)
 * And finally here is another book full of useful information, though significantly more technical than the other one: [The Jackknife and Bootstrap](https://www.springer.com/gp/book/9780387945156) (Shao, Tu)