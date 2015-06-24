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
package ;

import hxbolts.Task;
import hxbolts.TaskCompletionSource;
import hxbolts.TaskCancellationException;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import util.TestException;
import util.TimerExecutor;

class TaskTest {
    public function new() : Void {
    }

    @Test
    public function testPrimitives() : Void {
        var complete : Task<Int> = Task.forResult(5);
        var error : Task<Int> = Task.forError(new TestException());
        var cancelled : Task<Int> = Task.cancelled();

        Assert.isTrue(complete.isCompleted);
        Assert.areEqual(5, complete.result);
        Assert.isFalse(complete.isFaulted);
        Assert.isFalse(complete.isCancelled);
        Assert.isTrue(complete.isSuccessed);

        Assert.isTrue(error.isCompleted);
        Assert.isType(error.error, TestException);
        Assert.isTrue(error.isFaulted);
        Assert.isFalse(error.isCancelled);
        Assert.isFalse(error.isSuccessed);

        Assert.isTrue(cancelled.isCompleted);
        Assert.isFalse(cancelled.isFaulted);
        Assert.isTrue(cancelled.isCancelled);
        Assert.isFalse(cancelled.isSuccessed);
    }

    @Test
    public function testSynchronousContinuation() : Void {
        var complete : Task<Int> = Task.forResult(5);
        var error : Task<Int> = Task.forError(new TestException());
        var cancelled : Task<Int> = Task.cancelled();

        var completeHandled : Bool = false;
        var errorHandled : Bool = false;
        var cancelledHandled : Bool = false;

        complete.continueWith(function(task : Task<Int>) : Void {
            Assert.areSame(complete, task);

            Assert.isTrue(task.isCompleted);
            Assert.areEqual(5, task.result);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isTrue(task.isSuccessed);

            completeHandled = true;
        });

        error.continueWith(function(task : Task<Int>) : Void {
            Assert.areSame(error, task);

            Assert.isTrue(task.isCompleted);
            Assert.isType(task.error, TestException);
            Assert.isTrue(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isFalse(task.isSuccessed);

            errorHandled = true;
        });

        cancelled.continueWith(function(task : Task<Int>) : Void {
            Assert.areSame(cancelled, task);

            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isTrue(task.isCancelled);
            Assert.isFalse(task.isSuccessed);

            cancelledHandled = true;
        });

        Assert.isTrue(completeHandled);
        Assert.isTrue(errorHandled);
        Assert.isTrue(cancelledHandled);
    }

    @Test
    public function testSynchronousChaining() : Void {
        var first : Task<Int> = Task.forResult(1);

        var second : Task<Int> = first.continueWith(function(task : Task<Int>) : Int {
            return 2;
        });

        var third = second.continueWithTask(function(task : Task<Int>) : Task<Int> {
            return Task.forResult(3);
        });

        Assert.isTrue(first.isCompleted);
        Assert.isTrue(second.isCompleted);
        Assert.isTrue(third.isCompleted);

        Assert.areEqual(1, first.result);
        Assert.areEqual(2, second.result);
        Assert.areEqual(3, third.result);
    }

    @Test
    public function testSynchronousCancellation() : Void {
        var first : Task<Int> = Task.forResult(1);

        var second : Task<Int> = first.continueWith(function(task : Task<Int>) : Int {
            throw new TaskCancellationException();
        });

        Assert.isTrue(first.isCompleted);
        Assert.isTrue(second.isCancelled);
    }

    @Test
    public function testSynchronousTaskCancellation() : Void {
        var first : Task<Int> = Task.forResult(1);

        var second : Task<Int> = first.continueWithTask(function(task : Task<Int>) : Task<Int> {
            throw new TaskCancellationException();
        });

        Assert.isTrue(first.isCompleted);
        Assert.isTrue(second.isCancelled);
    }

    @AsyncTest
    public function testBackgroundCall(factory : AsyncFactory) : Void {
        var timerExecutor = new TimerExecutor(10);
        var task : Task<Int> = null;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.areEqual(5, task.result);
        }, 5000);

        Task.call(function() : Int {
            return 5;
        }, timerExecutor).continueWith(function(t : Task<Int>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testBackgroundError(factory : AsyncFactory) : Void {
        var timerExecutor = new TimerExecutor(10);
        var task : Task<Int> = null;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isFaulted);
            Assert.isType(task.error, TestException);
        }, 5000);

        Task.call(function() : Int {
            throw new TestException();
        }, timerExecutor).continueWith(function(t : Task<Int>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testBackgroundCancellation(factory : AsyncFactory) : Void {
        var timerExecutor = new TimerExecutor(10);
        var task : Task<Int> = null;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCancelled);
        }, 5000);

        Task.call(function() : Int {
            throw new TaskCancellationException();
        }, timerExecutor).continueWith(function(t : Task<Int>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testContinueOnTimerExecutor(factory : AsyncFactory) : Void {
        var timerExecutor = new TimerExecutor(10);
        var task : Task<Int> = null;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.areEqual(3, task.result);
        }, 5000);

        Task.call(function() : Int {
            return 1;
        }, timerExecutor).continueWith(function(t : Task<Int>) : Int {
            return t.result + 1;
        }, timerExecutor).continueWithTask(function(t : Task<Int>) : Task<Int> {
            return Task.forResult(t.result + 1);
        }, timerExecutor).continueWith(function(t : Task<Int>) : Void {
            task = t;
            handler();
        });
    }

    @Test
    public function testWhenAllNoTasks() : Void {
        var task : Task<Void> = Task.whenAll(new Array<Task<Void>>());

        Assert.isTrue(task.isCompleted);
        Assert.isFalse(task.isFaulted);
        Assert.isFalse(task.isCancelled);
        Assert.isTrue(task.isSuccessed);
    }

    @AsyncTest
    public function testWhenAnyResultFirstSuccess(factory : AsyncFactory) : Void {
        var task : Task<Task<Int>> = null;
        var tasks = new Array<Task<Int>>();

        var firstToCompleteSuccess = Task.call(function() : Int {
            return 2000;
        }, new TimerExecutor(50));

        addTasksWithRandomCompletions(tasks, 5);
        tasks.push(firstToCompleteSuccess);
        addTasksWithRandomCompletions(tasks, 5);

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isTrue(task.isSuccessed);

            Assert.areSame(firstToCompleteSuccess, task.result);

            Assert.isTrue(task.result.isCompleted);
            Assert.isFalse(task.result.isFaulted);
            Assert.isFalse(task.result.isCancelled);
            Assert.isTrue(task.result.isSuccessed);

            Assert.areEqual(2000, task.result.result);
        }, 5000);

        Task.whenAny(tasks).continueWith(function(t : Task<Task<Int>>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testWhenAnyFirstSuccess(factory : AsyncFactory) : Void {
        var task : Task<Task<Dynamic>> = null;
        var tasks = new Array<Task<Dynamic>>();

        var firstToCompleteSuccess = Task.call(function() : String {
            return "SUCCESS";
        }, new TimerExecutor(50));

        addTasksWithRandomCompletions(tasks, 5);
        tasks.push(firstToCompleteSuccess);
        addTasksWithRandomCompletions(tasks, 5);

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isTrue(task.isSuccessed);

            Assert.areSame(firstToCompleteSuccess, task.result);

            Assert.isTrue(task.result.isCompleted);
            Assert.isFalse(task.result.isFaulted);
            Assert.isFalse(task.result.isCancelled);
            Assert.isTrue(task.result.isSuccessed);

            Assert.areEqual("SUCCESS", task.result.result);
        }, 5000);

        Task.whenAny(tasks).continueWith(function(t : Task<Task<Dynamic>>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testWhenAnyFirstError(factory : AsyncFactory) : Void {
        var task : Task<Task<Dynamic>> = null;
        var error = new TestException();
        var tasks = new Array<Task<Dynamic>>();

        var firstToCompleteError = Task.call(function() : String {
            throw error;
        }, new TimerExecutor(50));

        addTasksWithRandomCompletions(tasks, 5);
        tasks.push(firstToCompleteError);
        addTasksWithRandomCompletions(tasks, 5);

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isTrue(task.isSuccessed);

            Assert.areSame(firstToCompleteError, task.result);

            Assert.isTrue(task.result.isCompleted);
            Assert.isTrue(task.result.isFaulted);
            Assert.isFalse(task.result.isCancelled);
            Assert.isFalse(task.result.isSuccessed);

            Assert.areSame(error, task.result.error);
        }, 5000);

        Task.whenAny(tasks).continueWith(function(t : Task<Task<Dynamic>>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testWhenAnyFirstCancelled(factory : AsyncFactory) : Void {
        var task : Task<Task<Dynamic>> = null;
        var tasks = new Array<Task<Dynamic>>();

        var firstToCompleteError = Task.call(function() : String {
            throw new TaskCancellationException();
        }, new TimerExecutor(50));

        addTasksWithRandomCompletions(tasks, 5);
        tasks.push(firstToCompleteError);
        addTasksWithRandomCompletions(tasks, 5);

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isTrue(task.isSuccessed);

            Assert.areSame(firstToCompleteError, task.result);

            Assert.isTrue(task.result.isCompleted);
            Assert.isFalse(task.result.isFaulted);
            Assert.isTrue(task.result.isCancelled);
            Assert.isFalse(task.result.isSuccessed);
        }, 5000);

        Task.whenAny(tasks).continueWith(function(t : Task<Task<Dynamic>>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testWhenAllSuccess(factory : AsyncFactory) : Void {
        var task : Task<Void> = null;
        var tasks = new Array<Task<Void>>();

        for (i in 0 ... 20) {
            tasks.push(Task.call(function() : Void {
                // do nothing
            }, new TimerExecutor(randomInt(10, 50))));
        }

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isTrue(task.isSuccessed);

            for (t in tasks) {
                Assert.isTrue(t.isCompleted);
            }
        }, 5000);

        Task.whenAll(tasks).continueWith(function(t : Task<Void>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testWhenAllOneError(factory : AsyncFactory) : Void {
        var task : Task<Void> = null;
        var error = new TestException();
        var tasks = new Array<Task<Void>>();

        for (i in 0 ... 20) {
            tasks.push(Task.call(function() : Void {
                if (i == 10) {
                    throw error;
                }
            }, new TimerExecutor(randomInt(10, 50))));
        }

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isTrue(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isFalse(task.isSuccessed);

            Assert.isType(task.error, Array);
            Assert.areEqual((cast task.error:Array<Dynamic>).length, 1);
            Assert.areSame((cast task.error:Array<Dynamic>)[0], error);

            for (t in tasks) {
                Assert.isTrue(t.isCompleted);
            }
        }, 5000);

        Task.whenAll(tasks).continueWith(function(t : Task<Void>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testWhenAllTwoErrors(factory : AsyncFactory) : Void {
        var task : Task<Void> = null;
        var error0 = new TestException();
        var error1 = new TestException();
        var tasks = new Array<Task<Void>>();

        for (i in 0 ... 20) {
            tasks.push(Task.call(function() : Void {
                if (i == 10) {
                    throw error0;
                } else if (i == 11) {
                    throw error1;
                }
            }, new TimerExecutor(10 + i * 10)));
        }

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isTrue(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isFalse(task.isSuccessed);

            Assert.isType(task.error, Array);
            Assert.areEqual((cast task.error:Array<Dynamic>).length, 2);
            Assert.areSame((cast task.error:Array<Dynamic>)[0], error0);
            Assert.areSame((cast task.error:Array<Dynamic>)[1], error1);

            for (t in tasks) {
                Assert.isTrue(t.isCompleted);
            }
        }, 5000);

        Task.whenAll(tasks).continueWith(function(t : Task<Void>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testWhenAllCancel(factory : AsyncFactory) : Void {
        var task : Task<Void> = null;
        var tasks = new Array<Task<Void>>();

        for (i in 0 ... 20) {
            var tcs = new TaskCompletionSource<Void>();

            Task.call(function() : Void {
                if (i == 10) {
                    tcs.setCancelled();
                } else {
                    tcs.setResult(null);
                }
            }, new TimerExecutor(randomInt(10, 50)));

            tasks.push(tcs.task);
        }

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isTrue(task.isCancelled);
            Assert.isFalse(task.isSuccessed);

            for (t in tasks) {
                Assert.isTrue(t.isCompleted);
            }
        }, 5000);

        Task.whenAll(tasks).continueWith(function(t : Task<Void>) : Void {
            task = t;
            handler();
        });
    }

    @Test
    public function testWhenAllResultNoTasks() : Void {
        var task : Task<Array<Void>> = Task.whenAllResult(new Array<Task<Void>>());

        Assert.isTrue(task.isCompleted);
        Assert.isFalse(task.isFaulted);
        Assert.isFalse(task.isCancelled);
        Assert.isTrue(task.isSuccessed);

        Assert.areEqual(task.result.length, 0);
    }

    @AsyncTest
    public function testWhenAllResultSuccess(factory : AsyncFactory) : Void {
        var task : Task<Array<Int>> = null;
        var tasks = new Array<Task<Int>>();

        for (i in 0 ... 20) {
            tasks.push(Task.call(function() : Int {
                return (i + 1);
            }, new TimerExecutor(randomInt(10, 50))));
        }

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);
            Assert.isTrue(task.isSuccessed);

            Assert.areEqual(tasks.length, task.result.length);

            for (i in 0 ... tasks.length) {
                var t = tasks[i];
                Assert.isTrue(t.isCompleted);
                Assert.areEqual(t.result, task.result[i]);
            }
        }, 5000);

        Task.whenAllResult(tasks).continueWith(function(t : Task<Array<Int>>) : Void {
            task = t;
            handler();
        });
    }

    @AsyncTest
    public function testAsyncChaining(factory : AsyncFactory) : Void {
        var task : Task<Void> = null;
        var tasks = new Array<Task<Int>>();

        var sequence = new Array<Int>();
        var result : Task<Void> = Task.forResult(null);

        for (i in 0 ... 20) {
            result = result.continueWithTask(function(task : Task<Void>) : Task<Void> {
                return Task.call(function() : Void {
                    sequence.push(i);
                }, new TimerExecutor(randomInt(10, 50)));
            });
        }

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.areEqual(20, sequence.length);

            for (i in 0 ... 20) {
                Assert.areEqual(i, sequence[i]);
            }
        }, 5000);

        result.continueWith(function(t : Task<Void>) : Void {
            task = t;
            handler();
        });
    }

    @Test
    public function testOnSuccess() : Void {
        var continuation = function(task : Task<Int>) : Int {
            return task.result + 1;
        };

        var complete : Task<Int> = Task.forResult(5).onSuccess(continuation);
        var error : Task<Int> = Task.forError(new TestException()).onSuccess(continuation);
        var cancelled : Task<Int> = Task.cancelled().onSuccess(continuation);

        Assert.isTrue(complete.isCompleted);
        Assert.areEqual(6, complete.result);
        Assert.isFalse(complete.isFaulted);
        Assert.isFalse(complete.isCancelled);
        Assert.isTrue(complete.isSuccessed);

        Assert.isTrue(error.isCompleted);
        Assert.isType(error.error, TestException);
        Assert.isTrue(error.isFaulted);
        Assert.isFalse(error.isCancelled);
        Assert.isFalse(error.isSuccessed);

        Assert.isTrue(cancelled.isCompleted);
        Assert.isFalse(cancelled.isFaulted);
        Assert.isTrue(cancelled.isCancelled);
        Assert.isFalse(cancelled.isSuccessed);
    }

    @Test
    public function testOnSuccessTask() : Void {
        var continuation = function(task : Task<Int>) : Task<Int> {
            return Task.forResult(task.result + 1);
        };

        var complete : Task<Int> = Task.forResult(5).onSuccessTask(continuation);
        var error : Task<Int> = Task.forError(new TestException()).onSuccessTask(continuation);
        var cancelled : Task<Int> = Task.cancelled().onSuccessTask(continuation);

        Assert.isTrue(complete.isCompleted);
        Assert.areEqual(6, complete.result);
        Assert.isFalse(complete.isFaulted);
        Assert.isFalse(complete.isCancelled);
        Assert.isTrue(complete.isSuccessed);

        Assert.isTrue(error.isCompleted);
        Assert.isType(error.error, TestException);
        Assert.isTrue(error.isFaulted);
        Assert.isFalse(error.isCancelled);
        Assert.isFalse(error.isSuccessed);

        Assert.isTrue(cancelled.isCompleted);
        Assert.isFalse(cancelled.isFaulted);
        Assert.isTrue(cancelled.isCancelled);
        Assert.isFalse(cancelled.isSuccessed);
    }

    @Test
    public function testContinueWhile() : Void {
        var count : Int = 0;
        var handled : Bool = false;

        Task.forResult(null).continueWhile(function() : Bool {
            return (count < 10);
        }, function(task : Task<Void>) : Task<Void> {
            count++;
            return null;
        }).continueWith(function(task : Task<Void>) : Void {
            Assert.areEqual(10, count);
            handled = true;
        });

        Assert.isTrue(handled);
    }

    @AsyncTest
    public function testContinueWhileAsync(factory : AsyncFactory) : Void {
        var count : Int = 0;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.areEqual(10, count);
        }, 15000);

        Task.forResult(null).continueWhile(function() : Bool {
            return (count < 10);
        }, function(task : Task<Void>) : Task<Void> {
            count++;
            return null;
        }, new TimerExecutor(10)).continueWith(function(task : Task<Void>) : Void {
            handler();
        });
    }

    @Test
    public function testNullError() : Void {
        var error : Task<Int> = Task.forError(null);

        Assert.isTrue(error.isCompleted);
        Assert.areSame(error.error, null);
        Assert.isTrue(error.isFaulted);
        Assert.isFalse(error.isCancelled);
        Assert.isFalse(error.isSuccessed);
    }

    private function addTasksWithRandomCompletions(
        tasks : Array<Task<Dynamic>>,
        numberOfTasksToLaunch : Int,
        minDelay : Int = 100,
        maxDelay : Int = 200,
        minResult : Int = 0,
        maxResult : Int = 1000
    ) : Void {
        for (i in 0 ... numberOfTasksToLaunch) {
            tasks.push(Task.call(function() : Int {
                var rand : Float = Math.random();

                if (rand >= 0.7) {
                    throw new TestException();
                } else if (rand >= 0.4) {
                    throw new TaskCancellationException();
                }

                return randomInt(minResult, maxResult);
            }, new TimerExecutor(randomInt(minDelay, maxDelay))));
        }
    }

    private function randomInt(from : Int, to : Int) : Int {
        return from + Math.floor((to - from + 1) * Math.random());
    }
}
