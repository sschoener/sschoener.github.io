---
layout: post
title: How to connect a Roland FP30 piano to a phone via midi bluetooth
excerpt: 
tags: []
---

I recently tried to connect a Roland FP30X piano to my Android phone via bluetooth to use it as a Midi input device. All guides I have found online either suppose that you only want to connect the piano's speakers to your phone, or only want to use the official Roland piano app. I however just want to use the piano as a midi input device on my phone (e.g. to use it in the browser) and just activating bluetooth did not work.

When you try to connect your phone via regular bluetooth to your piano, you will only be able to use the piano's speakers. The problem is that "midi via bluetooth" is apparently a completely different protocol from just "bluetooth." You need a custom built app that can handle midi via bluetooth. I have tried various and found that [MIDI BLE Connect](https://play.google.com/store/apps/details?id=com.mobileer.example.midibtlepairing) works best on Android. Once you have installed it and enabled bluetooth, you should see the piano as "FP30 Midi" in the app. Tap it to connect, now the piano is available as a bluetooth device on your phone. Your browser should detect it automatically from here on.
