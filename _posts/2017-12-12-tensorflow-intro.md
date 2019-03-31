---
layout: post
title: TensorFlow - An Introduction
excerpt: In which I explain how to use TensorFlow from first principles.
tags: [computer science, machine learning, python, tensorflow]
image: /img/2017-12-12-tensorflow-intro/tf_logo.png
---

This is an introduction to TensorFlow written for some colleagues in October 2017. It assumes no prior knowledge of TensorFlow, but it is not a Deep Learning tutorial (and later parts assume that you know about DNNs). It covers everything from setting up TensorFlow on your machine to training and saving models. As a special feature, it covers how to efficiently use the recently introduced dataset API to load a training dataset given as single pictures.
The tutorial is actually an interactive Jupyter notebook. [You can download it here.](http://www.s-schoener.com/files/tensorflow/tensorflow-tutorial.zip) It comes with the MNIST dataset as single pictures, so it is a bit heavy.

## Installing TensorFlow & Jupyter Notebook
Before we get started, a few words on how to obtain a functioning TensorFlow
installation. We will use Anaconda; this allows us to easily separate TensorFlow
and its dependencies into a separate development environment. For this
introduction, we will be using Python 2.7 and TensorFlow 1.3 (the latest version
as of writing, though feel free to use a more recent version).

1. [Download and install Anaconda](https://www.anaconda.com/download/) for your
operating system.
2. Create a new TensorFlow environment by entering
`conda create -n tensorflow-introduction python=2.7` into your terminal.
3. Activate this environment using `source activate tensorflow-introduction`.
4. Install Tensorflow in this environment by following the [installation
instructions for Anaconda on Linux](https://www.tensorflow.org/install/install_linux#installing_with_anaconda).
Make sure to download TensorFlow with GPU
support. In our case, the installation simply consists of entering
```pip install --ignore-installed --upgrade https://storage.googleapis.com/tensorflow/linux/gpu/tensorflow_gpu-1.3.0-cp27-none-linux_x86_64.whl```
in your terminal (while the Anaconda environment is active, of course).
5. Finally, for Jupyter Notebook support, execute `conda install jupyter
notebook pillow matplotlib`. The latter, `pillow` and `matplotlib` are only
needed for this notebook, specifically.

Note that this last step is entirely optional; it is merely more convenient if
you want to follow along: Start up a jupyter notebook server in the directory
that contains this notebook by entering `jupyter notebook` and open this
notebook to get a more interactive experience :)


```python
# This may take a few seconds if you are running it for the first time
%matplotlib notebook
import tensorflow as tf
import numpy as np
import matplotlib.pyplot as plt
import tutorial  # see tutorial.py
from PIL import Image
from os.path import abspath
```

### Running the notebook a second time?
If you are running the notebook more than once, you will need to ensure that
TensorFlow resets its internal state by executing the following cell:

```python
tf.reset_default_graph()
```

### Verify your installation
To verify that your installation works, execute the following piece of code. It
is the equivalent of a Hello World program in TensorFlow.

```python
hello_world = tf.constant("Hello World!")
with tf.Session() as sess:
    print(sess.run(hello_world))
```
```
Hello World!
```


If everything worked as intended, you should see some debug output in the
terminal running the jupyter notebook
along with the output of the program beneath the code cell above, namely `Hello
World!`.

Congratulations! You are good to go!

## The TensorFlow Philosophy

### Computation Graphs
TensorFlow is a library for *building* and *executing* computation graphs on,
well, tensors. Hence, each program in TensorFlow usually roughly consists of two
parts: One part building up the computation graph and another that is actually
executing the computation.

We will start with a simple example. First, we build up a computation (in this
case, the computation `8 + 34`):

```python
x = tf.constant(8)
y = tf.constant(34)
result = tf.add(x, y)
```

These commands build up a computational graph with three nodes (two constants
and the add-operation) and two edges connecting the constant nodes to the
addition node. **The outputs of the nodes are the tensors** that give TensorFlow
its name. Each of the variables above now points to such a tensor:

```python
print(x)
print(y)
print(result)
```
```
Tensor("Const_1:0", shape=(), dtype=int32)
Tensor("Const_2:0", shape=(), dtype=int32)
Tensor("Add:0", shape=(), dtype=int32)
```


![Computation Graph](/img/2017-12-12-tensorflow-intro/add_graph.png){: .center-image}
As you can see, each tensor has a unique name (which is comprised of the name of
the name of the node that they come from and the output index at that node, like
this: `node_name:index`), a shape, and a data type. In the example above, the
shape of all of the variables is a scalar, denoted by the empty tuple `()`.

Note also how the none of the tensors have any values yet. Specifically, **the
piece of code above did not trigger any addition yet**. The actual execution of
the computation happens within a *session*:

```python
with tf.Session() as sess:
    print(sess.run(result))
```
```
42
```


A single session can be reused over and over again to perform more computation.
The first parameter to the `run` method represents the tensors and operations
that should be evaluated. TensorFlow will then inspect the computational graph
and run all operations that are required to determine the requested value. You
can also pass structured arguments to `run` to evaluate multiple tensors:

```python
with tf.Session() as sess:
    print(sess.run(x))  # returns a scalar
    print(sess.run([x, y, result]))  # returns a list of scalars
    print(sess.run({"x": x, "my_result": result}))  # returns a dictionary of scalars
```
```
8
[8, 34, 42]
{'x': 8, 'my_result': 42}
```

**N.B.:** Make sure that you are using sessions in a `with` construct or
manually close them using `session.close()` once you do not need them anymore.

### Placeholders, Variables, Optimizers
Before we get to the meat of TensorFlow, i.e. building and training deep neural
networks, let us take a few minutes to look at three more components that we
will be using later on: *Placeholders*, *variables*, and *optimizers*.

#### Placeholders
Placeholders can be thought of *holes* in the computation graph, or simply
parameters of the computation graph that can be set independently for each run
in a session. They are very useful to represent inputs to a computation. We
could, for example, parametrize our example from above to add *arbitrary
numbers* instead of hard-coded constants:

```python
x = tf.placeholder(name="x", dtype=tf.float32)  # almost anything in TensorFlow can be named.
y = tf.placeholder(name="y", dtype=tf.float32)
result = x + y  # the common operations for tensors are available as operators

print(x)
print(y)
print(result)
```
```
Tensor("x:0", dtype=float32)
Tensor("y:0", dtype=float32)
Tensor("add:0", dtype=float32)
```

![Computation Graph](/img/2017-12-12-tensorflow-intro/add_variables_graph.png){: .center-image}

The actual values of the placeholders are filled in at runtime like so:

```python
with tf.Session() as sess:
    # Add up 8 and 34
    result_value = sess.run(result, feed_dict={x: 8, y: 34})
    print("8 + 34 = %d" % result_value)
        
    # We didn't specify the shapes of our placeholders above, so we can substitute in anything
    # that can be added up!
    feed_dict = {
        x: np.arange(12).reshape(3, 4),
        y: np.ones(12).reshape(3, 4) * 10
    }
    result_value = sess.run(result, feed_dict)
    print("Sum of two 3x4 matrices:\n" + str(result_value))
```
```
8 + 34 = 42
Sum of two 3x4 matrices:
[[ 10.  11.  12.  13.]
 [ 14.  15.  16.  17.]
 [ 18.  19.  20.  21.]]
```

#### Variables
Variables are *stateful elements* in the graph, i.e., they store their values
across multiple calls to `run` within a session. This is useful to keep track of
the number of steps that have been executed in an optimization or to store
weights that change over the course of optimization (e.g. weights of a neural
network).

In TensorFlow, variables must be initialized to some value before running a
session. Therefore, each variable has its own *variable initializer*. By
default, this is a uniformly random initialization.

In the following, we will use a variable to keep a running sum over all inputs
that we have seen. Keep the analogy to writing a program vs. executing it in
mind when reading the following cell:

```python
a = tf.placeholder(name="a", shape=(2, 2), dtype=tf.float32)  # our input are 1x2 matrices

# create the variable and specify that it should be initialized with zeros
accumulator = tf.get_variable(name="acc",
                              shape=(2, 2),
                              dtype=tf.float32,
                              initializer=tf.zeros_initializer())
    
# compute the new value of the accumulator and assign it to the variable
new_accumulator = accumulator + a
update_accumulator = tf.assign(accumulator, new_accumulator)
```

![Computation Graph](/img/2017-12-12-tensorflow-intro/accumulator_graph.png){: .center-image}

Note that the yellow edge specifies that the `assign` operation *references* the
accumulator `acc`. The edges in the graph (that is, the *tensors*) are annotated
with their statically known shapes that we hardcoded into the program.

Under the hood, TensorFlow created a bunch of operations and grouped them with
our given name `acc`. This is typical: TensorFlow provides many primitive
operations, but you will usually use them through abstractions:

![Under The Hood](/img/2017-12-12-tensorflow-intro/accumulator_graph_under_the_hood.png){: .center-image}

We can now run a few steps of the computation:

```python
with tf.Session() as sess:
    sess.run(tf.global_variables_initializer())  # variables need to be initialized before using them!
    
    # let's look at the initial value of the accumulator:
    print('Initial value of `acc`: \n' + str(sess.run(accumulator)))
    
    # we can query the value of `new_accumulator` without updating the variable `acc`
    summand = np.random.randn(2, 2)
    feed_dict = {a: summand}
    results = sess.run([new_accumulator, accumulator], feed_dict)
    print('Evaluating `new_accumulator` does not update `acc`: \n' + str(results[1]))
    
    # but evaluating the assignment does update the accumulator
    for i in range(10):
        summand = np.random.randn(2, 2)
        sess.run(update_accumulator, feed_dict={a: summand})
    print('Evaluating `update_accumulator` updates `acc`: \n' + str(sess.run(accumulator)))
```
```
Initial value of `acc`: 
[[ 0.  0.]
 [ 0.  0.]]
Evaluating `new_accumulator` does not update `acc`: 
[[ 0.  0.]
 [ 0.  0.]]
Evaluating `update_accumulator` updates `acc`: 
[[ 3.20579314 -1.38578141]
 [-2.16290545  1.50033629]]
```

Note that
* variables *must* be initialized prior to using them and we can specify and
initializer for them,
* the assignment is only executed *if we explicitly ask for it*,
* explicit variable use is most likely not something that you will stumble over
regularly.

#### Optimizers
The last conceptual puzzle piece that we need are *optimizers*. Optimizers are
high-level abstractions in TensorFlow that allow you to perform optimization and
automatically adjust variables over the course of a session. Optimizers allow
you to minimize a given quantity in your graph using gradient descent and its
relatives.

In the following, we will use placeholders, variables, and optimizers to
calculate the square-root of an input value using gradient descent.

```python
q = tf.placeholder(name="q", shape=(), dtype=tf.float32)
sqrt_q = tf.get_variable(name="sqrt_q",
                         shape=(),
                         dtype=tf.float32,
                         initializer=tf.ones_initializer())

# Name scopes can be used to group operations together, making it easier to avoid name-clashes
# and making the graph structure easier to understand
with tf.name_scope("error"):
    delta = (q - (sqrt_q * sqrt_q))
    loss = tf.multiply(delta, delta)

# build the optimizer and get a tensor that performs the optimization when evaluated
optimizer = tf.train.GradientDescentOptimizer(name="SGD", learning_rate=0.001)
optimization_step = optimizer.minimize(loss)
```

![Computation Graph](/img/2017-12-12-tensorflow-intro/optimizer_1.png){: .center-image}

As you can see,
* TensorFlow automatically added operations to compute the gradients for the
optimizer,
* the optimizer takes care of updating our variable `sqrt_q`,
* we neatly grouped the computation of the error, making the graph easy to read.

Let us now run the actual optimization step-by-step until convergence:

```python
def compute_sqrt(x):
    with tf.Session() as sess:
        # Initialize all variables, in our case this sets sqrt_q to 1
        sess.run(tf.global_variables_initializer())
    
        feed_dict = {
            q: x
        }
    
        step = 0
        loss_value = 1
        while loss_value > 1e-10:
            # we repeatedly evaluate the optimization step, get the loss, and optimized value
            _, loss_value, sqrt = sess.run((optimization_step, loss, sqrt_q), feed_dict=feed_dict)
            
            if step % 5 == 0:
                print('Current loss: %f with value %f' % (loss_value, sqrt))
            step += 1

        print('Final loss: %f after %d steps' % (loss_value, step))
        sqrt = sess.run(sqrt_q)
        print('Sqrt of %f is %f' % (x, sqrt))
        return sqrt

compute_sqrt(49)
```
```
Current loss: 2304.000000 with value 1.000000
Current loss: 1887.734863 with value 2.356254
Current loss: 688.755493 with value 4.770309
Current loss: 30.682312 with value 6.592484
Current loss: 0.291972 with value 6.961297
Current loss: 0.002077 with value 6.996744
Current loss: 0.000014 with value 6.999729
Current loss: 0.000000 with value 6.999977
Current loss: 0.000000 with value 6.999998
Final loss: 0.000000 after 43 steps
Sqrt of 49.000000 is 7.000000

6.9999995
```


Of course, there are *much* better ways to compute the square-root of a number,
but the general idea of how to use optimizers has hopefully been made clear :)

## Cleaning the Plate
We should now wipe the plate clean before we start with DNNs in TensorFlow:
Everything that we did up until now has been added *to the same computation
graph*. The pictures above don't tell the whole story; it would look rather
messy right now. Right now, we should not worry about managing the graph that
TensorFlow creates its operations in, but we should return to a clean graph
using:

```python
tf.reset_default_graph()
```

This is mostly necessary when using TensorFlow within a Jupyter notebook, since
the default graph would be reset anyway every time you shut down Python.

## Your First CNN in TensorFlow
As a slightly more exciting application, we will implement a CNN for MNIST
classification, covering the following points:

* defining a CNN,
* loading data from files asynchronously,
* saving the state of the CNN,
* and monitoring the training using TensorBoard.

The part on data loading is absolutely on the bleeding edge, as we will be using
TensorFlow's new Dataset API that was added in version 1.3 and is going to get
exciting new features in version 1.4.

### Building the Model
By now, you probably have an idea of what it takes to create a CNN in
TensorFlow:

* create a placeholder tensor that represents the input,
* define variables for the kernels, weights, and biases of the layers,
* create an optimizer and minimize some loss.

In general, it is a good idea to write a bunch of functions that abstract over
some of these steps. Specifically, we will separate the concerns of building the
model, training the model, and feeding data into the model. This way we can use
the same model for evaluation (needs data streaming, but no optimization),
training (needs data streaming and optimization), and deployment (operates on
single images, but no optimization).

#### Building a convolution
Since we will need to define multiple convolutions, we may be tempted to write a
function to do that:

```python
def make_convolution(input, name, kernel_size, num_filters, stride, padding='SAME'):
    
    # We are using a variable scope here to ensure that the `kernel` variable name
    # is taken relative to the name of this convolution.
    with tf.name_scope(name), tf.variable_scope(name):
        # get the number of input channels, assuming NHWC format
        in_channels = input.get_shape()[-1]
        # create the kernel of the convolution
        kernel = tf.get_variable(name="kernel",
                                 shape=[kernel_size, kernel_size, in_channels, num_filters])
        output = tf.nn.conv2d(input,
                              kernel,
                              strides=[1, stride, stride, 1],
                              padding=padding)
        # create bias, choose correct initializers etc.
        return tf.nn.relu(output)
```

While this is generally possible, the above implementation has multiple issues
and it should go without saying that we usually do not need this level of
detail. Luckily, these problems have already been solved by other people. There
are plenty of libraries around that can be used to make the task of specifying
DNNs less painful:

* TF Layers
* TF Slim
* Keras
* ...

We will use TFLayers (TFSlim is also a very good choice, especially for larger
networks), since it is a somewhat thinner wrapper around TensorFlow than Slim.

#### The Model Function

```python
def model(input):
    """
        This function creates a CNN with two convolution/pooling pairs, followed by two dense layers.
        These are then used to predict one of ten digit classes.
        
        Arguments:
            input: a tensor with shape `[batch_size, 28, 28, 1]` representing MNIST data.
        
        Returns:
            A dictionary with the keys `probabilities`, `class`, and `logits`, containing the 
            corresponding tensors.
    """
    
    # we assume the input has shape [batch_size, 28, 28, 1]
    net = input
    
    # create two convolution/pooling layers
    for i in range(1, 3):
        net = tf.layers.conv2d(inputs=net,
                               filters=32 * i,
                               kernel_size=[5, 5],
                               padding="same",
                               activation=tf.nn.relu,
                               name="conv2d_%d" % i)
        net = tf.layers.max_pooling2d(inputs=net,
                                      pool_size=[2, 2],
                                      strides=2,
                                      name="maxpool_%d" % i)
    # flatten the input to [batch_size, 7 * 7 * 64]
    net = tf.reshape(net, [-1, 7 * 7 * 64])
    net = tf.layers.dense(net, units=128, name="dense_1")
    logits = tf.layers.dense(net, units=10, name="dense_2")
    # logits has shape [batch_size, 10]
    
    # The predictions of our model; we return the logits to formulate a numerically
    # stable loss in our optimization routine
    tensors = {
        "probabilities": tf.nn.softmax(logits),
        "class": tf.argmax(logits, axis=-1),
        "logits": logits
    }
    return tensors
```

This is the core of the model. We could now use it like this:

```python
def classify_image(img):
    input_image = tf.placeholder(...)
    outputs = model(input_image)
    with tf.Session() as sess:
        # initialize model etc. ...
        return sess.run(outputs["class"], feed_dict: {input_image: img})
```
But the strength of this approach is that we can also use different ways to feed
images to the model. Before we get to that, we need to define an optimizer and
the corresponding loss:

```python
def training_model(input, label):
    tensors = model(input)
    logits = tensors["logits"]
    
    # one-hot encode the labels, compute cross-entropy loss, average
    # over the number of elements in the mini-batch
    with tf.name_scope("loss"):
        label = tf.one_hot(label, 10)
        loss = tf.nn.softmax_cross_entropy_with_logits(labels=label, logits=logits)
        loss = tf.reduce_mean(loss)
    tensors["loss"] = loss
        
    # create the optimizer and register the global step counter with it,
    # it is increased every time the optimization step is executed
    optimizer = tf.train.AdamOptimizer(learning_rate=1e-3)
    global_step = tf.train.get_or_create_global_step()
    tensors["opt_step"] = optimizer.minimize(loss, global_step=global_step)
    return tensors
```

We are almost there now. The only thing to create a proper training procedure is
data. The next part deals with loading data, but feel free to skip any details.

### Loading Data
Starting with version 1.3, TensorFlow ships with a powerful dataset API that
allows you to quickly manipulate and load datasets with multi-threading support.
The API's design has a functional flavor and should be familiar to anyone who
has programmed with LINQ in C#, Haskell, or another functional programming
language. A dataset can then be thought of as a process producing data points
sequentially.

Our data is split in testing and training data. Each digit class has its own
subfolder in which each image is stored as a PNG file. For both training and
testing sets, a file containing a list of the relative paths to all of these
files has been created. We will proceed as follows:

* In Python code, we will read that list, construct the labels from it, and
shuffle them once
* Using the dataset API, we construct a dataset from the list of datapoints by
splitting it into two lists and calling `Dataset.from_tensor_slices` on it.
* This dataset now contains pairs of relative file paths and class labels. These
are already tensors, and from here on no Python code will touch this data during
runtime.
* For training, this dataset is repeated indefinitely (`repeat(-1)`) and
shuffled again internally by randomly picking one of the next 10000 data points
(`shuffle(10000)`)
* In all cases, we use `Dataset.map` to apply an operation to each element of
the dataset: In our case, this operation reads the file at the given path,
decodes it as a PNG, and casts it to a float. Note that the call is
`map(read_image)`, but `read_image` here is only the Python function that
*constructs* the operation that is applied to each image. Note also that we are
using 4 threads to load the images in parallel and keep up to `100 * batch_size`
many images ready.
* For the training dataset, we batch the specified number of datapoints

For MNIST, this is of course overkill, since the dataset would actually fit into
memory in its entirety. Also, if this approach here is used, it would probably
be faster to *not* load the list-file into memory at once: Either use a file
format that is able to store not only the images but also the labels, or
reconstruct the labels from the file paths using pure TensorFlow code at run
time.

```python
def load_data_set(is_training=True):
    """
        Loads either the training or evaluation dataset by performing the following steps:
        1. Read the file containing the file paths of the images.
        2. Construct the correct labels from the file paths.
        3. Shuffle paths jointly with the labels.
        4. Turn them into a dataset of tuples.
        
        Arguments:
            is_training: whether to load the training dataset or the evaluation dataset
        
        Returns:
            The requested dataset as a dataset containing tuples `(relative_path, label)`.
    """
    substring = "training" if is_training else "testing"
    file = "mnist_%s.dataset" % substring
    
    # this converts the file names into (file_name, class) tuples
    offset = len('mnist_data/%s/c' % substring)
    data_points = []
    with open(file, 'r') as f:
        for line in f:
            cls = int(line[offset])
            path = abspath(line.strip())
            data_points.append((path, cls))
            
    # now shuffle all data points around and create a dataset from it
    from random import shuffle
    shuffle(data_points)
    
    # Neat fact: zip can be used to build its own inverse:
    data_points = zip(*data_points)
    
    # note how this is a tensor of strings! Tensors are not inherently numeric!
    images = tf.constant(data_points[0])
    labels = tf.constant(data_points[1])
    
    # `from_tensor_slices` takes a tuple of tensors slices them along the first
    # dimension. Thus we get a dataset of tuples.
    return tf.contrib.data.Dataset.from_tensor_slices((images, labels))

def read_image(img_path, label):
    """
        Constructs operations to turn the path to an image to the actual image data.
        
        Arguments:
            img_path: The path to the image.
            label: The label for the image.
        
        Returns:
            A tuple `(img, label)`, where `img` is the loaded image.
    """
    img_content = tf.read_file(img_path)
    img = tf.image.decode_png(img_content, channels=1)
    img = tf.image.convert_image_dtype(img, tf.float32)
    return img, label

def make_training_dataset(batch_size=128):
    """
        Creates a training dataset with the given batch size.
    """
    dataset = load_data_set(is_training=True)
    dataset = dataset.repeat(-1)
    dataset = dataset.shuffle(10000)
    dataset = dataset.map(read_image,
                          num_threads=4,
                          output_buffer_size=100 * batch_size)
    dataset = dataset.batch(batch_size)
    return dataset

def make_eval_dataset(batch_size=128):
    """
        Creates the evaluation dataset.
    """
    dataset = load_data_set(is_training=False)
    dataset = dataset.map(read_image,
                          num_threads=4,
                          output_buffer_size=100 * batch_size)
    dataset = dataset.batch(batch_size)
    return dataset
```

### Training the Model
Finally, we get to train the model. Most of the steps should be familiar by now.
Note here how the dataset is accessed: We create an iterator from the dataset
and call `get_next` on it to receive a tuple of tensors that represent the next
images and labels of the input. Again, **calling `get_next` does not execute
anything**: Only by passing these tensors to the model we force their evaluation
when the model is run, which is when the data is actually fetched from the input
dataset.

```python
def perform_training(steps, batch_size):
    dataset = make_training_dataset(batch_size)
    # The one-shot iterator is just another node in the graph, and so is the
    # `get_next` operation. The tensors produced by `get_next` depend on the
    # structure of the dataset that we build: Our dataset consists of tuples,
    # so we get a tuple of tensors.
    next_image, next_label = dataset.make_one_shot_iterator().get_next()   
    model_outputs = training_model(next_image, next_label)
    
    loss = model_outputs["loss"]
    opt_step = model_outputs["opt_step"]
    with tf.Session() as sess:
        sess.run(tf.global_variables_initializer())
        
        for i in xrange(steps):
            # Note how we no longer need to use the `feed_dict`. This avoids
            # additional overhead due to Python -> native Tensorflow
            # serialization
            _, loss_value = sess.run((opt_step, loss))
            
            if i % 5 == 0:
                print("Loss: %f" % loss_value)
        print("Final Loss: %f" % loss_value)
```

![Training Graph](/img/2017-12-12-tensorflow-intro/training_graph.png){: .center-image}

We can now train the model for a few steps and watch the loss go down. I have
added a bit of visualization code to the `perform_training` function from above,
so the signature has changed slightly, but the code is essentially the same:

```python
tutorial.perform_training_with_visualization(steps=500, batch_size=128,
                                             dataset=make_training_dataset,
                                             model=training_model)
```
```
<IPython.core.display.Javascript object>
```



<img src="data:image/png;base64,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" width="640">

```
Final Loss: 0.059373
```


#### Saving and Loading Models
The training code form above still has an obvious problem: It does not save the
weights it has learned. Once the session is closed, all variables are lost.
TensorFlow models are stored in two parts:

1. You can save the whole computation graph as a *metagraph* file. This writes
the structure of the computation graph into a file that can be reimported later.
If you are familiar with caffe: This corresponds to saving a protobuf definition
of your network. **I generally want to discourage this:** Instead of saving the
metagraph, save the Python code that creates your model. Metagraphs are stored
as binary protobufs, which makes them hard to read for humans, and even harder
to modify. Avoid getting into a situation in which a metagraph is the only way
to rebuild the computation graph of your model. If you are still interested in
metagraphs, check the [TensorFlow
documentation](https://www.tensorflow.org/api_guides/python/meta_graph).

2. The values of variables of a model can be saved in a *checkpoint*. This is
what we will be using to store the state of our model. By default, all variables
in your model's graph are saved, but you can also select a subset. Generally,
what you need to save depends on your use-case: If you are storing a checkpoint
to resume training later on, you will want to also save the variables introduced
by the optimizer. If you are storing a checkpoint to load it for inference, you
can drop all of that.

Saving a checkpoint for a model works by using `tf.train.Saver` and its
associated `save` and `restore` methods:
```python
    saver = tf.train.Saver(variables_to_save)
    with tf.Session() as sess:
        sess.run(tf.global_variables_initializer())
        saver.restore(sess, "checkpoint-file-to-restore-from")
        # your code here
        saver.save(sess, "checkpoint-file-to-save-to")
```
Here is a revised training method that supports saving. It uses
`get_variables_for_saver` from the accompanying `tutorial.py` file to filter the
variables of the model according to regular expressions.

```python
def perform_training(steps, batch_size, checkpoint_name):
    dataset = make_training_dataset(batch_size)
    next_image, next_label = dataset.make_one_shot_iterator().get_next()   
    model_outputs = training_model(next_image, next_label)
    
    loss = model_outputs["loss"]
    opt_step = model_outputs["opt_step"]
    
    # We exclude some variables created by the optimizer and data loading process
    # when saving the model, since we assume that we do not want to continue training
    # from the checkpoint.
    variables_to_save = tutorial.get_variables_for_saver(exclude=[".*Adam", ".*beta", ".*Iterator"])
    saver = tf.train.Saver(variables_to_save)
    with tf.Session() as sess:
        sess.run(tf.global_variables_initializer())
        
        for i in xrange(steps):
            _, loss_value = sess.run((opt_step, loss))
        
        # In the end, we  will save the model
        saver.save(sess, checkpoint_name)
        print("Final Loss: %f" % loss_value)


tf.reset_default_graph()
perform_training(steps=100, batch_size=128,
                 checkpoint_name="model")
```
```
Final Loss: 0.060810
```

#### Building an Image Classifier
This can now be used to build an image classifier that takes the name of the
checkpoint with the variables and a list of images (as numpy arrays) and maps
them to a list of predictions:

```python
def image_classifier(checkpoint_name, *images):
    # note that we are deciding to feed the images one-by-one for simplicity
    input = tf.placeholder(name="input", shape=(1, 28, 28, 1), dtype="float32")
    tensors = model(input)
    
    saver = tf.train.Saver()
    with tf.Session() as sess:
        # Initialize all variables, since there may be variables in our graph that aren't
        # loaded form the checkpoint
        sess.run(tf.global_variables_initializer())
        saver.restore(sess, checkpoint_name)
        
        classes = []
        for i in images:
            cls = sess.run(tensors["class"], feed_dict={input: np.expand_dims(i, 0)})
            classes.append(cls[0])
        return classes
```

Let's give it a shot:

```python
def load_image_as_array(filepath):
    im = Image.open(abspath(filepath)).convert('L')
    (width, height) = im.size
    greyscale_map = list(im.getdata())
    greyscale_map = np.array(greyscale_map)
    greyscale_map = greyscale_map.reshape((height, width, 1))
    return greyscale_map


tf.reset_default_graph()
images = [
    "mnist_data/testing/c1/994.png",
    "mnist_data/testing/c8/606.png",
    "mnist_data/testing/c4/42.png"
]
classification = image_classifier("model", *map(load_image_as_array, images))
print("Classification: " + str(classification))
```
```
INFO:tensorflow:Restoring parameters from model
Classification: [1, 8, 4]
```

This is probably not the best way to turn this into a classifier for deployment,
but absolutely sufficient for development environments. There is detailed
documentation available on what is the proper way to do this, see for example
the [TensorFlow Serving documentation](https://www.tensorflow.org/serving/).

#### A Very Basic Evaluation
With all of this, we can build a minimal evaluation script that loads the
weights and keeps track of some metrics.
Tensorflow comes with support for some metrics, making it easy to track them. We
can write a simple wrapper around our model that tracks
* accuracy,
* number of false negatives, and
* number of false positives.
Each metric consists of an operation to update the metric and a tensor that
represents the value of the metric. The update-operation needs to be run in each
step of the evaluation.

```python
def evaluation_model(input, label):
    tensors = model(input)
    # Let's track some metrics like accuracy, false negatives, and false positives.
    # Each of them returns a tuple `(value, update_op)`. The value is, well, the value
    # of the metric, the update_op is the tensor that needs to be evaluated to update
    # the metric.
    accuracy, update_acc = tf.metrics.accuracy(label, tensors["class"])
    false_negatives, update_fn = tf.metrics.false_negatives(label, tensors["class"])
    false_positives, update_fp = tf.metrics.false_positives(label, tensors["class"])
    tensors["accuracy"] = accuracy
    tensors["false_negatives"] = false_negatives
    tensors["false_positives"] = false_positives
    # We can group the three metric updates into a single operation and run that instead.
    tensors["update_metrics"] = tf.group(update_acc, update_fn, update_fp)
    return tensors
```

Running the evaluation is very similar to running the training, but

* it uses the evaluation model and dataset,
* it loads the checkpoint created in the training procedure to get the correct
weights,
* instead of running the optimization operation, it just updates the metrics,
* it only goes over the input dataset once and stop once we processed all
samples,
* it outputs the metrics in the end.

```python
def perform_evaluation(checkpoint_name):
    # this is the same as in the training case, except that we are using the
    # evaluation dataset and model
    dataset = make_eval_dataset()
    next_image, next_label = dataset.make_one_shot_iterator().get_next()   
    model_outputs = evaluation_model(next_image, next_label)
    
    saver = tf.train.Saver()
    with tf.Session() as sess:
        # Initialize variables. This is really necessary here since the metrics
        # need to be initialized to sensible values. They are local variables,
        # meaning that they are not saved by default, which is why we need to run
        # `local_variables_initializer`.
        sess.run(tf.global_variables_initializer())
        sess.run(tf.local_variables_initializer())
        # restore the weights
        saver.restore(sess, checkpoint_name)
        
        update_metrics = model_outputs["update_metrics"]
        # feed the inputs until we run out of images
        while True:
            try:
                _ = sess.run(update_metrics)
            except tf.errors.OutOfRangeError: 
                # this happens when the iterator runs out of samples
                break
        
        # Get the final values of the metrics. Note that this call does not access the
        # `get_next` node of the dataset iterator, since these tensors can be evaluated
        # on their own and therefore don't cause the exception seen above to be triggered
        # again.
        accuracy = model_outputs["accuracy"]
        false_negatives = model_outputs["false_negatives"]
        false_positives = model_outputs["false_positives"]
        acc, fp, fn = sess.run((accuracy, false_negatives, false_positives))
        print("Accuracy: %f" % acc)
        print("False positives: %d" % fp)
        print("False negatives: %d" % fn)


tf.reset_default_graph()
perform_evaluation(checkpoint_name="model")
```
```
INFO:tensorflow:Restoring parameters from model
Accuracy: 0.963600
False positives: 39
False negatives: 10
```

### Monitoring Training and Visualizing Your Model
For the training in this notebook, we used a custom visualization using
`pyplot`. Tensorflow comes with its own tools that help you to monitor the
training process and visualize the computation graph (this is also what was used
to generate the graph drawings in this notebook).

There are two steps to monitoring your model:

1. Change the training script to create summaries of all the variables you want
to keep track of. All the relevant functions for this live in
`tensorflow.summary`. For example `tensorflow.summary.scalar(name, tensor)`
returns a tensor that when executed creates a summary that can be logged into
what is known as an *event file*. As such, the summary tensors must be evaluated
periodically and their results written to file.
2. Open TensorBoard to access the summaries from a web-interface.

For the first step, we will modify the training procedure such that we have two
different summary operations that are executed from time to time: In every
training step, we will keep a summary of the log. Additionally, we will write
out the input image and histograms of the softmax distribution and the logit
activations every few steps.

```python
def perform_training(steps, batch_size, checkpoint_name, logdir):
    dataset = make_training_dataset(batch_size)
    next_image, next_label = dataset.make_one_shot_iterator().get_next()   
    model_outputs = training_model(next_image, next_label)
    
    loss = model_outputs["loss"]
    opt_step = model_outputs["opt_step"]
    
    # generate summary tensors, but don't store them -- there's a better way
    frequent_summary = tf.summary.scalar("loss", loss)
    tf.summary.histogram("logits", model_outputs["logits"])
    tf.summary.histogram("probabilities", model_outputs["probabilities"])
    # only log one of the `batch_size` many images
    tf.summary.image("input_image", next_image, max_outputs=1)
    
    # merge all summary ops into a single operation
    infrequent_summary = tf.summary.merge_all()
    
    variables_to_save = tutorial.get_variables_for_saver(exclude=[".*Adam", ".*beta", ".*Iterator"])
    saver = tf.train.Saver(variables_to_save)
    
    # the summary writer will write the summaries to the specified log directory
    summary_writer = tf.summary.FileWriter(logdir=logdir, graph=tf.get_default_graph())
    with tf.Session() as sess:
        sess.run(tf.global_variables_initializer())
        
        for i in xrange(steps):
            # note that we explicitly ask for the evaluation of the summary ops
            if i % 10 == 0:
                _, summary = sess.run((opt_step, infrequent_summary))
            else:
                _, summary = sess.run((opt_step, frequent_summary))
            # ...and we also need to explicitly add them to the summary writer
            summary_writer.add_summary(summary, global_step=i)
        
        saver.save(sess, checkpoint_name)
        summary_writer.close()


tf.reset_default_graph()
# It's a good idea to keep the checkpoint and the event files in the same directory
perform_training(steps=5000,
                 batch_size=128,
                 checkpoint_name="training/model",
                 logdir="training")

tf.reset_default_graph()
perform_evaluation(checkpoint_name="training/model")
```
```
INFO:tensorflow:Restoring parameters from training/model
Accuracy: 0.991700
False positives: 7
False negatives: 3
```

To view the data, run TensorBoard and point it to the right directory:
`tensorboard --logdir training`, in our case.

**TensorBoard live demo here!**

## What Next?
If you are interested, I would be willing to prepare another session on multi-
GPU training with TensorFlow. This would most likely also cover some topics like
how to use the currently available profiling tools and whatever questions you
would like to get answers to.


## Further Reading
TensorFlow comes with a plethora of libraries that make life easier:

* [`tf.image`](https://www.tensorflow.org/api_docs/python/tf/image) has
functions that can be used for loading and augmenting images
* [`tf.contrib`](https://www.tensorflow.org/api_docs/python/tf/contrib) contains
all kinds of contributed code that is still subject to change
* [`tf.distributions`](https://www.tensorflow.org/api_docs/python/tf/distributions) contains code for sampling within your models
* [`tf.estimator`](https://www.tensorflow.org/api_docs/python/tf/estimator)
contains the Estimators API, which allows to quickly create, train, and execute
models with a SciKitLearn-like interface
* [`tf.losses`](https://www.tensorflow.org/api_docs/python/tf/losses) contains
common loss functions
* [`tf.nn`](https://www.tensorflow.org/api_docs/python/tf/nn) contains functions
that are suitable to build neural networks from scratch
* [`tf.profiler`](https://www.tensorflow.org/api_docs/python/tf/profiler)
contains profiling tools for TensorFlow models; these are still in development
but can already give you some good insights into what your model is doing
* [`tf.train`](https://www.tensorflow.org/api_docs/python/tf/train) contains
many features that take a high-level approach to training models. Take a look at
`MonitoredTrainingSession`, which automates checkpoint saving, writing
summaries, failure handling, etc.
*
[`tf.contrib.data`](https://www.tensorflow.org/api_docs/python/tf/contrib/data)
contains the dataset API that we have been using in this notebook. This API is
under very active development and should get even better over time :)
