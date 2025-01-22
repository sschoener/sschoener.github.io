---
layout: post
title: Unity Async On-Demand Imports
excerpt:
tags: [Unity]
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener) and [Bluesky](https://bsky.app/profile/sschoener.bsky.social)!_

For a while now, Unity has had a neat little feature: async, on-demand imports. It's not widely used or implemented, but it exists. This blog post is going to point you in the general direction of how to implement such an importer. TL;DR: [example is on Github](https://github.com/sschoener/unity-async-scripted-importer/).

First, some terminology and concepts: By default, Unity watches all changes in your project. If there are any changes detected, it triggers a "refresh" and subsequentely imports the new assets into the project. This process is automatic and blocking. You can disable automatic refreshes, but at some point you will want to trigger a refresh to make your changes available. Unity generally "knows" how to import files: FBX files go into the FBX importer, PNG files go into the texture importer etc.. This means that any asset in your project will naturally map to the output of some import process that happened automatically. The output is called an "artifact", and the artifact produced by this automatic process is the asset's "primary artifact."

You can write your own importers by deriving from `ScriptedImporter` and using some attribute:
```csharp
[ScriptedImporter(15, "html", AllowCaching = true)]
public class MyHtmlImporter : ScriptedImporter
{ ... }
```
The attribute tells the asset pipeline what file type to apply this to (`html` files, in this case) and what version this importer is (15). We already know why we need the extension: That's how Unity knows when to use this importer to produce primary artifacts.

The version brings us to arguably the most important concept in asset importing, and that's _dependencies_: How does the asset import pipeline know when to reimport an asset? Let's call the file you put into your Unity project (the FBX or PNG file) the _source_. Clearly, we need to reimport an asset if its source changes. What else? If your HTML importer looks at the content of the HTML, figures out what javascript file goes along with it, and opens that, then you also depend on the javascript file! So you have to declare that dependency. Similarly, you may decide to look at the result of another import ("My importer looks at the mipmaps of this texture my asset references"), in which case you don't depend on that texture's source, but on that texture's artifact (and you inherited all of its dependencies, congratulations! -- This quickly gets out of hand if not handled with care).

All of this is to say that the code of your importer is a dependency of all the artifacts produced by running it. The version numer is used to track this. If you make any changes to the importer, you need to bump the version number, so the asset pipeline knows to reimport your assets.

For a while now (since Unity 2019.4, I think?), Unity has supported using importers to produce non-primary artifacts from assets on demand. For this to work, you need to explicitly ask Unity to import a specific asset using a specific importer. This mechanism has been used by DOTS for years now and is the backbone of the scene baking process, which takes a Unity asset (a scene file), looks at its import artifact (the Unity objects in the scene), and then produces flat binary data from it. DOTS has used this mechanism to continue using Unity's authoring framework (GameObjects, scenes) but also produce unmanaged Entity data for the runtime.

Async on-demand imports happen in the background in a separate process. Unity boots up one or more "asset import workers", and you can configure some specifics about this in the Project Settings (Editor tab, look for the "Asset Pipeline" section). This also means that your importer code does not run in the main process. This is important if you want to debug it: you need to explicitly attach to one of the import workers (the right one, preferably). This is easier when you reduce the number of import workers to 1 in the settings. Logs from your importer also go into a separate log, because it's a separate process. You can find the logs in your project's `Logs` directory: look for the `AssetImportWorker-X.log` files.

Here is roughly what you need to do:
 * Declare a new scripted importer and set its target extension in the `ScriptedImporter` attribute to something that will never be hit. Unity uses `extDontMatter`.
 * Use the `AssetDatabaseExperimental.ProduceArtifactsAsync` API with some assets and the type of your importer to kick off the import. Yes, it's called experimental. No, it hasn't changed in years, and no, Unity can't take it away without completely breaking DOTS.
 * Use the `AssetDatabaseExperimental.GetOnDemandArtifactProgress` API to check on the progress of your imports.
 * Use the `AssetDatabaseExperimental.GetArtifactPaths` API to get the paths to your imported artifacts.

I know all of this is very abstract, and I don't think it's sufficient to write a description. So I have created a working, minimal example and [put it on GitHub](https://github.com/sschoener/unity-async-scripted-importer/blob/b1955f694097c4bd2a886b3c6310ca6295e01a48/Assets/Editor/ImportTrigger.cs). This sample project uses a scriptable importer to convert scriptable objects to JSON in an importer. You would run this importer whenever you need the JSON and can wait for the result asynchronously (that's in the editor), and in your build script. You can then query the paths to actually get the resulting JSON and include it in your build or load it. In a real world scenario, you would probably go for a binary format, but the idea is the same.

Please read the code carefully. I have commented it extensively and included the edge cases I am aware of.

Here are some random bits that I have found useful:
 * There are two versions in the asset database that you can use to broadly check whether some import was done. See [GlobalArtifactProcessedVersion](https://docs.unity3d.com/ScriptReference/AssetDatabase.GlobalArtifactProcessedVersion.html) and [GlobalArtifactDependencyVersion](https://docs.unity3d.com/ScriptReference/AssetDatabase.GlobalArtifactDependencyVersion.html).
 * You can register custom dependencies. This essentially allows you to associate a hash with a name and whenever that hash changes, anything that depends on the name needs to be reimported. That's [AssetDatabase.RegisterCustomDependency](https://docs.unity3d.com/ScriptReference/AssetDatabase.RegisterCustomDependency.html).