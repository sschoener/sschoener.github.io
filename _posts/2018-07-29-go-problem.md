---
layout: post
title: The Problem With Go
excerpt: In which I complain about missing generics and templates
tags: [computer science, programming, golang]
---

I have written about the Go programming language [before]({% post_url 2018-02-17-a-week-with-go %}). There, I made clear that I (among other things) disagree with Go's choice to not include a templating mechanism or generic types.

Now, a few months later, I still stand by that but want to provide some evidence as to why I don't like the choice. What follows is a part of a function from a Go code base that I am contributing to. Rest assured that once I saw this monstrosity I made room in my schedule to simplify it and clean it up (in fact, what you see below has been simplified a bit for this post).

```golang
// search the AI-inventory for the object representing the product
invSlotLoop:
for _, invSlot := range aiInv.Slots {
    if invSlot.IsObject() {
        objectID := invSlot.ObjectID()
        // is it the right product?
        product, isProduct := aiHan.pool.Product.TryGet(objectID)
        if isProduct && product.BlueprintID == job.BlueprintID {
            // are all the slots that the current job should install done?
            for _, jobSlotIndex := range job.BlueprintSlotIndices {
                if !product.IsSlotInstalled(jobSlotIndex) {
                    continue invSlotLoop
                }
            }
            // all slots done! this is our product!
            // get it to one of the output inventories.
            productStorable := aiHan.pool.Storable.Get(objectID)

        outInvLoop:
            for _, outInvEnt := range workplace.OutputInventories {
                outInv := aiHan.pool.Inventory.Get(outInvEnt)
                for _, outInvSlot := range outInv.Slots {
                    if outInvSlot.IsEmpty() && outInvSlot.IsCompatible(objectID, productStorable) {
                        // we have found an inventory where we can put it! walk to the inventory!
                        hasToWalk, err := aiHan.walkToEntity(aiEnt, outInvEnt)
                        if err != nil {
                            // nah, we can't walk to it. have to find another inventory
                            continue outInvLoop
                        }
                        if hasToWalk {
                            // walking is triggered, wait until he gets there
                            return
                        }
                        // transfer the object
                        aiHan.invTransferMan.Transfer(aiEnt, outInvEnt, nil, objectID)
                    }
                }
            }
        }
    }
}
```
The code above should of course be simplified by introducing a few functions that break the nesting and make it easier to follow the flow; there also is some error handling that I do not agree with. 

I count a full 7 (!) levels of nesting, including 2 loops with labels and label-targeted `continue`s. Of course, Go does not force you to write your code like this, but it definitely makes it easier and much more attractive for people to do it.

Notice how the first `continue` targeting the outer most loop is essentially checking whether some predicate ( = `!product.IsSlotInstalled`) is true for any item in a slice. In another language, we might write something like this:
```golang
if job.BlueprintSlotIndices.Any(x => !product.IsSlotInstalled(x)) {
    continue
}
```
In Go, we would have to define `Any` for each type separately, with its own name like `AnyUInt32`. Well, it turns out that people don't really do that. They write out the loop each and every time, because - well - it's *only* five lines. The piece of code above shows pretty clearly where this is heading.

Functions serve multiple purposes: Firstly, they should encapsulate commonly used code so that you only have to debug it once etc. Secondly, and more importantly, they should abstract away details. While the details of a simple `for`-loop should be quite familiar to anyone, there is no arguing that within a function such as the one above a call like `xs.Contains(...)` would be *much* easier to parse[^shorter] than the equivalent 5-line loop, because there are already so many things going on.

By now, I treat each labeled loop in Go as a pretty serious problem. Heck, even just nested loops are suspicious.

Oh, and this is my version of the function from above (with some additional functionality):
```golang
productEntity, ok := getCompatibleFinishedProductInInventory(job, aiInv)
if !ok {
    aiHan.tryTakeProduct(aiEnt, job, job.Crafter, true /* take only finished products */)
    return
}

result := aiHan.tryStoreObject(aiEnt, productEntity, workplace.OutputInventories)
if result == AIInventoryTransferResultNoSuitableInventory {
    aiHan.setNoSpaceFailState(aiEnt, nil)
    aiHan.blockWorker(aiEnt)
} else if result == AIInventoryTransferResultNoPath {
    aiHan.setNoPathFailState(aiEnt, ecs.InvalidEntityID)
    aiHan.blockWorker(aiEnt)
}
```

---
---
---

[^shorter]: Also, it would be shorter. I am not convinced that brevity is always a virtue in programming, but some people like Cliff Click argue that the number of bugs created by a programmer is mostly proportional to the lines of code written, not the number of features implemented.