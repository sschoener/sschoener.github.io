---
layout: post
title: TensorFlow - Multi GPU Computation
excerpt: In which I explain how to use multiple GPUs across multiple computers to train deep neural networks.
tags: [computer science, deep learning, python, tensorflow]
image: /img/2017-12-12-tensorflow-intro/tf_logo.png
---

This is the second part of a tutorial on TensorFlow ([first post]({% post_url 2017-12-12-tensorflow-intro %})).
It is an introduction to multi GPU computation in TensorFlow written for some colleagues in November 2017. The version of TensorFlow that this tutorial is targeting is v1.3. Making multi GPU training of models easier is, as I understand, one of the priorities of the TensorFlow development team. As such, I won't be surprised if some of the methods in this document are soon superseded by cleaner, easier approaches. Also note that this document assumes that you want detailed control over the training process. If that is not the case, you may want to take a look at the [estimator API](https://www.tensorflow.org/api_docs/python/tf/estimator/train_and_evaluate) that makes it very easy to train a single model across multiple machines.
The tutorial is actually an interactive Jupyter notebook. [You can download it here.](http://www.s-schoener.com/files/tensorflow/tensorflow-multi-gpu.zip)

# Multi-GPU Training in TensorFlow

This is a short introduction to multi-GPU training in TensorFlow. We will cover
the following topics:

* training your model with multiple GPUs on your local machine by using in-graph
  replication, and
* training your model using distributed TensorFlow.

In the following, I will assume that you have multiple *devices* (multiple GPUs,
CPUs) that you want to make use of when training your model. They could either
be installed in your local machine or in multiple machines across a network
cluster.

Before we get started on this, here are some general points about training
models in parallel:
There are, generally speaking, at least two aspects two consider when
parallelizing a model.

1. First, how should the model be parallelized? One possibility would be to
divide a model in various *horziontal slices* and parallelize those, i.e. the
first device handles the first few steps of the computation, the second device
next steps etc. This means that each device will have more memory available for
its computation, allowing you to increase the minibatch size. Alternatively,
*vertical slices* of the model could be distributed across devices, meaning that
each device goes through all steps of the model. This means that you effectively
multiply your minibatch size with the number of your devices.
The general consensus seems to be that the second method, called *replicated
training*, is superior to the first, if only for its simplicity: Its very easy
to add more and more devices without spending any thought on how the model needs
to be chopped up to accomodate these additional devices. The downside to this
approach is that all the devices need to share weights for the model, which
implies that some mechanism for synchronizing these must be in place.

2. Second, assuming we settled for the second method, how does the
synchronization of variables work across the models? This depends on your setup:
In a networked setting, you will probably use multiple instances of TensorFlow
(*between graph replication*), with one (or multiple) of these designated as
*parameter servers*. If you have multiple devices on your local machine, it
might be a better idea to explicitly do the replication in a single TensorFlow
instance (in-graph replication) and have a designated *controller device* (such
as the CPU) that will keep track of the variables in the graph.
During training, each of the replicas will perform a forward pass, followed by a
backward pass, and send its gradient updates to the controller/parameter server,
which applies the update and sends an update back to the device. This can either
happen *synchronously* (the devices wait for each other to finish and always use
the same weights) or *asynchronously* (devices operate without locking to each
other, therefore each device may have slightly different parameters).
Asynchronous training can reduce training times but is known to lead to slightly
worse predictive performance.

## What to Expect From Multi-GPU Training

Multi-GPU training is not the solution to all of your problems. Let's discuss
some misconceptions:

* The training speed does **not** scale linearly with the number of GPUs in use.
There are various factors at play here: Can you load data fast enough to feed
all of the GPUs attached to your system(s)? Is your model's runtime large enough
to hide the latencies of transferring the weights from controllers to devices?
What are your devices doing while your controller applies the gradient updates?
* When you handled all of the above, you might still not see improvements in
training progress (as measured in changes of the loss). Sure, you will
(hopefully) burn through your data at X times the speed of a single device
(personal experience: ~2.7 times speedup with 3 GPUs in synchronous training is
possible), but does that translate to faster training? Effectively, synchronous
training increases the minibatch size, meaning that you can expect to get more
accurate estimates of the true gradient. Translating this into a faster decrease
of the loss is still up to you (e.g., by increasing the learning rate when using
standard SGD). This latter point is a bit different with asynchronous training,
since that really *does* cause more parameter updates to occur; though I have
not yet seen a systematic study of this.

```python
import tensorflow as tf
```

## Local Training with Multiple GPUs
In this section, we will be using in-graph replication with synchronous training
to parallelize the model's training across multiple GPUs installed in the local
machine. The controller device will be the CPU, meaning that all variables will
live on this device and will be copied to the GPUs in each step.
The model that we will be using here is an MNIST classifier. Note that this
model is much too small to greatly benefit from multi GPU computation -- most of
the time will be spend on transferring weights and training data between CPU and
GPU.

For the way that the model is setup, see the [original tutorial]({% post_url 2017-12-12-tensorflow-intro %}).

```python
def core_model(input_img, num_classes=10):
    """
        A simple model to perform classification on 28x28 grayscale images in MNIST style.

        Args:
        input_img:  A floating point tensor with a shape that is reshapable to batchsizex28x28. It
            represents the inputs to the model
        num_classes:  The number of classes
    """
    net = tf.reshape(input_img, [-1, 28, 28, 1])
    net = tf.layers.conv2d(inputs=net, filters=32, kernel_size=[5, 5],
                           padding="same", activation=tf.nn.relu,
                           name="conv2d_1")
    net = tf.layers.max_pooling2d(inputs=net, pool_size=[2, 2], strides=2)

    net = tf.layers.conv2d(inputs=net, filters=64, kernel_size=[5, 5],
                           padding="same", activation=tf.nn.relu,
                           name="conv2d_2")
    net = tf.layers.max_pooling2d(inputs=net, pool_size=[2, 2], strides=2)
    net = tf.reshape(net, [-1, 7 * 7 * 64])
    net = tf.layers.dense(inputs=net, units=1024, name="dense_1", activation=tf.nn.relu)
    logits = tf.layers.dense(inputs=net, units=num_classes, name="dense_2")
    return logits
```

As before, we will define a training model that turns our core model into a loss
that can be passed to an optimizer. To keep things a bit shorter, we will simply
return the loss and nothing else.
Note one crucial difference here: Instead of a tensor representing the inputs to
the model, this function takes a *function that produces such a tensor*. This
will be crucial for parallelizing the model later on, since each copy of the
model should have its own such tensor.

```python
def training_model(input_fn):
    inputs = input_fn()
    image = inputs[0]
    label = tf.cast(inputs[1], tf.int32)
    logits = core_model(image)
    loss = tf.nn.sparse_softmax_cross_entropy_with_logits(labels=label, logits=logits)
    return tf.reduce_mean(loss)
```

We will be taking a slightly unorthodox (and inefficient) short-cut to get the
MNIST data shipping with Tensorflow in a dataset-API format:

```python
def training_dataset(epochs=5, batch_size=128):
    from tensorflow.examples.tutorials.mnist import input_data
    mnist_data = input_data.read_data_sets("data")
    all_data_points = mnist_data.train.next_batch(60000)
    dataset = tf.contrib.data.Dataset.from_tensor_slices(all_data_points)
    dataset = dataset.repeat(epochs).shuffle(10000).batch(batch_size)
    return dataset
```

We can now train this model as usual before we go to the parallel setting (all
non-essential steps like saving, summaries, etc. are skipped):

```python
def do_training(update_op, loss):
    with tf.Session() as sess:
        sess.run(tf.global_variables_initializer())
        try:
            step = 0
            while True:
                _, loss_value = sess.run((update_op, loss))
                if step % 100 == 0:
                    print('Step {} with loss {}'.format(step, loss_value))
                step += 1
        except tf.errors.OutOfRangeError:
            # we're through the dataset
            pass
    print('Final loss: {}'.format(loss_value))

def serial_training(model_fn, dataset):
    iterator = dataset.make_one_shot_iterator()
    
    loss = model_fn(lambda: iterator.get_next())
    optimizer = tf.train.AdamOptimizer(learning_rate=1E-3)
    global_step = tf.train.get_or_create_global_step()
    update_op = optimizer.minimize(loss, global_step=global_step)
    
    do_training(update_op, loss)


tf.reset_default_graph()
serial_training(training_model, training_dataset(epochs=2))
```
```
Extracting data/train-images-idx3-ubyte.gz
Extracting data/train-labels-idx1-ubyte.gz
Extracting data/t10k-images-idx3-ubyte.gz
Extracting data/t10k-labels-idx1-ubyte.gz
Step 0 with loss 2.30421590805
Step 100 with loss 0.0781030803919
Step 200 with loss 0.0625318139791
Step 300 with loss 0.0476590171456
Step 400 with loss 0.0532032027841
Step 500 with loss 0.100487187505
Step 600 with loss 0.011965803802
Step 700 with loss 0.0720254331827
Step 800 with loss 0.017533345148
Step 900 with loss 0.00320947216824
Final loss: 0.187678039074
```

We'll skip evaluation, since you probably have a good idea of how to do that
yourself. Let's get to the interesting part: Replication across multiple GPU!

### The Multi-GPU version

There are two different perspectives one can take on this: One could either
attempt to create a function that takes a model function as an input and returns
a model function for the parallelized model (philosophically, this means that
parallelity is a property of the model), or one can create a specialized
training procedure that takes a model function and trains the modle in parallel
(parallelity is a property of the optimization process). *I am heavily leaning
towards the latter*, since parallelization of a model requires some knowledge of
the optimizer in use.

Here is a short road-map of what we will be doing:
* We will create a specialized training function that trains a model given by
its model function on multiple devices,
* this function will create one copy of the model (called a *tower*) per device
and instruct it to compute forward and backward passes,
* the gradients will then be averaged and applied on the controller device where
all the model's variables reside.

This already alludes to why parallelity should be seen as a property of the
training procedure, not the model: We will need to split the minimize step of
the optimizer into `compute_gradients` (performed on the devices) and
`apply_gradients` (running on the controller). Thus whatever makes the parallel
training work will need to know about the optimizer!

This is the final training function: All the magic happens in
`create_parallel_optimization`, and we will slowly work towards this function.

```python
def parallel_training(model_fn, dataset):
    iterator = dataset.make_one_shot_iterator()
    
    def input_fn():
        with tf.device(None):
            # remove any device specifications for the input data
            return iterator.get_next()
    
    optimizer = tf.train.AdamOptimizer(learning_rate=1E-3)
    update_op, loss = create_parallel_optimization(model_fn,
                                                   input_fn,
                                                   optimizer)

    do_training(update_op, loss)
```

#### Specifying the Device for an Operation
TensorFlow allows the specification of a device for each of the operations you
create. This works by using `tf.device`, as in the following cell:

```python
def device_example():
    # allocate variables on the CPU
    with tf.device('/cpu:0'):
        M = tf.get_variable('M', shape=[10,8], dtype=tf.float32)
        x = tf.get_variable('x', shape=[8, 1], dtype=tf.float32)
    # perform the operation on the fi=rst GPU device
    with tf.device('/gpu:0'):
        y = tf.matmul(M, x)
```

Since all variables in our setting should live on the controller device, but all
operations should run on the operating devices, we can either explicitly
allocate all variables beforehand (tedious!) or make use of the fact that
`tf.device` can also take a function as its argument: This function then
dynamically decides which operation to put where.

The following function allows us to construct a suitable argument for
`tf.device` that places all variables on the controlling device, and everything
else on a device of our choice (all credit goes to the author with that GitHub
issue):

```python
PS_OPS = [
    'Variable', 'VariableV2', 'AutoReloadVariable', 'MutableHashTable',
    'MutableHashTableOfTensors', 'MutableDenseHashTable'
]
    
# see https://github.com/tensorflow/tensorflow/issues/9517
def assign_to_device(device, ps_device):
    """Returns a function to place variables on the ps_device.

    Args:
        device: Device for everything but variables
        ps_device: Device to put the variables on. Example values are /GPU:0 and /CPU:0.

    If ps_device is not set then the variables will be placed on the default device.
    The best device for shared varibles depends on the platform as well as the
    model. Start with CPU:0 and then test GPU:0 to see if there is an
    improvement.
    """
    def _assign(op):
        node_def = op if isinstance(op, tf.NodeDef) else op.node_def
        if node_def.op in PS_OPS:
            return ps_device
        else:
            return device
    return _assign
```

We can use the same example as above to demonstrate its usage:

```python
def device_example_2():
    # allocate variables on the CPU, perform the operation on the first GPU device
    with tf.device(assign_to_device('/gpu:0', '/cpu:0')):
        M = tf.get_variable('M', shape=[10,8], dtype=tf.float32)
        x = tf.get_variable('x', shape=[8, 1], dtype=tf.float32)
        y = tf.matmul(M, x)
```

As an aside: You may find it helpful to allow TensorFlow to violate your device
specifications when necessary (*soft placement*) or to check which devices are
used for which operations. Both of it is possible with customizing the session
which is running the operations:

```python
def device_options():
    config = tf.ConfigProto(log_device_placement=False, allow_soft_placement=True)
    with tf.Session(config=config) as sess:
        # your code here
        pass
```

Using TensorBoard's graph view, you can also inspect which operations are placed
on which device, but that view only shows static information (and not
TensorFlow's placement decisions).

#### Reusing Variables
One crucial point when parallelizing a model is that you need to ensure that
multiple copies of the same operation share common weights. For this, it is
necessary to briefly talk about *variable scopes*: Variables scopes are like
name scopes, except that they affect variables instead of operations. Two
variables can have the same name as long as they live in different scopes. The
`tf.get_variable` function is essentially performing variable look-up in the
local scope, and if a variable doesn't exist yet, it is created for you.
A vital feature is that you can *reuse* variable scopes, that is, you can go
back into a variable scope you already created earlier, and access variables you
used before. For example:

```python
def variable_scope_example():
    with tf.variable_scope('test_scope'):
        M = tf.get_variable('matrix1', shape=[10, 8], dtype=tf.float32)
        x = tf.get_variable('matrix2', shape=[8, 1], dtype=tf.float32)
        y = tf.matmul(M, x)
    # Here, we are instructing TensorFlow to reuse to variables declared above.
    # The `M` from above and the `N` from below reference the same Tensor!
    with tf.variable_scope('test_scope', reuse=True):
        N = tf.get_variable('matrix1', shape=[10, 8], dtype=tf.float32)
        z = tf.get_variable('matrix2', shape=[8, 1], dtype=tf.float32)
        w = tf.matmul(N, z)
```

There are a few things worth noting:
* By setting `reuse=True` above, we state that *all* variables we request have
already been defined. We cannot declare new ones in that scope.
* Obviously, we have to ensure that the variables agree on their parameters. For
example, in the code above we could not change `N` to have shape `[10, 10]` in
the second scope because it already exists with a shape of `[10, 8]`.
* In many places of higher-level APIs, variable scopes are created
automatically. They often use consecutive naming when no default name is given.
Variable-reusing only works when the variable scopes have the exact same name
and path, so **always name your layers when using TFLayers or Slim**. For
example, the following will **not** reuse variables:

```python
def variable_scope_layers_failure():
    input_tensor = tf.placeholder(dtype=tf.float32, shape=[1, 10, 10, 1])
    with tf.variable_scope('test_scope'):
        tf.layers.conv2d(input_tensor, filters=10, kernel_size=[5, 5])

    # This will NOT reuse variables, since both `conv2d` implicitly create a variable scope with a
    # fresh name. Add `name='layer_name'` to make it work.
    with tf.variable_scope('test_scope', reuse=True):
        tf.layers.conv2d(input_tensor, filters=10, kernel_size=[5, 5])


def variable_scope_layers_correct():
    input_tensor = tf.placeholder(dtype=tf.float32, shape=[1, 10, 10, 1])
    with tf.variable_scope('test_scope'):
        tf.layers.conv2d(input_tensor, filters=10, kernel_size=[5, 5],
                         name='my_conv')
    # This does what it is supposed to do since both convolutional layers have been given
    # the same name
    with tf.variable_scope('test_scope', reuse=True):
        tf.layers.conv2d(input_tensor, filters=10, kernel_size=[5, 5],
                         name='my_conv')
```

Instead of setting `reuse=True`, we can also call `reuse_variables` on the scope
to achieve the same effect.

```python
def variable_scope_example_2():
    with tf.variable_scope('test_scope') as vscope:
        M = tf.get_variable('matrix1', shape=[10, 8], dtype=tf.float32)
        x = tf.get_variable('matrix2', shape=[8, 1], dtype=tf.float32)
        y = tf.matmul(M, x)
        
        vscope.reuse_variables()
        
        # variables are reused here
        N = tf.get_variable('matrix1', shape=[10, 8], dtype=tf.float32)
        z = tf.get_variable('matrix2', shape=[8, 1], dtype=tf.float32)
        w = tf.matmul(N, z)
```

#### Creating the Parallel Optimization Routine
Now we are ready to assemble the parts. There are still some unknowns in the
following code; we will discuss them shortly:

```python
def create_parallel_optimization(model_fn, input_fn, optimizer, controller="/cpu:0"):
    # This function is defined below; it returns a list of device ids like
    # `['/gpu:0', '/gpu:1']`
    devices = get_available_gpus()
        
    # This list keeps track of the gradients per tower and the losses
    tower_grads = []
    losses = []
    
    # Get the current variable scope so we can reuse all variables we need once we get
    # to the second iteration of the loop below
    with tf.variable_scope(tf.get_variable_scope()) as outer_scope:
        for i, id in enumerate(devices):
            name = 'tower_{}'.format(i)
            # Use the assign_to_device function to ensure that variables are created on the
            # controller.
            with tf.device(assign_to_device(id, controller)), tf.name_scope(name):
                
                # Compute loss and gradients, but don't apply them yet
                loss = model_fn(input_fn)
                
                with tf.name_scope("compute_gradients"):
                    # `compute_gradients` returns a list of (gradient, variable) pairs
                    grads = optimizer.compute_gradients(loss)
                    tower_grads.append(grads)
                    
                losses.append(loss)
            
            # After the first iteration, we want to reuse the variables.
            outer_scope.reuse_variables()
                
    # Apply the gradients on the controlling device
    with tf.name_scope("apply_gradients"), tf.device(controller):
        # Note that what we are doing here mathematically is equivalent to returning the
        # average loss over the towers and compute the gradients relative to that.
        # Unfortunately, this would place all gradient-computations on one device, which is
        # why we had to compute the gradients above per tower and need to average them here.
        
        # This function is defined below; it takes the list of (gradient, variable) lists
        # and turns it into a single (gradient, variables) list.
        gradients = average_gradients(tower_grads)
        global_step = tf.train.get_or_create_global_step()
        apply_gradient_op = optimizer.apply_gradients(gradients, global_step)
        avg_loss = tf.reduce_mean(losses)

    return apply_gradient_op, avg_loss
```

That wasn't so difficult, was it?

At this point, I should point out that the `input_fn` has been called once for
each model. This is critical: If we had called `iterator.get_next()` once and
passed the resulting tensor to each of the models, all of the models would use
the same data in every step.

The `get_available_gpus` function isn't worth further discussion (credits to the
original author at the given source):

```python
# Source:
# https://stackoverflow.com/questions/38559755/how-to-get-current-available-gpus-in-tensorflow
def get_available_gpus():
    """
        Returns a list of the identifiers of all visible GPUs.
    """
    from tensorflow.python.client import device_lib
    local_device_protos = device_lib.list_local_devices()
    return [x.name for x in local_device_protos if x.device_type == 'GPU']
```

The only missing part is the `average_gradients` function. It does what you'd
think it would do (credits to the original author at the given source, some
modifications have been made):

```python
# Source:
# https://github.com/tensorflow/models/blob/master/tutorials/image/cifar10/cifar10_multi_gpu_train.py#L101
def average_gradients(tower_grads):
    """Calculate the average gradient for each shared variable across all towers.
    Note that this function provides a synchronization point across all towers.
    Args:
    tower_grads: List of lists of (gradient, variable) tuples. The outer list ranges
        over the devices. The inner list ranges over the different variables.
    Returns:
            List of pairs of (gradient, variable) where the gradient has been averaged
            across all towers.
    """
    average_grads = []
    for grad_and_vars in zip(*tower_grads):

        # Note that each grad_and_vars looks like the following:
        #   ((grad0_gpu0, var0_gpu0), ... , (grad0_gpuN, var0_gpuN))
        grads = [g for g, _ in grad_and_vars]
        grad = tf.reduce_mean(grads, 0)

        # Keep in mind that the Variables are redundant because they are shared
        # across towers. So .. we will just return the first tower's pointer to
        # the Variable.
        v = grad_and_vars[0][1]
        grad_and_var = (grad, v)
        average_grads.append(grad_and_var)
    return average_grads

tf.reset_default_graph()
parallel_training(training_model, training_dataset(epochs=2))
```
```
Extracting data/train-images-idx3-ubyte.gz
Extracting data/train-labels-idx1-ubyte.gz
Extracting data/t10k-images-idx3-ubyte.gz
Extracting data/t10k-labels-idx1-ubyte.gz
Step 0 with loss 2.29874181747
Step 100 with loss 0.114577434957
Step 200 with loss 0.0739449113607
Step 300 with loss 0.0614554695785
Step 400 with loss 0.013178229332
Final loss: 0.0271248538047
```

Note how the number of steps is about half as much as that observed with one
GPU. This makes perfect sense, since we have effectively doubled the minibatch
size.

### Effective Training on Multiple GPUs
Here are a few general pointers for making sure that you really benefit from
multi GPU systems:

* Make sure that you have enough data available to feed your GPUs. This may mean
that you need use multi-threading in your input pipeline. If you are using the
dataset API, this is as simple as using `map` with the right parameters.
Experimenting with the number of threads to use can be helpful, since there is a
tradeoff between using the CPU to load data and using the CPU to average
gradients (assuming your CPU is the controller device).
* Depending on your setup, it may be advantageous to use one of your GPUs as a
controller device. This would lead to much faster averaging of the gradients
(and for a large model, this step is non-negligible), but it is only helpful
when your GPUs have direct access to each other's memory - otherwise you are
just adding more and more inter-device transfers and slow the system down.
* If your controller device is the CPU, you should think about what your GPUs
will be doing while the CPU is averaging their gradients and applying them. They
cannot start working on the next batch of inputs, since they are still waiting
for the new weights. However, if your model is using data augmentation, your
GPUs could already work on augmenting the next batch of images. This intra-model
pipelining can be implemented using a [StagingArea](https://www.tensorflow.org/a
pi_docs/python/tf/contrib/staging/StagingArea) and probably warrants a small
tutorial on its own. Note that `tf.contrib.staging.StagingArea` lives in the
`contrib` namespace and is therefore subject to changes. It will likely be
superseded in the near future by staging support built-in into the dataset API
([see here](https://docs.google.com/presentation/d/16kHNtQslt-yuJ3w8GIx-
eEH6t_AvFeQOchqGRFpAD7U/edit#slide=id.g254d08e080_0_322)).

## Training a Model using Distributed TensorFlow
Distributed TensorFlow allows training of models across multiple computers, but
it can also be used on a single machine (which is what we will do here, for
testing purposes). The basic principles remain the same.

Since distributed TensorFlow requires multiple TensorFlow instances to run at
once, it is difficult to present everything in a single notebook. Therefore, we
will go over the necessary code, but not actually execute it here.

As already pointed out before, there are two different kinds of entities that
make up a distributed TensorFlow training procedure: *Parameter servers* (PS)
and *workers*. They need different code to run, but luckily the code for the
parameter servers is very simple. Before a distributed training is started, the
workers and parameter servers that should participate need to be specified. This
is called a *cluster specification*:

```python
cluster_specification = {
    "ps": ["localhost:2222"], # list of parameter servers,
    "worker": ["localhost:2223", "localhost:2224"] # list of workers
}
```

The terminology here is that our cluster specification has to *jobs* (`ps` and
`worker`), and for each of them we specify *tasks* by giving the address of the
TensorFlow instance that will work on that task.

In our case, these are all local task. This means we will have 3 TensorFlow
instances running (my local machine has 2 GPUs for two worker tasks, plus the
parameter server). By default, each TensorFlow instance will try to claim *all
memory on all visible GPUs*! To prevent this, set the `CUDA_VISIBLE_DEVICES`
environment variable before starting each task. For example,
`CUDA_VISIBLE_DEVICES=0` to only set the first GPU as visible.

That said, here is the code that needs to be run for parameter server tasks:

```python
def start_parameter_server(task_index, cluster_specifcation):
    cluster_spec = tf.train.ClusterSpec(cluster_specification)
    server = tf.train.Server(cluster_spec, job_name='ps', task_index=task_index)
    server.join()
```

It doesn't even depend on (or know about) the model you are running.

For the worker jobs, we will need slightly more code, but not all that much. We
will use `tf.train.MonitoredTrainingSession` instead of `tf.Session` below,
since that already includes a bunch of useful helpers that make distributed
training easier. See below for a short discussion about
`tf.train.MonitoredTrainingSession`.

```python
def start_worker(task_index, cluster_specification, dataset):  
    cluster_spec = tf.train.ClusterSpec(cluster_specification)
    server = tf.train.Server(cluster_spec, job_name="worker", task_index=task_index)
    
    worker_device = "/job:worker/task:{}".format(task_index)
    # `tf.train.replace_device_setter` automatically determines where to place variables
    with tf.device(tf.train.replica_device_setter(worker_device=worker_device,
                                                  cluster=cluster_spec)):
        iterator = dataset.make_one_shot_iterator()
        loss = training_model(lambda: iterator.get_next())
        
        optimizer = tf.train.AdamOptimizer(learning_rate=1E-3)
        global_step = tf.train.get_or_create_global_step()
        update_op = optimizer.minimize(loss, global_step=global_step)
        
        # `tf.train.MonitoredTrainingSession` can be used as a drop-in replacement
        # for regular sessions.
        with tf.train.MonitoredTrainingSession(master=server.target,
                                               is_chief=task_index == 0) as sess:
            while not sess.should_stop():
                sess.run(update_op)
```

There are a few details we should quickly talk about.

**Setting devices** -
As before, each variable needs to be set to a device. Here, we are using
`tf.train.replica_device_setter` to do that automatically. It could also be done
manually by using e.g. `tf.device('/job:ps/task:0)` to specify that something
should be performed by the first parameter server. The
`tf.train.replica_devise_setter` is a bit more conservative than our solution
above, since (by default) it only allocates `tf.Variable` on parameter servers,
but (as with many other aspects of its behaviour) this can be customized.
Similarly, the procedure by default uses a round-robin style assignment of
variables, but you can also define custom parameter distribution strategies.

**The Monitored Training Session** -
In the example above, we have used `tf.train.MonitoredTrainingSession` instead
of `tf.Session`. This is a wrapper around sessions that handles
 * saving summaries,
 * saving checkpoints and restoring from them after crashes,
 * measuring steps/second,
 * variable initialization,
 * distributed training.
Most of its behaviour can be changed via its arguments (they are mostly pretty
self-explanatory), but some features require you to add custom *hooks* to the
session. A common use case for that would be when you have two classes of
summaries: Ones that you want to evaluate frequently, and other more expensive
summary operations that should only be evaluated every once in a while. This
will need a custom hook. Similarly, starting training from some given
initialization needs some additional work with this session-like object.
For more information, see [the TensorFlow documentation](https://www.tensorflow.
org/api_docs/python/tf/train/MonitoredTrainingSession). Take special note of the
`scaffold` parameter; it looks innocent but once you try to do anything non-
trivial with `MonitoredTrainingSession`, you will need it. See [its
documentation](https://www.tensorflow.org/api_docs/python/tf/train/Scaffold).

**Chief and Master** -
These, `master` and `is_chief`, are two of the arguments of
`MonitoredTrainingSession` that need some explanation. First, *chief* is short
for *chief worker*. This is a designated worker job with special
responsibilities, like initializing and recovering the model after failures. For
most intents and purposes, you should not worry about it. Just make sure there
is a chief (in our case, the worker with task index 0).
The *master* on the other hand is responsible for actually coordinating the work
between different jobs.


### Starting the Training Process
We are almost there, but still need to start the jobs. Execute the following in
three separate terminals to see everything in action (remember to make sure to
set `CUDA_VISIBLE_DEVICES` appropriately beforehand):

`start_parameter_server(0, cluster_specification)`

`start_worker(0, cluster_specification, training_dataset())`

`start_worker(1, cluster_specification, training_dataset())`

Your jobs should now slowly start to train the model.

## Conclusion

All in all, distributed training is probably easier to set up than manual in-
graph replication, but this approach will not necessarily yield the same
performance: It requires interprocess or network communication, which can be
quite a slow down.
On my local machine, I get the following performance:
* Single GPU: 200 batches of 128 images per second
* Two GPUs, in-graph replication: 80 batches of 2x128 images per second
* Two GPUs, distributed (2 workers): 50 batches of 2x128 images per second

This is *even though* the distributed training works asynchronously, whereas the
in-graph replication example uses synchronous training. Remember that this is
not a real-world example and, as already said, the model is *much* too small to
expect any performance gains from parallelization, since most of the time will
be spent on communication overhead, transfers, etc.

For larger models, these numbers will change, but you should not expect
distributed TensorFlow to beat in-graph replication (assuming both are runnig on
a single machine). When you have many machines available, distributed TensorFlow
is the way to go, though you may want to consider doing synchronized multi GPU
training on each machine separately and aggregate across machines by using
distributed TensorFlow. At some point, it would also be wise to add more
parameter servers to the cluster to reduce the load on that machine and its
network connection.

## Further Reading
* For synchronous distributed training, take a look at [SyncReplicasOptimizer](h
ttps://www.tensorflow.org/api_docs/python/tf/train/SyncReplicasOptimizer),
* TensorFlow's documentation has a [page on distributed training](https://www.tensorflow.org/deploy/distributed). There is not much on
it that we haven't covered here as well, but the talk linked on that page is
worth watching.
* The in-graph replication code is inspired by [this implementation](https://github.com/tensorflow/models/blob/master/tutorials/image/cifar10/cifar10_multi_gpu_train.py), though this is already somewhat older.
* There are frameworks that offer alternatives to the TensorFlow built-in
support for distributed training. Some like Uber's
[Horovod](https://eng.uber.com/horovod/) claim to give much better performance,
but I have not tested them.
