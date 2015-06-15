/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts;

#if (flash || nme || openfl || lime)
    import hxbolts.executors.UiThreadTaskExecutor;
#end

#if (cpp || neko || java)
    import hxbolts.executors.BackgroundThreadTaskExecutor;
#end

class TaskExt {
    #if (flash || nme || openfl || lime)
        public static var UI_EXECUTOR(default, null) = new UiThreadTaskExecutor();
    #end

    #if (cpp || neko || java)
        public static var BACKGROUND_EXECUTOR(default, null) = new BackgroundThreadTaskExecutor(8);
    #end
}
