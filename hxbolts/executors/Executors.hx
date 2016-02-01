/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts.executors;

class Executors {
    public static var IMMEDIATE_EXECUTOR(default, null) : TaskExecutor = new ImmediateTaskExecutor();

    private static var _UI_EXECUTOR : TaskExecutor = null;
    public static var UI_EXECUTOR(get, null) : TaskExecutor;

    private static var _BACKGROUND_EXECUTOR : TaskExecutor = null;
    public static var BACKGROUND_EXECUTOR(get, null) : TaskExecutor;

    @:noCompletion
    private static function get_UI_EXECUTOR() : TaskExecutor {
        if (_UI_EXECUTOR == null) {
            #if (openfl || lime || nme || flash || js)
                _UI_EXECUTOR = new UiThreadTaskExecutor();
            #else
                // Fallback.
                _UI_EXECUTOR = IMMEDIATE_EXECUTOR;
            #end
        }

        return _UI_EXECUTOR;
    }

    @:noCompletion
    private static function get_BACKGROUND_EXECUTOR() : TaskExecutor {
        if (_BACKGROUND_EXECUTOR == null) {
            #if (cpp || neko || java)
                _BACKGROUND_EXECUTOR = new BackgroundThreadTaskExecutor(8);
            #else
                // It is just fallback to be able to have the same code for all platforms.
                // It doesn't mean that, say, javascript will have real background thread.
                _BACKGROUND_EXECUTOR = UI_EXECUTOR;
            #end
        }

        return _BACKGROUND_EXECUTOR;
    }
}
