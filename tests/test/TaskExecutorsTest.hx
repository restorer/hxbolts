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

        var isTaskExecuted : Bool = false;
        var isTaskOnInitialThread : Bool = false;
        var isAfterTaskExecuted : Bool = false;
        var isContinuedOnInitialThread : Bool = false;
        var handled : Bool = false;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(isTaskExecuted);
            Assert.isTrue(isTaskOnInitialThread);
            Assert.isTrue(isAfterTaskExecuted);
            Assert.isTrue(isContinuedOnInitialThread);
        }, 5000);

        Task.call(function() : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            isTaskExecuted = true;
            isTaskOnInitialThread = isThisThread(initialThread);
            mutex.release();

            return null;
        }, currentThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            isContinuedOnInitialThread = isThisThread(initialThread);

            mutex.acquire();
            handled = true;
            mutex.release();

            handler();
            return null;
        });

        mutex.acquire();

        if (!isTaskExecuted) {
            isAfterTaskExecuted = true;
        }

        mutex.release();
        var st = Timer.stamp();

        while ((Timer.stamp() - st) < 5000) {
            currentThreadTaskExecutor.tick();

            mutex.acquire();
            var wasHandled = handled;
            mutex.release();

            if (wasHandled) {
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

        var isTaskExecuted : Bool = false;
        var isTaskNotOnInitialThread : Bool = false;
        var isAfterTaskExecuted : Bool = false;
        var isContinuedNotOnInitialThread : Bool = false;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(isTaskExecuted);
            Assert.isTrue(isTaskNotOnInitialThread);
            Assert.isTrue(isAfterTaskExecuted);
            Assert.isTrue(isContinuedNotOnInitialThread);

            backgroundThreadTaskExecutor.shutdown();
        }, 5000);

        Task.call(function() : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            isTaskExecuted = true;
            isTaskNotOnInitialThread = !isThisThread(initialThread);
            mutex.release();

            return null;
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            isContinuedNotOnInitialThread = !isThisThread(initialThread);
            handler();
            return null;
        });

        mutex.acquire();

        if (!isTaskExecuted) {
            isAfterTaskExecuted = true;
        }

        mutex.release();
    }

    @AsyncTest
    public function testSwitchingBetweenExecutors(factory : AsyncFactory) : Void {
        var mutex = new Mutex();
        var initialThread = Thread.current();
        var currentThreadTaskExecutor = new CurrentThreadTaskExecutor();
        var backgroundThreadTaskExecutor = new BackgroundThreadTaskExecutor(1);

        var notOnInitialThread1 : Bool = false;
        var onInitialThread2 : Bool = false;
        var notOnInitialThread3 : Bool = false;
        var onInitialThread4 : Bool = false;
        var isAfterTaskExecuted : Bool = false;
        var handled : Bool = false;

        var handler : Dynamic = factory.createHandler(this, function() : Void {
            Assert.isTrue(notOnInitialThread1);
            Assert.isTrue(onInitialThread2);
            Assert.isTrue(notOnInitialThread3);
            Assert.isTrue(onInitialThread4);
            Assert.isTrue(isAfterTaskExecuted);

            backgroundThreadTaskExecutor.shutdown();
        }, 5000);

        Task.call(function() : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            notOnInitialThread1 = !isThisThread(initialThread);
            mutex.release();

            return null;
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            onInitialThread2 = isThisThread(initialThread);
            mutex.release();

            return null;
        }, currentThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            notOnInitialThread3 = !isThisThread(initialThread);
            mutex.release();

            return null;
        }, backgroundThreadTaskExecutor).continueWith(function(t : Task<Nothing>) : Nothing {
            Sys.sleep(0.1);

            mutex.acquire();
            onInitialThread4 = isThisThread(initialThread);
            handled = true;
            mutex.release();

            handler();
            return null;
        }, currentThreadTaskExecutor);

        mutex.acquire();

        if (!notOnInitialThread1 && !onInitialThread2 && !notOnInitialThread3 && !onInitialThread4) {
            isAfterTaskExecuted = true;
        }

        mutex.release();
        var st = Timer.stamp();

        while ((Timer.stamp() - st) < 5000) {
            currentThreadTaskExecutor.tick();

            mutex.acquire();
            var wasHandled = handled;
            mutex.release();

            if (wasHandled) {
                break;
            }

            Sys.sleep(0.1);
        }
    }

    private function isThisThread(thread : Thread) : Bool {
        var messages = new List<Dynamic>();

        while (true) {
            var msg : Dynamic = Thread.readMessage(false);

            if (msg == null) {
                break;
            }

            if (msg != "THIS_THREAD") {
                messages.push(msg);
            }
        }

        thread.sendMessage("THIS_THREAD");
        var ret = (Thread.readMessage(false) == "THIS_THREAD");

        var currentThread = Thread.current();

        for (msg in messages) {
            currentThread.sendMessage(msg);
        }

        return ret;
    }

    #end
}
