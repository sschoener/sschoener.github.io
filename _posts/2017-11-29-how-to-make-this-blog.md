---
layout: post
title: How this blog was setup
tags: [quine]
---

Dear future me,

a time will (inevitably) come when you will wonder how all of this was setup. This is a gentle reminder for you:

1. Due to your current situation, you probably have to administer your blog from a Windows system. Yes, you could make use of dual boot, but we both know that you never get around to posting if you have to reboot for that. Luckily, Windows 10 allows you to run a *real bash* with all the bells and whistles you are used to from your beloved Linux machine (though I am not sure whether you can change to *fish* as a shell). It's not that difficult to setup:
    1. First off, [visit this website](https://msdn.microsoft.com/en-us/commandline/wsl/install-win10) to learn how to setup the Linux subsystem.
    2. Get yourself a proper terminal like [ConEmu](https://conemu.github.io/). You will like this one, since it offers a *guake*-like dropdown terminal. It's not quite as responsive as native guake and has a few weird hotkeys (*Win+Shift+Q* to switch tabs, *Win+W* to create new tabs -- you can change these, but probably won't because you might break some other shortcuts). You can open it using *Ctrl+`*. In the settings, make sure that you activate autostart and check out [this](https://conemu.github.io/en/BashOnWindows.html#wsl-home) to set the proper starting directory for the shell.

2. With that done, on to the actual website. This one is setup using [Jekyll](https://jekyllrb.com/). Naturally, you'll have to install that:
```
gem install jekyll
gem install bundler -v 1.16.1
```
 
3. Once this is done, download [Beautiful Jekyll](https://deanattali.com/beautiful-jekyll/) and install it. It is straightforward to setup. Don't forget to run `bundle` in the folder that you have downloaded. If you have trouble running `jekyll serve`, try `bundle exec jekyll serve`.

4. Make sure to delete the annoying 404 image from the default design, configure everything in `_config.yml`, and don't forget to also take a look at the `.html` files, since last time it took you ages to figure that out.

5. In case you still like to dabble in math (if you don't anymore, then SHAME ON YOU, WHAT HAVE YOU BECOME!?), you will want to install MathJax. This requires nothing more than adding
```html
<script type="text/javascript"
    src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
</script>
```
to the header in your base layout. Note that you can now write equations as
`\\( a^2 + b\_2 + 4\\)` if they are inline (note the escaping of special characters such as the underscore) or `\\[ a^2 + b^2 = c^2 \\]` for line equations. To get proper support for `$`, check the [configuration options](http://docs.mathjax.org/en/latest/configuration.html#using-in-line-configuration-options).

6. Setting up disqus (if that's still around and you decided that it wasn't just a stupid idea to put it on the website) is a breeze and fully covered in the ReadMe. Just thought I'd point it out, because you apparently didn't fully read it the first time around.