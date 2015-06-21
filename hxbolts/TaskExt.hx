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
        private static var _UI_EXECUTOR : UiThreadTaskExecutor = null;
        public static var UI_EXECUTOR(get, null) : UiThreadTaskExecutor;

        @:noCompletion
        private static function get_UI_EXECUTOR() : UiThreadTaskExecutor {
            if (_UI_EXECUTOR == null) {
                _UI_EXECUTOR = new UiThreadTaskExecutor();
            }

            return _UI_EXECUTOR;
        }
    #end

    #if (cpp || neko || java)
        private static var _BACKGROUND_EXECUTOR : BackgroundThreadTaskExecutor = null;
        public static var BACKGROUND_EXECUTOR(get, null) : BackgroundThreadTaskExecutor;

        @:noCompletion
        private static function get_BACKGROUND_EXECUTOR() : BackgroundThreadTaskExecutor {
            if (_BACKGROUND_EXECUTOR == null) {
                _BACKGROUND_EXECUTOR = new BackgroundThreadTaskExecutor(8);
            }

            return _BACKGROUND_EXECUTOR;
        }
    #end
}
