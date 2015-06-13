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

class UiThreadTaskExecutor implements TaskExecutor {
    private static var runnableQueueMutex : Mutex = new Mutex();
    private static var runnableQueue : List<Void -> Void> = new List<Void -> Void>();

    public function new() : Void {
    }

    public function execute(runnable : Void -> Void) : Void {
        runnableQueueMutex.acquire();
        runnableQueue.add(runnable);
        runnableQueueMutex.release();
    }

    public static function tick() : Void {
        while (true) {
            runnableQueueMutex.acquire();
            var runnable : Void -> Void = runnableQueue.pop();
            runnableQueueMutex.release();

            if (runnable != null) {
                runnable();
            } else {
                break;
            }
        }
    }
}
