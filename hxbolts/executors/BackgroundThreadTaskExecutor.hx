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
    import cpp.vm.Thread;
#elseif neko
    import neko.vm.Thread;
#elseif java
    import java.vm.Thread;
#end

enum BackgroundThreadTaskExecutorMessage {
    Execute(runnable : Void -> Void);
    Shutdown;
}

class BackgroundThreadTaskExecutor implements TaskExecutor {
    private var thread : Thread;

    public function new() : Void {
        thread = Thread.create(loop);
    }

    private function loop() : Void {
        while (true) {
            var message : BackgroundThreadTaskExecutorMessage = Thread.readMessage(true);

            switch (message) {
                case Execute(runnable):
                    runnable();

                case Shutdown:
                    break;
            }
        }
    }

    public function execute(runnable : Void -> Void) : Void {
        thread.sendMessage(BackgroundThreadTaskExecutorMessage.Execute(runnable));
    }

    public function shutdown() : Void {
        thread.sendMessage(BackgroundThreadTaskExecutorMessage.Shutdown);
    }
}
