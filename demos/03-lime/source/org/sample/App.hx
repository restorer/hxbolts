package org.sample;

import haxe.Timer;
import hxbolts.executors.Executors;
import hxbolts.Task;
import lime.app.Application;
import lime.Assets;
import lime.graphics.Image;
import lime.graphics.Renderer;

#if flash
    import flash.display.Bitmap;
    import flash.display.PixelSnapping;
    import flash.display.Sprite;
#else
    import lime.graphics.opengl.GLBuffer;
    import lime.graphics.opengl.GLProgram;
    import lime.graphics.opengl.GLTexture;
    import lime.graphics.opengl.GLUniformLocation;
    import lime.math.Matrix4;
    import lime.math.Vector4;
    import lime.utils.Float32Array;
    import lime.utils.GLUtils;
#end

#if cpp
    import cpp.vm.Thread;
#elseif neko
    import neko.vm.Thread;
#elseif java
    import java.vm.Thread;
#end

class App extends Application {
    private var startTime : Float;
    private var image : Image = null;

    #if flash
        private var logoSprite : Sprite;
    #else
        private var program : GLProgram;
        private var vertexAttributeLocation : Int;
        private var textureAttributeLocation : Int;
        private var matrixUniformLocation : GLUniformLocation;
        private var imageUniformLocation : GLUniformLocation;
        private var buffer : GLBuffer;
        private var texture : GLTexture;
    #end

    private var currentPrime : Int = 1;
    private var primesFound : Int = 1;

    #if (cpp || neko || java)
        private var uiThread : Thread;
    #end

    public function new() {
        super();

        #if (cpp || neko || java)
            uiThread = Thread.current();
        #end

        trace("RUNNING ANIMATION ON THE UI THREAD,");
        trace("WHILE COMPUTING PRIMES AND SLEEPING");

        #if no_background_thread
            trace("IN THE SAME UI THREAD.");
        #elseif (cpp || neko || java)
            trace("IN THE BACKGROUND THREAD.");
        #else
            trace("IN THE FAKE BACKGROUND THREAD.");
        #end

        updateTextFields();

        trace("Let's computation begins");
        computeNextPrime();
    }

    public override function render(renderer : Renderer) : Void {
        if (image == null && preloader.complete) {
            image = Assets.getImage("assets/logo.png");
            startTime = Timer.stamp();

            switch (renderer.context) {
                #if flash
                    case FLASH(sprite):
                        logoSprite = new Sprite();
                        sprite.addChild(logoSprite);

                        var logoBitmap = new Bitmap(cast image.buffer.src, PixelSnapping.AUTO, true);
                        logoBitmap.x = - image.width / 2.0;
                        logoBitmap.y = - image.height / 2.0;
                        logoSprite.addChild(logoBitmap);
                #else
                    case OPENGL(gl):
                        var vertexShaderSource = "
                            varying vec2 vTexCoord;
                            attribute vec4 aPosition;
                            attribute vec2 aTexCoord;
                            uniform mat4 uMatrix;

                            void main(void) {
                                vTexCoord = aTexCoord;
                                gl_Position = uMatrix * aPosition;
                            }
                        ";

                        var fragmentShaderSource = #if !desktop "precision mediump float;" + #end "
                            varying vec2 vTexCoord;
                            uniform sampler2D uImage0;

                            void main(void) {
                                gl_FragColor = texture2D(uImage0, vTexCoord);
                            }
                        ";

                        program = GLUtils.createProgram(vertexShaderSource, fragmentShaderSource);
                        gl.useProgram(program);

                        vertexAttributeLocation = gl.getAttribLocation(program, "aPosition");
                        textureAttributeLocation = gl.getAttribLocation(program, "aTexCoord");
                        matrixUniformLocation = gl.getUniformLocation(program, "uMatrix");
                        imageUniformLocation = gl.getUniformLocation(program, "uImage0");

                        gl.enableVertexAttribArray(vertexAttributeLocation);
                        gl.enableVertexAttribArray(textureAttributeLocation);
                        gl.uniform1i(imageUniformLocation, 0);

                        var data = [
                            image.width / 2.0, image.height / 2.0, 0.0, 1.0, 1.0,
                            - image.width / 2.0, image.height / 2.0, 0.0, 0.0, 1.0,
                            image.width / 2.0, - image.height / 2.0, 0.0, 1.0, 0.0,
                            - image.width / 2.0, - image.height / 2.0, 0.0, 0.0, 0.0,
                        ];

                        buffer = gl.createBuffer();
                        gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
                        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW);
                        gl.bindBuffer(gl.ARRAY_BUFFER, null);

                        texture = gl.createTexture();
                        gl.bindTexture(gl.TEXTURE_2D, texture);
                        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
                        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

                        #if js
                            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image.src);
                        #else
                            gl.texImage2D(
                                gl.TEXTURE_2D,
                                0,
                                gl.RGBA,
                                image.buffer.width,
                                image.buffer.height,
                                0,
                                gl.RGBA,
                                gl.UNSIGNED_BYTE,
                                image.data
                            );
                        #end

                        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
                        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
                        gl.bindTexture(gl.TEXTURE_2D, null);
                #end

                default:
                    throw 'Unsupported context: ${Type.enumConstructor(renderer.context)}';
            }
        }

        var currentTime = Timer.stamp() - startTime;

        switch (renderer.context) {
            #if flash
                case FLASH(sprite):
                    logoSprite.x = sprite.stage.stageWidth / 2.0;
                    logoSprite.y = sprite.stage.stageHeight / 2.0;
                    logoSprite.rotation = currentTime / Math.PI * 360.0;

            #else
                case OPENGL(gl):
                    gl.viewport(0, 0, window.width, window.height);

                    gl.clearColor(1.0, 1.0, 1.0, 1.0);
                    gl.clear(gl.COLOR_BUFFER_BIT);
                    gl.disable(gl.CULL_FACE);

                    var matrix = Matrix4.createOrtho(0.0, window.width, window.height, 0.0, 0.0, 1000.0);
                    matrix.prependTranslation(window.width / 2.0, window.height / 2.0, 0.0);
                    matrix.prependRotation(currentTime / Math.PI * 360.0, Vector4.Z_AXIS);

                    gl.useProgram(program);
                    gl.uniformMatrix4fv(matrixUniformLocation, false, matrix);

                    gl.activeTexture(gl.TEXTURE0);
                    gl.bindTexture(gl.TEXTURE_2D, texture);

                    #if desktop
                        gl.enable(gl.TEXTURE_2D);
                    #end

                    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
                    gl.enable(gl.BLEND);

                    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
                    gl.vertexAttribPointer(vertexAttributeLocation, 3, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 0);

                    gl.vertexAttribPointer(
                        textureAttributeLocation,
                        2,
                        gl.FLOAT,
                        false,
                        5 * Float32Array.BYTES_PER_ELEMENT,
                        3 * Float32Array.BYTES_PER_ELEMENT
                    );

                    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
            #end

            default:
                throw 'Unsupported context: ${Type.enumConstructor(renderer.context)}';
        }
    }

    private function updateTextFields() : Void {
        trace('CURRENT PRIME: ${currentPrime} / PRIMES FOUND: ${primesFound}');
    }

    private function computeNextPrime() : Void {
        #if (cpp || neko || java)
            if (Thread.current() != uiThread) {
                trace("ERROR: Non-UI thread at start of computeNextPrime()");
            }
        #end

        Task.call(function() : Int {
            #if (cpp || neko || java)
                if (Thread.current() != uiThread) {
                    trace("ERROR: Non-UI in first task");
                }
            #end

            return currentPrime;
        }).continueWith(function(task : Task<Int>) : Int {
            #if (cpp || neko || java)
                #if no_background_thread
                    if (Thread.current() != uiThread) {
                        trace("ERROR: Non-UI thread in computation function");
                    }
                #else
                    if (Thread.current() == uiThread) {
                        trace("ERROR: UI thread in computation function");
                    }
                #end
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

                #if (cpp || neko || java)
                    Sys.sleep(0.1); // sleep for teh slowness
                #else
                    var sum : Int = 0;

                    for (i in 0 ... 1000000) {
                        sum += i;
                    }
                #end
            }

            return number;
        } #if !no_background_thread , Executors.BACKGROUND_EXECUTOR #end).continueWith(function(task : Task<Int>) : Void {
            #if (cpp || neko || java)
                if (Thread.current() != uiThread) {
                    trace("ERROR: Non-UI thread at continueWith()");
                }
            #end

            currentPrime = task.result;
            primesFound++;

            updateTextFields();
            Executors.UI_EXECUTOR.execute(computeNextPrime);
        }, Executors.UI_EXECUTOR);
    }
}
