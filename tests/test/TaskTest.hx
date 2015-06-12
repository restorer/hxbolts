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

import hxbolts.Nothing;
import hxbolts.Task;
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

        Assert.isTrue(error.isCompleted);
        Assert.isType(error.error, TestException);
        Assert.isTrue(error.isFaulted);
        Assert.isFalse(error.isCancelled);

        Assert.isTrue(cancelled.isCompleted);
        Assert.isFalse(cancelled.isFaulted);
        Assert.isTrue(cancelled.isCancelled);
    }

    @Test
    public function testSynchronousContinuation() : Void {
        var complete : Task<Int> = Task.forResult(5);
        var error : Task<Int> = Task.forError(new TestException());
        var cancelled : Task<Int> = Task.cancelled();

        complete.continueWith(function(task : Task<Int>) : Nothing {
            Assert.areEqual(complete, task);
            Assert.isTrue(task.isCompleted);
            Assert.areEqual(5, task.result);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);

            return null;
        });

        error.continueWith(function(task : Task<Int>) : Nothing {
            Assert.areEqual(error, task);
            Assert.isTrue(task.isCompleted);
            Assert.isType(task.error, TestException);
            Assert.isTrue(task.isFaulted);
            Assert.isFalse(task.isCancelled);

            return null;
        });

        cancelled.continueWith(function(task : Task<Int>) : Nothing {
            Assert.areEqual(cancelled, task);
            Assert.isTrue(cancelled.isCompleted);
            Assert.isFalse(cancelled.isFaulted);
            Assert.isTrue(cancelled.isCancelled);

            return null;
        });
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
        var timerExecutor = new TimerExecutor(100);
        var task : Task<Int> = null;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.areEqual(5, task.result);
        }, 200);

        Task.call(function() : Int {
            return 5;
        }, timerExecutor).continueWith(function(t : Task<Int>) : Nothing {
            task = t;
            handler();
            return null;
        });
    }

    @AsyncTest
    public function testBackgroundError(factory : AsyncFactory) : Void {
        var timerExecutor = new TimerExecutor(100);
        var task : Task<Int> = null;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isFaulted);
            Assert.isType(task.error, TestException);
        }, 200);

        Task.call(function() : Int {
            throw new TestException();
        }, timerExecutor).continueWith(function(t : Task<Int>) : Nothing {
            task = t;
            handler();
            return null;
        });
    }

    @AsyncTest
    public function testBackgroundCancellation(factory : AsyncFactory) : Void {
        var timerExecutor = new TimerExecutor(100);
        var task : Task<Int> = null;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCancelled);
        }, 200);

        Task.call(function() : Int {
            throw new TaskCancellationException();
        }, timerExecutor).continueWith(function(t : Task<Int>) : Nothing {
            task = t;
            handler();
            return null;
        });
    }

    @AsyncTest
    public function testContinueOnTimerExecutor(factory : AsyncFactory) : Void {
        var timerExecutor = new TimerExecutor(100);
        var task : Task<Int> = null;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.areEqual(3, task.result);
        }, 400);

        Task.call(function() : Int {
            return 1;
        }, timerExecutor).continueWith(function(t : Task<Int>) : Int {
            return t.result + 1;
        }, timerExecutor).continueWithTask(function(t : Task<Int>) : Task<Int> {
            return Task.forResult(t.result + 1);
        }, timerExecutor).continueWith(function(t : Task<Int>) : Nothing {
            task = t;
            handler();
            return null;
        });
    }

    @Test
    public function testWhenAllNoTasks() : Void {
        var task : Task<Nothing> = Task.whenAll(new Array<Task<Nothing>>());

        Assert.isTrue(task.isCompleted);
        Assert.isFalse(task.isFaulted);
        Assert.isFalse(task.isCancelled);
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
            Assert.areEqual(firstToCompleteSuccess, task.result);
            Assert.isTrue(task.result.isCompleted);
            Assert.isFalse(task.result.isFaulted);
            Assert.isFalse(task.result.isCancelled);
            Assert.areEqual(2000, task.result.result);
        }, 300);

        Task.whenAny(tasks).continueWith(function(t : Task<Task<Int>>) : Nothing {
            task = t;
            handler();
            return null;
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
            Assert.areEqual(firstToCompleteSuccess, task.result);
            Assert.isTrue(task.result.isCompleted);
            Assert.isFalse(task.result.isFaulted);
            Assert.isFalse(task.result.isCancelled);
            Assert.areEqual("SUCCESS", task.result.result);
        }, 300);

        Task.whenAny(tasks).continueWith(function(t : Task<Task<Dynamic>>) : Nothing {
            task = t;
            handler();
            return null;
        });
    }

    @AsyncTest
    public function testWhenAnyFirstError(factory : AsyncFactory) : Void {
        var task : Task<Task<Dynamic>> = null;
        var tasks = new Array<Task<Dynamic>>();

        var error = new TestException();

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
            Assert.areEqual(firstToCompleteError, task.result);
            Assert.isTrue(task.result.isCompleted);
            Assert.isTrue(task.result.isFaulted);
            Assert.isFalse(task.result.isCancelled);
            Assert.areEqual(error, task.result.error);
        }, 300);

        Task.whenAny(tasks).continueWith(function(t : Task<Task<Dynamic>>) : Nothing {
            task = t;
            handler();
            return null;
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
            Assert.areEqual(firstToCompleteError, task.result);
            Assert.isTrue(task.result.isCompleted);
            Assert.isFalse(task.result.isFaulted);
            Assert.isTrue(task.result.isCancelled);
        }, 300);

        Task.whenAny(tasks).continueWith(function(t : Task<Task<Dynamic>>) : Nothing {
            task = t;
            handler();
            return null;
        });
    }

    @AsyncTest
    public function testWhenAllSuccess(factory : AsyncFactory) : Void {
        var task : Task<Nothing> = null;
        var tasks = new Array<Task<Nothing>>();

        for (i in 0 ... 20) {
            tasks.push(Task.call(function() : Nothing {
                return null;
            }, new TimerExecutor(randomInt(10, 50))));
        }

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(task.isCompleted);
            Assert.isFalse(task.isFaulted);
            Assert.isFalse(task.isCancelled);

            for (t in tasks) {
                Assert.isTrue(t.isCompleted);
            }
        }, 100);

        Task.whenAll(tasks).continueWith(function(t : Task<Nothing>) : Nothing {
            task = t;
            handler();
            return null;
        });
    }

    // testWhenAllOneError
    // testWhenAllTwoErrors
    // testWhenAllCancel
    // testWhenAllResultNoTasks
    // testWhenAllResultSuccess
    // testAsyncChaining
    // testOnSuccess
    // testOnSuccessTask
    // testContinueWhile
    // testContinueWhileAsync

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
