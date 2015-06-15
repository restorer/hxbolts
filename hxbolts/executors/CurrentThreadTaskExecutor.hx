/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts.executors;

#if cpp
    import cpp.vm.Mutex;
#elseif neko
    import neko.vm.Mutex;
#elseif java
    import java.vm.Mutex;
#end

class CurrentThreadTaskExecutor implements TaskExecutor {
    private var runnableQueueMutex : Mutex = new Mutex();
    private var runnableQueue : List<Void -> Void> = new List<Void -> Void>();

    public function new() : Void {
    }

    public function execute(runnable : Void -> Void) : Void {
        runnableQueueMutex.acquire();
        runnableQueue.add(runnable);
        runnableQueueMutex.release();
    }

    public function tick() : Void {
        runnableQueueMutex.acquire();

        if (runnableQueue.isEmpty()) {
            runnableQueueMutex.release();
            return;
        }

        var queue = Lambda.list(runnableQueue);
        runnableQueue.clear();
        runnableQueueMutex.release();

        var runnable : Void -> Void;

        while ((runnable = queue.pop()) != null) {
            runnable();
        }
    }

    public function shutdown() : Void {
    }
}
