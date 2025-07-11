---
layout: post
title: Value Semantics and C# structs
subtitle: To struct or not to struct
excerpt: In which I talk about guidelines on when to use structs vs. classes in C#.
tags: [computer science, programming, c#]
---

If you are familiar with C++, value semantics really *should* be second nature for you (or at least I hope so). If you are however mainly programming in C#, you may never even have thought about value semantics. Which is a pity. In this post, I'd like to first give a brief overview of value semantics and its implementation in C# and then discuss some guidelines that I have on when to use value semantics in C#. If you want to try any of the examples for yourself, you could use [try.dot.net](https://try.dot.net/) (to run them) or [SharpLab](https://sharplab.io/) (to see what it compiles to).

---

* TOC
{:toc}

---

# Value Semantics in a Nutshell
Let's start with a C# example:
```csharp
int x = 5;
int y = x;
x++;
```
What is the value of `y` after the last line? Well, *obviously* it is still `5`, whereas `x` is now 6. This is very different from
```csharp
List<int> x = new List<int> { 1, 2, 3 };
List<int> y = x;
x.Add(4);
```
After the execution of the last line, `y` will *also* evaluate to the list `1, 2, 3, 4`.
In the first example, changing the original variable, `x`, does not change `y`, but in the second it seemingly *does*. This difference is inherently because `int` (as all the other basic types except for `string`) has *value semantics*, whereas almost all other types in C# have *reference semantics*.

Essentially, the only difference is that variables of a value type hold a value by itself, whereas variables of a reference type hold a *reference* to a value that lives somewhere else, independently of any references to it. Thus reference types have a notion of identity beyond equality: Two lists can hold the same values, but still be different. Whether to objects of value type are equal only depends on their values.

In C#, the issue of value semantics for types is deeply confounded with its implementation of these semantics -- it is just very hard to discuss value semantics in the abstract and still get any mileage from the discussion, hence all of the following blurs this distinction between semantics and implementation. For example, the identity of a reference type object is basically its address in memory -- other implementations are conceivable, but I want to talk about C# and its usual implementation specifically.

# The implementation of value semantics
Whenever I try to see what a feature in a language really does, I ask myself how to compile it myself. In fact, I object to the very notion of using features that you could not at least in principle compile manually[^compiling]. Only if you know what is *really* happening will you be able to get a feeling for what implications using a particular feature has, both for performance and the meaning of the code you write. With value semantics, you pretty much *need* this mindset.

Let us take a closer look at what the lines
```csharp
int x = 5;
int y = x;
```
actually mean. Whenever you declare a variable in a C# function (as with `int x;`) you are essentially saying:

> Dear compiler, please reserve enough space to hold an `int` (i.e., a storage location for 4 bytes) right here, local to the current function.[^compiler-request]

This means that when you then write `int y;` you would rightfully expect to get a different 4 byte storage location for an `int`. The line `int y = x;` now says:

> Copy whatever is in the 4 bytes of the storage location denoted by `x` to the storage location denoted by `y`.

In C#, it is not wrong to think of the innocent looking `=` as a copy-instruction. In a picture:

![Assigning ints](/assets/img/2018-03-04-value-semantics/1_copying_ints.jpg){: .center-image}

Similarly then, `x++` simply increases the value stored in `x` by one, which of course does not change `y` in any way. You could do the same thing with, say, `long` instead of `int` and get the same behavior (with the difference that you are now talking about 8 byte storage locations).

How is this different from the second case with Lists? Well, it is not actually all that different! A declaration like `List<int> x;` does not do more than ask the compiler to reserve enough space for a `List<int>` variable locally. The problem with this naive thinking is that for the way C# (and all another languages I am aware of) work, you need to know *exactly* how much local storage will be required by any function *before calling it* -- but a list can grow without bounds[^list], so how could the compiler figure out how much local storage space the function will need?

It is here where references help: The declaration `List<int> x;` does not *actually* reserve local storage for a list, but only for a *reference* to a list. A reference can be thought of as the address of a point in memory where an object lives. This is not quite the full-story for C#, but good enough[^references]. Luckily, such references have a fixed size (usually either 4 or 8 bytes, depending on the machine). So `List<int> x;` does *not* reserve storage space for the value of a list, but for a reference to it: Hence the term *reference semantics*. An assignment such as `List<int> y = x;` then does just the same as `int y = x;` -- it copies the contents of the storage location denoted by `x` to the storage location denoted by `y`. The only difference is that in this case, the content that is being copied is a reference. In a picture:

![Assigning Lists](/assets/img/2018-03-04-value-semantics/2_assigning_lists.jpg){: .center-image}

In short:
 * if a type `T` has *value semantics* then a declaration `T t;` reserves a storage location to store an actual *value* of type `T`,
 * if a type `T` has *reference semantics* then a declaration `T t;` reserves a storage location to store a reference to a value of type `T` that lives somewhere else in memory.

---

## The `ref` keyword in C\#
Now that we have cleared up what value and reference semantics are, we should also briefly talk about the `ref` keyword in C#, especially so because it will get more and more common with the [recent C# 7](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/ref-returns). The notion of reference as embodied by `ref` pretty much exactly what you would expect from C++, in case you are familiar with it.

---

### `ref` parameters
`ref` parameters allow to pass a reference (in the precise sense defined above) to any storage location. For example:
```csharp
void Increment(int y) {
  y++;
}

void IncrementRef(ref int y) {
  y++;
}

void Test() {
  int x = 5;
  Increment(x);
  // x still has value 5
  IncrementRef(ref x);
  // x has value 6 now
}
```
Here, `Increment` receives a copy of the value stored in `x` and increments it (only to discard the copy when it returns). `IncrementRef` on the other hand receives a reference to the storage location `x` from `Test` and can act on it, which means that it can change the value in `x`.

---

### `ref` return values and locals
Since C# 7, `ref` can also be used on return values to return a reference to a storage location. As I have briefly mentioned earlier, local storage locations vanish completely once the function they are local to returns. As such, it does not make sense to return a reference to such a local storage location -- it will be invalid by the time the function returns!

```csharp
ref int GetValue() {
  return 5; // invalid! 5 is a value, not a storage location!
}
```

There are of course plenty of use-cases for `ref`-returns. One that immediately springs to mind is that of looking for a value in an array with the intention of modifying it. Usually, you would return the index of the value in the array to modifiy it. For example, take this piece of code that makes the first odd number in an array even:
```csharp
int IndexOfFirstOdd(int[] values) {
  for (int i = 0; i < values.Length; i++) {
    if (values[i] % 2 == 1) {
      return i;
    }
  }
  return -1;
}

void MakeFirstEven(int[] values) {
  int oddIndex = IndexOfFirstOdd(values);
  if (oddIndex >= 0)
    values[oddIndex] *= 2;
}
```
Instead of returning an index we could also return a reference to the value in the array:
```csharp
ref int IndexOfFirstOdd(int[] values) {
  for (int i = 0; i < values.Length; i++) {
    if (values[i] % 2 == 1) {
      return ref values[i];
    }
  }
  // assuming values.Length >= 1
  return ref values[0];
}

void MakeFirstEven(int[] values) {
  // note the ref on both sides
  ref int oddNumber = ref IndexOfFirstOdd(values);
  if (oddNumber % 2 == 1) {
    // this actually changes the value in the array!
    oddNumber *= 2;
  }
}
```
Admittedly, this quite a contrived example, especially since we don't know whether the array even contains an odd number, forcing us to return a default value if none is found (which then forces us to again check whether the value we get by reference is actually odd). What this example should show is that `oddNumber` in `MakeFirstEven` is a reference to the storage location within the array, or simply an *alias* for it.

In short, the `ref` keyword allows us to create and pass around references to storage locations, such that a value type can be used with limited reference semantics.

---

## Defining Data Types with Value Semantics in C\#
Whereas C++ makes it easy to use every type with both value and reference semantics, C# forces us to make a per-type choice of whether this type should support value semantics. In C#, this distinction is that between using a `class` (reference semantics) or a `struct` (value semantics) -- again in stark contrast to C++, where the only difference between structs and classes is the default access modifier for members.

As an example, take the following data type definitions in C#:
```csharp
public struct ValueTuple {
  public int x;
  public List<int> y;
}

public class Tuple {
  public int x;
  public List<int> y;
}
```
Then:
```csharp
void Test() {
  ValueTuple vt1 = new ValueTuple { x = 1, y = new List<int>() };
  ValueTuple vt2 = vt1;
  vt1.x = 15; // does NOT change vt2.x, it is still 1
  vt1.y.Add(2);
  // does change vt2.y, since vt2.y references the same object as vt1.y

  Tuple t1 = new Tuple { x = 1, y = 2 };
  Tuple t2 = t1;
  t1.x = 15; // does change t2.x, since t2 and t1 reference the same Tuple object
  t1.y.Add(2); // dito
}
```
What this shows is that `ValueTuple` has value semantics[^value-tuples]: When declaring `ValueTuple vt1;`, you reserve a local storage liocation for an `int` and a reference to `List<int>`, since that is what makes a `ValueTuple`. In contrast, `Tuple` has reference semantics and declaring `Tuple t1;` reserves a local storage location for a reference to a `Tuple` that lives somewhere else in memory. Therefore, it makes sense to ask whether `t1 == null`, because the reference could well not be initialized and point to the invalid memory location at `0`. However, it does not make any sense whatsoever to ask whether `vt1 == null`: A `ValueTuple` is a not a reference to a some place storing a an `int` and `List<int>`.

With `ValueTuple vt2 = vt1;`, the entire tuple `vt1` is copied to `vt2`. This means that every member is copied, which implies that `vt1` and `vt2` now both share a reference to a list (the reference was copied but still points to the same place in memory).

---

### `struct`-type member fields
Just as local variables of struct types have value semantics, so have member variables. Take a look at the following:
```csharp
struct S1 { int x; }
struct S2 { S1 t1; int y; }
struct S3 { S2 t2; int z; }
```
In memory, a variable `m` of type `S2` and a variable `n` of type `S3` look like this:

![Struct Memory Layout](/assets/img/2018-03-04-value-semantics/3_struct_memory_layout.jpg){: .center-image}

Note how `n` of type `S3` directly contains a value of type `S2`:

You can convince yourself of the size of the values of these struct types by using `unsafe` in C#:
```csharp
unsafe {
  Console.WriteLine(sizeof(S1)); // 4 bytes
  Console.WriteLine(sizeof(S2)); // 8 bytes
  Console.WriteLine(sizeof(S3)); // 12 bytes
}
```
(This is not possible for class types; `sizeof` only takes structs.) This further reinforces that a struct is nothing more than the sum of its parts.

Compare this to a variable `k` of type `C3`[^memory-layout]:
```
class C1 { int x; }
class C2 { C1 d1; int y; }
class C3 { C2 d2; int z; }
```

![Class Memory Layout](/assets/img/2018-03-04-value-semantics/4_class_memory_layout.jpg){: .center-image}

Classes and structs can of course be mixed freely, as in:
```csharp
class C {
  S2 t;
  int z;
}
```
Which then looks like this when used:

![Struct in Class Memory Layout](/assets/img/2018-03-04-value-semantics/5_struct_in_class_layout.jpg){: .center-image}

---

## Consequences of using value-semantics
In this section, I would like to show that many of the properties and restrictions of structs are just a consequence of the implementation of value semantics in C#.

---

### Corollary 1: No cycles between structs
An immediate consequence of what we have learned above is that the following is illegal[^haskell]:
```csharp
struct S1 { S1 other; int x; }
```
whereas this is perfectly fine:
```csharp
class C1 { C1 other; int x; }
```
What is the first declaration of structs even supposed to mean? What would be the amount of memory you'd need to reserve for a value of type `S1`? Hence:
```
sizeof(S1) = sizeof(int) + sizeof(S1) = 2 * sizeof(int) + sizeof(S1)
```
The only conclusion we can reasonably draw is that `sizeof(S1)` is no finite number, illustrating why this cannot work.

---

### Corollary 2: No inheritance for structs
Consider the following class declarations with inheritance:
```csharp
class C1 {
  int x;
}
class C2 : C1 {
  int y;
}
```
Unsurprisingly, this works:
```csharp
C1 baseTypeVariable = new C2();
```
Because `C1` is a reference type, the compiler can statically deduce the size of the storage location `baseTypeVariable` (it simply has the size of a reference). The reference is then set to point to an instance of `C2`, which is definitely larger than `C1` because it contains an additional field. On the other hand, the following is illegal in C#:
```csharp
struct S1 {
  int x;
}
struct S2 : S1 {
  int y;
}
```
If it were legal C#, then users might expect to be able to write something like:
```csharp
S1 baseTypeVariable = new S2();
```
The mere declaration `S1 baseTypeVariable` asks the compiler to allocate enough space for a value of type `S1` -- and this size is just the size of an `int` by definition of `S1`. Assigning a value of type `S2` to that variable poses a problem, because `S2` values use up more memory. In C++, the moral equivalent of the above actually *does* work and will simply ignore that the value being assigned is of type `S2` and only copy that value's `S1`-part. This is known as the [slicing problem](https://en.wikipedia.org/wiki/Object_slicing) and is prevented by C# simply by disallowing structs to inherit anything.

---

### Corollary 3: Boxing
From the last paragraphs, it is evident that whenever a variable of struct type is declared, its runtime type is completely determined to be that struct type and nothing else. For this reason, it is not necessary to store any additional type information with the value. Contrast this to:
```csharp
string x = "Test";
object y = x; // static type is object, dynamic type string
y.ToString(); // virtual call: should call the method on string, not object.
```
In C# (and .NET more generally), each and every object is derived from `object`. Whenever a virtual function is called on an object, it needs to be able to determine its *actual* dynamic type to be able to call the right method. Hence, values of class types always carry some meta information around that determines their dynamic type and allows to correctly dispatch virtual calls (I glossed over that detail in some of the earlier pictures).

When I said that every object is derived from `object`, I really meant *every*: Even value types.
```csharp
int x = 42;
object y = x; // completely valid
y.ToString(); // virtual call
```
Such an assigment of a value type object to a storage location with reference semantics (phew, what a mouthful!) must therefore somehow conjure up additional runtime type information. The example above is of course simplified and any compiler worth its salt would take note that `y` is statically known to contain an `int` and not bother with a virtual function call. But things get much trickier when calling a function with an `object` parameter by passing an `int` value. That function could do literally *anything*, so including the aforementioned meta data is mandatory.

This problem is solved through *boxing*: A *box* is allocated somewhere (usually in long-lived memory[^heap]), and the sole purpose of the box is to store the value and its meta data so it can be accessed by a reference. Whenever `T` is a reference type or interface and `y`'s type has value semantics, each assignment of the form `T x = y;` should be expected to cause boxing.

![Boxing](/assets/img/2018-03-04-value-semantics/6_boxing.jpg){: .center-image}

This example should make this clear:
```csharp
int x = 42;
object a = x;
object b = x;
a == b; // this evaluates to false, because a and b reference different boxes
a.Equals(b); // this evaluates to true, because both boxes hold the value 42
```
Note at this point that the value of `x` is *copied* to the box, because `int` has value semantics:
```csharp
int x = 42;
object a = x;
x++;
a.Equals(x); // this evaluates to false, since x is 43, but x contains 42.
```
I should point out that in this last example, there are two instances of boxing occuring: First for the line `object a = x`, then again for `a.Equals(x)`, because `Equals` takes an argument of type `object`.

---

### Corollary 4: No default constructors
When you declare a variable in C#, you get the guarantee by the language that this memory does not contain random garbage but is set to zero. For example, the default value for an `int` is `0`, because that's what you get when you zero out all its bits. Usually, the compiler will stop you from accessing any variables that have not been explicitly initialized and only hold their default value:
```csharp
int x;
x++; // error! Trying to access uninitialized variable x!
```
But in one case you routinely access such default-initialized values: Arrays and fields of objects. For example:
```csharp
int[] x = new int[1];
x[0]++; // perfectly fine!
```
Zeroing out the memory of an array is comparatively cheap because setting large contiguous regions of memory to a value usually enjoys hardware support. The same zeroing out happens when allocating an array of classes, because each entry in the array will actually be a reference and can be set to null. An array of values of struct types however contains the actual values directly in the array itself. As an example, consider the following struct:
```csharp
struct Vector2 {
  float x;
  float y;
}
```
In memory, this will look something like this (`object[]` on the left, `Vector2[]` on the right):

![Boxing](/assets/img/2018-03-04-value-semantics/7_arrays.jpg){: .center-image}

This shows why there can be no default constructor: The runtime does not want to initialize each value of the array. Setting the whole memory of the array to zero sets the bits of the structs to zero; this *is* the initialization you get. If you were allowed to define a default constructor that does something else, it would be forced to run for each value of the array.

---

## Common gotchas with structs
There are a few things that you should look out for when using structs because they might at first seem very weird. Here is a list of my favorites:

---

### Arrays vs. lists of structs
Arrays of structs and lists of structs are superficially very similar, but have one striking difference: Whether you access the elements by reference or by value. As an example, consider this:

```csharp
var arr = new Vector2[1];
arr[0].x = 1f;
// arr[0] is Vector2 { x = 1, y = 0 }

var list = new List<Vector2>();
list.Add(new Vector2());
list[0].x = 1f; // error! Cannot modify return value.
```

The array access `arr[0]` allows us to modify the value in the array. Morally, we can think of the `this[int]` accessor to be declared as:
```csharp
ref Vector2 this[int index] { get; set; }
```
This is not quite how array accessor are defined, because arrays are hardwired into the runtime and C# versions before 7.2 did not have `ref` returns, but it would have the same semantics. Lists on the other hand have an accessor defined like this:
```csharp
Vector2 this[int index] { get; set; }
```
It always returns a *copy* of the value at the index and that copy is temporary until we copy it (again) into a variable. Hence any modifications to this temporary object will just be discarded anyway, so the language makes them invalid.

---

### Beware of non-obvious boxing
While we are talking about lists, it is worth pointing out that the standard C# collections often lead to excessive boxing when used without care. Generally, you will want to avoid boxing because it can be quite expensive (it allocates new objects in long lived memory, that is bad enough already). As an example, consider the cost of a call such as 
```csharp
bool IsInList(List<Vector2> list, Vector2 v) {
  return list.Contains(v);
}
```
With our naive implementation of `Vector2`, this will yield \\(O(n)\\) boxing operations. This is because `Contains` will call `bool Equals(object)` for every element of the list to check whether it is equal to the target value. Getting from `Vector2` to the `object` required by `bool Equals(object)` causes the boxing. You can avoid most of the boxing by making your struct implement `IEquatable<T>`, but that of course only works if you have access to the struct's source code. Otherwise, you might want to read this [excellent article by Jackson Dunstan](https://jacksondunstan.com/articles/3899) on using code generation to deal with such cases.
Note that the boxing here does *not* occur because `List<T>` is a generic type and somehow causes boxing per se, quite the opposite: Generics are specifically designed to *avoid* boxing; this is about using generics carelessly.

My general message here is not only to remember to implement `IEquatable<T>` where necessary, but to watch out for where and how boxing might occur en masse.

---

### Methods on structs and `readonly`
Unless explicitly specified as `ref`, structs are passed to functions by value -- i.e., as a copy. This is the whole point of value semantics after all! Yet in one instance, this is not quite true: Methods on structs. Consider this:
```csharp
struct Counter {
  private int _value;
  public void Increase() { this._value++; }
  public int GetValue() { return _value; }
}
```
Besides the fact that it is not quite idiomatic to not use a property for `_value`, this should be an easy struct to understand. Using it like this yields the expected results:
```csharp
var ctr = new Counter();
ctr.Increase();
ctr.Increase();
ctr.GetValue(); // evaluates to 2
```
What this shows is that the `this` parameter of a method is passed to the method by reference, *even for structs*. This is definitely what you want, trust me. 
In some cases, however, this leads to unexpected consequences: Enter `readonly`. In C#, a `readonly` field means that the storage location that this field denotes *cannot* change (except when it is dealllocated). For reference types, the storage location will merely hold a reference and so you cannot change the reference, but the value that is referenced can still be modified. For value types on the other hand, the storage location holds *the whole value*, so you cannot change *anything* about this value. Example:

```csharp
class C { public int X; }
struct S { public int X; }

class Example {
  readonly C c;
  readonly S s;

  public Example() {
    s = new S();
    c = new C();
  }

  public void DoThings() {
    c.X++; // valid
    c = new C(); // error! cannot change readonly field
    s.X++; // error! cannot change readonly field
    s = new S(); // error! cannot change readonly field
  }
}
```

So what about methods on structs? Adding a method to the example struct above and calling it has unintuitive consequences:
```csharp
struct S {
  public int X;
  public void Increase() { X++; }
}

class Example {
  readonly S s;
  public Example() { s = new S(); }
  public void DoThings() {
    s.Increase(); // increase X by one
    Debug.Assert(s.X == 0); // huh!? s.X is in fact 0.
  }
}
```
Yes, this is really what happens. The compiler does everything it can to prevent you from modifying a `readonly` field. In this case, it even decides to create a copy of `s` before calling `Increase`. This is *not* because the compiler figured out that `Increase` modifies `s`, but because it does not try to figure that out and just flatout assumes that every such call will modify the struct. In other words: For structs in `readonly` storage locations, `this` is effectively passed by value.

C# 7.2 added the `in` parameter modifier which may be thought of as `readonly ref`[^readonly-ref] that leads to the same behavior. Interestingly, C# adds the possibility to declare a whole struct as `readonly` by using `readonly struct S { ... }` which will prevent these copies; this is again moving a site-by-site decision as in C++ to a type-by-type decision in C#, although they seem to be keeping [a door open](https://github.com/dotnet/csharplang/blob/master/meetings/2017/LDM-2017-02-22.md#readonly-struct-types) to change that.

---

# Advice on using structs
Values vs. references has a long history of debates around it, most of them in the C++ community (just google `c++ by value vs. by reference`) where the choice comes up basically anytime you want to pass a variable to a function or create an object. In C#, this choice has to be made per type (with the option to locally switch from value semantics to reference semantics by using `ref` in some special cases), which is why you should be much more considerate about it. Here are some thoughts about when to use structs instead of classes and when not to (take them with a pinch of salt):

---

## Structs should be small
When you make something a struct, you can be certain that it will be copied around a lot. If you make your struct larger than a few words, then you will likely suffer a performance hit if you do not pass it around by reference. For a detailed benchmark, see [Adam Sitnik's post over here](http://adamsitnik.com/ref-returns-and-ref-locals/). Note how his post looks at structs that have the size of 5 `int`s and finds quite a large difference between passing by value (copying) and by reference (no copying). (The usual disclaimer about microbenchmakers and premature optimization apply.)

---

## Avoid mixing references and values in a struct
You should probably not use a struct if your struct would contain both value and reference type members. For example, imagine that I want to write a Stack with fixed capacity as a value type. The main part of the definition could look something like this:
```csharp
struct FixedStack<T> {
  private T[] _entries;
  public int Capacity { get { return _entries.Length; } }
  public int Size { get; private set; }

  public FixedStack(int capacity) {
    _entries = new T[capacity];
    Size = 0;
  }

  public bool Push(in T value) {
    if (Size < Capacity) {
      _entries[Size++] = value;
      return true;
    }
    return false;
  }

  public void Pop() { Size = Size == 0 ? 0 : Size - 1; }
  public ref readonly T Top() { return ref _entries[Size - 1]; }
}
```
It sure is small: It only takes a reference to an array and an `int` to store its current size. There is another problem here, namely that a copy of a `FixedStack` is not a deep copy, but shallow, leading to absolutely unintuitive behavior:
```csharp
var s = new FixedStack<int>(5);
s.Push(1);
// s.Size == 1

var s2 = s;
s2.Push(0);
// s2.Size == 2, but s.Size == 1
s.Push(2);
// s2.Top() == 2
```
Languages such as C++ allow the user to customize how copying is performed, such that you can *always* make a deep copy, but this comes with lots of problems of its own and inevitably leads to move semantics (which I fear even less people understand properly, although it is really not all that difficult). C# does not, so you have to design around it.

There are of course examples where mixing value and reference types in a struct is OK, for example when your struct is readonly and does not allow to modify the referenced object[^golang]. An obvious example would be a struct like `ReadonlySpan` that describes a slice of memory that can only be read, but not written to.

##### Another example
As a side note, this point is the reason why I felt the need to write this post. A colleague suggested to define the following struct:
```csharp
struct EntryCollection {
  public Dictionary<int, string> Values;
  public Action<int, string> ValueAdded;
}
```
I objected to this definition for two reasons: First, this violates the principle of not mixing values and references. Second and more importantly, this is not all that obvious in this case. While it is intuitive that function pointers by their very nature have value semantics, C#'s delegates are not function pointers. A delegate can represent *multiple* functions; this is known as a *multicast delegate*. It is backed by an invocation list that contains the functions to be called. I guess that most people who hear "list" and would infer "reference type". But no, `Action<int, string>` has value semantics. If you do not have this on your mind all the time, you will use this struct incorrectly and probably spend the better part of a day debugging why your callbacks are not called every time you add a value to the dictionary.

In my colleagues defense, this struct was a private nested struct (and has since been changed to a class, which was then changed to be public).

---

## Consider structs for cache-friendly arrays
Among the top reasons why you would use an array is because you determined that using a class is not fast enough. As we have seen before, an array of struct values really holds all of the structs, not just references to them. This makes traversals of these arrays much faster, because you do not need to dereference the references (which will most likely cause a cache miss) to get to the actual values. To get the full story, [click here](https://jacksondunstan.com/articles/3860) and let Jackson Dunstan explain it to you.

---

## Consider structs to avoid allocations for short-lived objects
Creating an object of a class-type causes an allocation somewhere in long-lived memory. The object thus created will have to be tracked by the garbage collector so it can destroy when it has become inaccessible, i.e. there are no accessible references to it left. All of this has a certain cost at runtime that you can avoid by using structs instead: They will usually be allocated in function-local short-lived memory (when used as a local variable inside a regular function at least) and automatically vanish once the function returns, making them much cheaper. Again, Adam Sitnik has a nice [write-up](http://adamsitnik.com/Value-Types-vs-Reference-Types/#gc-impact) with benchmarks.

To seriously benefit from this you of course then need to keep track of all kinds of boxing that may occur.

---

## Have a good reason to use a struct
When you are using a struct instead of a class, ask yourself why you are doing it. Just saying "this is a small class, so I should make it a struct" is probably not good enough a reason. There are certainly cases where the only natural choice will be a struct: If `int` did not have value semantics, we'd all be scratching our heads. I do not want to discourage anyone from using structs (I love value semantics!), but *please know what you are getting everyone into* and remember that there is probably at least one person on your team that does not fully understand value semantics.


---
---
---

[^compiling]: I am not saying that you need to be able to produce completely correct x86 assembly language and implement the feature in the most efficient way possible, but you should know how to break that feature down into the basic operations your computer is capable of. [There can be no magic left.]({% post_url 2017-11-29-no-magic %}).

[^compiler-request]: Whether the compiler will actually follow your request is an entirely different story. I am also lying a little bit about local storage here, because using a local variable in a closure or as part of an iterator block will change everything. Technically, value semantics is also completely decoupled from any of its implementations and how that implementation uses memory, so I am confounding to issues here. In practice, value semantics is usually understood to have an implementation that is the same as the one I am talking about here, at least in spirit.

[^list]: This is a blatant lie. The instance of the list has a fixed size and references a growing memory buffer, but the general problem remains.

[^references]: C# should not really be thought of as pointers, because the thing they are referencing could change its location due to the garbage collector moving stuff around. Furthermore, references are not quite as they are in C++: C# references are something of a middle-ground between C++'s references and pointers: They are nullable and reassignable, but have no support for pointer arithmetic. See this [interesting write-up by Vladimir Sadov](http://mustoverride.com/managed-refs-CLR/).

[^value-tuples]: You do not need to introduce a type for value tuples anymore, because [C# 7 already ships with those](https://blogs.msdn.microsoft.com/mazhou/2017/05/26/c-7-series-part-1-value-tuples/).

[^memory-layout]: This is true only morally. While structs really consist just of their fields and nothing more, classes have a bit of meta-data attached to them such that you can recover the dynamic type of a variable and do locking etc. There is an [awesome blogpost by Adam Sitnik](http://adamsitnik.com/Value-Types-vs-Reference-Types/) that goes into more detail about this and should definitely be read by everyone.

[^haskell]: In other languages with value semantics this might still be possible (Haskell, for example, will happily accept this definition). This is therefore a consequence of C#'s implementation of value semantics, not value semantics itself.

{% capture comment %}
[^aliasing]: I can give you an argument for why C++ does not allow values that take up zero bytes, and I am pretty sure that this is also the reason why C# disallows it: Basically, it all comes down to *aliasing*. Two pointers `p, q` are aliasing each other if they point to the same memory location. The canonical example is the following:
    ```cpp
    int Tinker(int* p, int* q) {
      *p = 1;
      *q = 0;
      return *p; // could return either 0 or 1.
    }
    ```
    Naively, you would expect the compiler to simply substitute `return 1` for `return *p`, because that is what was just assigned to `*p`, right? But the compiler is smarter than that, because `p, q` could refer to the *same* memory location -- they are aliasing each other. The aliasing assumption that C++ does allow compilers to make is that two pointers cannot alias each other if they have different types. Hence, `float* p` and `int* q` cannot point to the same memory location and if they do (because of an `reinterpret_cast` for example), you end up with undefined behaviour. This only works because no data type can have size 0. Assume `T` has size 0, then if an `int` is located right after a value of type `T`, then they would share an address.

    Note that this assumption of non-zero sizes is not universally true. Go for example allows values of size zero:
    ```golang
    package main

    import "unsafe"

    type T struct {}
    func main() {
      s := unsafe.Sizeof(T{}) // this evaluates to 0!
      fmt.Println(s)
    }
    ```
{% endcapture %}

[^heap]: I am doing my best to avoid the words heap and stack, because I don't want [Eric Lippert to come around and slap me](https://blogs.msdn.microsoft.com/ericlippert/2009/04/27/the-stack-is-an-implementation-detail-part-one/) ;) But quite frankly, C# 7.2 will make the `stackalloc` keyword much more common in code bases and you shouldn't feel dirty for talking about stack vs. heap. It may still be an implementation detail, but I believe that we should stop pretending that we don't care about the implementation.

[^readonly-ref]: Marking a field `readonly` means two things: You cannot change it and nobody else can. This is a very strong guarantee. Marking a parameter as `in` gives you something weaker: It only means that you cannot change it, but someone else still might. In fact, consider the following example (which made me feel smart until I noticed it is right in the [feature proposal](https://github.com/dotnet/csharplang/blob/master/proposals/csharp-7.2/readonly-ref.md#aliasing-behavior-in-general)):
    ```csharp
    class Example {
      private int x;
      private int y;
      private int z;

      public void Unintuitive(in int w) {
        y = w;
        x++; // if called as below, this line changes w
        z = w;
      }

      public void Do() {
        x = y = z = 0;
        Unintuitive(in x);
      }
    }
    ```
    It therefore first seemed to me that `in` was specifically *not* named `readonly ref`, since the meaning of `readonly` here differs from its meaning on fields. Alas, this is probably not the case because C# has `ref readonly` return values that allow the same aliasing problems. In the end, `in` was chosen for its brevity, according to this [language design meeting protocol](https://github.com/dotnet/csharplang/blob/master/meetings/2017/LDM-2017-02-22.md#in-parameters).

[^golang]: This is one of my main gripes with Go: The inbuilt slices are just such structs with both reference and value members. [See my post here.]({% post_url 2018-02-17-a-week-with-go %})) There is nothing wrong with slices per se: They are great for representing a read-only view on a list or string, but Go does not know anything about read-only/const references.