/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts.executors.internal;

#if (haxe_ver >= "4.0.0" && (cpp || neko || java))
    import sys.thread.Thread;
#elseif cpp
    import cpp.vm.Thread;
#elseif neko
    import neko.vm.Thread;
#elseif java
    import java.vm.Thread;
#end

typedef BackgroundThreadTaskExecutorWorker = {
    thread : Thread,
    loadFactor : Int,
};
