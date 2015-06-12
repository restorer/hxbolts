/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts;

class ImmediateTaskExecutor implements TaskExecutor {
    public function new() : Void {
    }

    public function execute(runnable : Void -> Void) : Void {
        runnable();
    }
}
