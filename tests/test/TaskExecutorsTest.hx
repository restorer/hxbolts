/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package ;

import haxe.Timer;
import hxbolts.Task;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import massive.munit.util.Timer;

#if (cpp || neko || java)
    import hxbolts.executors.BackgroundThreadTaskExecutor;
    import hxbolts.executors.CurrentThreadTaskExecutor;
#end

#if cpp
    import cpp.vm.Mutex;
    import cpp.vm.Thread;
#elseif neko
    import neko.vm.Mutex;
    import neko.vm.Thread;
#elseif java
    import java.vm.Mutex;
    import java.vm.Thread;
#end

class TaskExecutorsTest {
    public function new() : Void {
    }

    #if (cpp || neko || java)

    @AsyncTest
    public function testCurrentThreadTaskExecutor(factory : AsyncFactory) : Void {
        var mutex = new Mutex();
        var initialThread = Thread.current();
        var currentThreadTaskExecutor = new CurrentThreadTaskExecutor();

        var immediateExecuted : Bool = false;
        var stopLooper : Bool = false;
        var task1Executed : Bool = false;
        var task1ThreadOk : Bool = false;
        var task2ThreadOk : Bool = false;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(immediateExecuted);
            Assert.isTrue(task1Executed);
            Assert.isTrue(task1ThreadOk);
            Assert.isTrue(task2ThreadOk);
        }, 5000);

        Task.call(function() : Void {
            Sys.sleep(0.1);

            mutex.acquire();
            task1Executed = true;
            task1ThreadOk = (Thread.current() == initialThread);
            mutex.release();
        }, currentThreadTaskExecutor).continueWith(function(t : Task<Void>) : Void {
            task2ThreadOk = (Thread.current() == initialThread);

            mutex.acquire();
            stopLooper = true;
            mutex.release();

            handler();
        });

        mutex.acquire();

        if (!task1Executed) {
            immediateExecuted = true;
        }

        mutex.release();
        var st = Timer.stamp();

        while ((Timer.stamp() - st) < 5000) {
            currentThreadTaskExecutor.tick();

            mutex.acquire();
            var shouldStopLooper = stopLooper;
            mutex.release();

            if (shouldStopLooper) {
                break;
            }

            Sys.sleep(0.1);
        }
    }

    @AsyncTest
    public function testBackgroundThreadTaskExecutor(factory : AsyncFactory) : Void {
        var mutex = new Mutex();
        var initialThread = Thread.current();
        var backgroundThreadTaskExecutor = new BackgroundThreadTaskExecutor(1);

        var immediateExecuted : Bool = false;
        var task1Executed : Bool = false;
        var task1ThreadOk : Bool = false;
        var task2ThreadOk : Bool = false;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(immediateExecuted);
            Assert.isTrue(task1Executed);
            Assert.isTrue(task1ThreadOk);
            Assert.isTrue(task2ThreadOk);

            backgroundThreadTaskExecutor.shutdown();
        }, 5000);

        Task.call(function() : Void {
            Sys.sleep(0.1);

            mutex.acquire();
            task1Executed = true;
            task1ThreadOk = (Thread.current() != initialThread);
            mutex.release();
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Void>) : Void {
            task2ThreadOk = (Thread.current() != initialThread);
            handler();
        });

        mutex.acquire();

        if (!task1Executed) {
            immediateExecuted = true;
        }

        mutex.release();
    }

    @AsyncTest
    public function testSwitchingBetweenExecutors(factory : AsyncFactory) : Void {
        var mutex = new Mutex();
        var initialThread = Thread.current();
        var currentThreadTaskExecutor = new CurrentThreadTaskExecutor();
        var backgroundThreadTaskExecutor = new BackgroundThreadTaskExecutor(1);

        var immediateExecuted : Bool = false;
        var stopLooper : Bool = false;
        var task1Executed : Bool = false;
        var task1ThreadOk : Bool = false;
        var task2ThreadOk : Bool = false;
        var task3ThreadOk : Bool = false;
        var task4ThreadOk : Bool = false;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(immediateExecuted);
            Assert.isTrue(task1Executed);
            Assert.isTrue(task1ThreadOk);
            Assert.isTrue(task2ThreadOk);
            Assert.isTrue(task3ThreadOk);
            Assert.isTrue(task4ThreadOk);

            backgroundThreadTaskExecutor.shutdown();
        }, 5000);

        Task.call(function() : Void {
            Sys.sleep(0.1);

            mutex.acquire();
            task1Executed = true;
            task1ThreadOk = (Thread.current() != initialThread);
            mutex.release();
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Void>) : Void {
            Sys.sleep(0.1);

            mutex.acquire();
            task2ThreadOk = (Thread.current() == initialThread);
            mutex.release();
        }, currentThreadTaskExecutor).continueWith(function(t : Task<Void>) : Void {
            Sys.sleep(0.1);

            mutex.acquire();
            task3ThreadOk = (Thread.current() != initialThread);
            mutex.release();
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Void>) : Void {
            Sys.sleep(0.1);

            mutex.acquire();
            task4ThreadOk = (Thread.current() == initialThread);
            stopLooper = true;
            mutex.release();

            handler();
        }, currentThreadTaskExecutor);

        mutex.acquire();

        if (!task1Executed) {
            immediateExecuted = true;
        }

        mutex.release();
        var st = Timer.stamp();

        while ((Timer.stamp() - st) < 5000) {
            currentThreadTaskExecutor.tick();

            mutex.acquire();
            var shouldStopLooper = stopLooper;
            mutex.release();

            if (shouldStopLooper) {
                break;
            }

            Sys.sleep(0.1);
        }
    }

    #end
}
