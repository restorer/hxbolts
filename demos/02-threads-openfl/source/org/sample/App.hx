package org.sample;

import hxbolts.Task;
import hxbolts.TaskExt;
import motion.Actuate;
import motion.easing.Linear;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.FPS;
import openfl.display.PixelSnapping;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

#if cpp
    import cpp.vm.Thread;
#elseif neko
    import neko.vm.Thread;
#elseif java
    import java.vm.Thread;
#end

class App extends Sprite {
    private var currentPrimeTextField : TextField;
    private var primesFoundTextField : TextField;

    private var currentPrime : Int = 1;
    private var primesFound : Int = 1;

    private var uiThread : Thread;

    public function new() : Void {
        super();

        uiThread = Thread.current();
        addChild(new FPS(10, 10, 0xff0000));

        var logoSprite = new Sprite();
        logoSprite.x = 400;
        logoSprite.y = 300;
        addChild(logoSprite);

        var logoBitmap = new Bitmap(Assets.getBitmapData("assets/Logo.png"), PixelSnapping.AUTO, true);
        logoBitmap.x = -128;
        logoBitmap.y = -128;
        logoSprite.addChild(logoBitmap);

        Actuate.tween(logoSprite, 3.0, { rotation: 359 }).ease(Linear.easeNone).repeat();

        addTextField(50, "RUNNING ANIMATION ON THE UI THREAD,");
        addTextField(50 + 30, "WHILE COMPUTING PRIMES AND SLEEPING");

        #if no_background_thread
            addTextField(50 + 30 * 2, "IN THE SAME UI THREAD.");
        #else
            addTextField(50 + 30 * 2, "IN THE BACKGROUND THREAD.");
        #end

        currentPrimeTextField = addTextField(450);
        primesFoundTextField = addTextField(450 + 30);

        updateTextFields();

        trace("Let's computation begins");
        computeNextPrime();
    }

    private function addTextField(y : Float, ?text : String) : TextField {
        var textField = new TextField();
        textField.x = 100;
        textField.y = y;
        textField.width = 600;
        textField.height = 30;
        textField.embedFonts = true;
        textField.selectable = false;

        var textFormat = new TextFormat();
        textFormat.size = 24;
        textFormat.color = 0x303030;
        textFormat.font = Assets.getFont("assets/Intro.ttf").fontName;
        textFormat.align = TextFormatAlign.CENTER;

        textField.defaultTextFormat = textFormat;

        if (text != null) {
            textField.text = text;
        }

        addChild(textField);
        return textField;
    }

    private function updateTextFields() : Void {
        currentPrimeTextField.text = 'CURRENT PRIME: ${currentPrime}';
        primesFoundTextField.text = 'PRIMES FOUND: ${primesFound}';
    }

    private function computeNextPrime() : Void {
        if (Thread.current() != uiThread) {
            trace("ERROR: Non-UI thread at start of computeNextPrime()");
        }

        Task.call(function() : Int {
            if (Thread.current() != uiThread) {
                trace("ERROR: Non-UI in first task");
            }

            return currentPrime;
        }).continueWith(function(task : Task<Int>) : Int {
            #if no_background_thread
                if (Thread.current() != uiThread) {
                    trace("ERROR: Non-UI thread in computation function");
                }
            #else
                if (Thread.current() == uiThread) {
                    trace("ERROR: UI thread in computation function");
                }
            #end

            var number = task.result;

            // Super UNoptimized alghoritm to show that computation
            // actually performed in the background thread

            while (true) {
                number++;
                var isPrime = true;

                for (i in 2 ... number) {
                    if (number % i == 0) {
                        isPrime = false;
                        break;
                    }
                }

                if (isPrime) {
                    break;
                }

                Sys.sleep(0.1); // sleep for teh slowness
            }

            return number;
        } #if !no_background_thread , TaskExt.BACKGROUND_EXECUTOR #end).continueWith(function(task : Task<Int>) : Void {
            if (Thread.current() != uiThread) {
                trace("ERROR: Non-UI thread at continueWith()");
            }

            currentPrime = task.result;
            primesFound++;

            updateTextFields();
            TaskExt.UI_EXECUTOR.execute(computeNextPrime);
        }, TaskExt.UI_EXECUTOR);
    }
}
