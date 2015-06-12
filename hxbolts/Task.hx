/*
 *  Original java implementation:
 *  Copyright (c) 2014, Facebook, Inc.
 *  All rights reserved.
 *
 *  Haxe version:
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the original project repo:
 *  https://github.com/BoltsFramework/Bolts-Android/
 *
 */
package hxbolts;

class Task<TResult> {
    public static var IMMEDIATE_EXECUTOR(default, null) : TaskExecutor = new ImmediateTaskExecutor();

    public var isCompleted(default, null) : Bool;
    public var isCancelled(default, null) : Bool;
    public var isFaulted(get, never) : Bool;
    public var result(default, null) : Null<TResult>;
    public var error(default, null) : Dynamic;

    private var continuations : Array<Task<TResult> -> Nothing>;

    private function new() : Void {
        isCompleted = false;
        isCancelled = false;
        result = null;
        error = null;
        continuations = [];
    }

    public function makeNothing() : Task<Nothing> {
        return continueWithTask(function(task : Task<TResult>) : Task<Nothing> {
            if (task.isCancelled) {
                return cast Task.cancelled();
            }

            if (task.isFaulted) {
                return cast Task.forError(task.error);
            }

            return cast Task.forResult(null);
        });
    }

    public function continueWhile(
        predicate : Void -> Bool,
        continuation : Task<Nothing> -> Task<Nothing>,
        ?executor : TaskExecutor
    ) : Task<Nothing> {
        var predicateContinuation = new Array<Task<Nothing> -> Task<Nothing>>();

        predicateContinuation.push(function(task : Task<Nothing>) : Task<Nothing> {
            if (predicate()) {
                return cast Task.forResult(null)
                    .onSuccessTask(continuation, executor)
                    .onSuccessTask(predicateContinuation[0], executor);
            }

            return cast Task.forResult(null);
        });

        return makeNothing().continueWithTask(predicateContinuation[0], executor);
    }

    public function continueWith<TContinuationResult>(
        continuation : Task<TResult> -> TContinuationResult,
        ?executor : TaskExecutor
    ) : Task<TContinuationResult> {
        if (executor == null) {
            executor = IMMEDIATE_EXECUTOR;
        }

        var tcs = new TaskCompletionSource<TContinuationResult>();

        if (isCompleted) {
            completeImmediately(tcs, continuation, this, executor);
        } else {
            continuations.push(function(task : Task<TResult>) : Nothing {
                completeImmediately(tcs, continuation, task, executor);
                return null;
            });
        }

        return tcs.task;
    }

    public function continueWithTask<TContinuationResult>(
        continuation : Task<TResult> -> Task<TContinuationResult>,
        ?executor : TaskExecutor
    ) : Task<TContinuationResult> {
        if (executor == null) {
            executor = IMMEDIATE_EXECUTOR;
        }

        var tcs = new TaskCompletionSource<TContinuationResult>();

        if (isCompleted) {
            completeAfterTask(tcs, continuation, this, executor);
        } else {
            continuations.push(function(task : Task<TResult>) : Nothing {
                completeAfterTask(tcs, continuation, task, executor);
                return null;
            });
        }

        return tcs.task;
    }

    public function onSuccess<TContinuationResult>(
        continuation : Task<TResult> -> TContinuationResult,
        ?executor : TaskExecutor
    ) : Task<TContinuationResult> {
        return continueWithTask(function(task : Task<TResult>) : Task<TContinuationResult> {
            if (task.isFaulted) {
                return cast Task.forError(task.error);
            } else if (task.isCancelled) {
                return cast Task.cancelled();
            } else {
                return task.continueWith(continuation);
            }
        }, executor);
    }

    public function onSuccessTask<TContinuationResult>(
        continuation : Task<TResult> -> Task<TContinuationResult>,
        ?executor : TaskExecutor
    ) : Task<TContinuationResult> {
        return continueWithTask(function(task : Task<TResult>) : Task<TContinuationResult> {
            if (task.isFaulted) {
                return cast Task.forError(task.error);
            } else if (task.isCancelled) {
                return cast Task.cancelled();
            } else {
                return task.continueWithTask(continuation);
            }
        }, executor);
    }

    private function runContinuations() : Void {
        for (continuation in continuations) {
            // do not catch exceptions here
            continuation(this);
        }

        continuations = null;
    }

    @:noCompletion
    private function get_isFaulted() : Bool {
        return (error != null);
    }

    public static function forResult<TResult>(value : Null<TResult>) : Task<TResult> {
        var tcs = new TaskCompletionSource<TResult>();
        tcs.setResult(value);
        return tcs.task;
    }

    public static function forError<TResult>(error : Dynamic) : Task<TResult> {
        var tcs = new TaskCompletionSource<TResult>();
        tcs.setError(error);
        return tcs.task;
    }

    public static function cancelled<TResult>() : Task<TResult> {
        var tcs = new TaskCompletionSource<TResult>();
        tcs.setCancelled();
        return tcs.task;
    }

    public static function call<TResult>(callable : Void -> Null<TResult>, ?executor : TaskExecutor) : Task<TResult> {
        if (executor == null) {
            executor = IMMEDIATE_EXECUTOR;
        }

        var tcs = new TaskCompletionSource<TResult>();

        executor.execute(function() : Void {
            try {
                tcs.setResult(callable());
            } catch (e : TaskCancellationException) {
                tcs.setCancelled();
            } catch (e : Dynamic) {
                tcs.setError(e);
            }
        });

        return tcs.task;
    }

    public static function whenAny<TResult>(tasks : Array<Task<TResult>>) : Task<Task<TResult>> {
        if (tasks.length == 0) {
            return cast Task.forResult(null);
        }

        var firstCompleted = new TaskCompletionSource<Task<TResult>>();
        var isAnyTaskComplete : Bool = false;

        for (t in tasks) {
            t.continueWith(function(task : Task<TResult>) : Nothing {
                if (!isAnyTaskComplete) {
                    isAnyTaskComplete = true;
                    firstCompleted.setResult(task);
                }

                return null;
            });
        }

        return firstCompleted.task;
    }

    public static function whenAll(tasks : Array<Task<Dynamic>>) : Task<Nothing> {
        if (tasks.length == 0) {
            return cast Task.forResult(null);
        }

        var allFinished = new TaskCompletionSource<Nothing>();
        var causes = new Array<Dynamic>();
        var count = tasks.length;
        var isAnyCancelled = false;

        for (t in tasks) {
            t.continueWith(function(task : Task<Dynamic>) : Nothing {
                if (task.isFaulted) {
                    causes.push(task.error);
                }

                if (task.isCancelled) {
                    isAnyCancelled = true;
                }

                count--;

                if (count == 0) {
                    if (causes.length != 0) {
                        allFinished.setError(causes);
                    } else if (isAnyCancelled) {
                        allFinished.setCancelled();
                    } else {
                        allFinished.setResult(null);
                    }
                }

                return null;
            });
        }

        return allFinished.task;
    }

    public static function whenAllResult<TResult>(tasks : Array<Task<TResult>>) : Task<Array<Null<TResult>>> {
        return whenAll(tasks).onSuccess(function(task : Task<Nothing>) : Array<Null<TResult>> {
            var results = new Array<Null<TResult>>();

            for (t in tasks) {
                results.push(t.result);
            }

            return results;
        });
    }

    private static function completeImmediately<TContinuationResult, TResult>(
        tcs : TaskCompletionSource<TContinuationResult>,
        continuation : Task<TResult> -> TContinuationResult,
        task : Task<TResult>,
        executor : TaskExecutor
    ) : Void {
        executor.execute(function() : Void {
            try {
                tcs.setResult(continuation(task));
            } catch (e : TaskCancellationException) {
                tcs.setCancelled();
            } catch (e : Dynamic) {
                tcs.setError(e);
            }
        });
    }

    private static function completeAfterTask<TContinuationResult, TResult>(
        tcs : TaskCompletionSource<TContinuationResult>,
        continuation : Task<TResult> -> Task<TContinuationResult>,
        task : Task<TResult>,
        executor : TaskExecutor
    ) : Void {
        executor.execute(function() : Void {
            try {
                var resultTask = continuation(task);

                if (resultTask == null) {
                    tcs.setResult(null);
                } else {
                    resultTask.continueWith(function(task : Task<TContinuationResult>) : Nothing {
                        if (task.isFaulted) {
                            tcs.setError(task.error);
                        } else if (task.isCancelled) {
                            tcs.setCancelled();
                        } else {
                            tcs.setResult(task.result);
                        }

                        return null;
                    });
                }
            } catch (e : TaskCancellationException) {
                tcs.setCancelled();
            } catch (e : Dynamic) {
                tcs.setError(e);
            }
        });
    }
}
