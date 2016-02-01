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

import hxbolts.executors.Executors;
import hxbolts.executors.TaskExecutor;

#if cpp
    import cpp.vm.Mutex;
#elseif neko
    import neko.vm.Mutex;
#elseif java
    import java.vm.Mutex;
#end

class Task<TResult> {
    private var _isCompleted : Bool;
    private var _isFaulted : Bool;
    private var _isCancelled : Bool;
    private var _result : Null<TResult>;
    private var _error : Dynamic;

    public var isCompleted(get, never) : Bool;
    public var isCancelled(get, never) : Bool;
    public var isFaulted(get, never) : Bool;
    public var isSuccessed(get, never) : Bool;
    public var result(get, never) : Null<TResult>;
    public var error(get, never) : Dynamic;

    private var continuations : Array<Task<TResult> -> Void>;

    #if (cpp || neko || java)
        private var mutex : Mutex;
    #end

    private function new() : Void {
        _isCompleted = false;
        _isFaulted = false;
        _isCancelled = false;
        _result = null;
        _error = null;
        continuations = [];

        #if (cpp || neko || java)
            mutex = new Mutex();
        #end
    }

    public function makeVoid() : Task<Void> {
        return continueWithTask(function(task : Task<TResult>) : Task<Void> {
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
        continuation : Task<Void> -> Task<Void>,
        ?executor : TaskExecutor
    ) : Task<Void> {
        var predicateContinuation = new Array<Task<Void> -> Task<Void>>();

        predicateContinuation.push(function(task : Task<Void>) : Task<Void> {
            if (predicate()) {
                return cast Task.forResult(null)
                    .onSuccessTask(continuation, executor)
                    .onSuccessTask(predicateContinuation[0], executor);
            }

            return cast Task.forResult(null);
        });

        return makeVoid().continueWithTask(predicateContinuation[0], executor);
    }

    public function continueWith<TContinuationResult>(
        continuation : Task<TResult> -> TContinuationResult,
        ?executor : TaskExecutor
    ) : Task<TContinuationResult> {
        if (executor == null) {
            executor = Executors.IMMEDIATE_EXECUTOR;
        }

        var tcs = new TaskCompletionSource<TContinuationResult>();

        #if (cpp || neko || java)
            mutex.acquire();
            var wasCompleted = _isCompleted;

            if (!wasCompleted) {
                continuations.push(function(task : Task<TResult>) : Void {
                    completeImmediately(tcs, continuation, task, executor);
                });
            }

            mutex.release();

            if (wasCompleted) {
                completeImmediately(tcs, continuation, this, executor);
            }
        #else
            if (_isCompleted) {
                completeImmediately(tcs, continuation, this, executor);
            } else {
                continuations.push(function(task : Task<TResult>) : Void {
                    completeImmediately(tcs, continuation, task, executor);
                });
            }
        #end

        return tcs.task;
    }

    public function continueWithTask<TContinuationResult>(
        continuation : Task<TResult> -> Task<TContinuationResult>,
        ?executor : TaskExecutor
    ) : Task<TContinuationResult> {
        if (executor == null) {
            executor = Executors.IMMEDIATE_EXECUTOR;
        }

        var tcs = new TaskCompletionSource<TContinuationResult>();

        #if (cpp || neko || java)
            mutex.acquire();
            var wasCompleted = _isCompleted;

            if (!wasCompleted) {
                continuations.push(function(task : Task<TResult>) : Void {
                    completeAfterTask(tcs, continuation, task, executor);
                });
            }

            mutex.release();

            if (wasCompleted) {
                completeAfterTask(tcs, continuation, this, executor);
            }
        #else
            if (_isCompleted) {
                completeAfterTask(tcs, continuation, this, executor);
            } else {
                continuations.push(function(task : Task<TResult>) : Void {
                    completeAfterTask(tcs, continuation, task, executor);
                });
            }
        #end

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

    // caller function must guard call to runContinuations with mutex
    private function runContinuations() : Void {
        for (continuation in continuations) {
            // do not catch exceptions here
            continuation(this);
        }

        continuations = null;
    }

    @:noCompletion
    private function get_isCompleted() : Bool {
        #if (cpp || neko || java)
            mutex.acquire();
            var ret : Bool = _isCompleted;
            mutex.release();
            return ret;
        #else
            return _isCompleted;
        #end
    }

    @:noCompletion
    private function get_isCancelled() : Bool {
        #if (cpp || neko || java)
            mutex.acquire();
            var ret : Bool = _isCancelled;
            mutex.release();
            return ret;
        #else
            return _isCancelled;
        #end
    }

    @:noCompletion
    private function get_isFaulted() : Bool {
        #if (cpp || neko || java)
            mutex.acquire();
            var ret : Bool = _isFaulted;
            mutex.release();
            return ret;
        #else
            return _isFaulted;
        #end
    }

    @:noCompletion
    private function get_isSuccessed() : Bool {
        #if (cpp || neko || java)
            mutex.acquire();
            var ret : Bool = (_isCompleted && !_isFaulted && !_isCancelled);
            mutex.release();
            return ret;
        #else
            return (_isCompleted && !_isFaulted && !_isCancelled);
        #end
    }

    @:noCompletion
    private function get_result() : Null<TResult> {
        #if (cpp || neko || java)
            mutex.acquire();
            var ret : Null<TResult> = _result;
            mutex.release();
            return ret;
        #else
            return _result;
        #end
    }

    @:noCompletion
    private function get_error() : Dynamic {
        #if (cpp || neko || java)
            mutex.acquire();
            var ret : Dynamic = _error;
            mutex.release();
            return ret;
        #else
            return _error;
        #end
    }

    public static function forResult<TResult>(value : Null<TResult>) : Task<TResult> {
        var tcs = new TaskCompletionSource<TResult>();
        tcs.setResult(value);
        return tcs.task;
    }

    public static function forError<TResult>(value : Dynamic) : Task<TResult> {
        var tcs = new TaskCompletionSource<TResult>();
        tcs.setError(value);
        return tcs.task;
    }

    public static function cancelled<TResult>() : Task<TResult> {
        var tcs = new TaskCompletionSource<TResult>();
        tcs.setCancelled();
        return tcs.task;
    }

    public static function call<TResult>(callable : Void -> Null<TResult>, ?executor : TaskExecutor) : Task<TResult> {
        if (executor == null) {
            executor = Executors.IMMEDIATE_EXECUTOR;
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

        #if (cpp || neko || java)
            var valMutex : Mutex = new Mutex();
        #end

        for (t in tasks) {
            t.continueWith(function(task : Task<TResult>) : Void {
                #if (cpp || neko || java)
                    var val = false;
                    valMutex.acquire();

                    if (!isAnyTaskComplete) {
                        isAnyTaskComplete = true;
                        val = true;
                    }

                    valMutex.release();

                    if (val) {
                        firstCompleted.setResult(task);
                    }
                #else
                    if (!isAnyTaskComplete) {
                        isAnyTaskComplete = true;
                        firstCompleted.setResult(task);
                    }
                #end
            });
        }

        return firstCompleted.task;
    }

    public static function whenAll(tasks : Array<Task<Dynamic>>) : Task<Void> {
        if (tasks.length == 0) {
            return cast Task.forResult(null);
        }

        var allFinished = new TaskCompletionSource<Void>();
        var causes = new Array<Dynamic>();
        var count = tasks.length;
        var isAnyCancelled = false;

        #if (cpp || neko || java)
            var valMutex : Mutex = new Mutex();
        #end

        for (t in tasks) {
            t.continueWith(function(task : Task<Dynamic>) : Void {
                if (task.isFaulted) {
                    #if (cpp || neko || java)
                        valMutex.acquire();
                        causes.push(task.error);
                        valMutex.release();
                    #else
                        causes.push(task.error);
                    #end
                }

                if (task.isCancelled) {
                    #if (cpp || neko || java)
                        valMutex.acquire();
                        isAnyCancelled = true;
                        valMutex.release();
                    #else
                        isAnyCancelled = true;
                    #end
                }

                #if (cpp || neko || java)
                    valMutex.acquire();
                    count--;
                    var val = (count == 0);
                    valMutex.release();

                    if (val) {
                        if (causes.length != 0) {
                            allFinished.setError(causes);
                        } else {
                            valMutex.acquire();
                            val = isAnyCancelled;
                            valMutex.release();

                            if (val) {
                                allFinished.setCancelled();
                            } else {
                                allFinished.setResult(null);
                            }
                        }
                    }
                #else
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
                #end
            });
        }

        return allFinished.task;
    }

    public static function whenAllResult<TResult>(tasks : Array<Task<TResult>>) : Task<Array<Null<TResult>>> {
        return whenAll(tasks).onSuccess(function(task : Task<Void>) : Array<Null<TResult>> {
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
                    resultTask.continueWith(function(task : Task<TContinuationResult>) : Void {
                        if (task.isFaulted) {
                            tcs.setError(task.error);
                        } else if (task.isCancelled) {
                            tcs.setCancelled();
                        } else {
                            tcs.setResult(task.result);
                        }
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
