/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts.executors;

#if (flash || nme || openfl)
    import openfl.Lib;
    import openfl.events.Event;
#elseif lime
    import lime.app.Application;
#else
    import haxe.Timer;
#end

class UiThreadTaskExecutor extends CurrentThreadTaskExecutor {
    #if (!flash && !nme && !openfl && !lime)
        private var tickTimer : Timer;
    #end

    public function new() : Void {
        super();

        #if (flash || nme || openfl)
            Lib.current.stage.addEventListener(Event.ENTER_FRAME, onNextFrame);
        #elseif lime
            Application.current.onUpdate.add(onNextFrame);
        #else
            tickTimer = new Timer(Std.int(1000 / 30));
            tickTimer.run = onNextFrame;
        #end
    }

    private function onNextFrame(#if (flash || nme || openfl || lime) _ #end) : Void {
        tick();
    }

    override public function shutdown() : Void {
        #if (flash || nme || openfl)
            Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onNextFrame);
        #elseif lime
            Application.current.onUpdate.remove(onNextFrame);
        #else
            tickTimer.stop();
        #end
    }
}
