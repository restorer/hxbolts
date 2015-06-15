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

class BackgroundThreadTaskExecutor implements TaskExecutor {
    private var mutex : Mutex = new Mutex();
    private var workerPool : Array<BackgroundThreadTaskExecutorWorker> = [];

    public function new(poolSize : Int) : Void {
        if (poolSize < 1) {
            throw 'poolSize must be >= 1';
        }

        for (i in 0 ... poolSize) {
            var worker : BackgroundThreadTaskExecutorWorker = {
                thread: Thread.create(workerLoop),
                loadFactor: 0,
            };

            worker.thread.sendMessage(BackgroundThreadTaskExecutorMessage.SetWorker(worker));
            workerPool.push(worker);
        }
    }

    private function workerLoop() : Void {
        var worker : BackgroundThreadTaskExecutorWorker = null;

        while (true) {
            var message : BackgroundThreadTaskExecutorMessage = Thread.readMessage(true);

            switch (message) {
                case SetWorker(_worker):
                    worker = _worker;

                case Execute(runnable):
                    runnable();

                    mutex.acquire();
                    worker.loadFactor--;
                    mutex.release();

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
        mutex.release();

        selectedWorker.thread.sendMessage(BackgroundThreadTaskExecutorMessage.Execute(runnable));
    }

    public function shutdown() : Void {
        for (worker in workerPool) {
            worker.thread.sendMessage(BackgroundThreadTaskExecutorMessage.Shutdown);
        }
    }
}
