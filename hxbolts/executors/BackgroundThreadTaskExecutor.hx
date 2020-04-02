/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts.executors;

import hxbolts.executors.internal.BackgroundThreadTaskExecutorMessage;
import hxbolts.executors.internal.BackgroundThreadTaskExecutorWorker;

#if (haxe_ver >= "4.0.0")
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

class BackgroundThreadTaskExecutor implements TaskExecutor {
    private var mutex : Mutex = new Mutex();
    private var workerPool : Array<BackgroundThreadTaskExecutorWorker> = [];

    public function new(poolSize : Int) {
        if (poolSize < 1) {
            throw "poolSize must be >= 1";
        }

        for (i in 0 ... poolSize) {
            workerPool.push({
                thread: null,
                loadFactor: 0,
            });
        }
    }

    private function workerLoop() : Void {
        var worker : BackgroundThreadTaskExecutorWorker = null;

        while (true) {
            var message : BackgroundThreadTaskExecutorMessage = Thread.readMessage(true);

            switch (message) {
                case SetWorker(_worker):
                    worker = _worker;

                case Execute(runnable): {
                    runnable();

                    var shouldShutdown = false;

                    mutex.acquire();
                    worker.loadFactor--;

                    if (worker.loadFactor <= 0) {
                        shouldShutdown = true;
                        worker.thread = null;
                    }

                    mutex.release();

                    if (shouldShutdown) {
                        break;
                    }
                }

                case Shutdown:
                    break;
            }
        }
    }

    public function execute(runnable : Void -> Void) : Void {
        var selectedWorker : BackgroundThreadTaskExecutorWorker = null;
        var minLoadFactor : Int = 0;

        mutex.acquire();

        for (worker in workerPool) {
            if (selectedWorker == null || worker.loadFactor < minLoadFactor) {
                selectedWorker = worker;
                minLoadFactor = worker.loadFactor;
            }
        }

        selectedWorker.loadFactor++;

        if (selectedWorker.thread == null) {
            selectedWorker.thread = Thread.create(workerLoop);
            selectedWorker.thread.sendMessage(BackgroundThreadTaskExecutorMessage.SetWorker(selectedWorker));
        }

        selectedWorker.thread.sendMessage(BackgroundThreadTaskExecutorMessage.Execute(runnable));
        mutex.release();
    }

    public function shutdown() : Void {
        for (worker in workerPool) {
            if (worker.thread != null) {
                worker.thread.sendMessage(BackgroundThreadTaskExecutorMessage.Shutdown);
            }
        }
    }
}
