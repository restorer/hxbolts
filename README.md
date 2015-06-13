[![BSD License](https://img.shields.io/badge/license-BSD-blue.svg?style=flat)](LICENSE)
[![Haxe 3](https://img.shields.io/badge/language-Haxe%203-orange.svg)](http://www.haxe.org)

# hxbolts

hxbolts is a port of a "tasks" component from java library named Bolts.
A task is kind of like a JavaScript Promise, but with different API.

hxbolts is not a binding to the java library, but pure-haxe cross-platform port.

Important note: original java library is about keeping long-running operations out of the UI thread,
but current version of hxbolts is more about transforming async callback hell into nice looking code.

# Tasks

To use all power of hxbolts, at first we need to *boltify* some existing function with callbacks.
For example, let we have a function:

```haxe
function doSomethingAsync(
    param : String,
    onSuccessCallback : Int -> Void,
    onFailureCallback : String -> Void,
    onCancelledCallback : Void -> Void
) : Void {
    ...
}
```

To *boltify* it create a `TaskCompletionSource`.
This object will let you create a new Task, and control whether it gets marked as finished or cancelled.
After you create a `Task`, you'll need to call `setResult`, `setError`, or `setCancelled` to trigger its continuations.

```haxe
function doSomethingAsyncTask(param : String) {
    var tcs = new TaskCompletionSource<Int>();

    doSomethingAsync(param, function(result : Int) : Void {
        tcs.setResult(result);
    }, function(failureReason : String) : Void {
        tcs.setError(failureReason);
    }, function() : Void {
        tcs.setCancelled();
    });

    return tcs.task;
}
```

That's all :) Now you can chain tasks together and do all async stuff in easy manner.

Another example:

```
function loadTextFromUrlAsync(url : String) : Task<String> {
    var tcs = new TaskCompletionSource<String>();
    var urlLoader = new URLLoader();

    var onLoaderComplete = function(_) : Void {
        tcs.setResult(Std.string(urlLoader.data));
    };

    var onLoaderError = function(e : Event) : Void {
        tcs.setError(e);
    };

    urlLoader.dataFormat = URLLoaderDataFormat.TEXT;
    urlLoader.addEventListener(Event.COMPLETE, onLoaderComplete);
    urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onLoaderError);
    urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoaderError);

    try {
        urlLoader.load(new URLRequest(url));
    } catch (e : Dynamic) {
        tcs.setError(e);
    }

    return tcs.task;
}
```

## The `continueWith` Method

Every `Task` has a method named `continueWith` which takes a continuation function, which called when the task is complete.
You can then inspect the task to check if it was successful and to get its result.

```haxe
loadTextFromUrlAsync("http://domain.tld").continueWith(function(task : Task<String>) : Nothing {
    if (task.isCancelled) {
        // the load was cancelled.
        // NB. loadTextFromUrlAsync() mentioned earlier is used just for illustration, actually it doesn't support cancelling.
    } else if (task.isFaulted) {
        // the load failed.
        var error : Dynamic = task.error;
    } else {
        // the text was loaded successfully.
        trace(task.result);
    }

    return null;
});
```

A continuation function **must** have a non-Void return type and **must** return a value.
If you don't want to do it, there is helper enum called `Nothing`.

Tasks are strongly-typed using generics, so getting the syntax right can be a little tricky at first.
Let's look closer at the types involved with an example.

```haxe
function getStringAsync() : Task<String> {
    // Let's suppose getIntAsync() returns a Task<Int>.
    return getIntAsync().continueWith(function(task : Task<Int>) : String {
        // This Continuation is a function which takes an Integer as input,
        // and provides a String as output. It must take an Integer because
        // that's what was returned from the previous Task.
        // The Task getIntAsync() returned is passed to this function for convenience.
        var number : Int = task.result;
        return 'The number = ${number}';
    });
}
```

In many cases, you only want to do more work if the previous task was successful, and propagate any errors or cancellations to be dealt with later.
To do this, use the `onSuccess` method instead of `continueWith`.

```haxe
loadTextFromUrlAsync("http://domain.tld").onSuccess(function(task : Task<String>) : Nothing {
    // the text was loaded successfully.
    trace(task.result);
    return null;
});
```

## Chaining Tasks Together

Tasks are a little bit magical, in that they let you chain them without nesting.
If you use `continueWithTask` instead of `continueWith`, then you can return a new task.
The task returned by `continueWithTask` will not be considered finished until the new task returned from within `continueWithTask` is.
This lets you perform multiple actions without incurring the pyramid code you would get with callbacks.
Likewise, `onSuccessTask` is a version of `onSuccess` that returns a new task.
So, use `continueWith`/`onSuccess` to do more synchronous work, or `continueWithTask`/`onSuccessTask` to do more asynchronous work.

```haxe
loadTextFromUrlAsync("http://domain.tld").onSuccessTask(function(task : Task<String>) : Task<Array<Int>> {
    return storeResultOnServerAndReturnResultCodeListAsync(task.result);
}).onSuccessTask(function(task : Task<Array<Int>>) : Task<String> {
    return loadTextFromUrlAsync("http://anotherdomain.tld/index.php?ret=" + task.result.join("-"));
}).onSuccessTask(function(task : Task<String>) : Task<CustomResultObject> {
    return storeAnotherResultOnServerAndReturnCustomResultObjectAsync(task.result);
}).onSuccess(function(task : Task<CustomResultObject>) : Nothing {
    // Everything is done!
    return null;
});
```

## Error Handling

By carefully choosing whether to call `continueWith` or `onSuccess`, you can control how errors are propagated in your application.
Using `continueWith` lets you handle errors by transforming them or dealing with them.
You can think of failed tasks kind of like throwing an exception.
In fact, if you throw an exception inside a continuation, the resulting task will be faulted with that exception.

```haxe
loadTextFromUrlAsync("http://domain.tld").onSuccessTask(function(task : Task<String>) : Task<Array<Int>> {
    // Force this callback to fail.
    throw "There was an error.";
}).onSuccessTask(function(task : Task<Array<Int>>) : Task<String> {
    // Now this continuation will be skipped.
    return loadTextFromUrlAsync("http://anotherdomain.tld/index.php?ret=" + task.result.join("-"));
}).continueWithTask(function(task : Task<String>) : Task<CustomResultObject> {
    if (task.isFaulted()) {
        // This error handler WILL be called.
        // The error will be "There was an error."
        // Let's handle the error by returning a new value.
        // The task will be completed with null as its value.
        return null;
    }

    // This will also be skipped.
    return storeAnotherResultOnServerAndReturnCustomResultObjectAsync(task.result);
}).onSuccess(function(task : Task<CustomResultObject>) : Nothing {
    // Everything is done! This gets called.
    // The task's result is null.
    return null;
});
```

It's often convenient to have a long chain of success callbacks with only one error handler at the end.

## Creating Tasks

You already know that tasks can be created using `TaskCompletionSource`.
But if you know the result of a task at the time it is created, there are some convenience methods you can use.

```haxe
var successful : Task<String> = Task.forResult("The good result.");
```

```haxe
var failed : Task<String>= Task.forError("An error message.");
```

> There is also `call` function that help you create tasks from straight blocks of code.
> `call` tries to execute its block immediately or at specified executor.
> However in current version of hxbolts it is not really usable due to missing of good background executors.

## Tasks in Series

Tasks are convenient when you want to do a series of tasks in a row, each one waiting for the previous to finish.
For example, imagine you want to delete all of the comments on your blog.

```haxe
findCommentsAsync({ post: 123 }).continueWithTask(function(resultTask : Task<Array<CommentInfo>>) : Task<Nothing> {
    // Create a trivial completed task as a base case.
    var task : Task<Nothing> = Task.forResult(null);

    for (commentInfo in resultTask.result) {
        // For each item, extend the task with a function to delete the item.
        task = task.continueWithTask(function(ignored : Task<Nothing>) : Task<Nothing> {
            // Return a task that will be marked as completed when the delete is finished.
            return deleteCommentAsync(commentInfo);
        });
    }

    return task;
}).continueWith(function(task : Task<Nothing>) : Nothing {
    if (task.isSuccessed) {
        // Every comment was deleted.
    }

    return null;
});
```

## Tasks in Parallel

You can also perform several tasks in parallel, using the `whenAll` method.
You can start multiple operations at once, and use `Task.whenAll` to create a new task that will be marked as completed when all of its input tasks are completed.
The new task will be successful only if all of the passed-in tasks succeed.
Performing operations in parallel will be faster than doing them serially, but may consume more system resources and bandwidth.

```haxe
findCommentsAsync({ post: 123 }).continueWithTask(function(resultTask : Task<Array<CommentInfo>>) : Task<Nothing> {
    // Collect one task for each delete into an array.
    var tasks = new Array<Task<Nothing>>();

    for (commentInfo in resultTask.result) {
        // Start this delete immediately and add its task to the list.
        tasks.push(deleteCommentAsync(commentInfo));
    }

    return Task.whenAll(tasks);
}).continueWith(function(task : Task<Nothing>) : Nothing {
    if (task.isSuccessed) {
        // Every comment was deleted.
    }

    return null;
});
```
