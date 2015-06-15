/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts.executors.internal;

enum BackgroundThreadTaskExecutorMessage {
    SetWorker(worker : BackgroundThreadTaskExecutorWorker);
    Execute(runnable : Void -> Void);
    Shutdown;
}
