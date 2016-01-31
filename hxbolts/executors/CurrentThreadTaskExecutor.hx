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
	#if (cpp || neko || java)
    private var runnableQueueMutex : Mutex = new Mutex();
	#end
    private var runnableQueue : List<Void -> Void> = new List<Void -> Void>();

    public function new() : Void {
    }

    public function execute(runnable : Void -> Void) : Void {
		#if (cpp || neko || java)
        runnableQueueMutex.acquire();
		#end
        runnableQueue.add(runnable);
		#if (cpp || neko || java)
        runnableQueueMutex.release();
		#end
    }

    public function tick() : Void {
		#if (cpp || neko || java)
        runnableQueueMutex.acquire();
		#end
		
        if (runnableQueue.isEmpty()) {
			#if (cpp || neko || java)
            runnableQueueMutex.release();
			#end
            return;
        }

        var queue = Lambda.list(runnableQueue);
        runnableQueue.clear();
		#if (cpp || neko || java)
        runnableQueueMutex.release();
		#end

        var runnable : Void -> Void;

        while ((runnable = queue.pop()) != null) {
            runnable();
        }
    }

    public function shutdown() : Void {
    }
}
