/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package util;

import hxbolts.executors.TaskExecutor;
import massive.munit.util.Timer;

class TimerExecutor implements TaskExecutor {
    private var delay : Int;

    public function new(delay : Int) {
        this.delay = delay;
    }

    public function execute(runnable : Void -> Void) : Void {
        Timer.delay(runnable, delay);
    }

    public function shutdown() : Void {
    }
}
