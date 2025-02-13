---
layout: post
title: Asynchronous programming in C# and the Task monad
excerpt: In which I show a few methods that really should be in the standard library
tags: [computer science, programming, c#]
---

Asynchronous programming in C# is truly awesome. I'm not going to give a full introduction into the topic, but here is the general gist: Suppose you have a operation that is expensive, not because it is CPU-heavy, but because it involves a lot of waiting. Typical examples of this are sending web requests or doing disk I/O. You *could* have a thread just wait for a hardware controller to come back with it with some results (the thread is *blocked*, the operation is *blocking*), or that thread could do something useful while it is waiting. C# gives you the option to do the latter very easily. Before `async/await` you had to juggle callbacks and use `BeginAsync/EndAsync` in cumbersome ways.

# Async/Await in C#
Here is an example of that: Opening a file and reading it in full. This is not real C# code, though it is syntactically valid; the API just looks different in practice. In a real-world scenario, you most likely *do not* want to read the file all at once, but let's roll with it for the sake of this example:

```csharp
// Task<string> is a future/promise to provide a string as soon as the operation is finished.
// async means that this function can use await
async Task<string> ReadFileAsync(string path) {

    // OpenFileAsync returns Task<File>
    File f = await OpenFileAsync(path);

    // ReadAsync returns Task<string>
    string contents = await f.ReadAsync();

    // Close returns Task
    await f.Close();

    // because this is an async function, we can return a string instead of a Task<string>
    return contents;
}
```

As you can see, `await` is used to transform a promise `Task<string>` to a manifest `string`. Under the hood, this means that whenever the execution hits on an `await`, it pauses the execution of the function and returns to the caller. Once the async operation is done, some thread will continue right after the `await`. If you are used to iterator-functions in C#, this shouldn't be hard to understand. There are plenty of questions that should immediately come to mind when you read this for the first time: Which thread is continuing the execution? What about exceptions in the asynchronous operations? How is this implemented by the compiler?
We might look into that some other day, because it is all worth learning about if you are using `async`. How else are you going to understand the costs of using it?

## Tasks and `async`
I only want to make two small points right now: First, `async` is not part of the function's type signature. It just allows you to use `await` in the function and instructs the compiler to transform the function into a fancy state machine. Second, and more importantly, you are not waiting for an asynchronous function but for a `Task` (or some other awaitable object in general). The `Task` represents the operation and *this* is what you are `await`ing. You can also return a `Task` from a non-`async` method by just constructing the `Task` and returning it. For example:

```csharp
interface IStringer {
    Task<string> GetString();
}

class Stringer1 : IStringer {
    public Task<string> GetString() {
        // Creates a Task that is not asynchronous at all! It already contains the computed value.
        // Awaiting this task will happen synchronously and not suspend the execution of the
        // awaiting method.
        return Task.FromResult("my string");
    }
}

class Stringer2 : IStringer {
    public Task<string> GetString() {
        // ReadFileAsync is async and returns a Task<string>, but this method is *not* async. It just
        // returns an async operation you can wait on.
        return ReadFileAsync("/path/to/file");
    }
}
```

# Task Monad
When I see the type `Task<T>`, I think monad. Indeed, it is straight-forward to build the corresponding methods: `return` is simply `Task.FromResult` and `bind` comes down to this:

```csharp
public static async Task<T> Bind<R, T>(this Task<R> task, System.Func<R, Task<T>> f) {
    var r = await task;
    return await f(r);
}
```

For completeness, here is the corresponding `Map` implementation:
```csharp
public static Task<T> Map<R, T>(this Task<R> task, System.Func<R, T> f) {
    return task.ContinueWith(r => f(task.Result));
}
```

Of course, the implementation for these methods is pretty straight forward, but I find them very helpful and cannot understand why they are not part of the standard library. In fact, I have a whole bunch of overloads for `Bind` that make working with `Task`s somewhat easier:

```csharp
public static class TaskHelper {
        public static Task<T> Map<R, T>(this Task<R> task, System.Func<R, T> f) {
            return task.ContinueWith(r => f(task.Result));
        }

        public static async Task<T> Bind<R, T>(this Task<R> task, System.Func<R, Task<T>> f) {
            var r = await task;
            return await f(r);
        }

        public static async Task Bind<R>(this Task<R> task, System.Func<R, Task> f) {
            var r = await task;
            await f(r);
            return;
        }

        public static async Task<T> Bind<T>(this Task task, System.Func<Task<T>> f) {
            await task;
            return await f();
        }

        public static async Task Bind(this Task task, System.Func<Task> f) {
            await task;
            await f();
            return;
        }
    }
```