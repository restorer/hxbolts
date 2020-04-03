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
import hxbolts.Nothing;
import hxbolts.Task;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import massive.munit.util.Timer;

#if (cpp || neko || java)
    import hxbolts.executors.BackgroundThreadTaskExecutor;
    import hxbolts.executors.CurrentThreadTaskExecutor;
#end

#if (haxe_ver >= "4.0.0" && (cpp || neko || java))
    import sys.thread.Mutex;
    import sys.thread.Thread;
#elseif cpp
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
    public function new() {
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

        Task.call(function() : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            task1Executed = true;
            task1ThreadOk = areThreadsEquals(Thread.current(), initialThread);
            mutex.release();

            return null;
        }, currentThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            task2ThreadOk = areThreadsEquals(Thread.current(), initialThread);

            mutex.acquire();
            stopLooper = true;
            mutex.release();

            handler();
            return null;
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

        Task.call(function() : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            task1Executed = true;
            task1ThreadOk = !areThreadsEquals(Thread.current(), initialThread);
            mutex.release();

            return null;
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            task2ThreadOk = !areThreadsEquals(Thread.current(), initialThread);
            handler();
            return null;
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

        Task.call(function() : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            task1Executed = true;
            task1ThreadOk = !areThreadsEquals(Thread.current(), initialThread);
            mutex.release();

            return null;
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            task2ThreadOk = areThreadsEquals(Thread.current(), initialThread);
            mutex.release();

            return null;
        }, currentThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            task3ThreadOk = !areThreadsEquals(Thread.current(), initialThread);
            mutex.release();

            return null;
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            task4ThreadOk = areThreadsEquals(Thread.current(), initialThread);
            stopLooper = true;
            mutex.release();

            handler();
            return null;
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

    private static inline function areThreadsEquals(t1 : Thread, t2 : Thread) : Bool {
        #if (cpp && haxe_ver >= "3.3" && have_ver < "4.0.0")
            return (t1.handle == t2.handle);
        #else
            return (t1 == t2);
        #end
    }

    #end
}
