/*
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */
package hxbolts.executors;

#if openfl
    import openfl.Lib;
    import openfl.events.Event;
#elseif lime
    import lime.app.Application;
#elseif nme
    import nme.Lib;
    import nme.events.Event;
#elseif flash
    import flash.Lib;
    import flash.events.Event;
#else
    import haxe.Timer;
#end

class UiThreadTaskExecutor extends CurrentThreadTaskExecutor {
    #if (!openfl && !lime && !nme && !flash)
        private var tickTimer : Timer;
    #end

    public function new() : Void {
        super();

        #if openfl
            Lib.current.stage.addEventListener(Event.ENTER_FRAME, onNextFrame);
        #elseif lime
            Application.current.onUpdate.add(onNextFrame);
        #elseif (nme || flash)
            // it is not an error - same line of code as for "openfl"
            Lib.current.stage.addEventListener(Event.ENTER_FRAME, onNextFrame);
        #else
            tickTimer = new Timer(Std.int(1000 / 30));
            tickTimer.run = onNextFrame;
        #end
    }

    private function onNextFrame(#if (openfl || lime || nme || flash) _ #end) : Void {
        tick();
    }

    override public function shutdown() : Void {
        #if openfl
            Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onNextFrame);
        #elseif lime
            Application.current.onUpdate.remove(onNextFrame);
        #elseif (nme || flash)
            // it is not an error - same line of code as for "openfl"
            Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onNextFrame);
        #else
            tickTimer.stop();
        #end
    }
}
