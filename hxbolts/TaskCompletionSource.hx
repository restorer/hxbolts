/*
 *  Original java implementation:
 *  Copyright (c) 2014, Facebook, Inc.
 *  All rights reserved.
 *
 *  Haxe version:
 *  Copyright (c) 2015, Viachaslau Tratsiak.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the original project repo:
 *  https://github.com/BoltsFramework/Bolts-Android/
 *
 */
package hxbolts;

@:access(hxbolts.Task)
class TaskCompletionSource<TResult> {
    public var task(default, null) : Task<TResult>;

    public function new() {
        this.task = new Task<TResult>();
    }

    public function trySetResult(value : TResult) : Bool {
        #if (cpp || neko || java)
            task.mutex.acquire();
        #end

        if (task._isCompleted) {
            #if (cpp || neko || java)
                task.mutex.release();
            #end

            return false;
        }

        task._isCompleted = true;
        task._result = value;
        task.runContinuations();

        #if (cpp || neko || java)
            task.mutex.release();
        #end

        return true;
    }

    public function trySetError(value : Dynamic = null) : Bool {
        #if (cpp || neko || java)
            task.mutex.acquire();
        #end

        if (task._isCompleted) {
            #if (cpp || neko || java)
                task.mutex.release();
            #end

            return false;
        }

        task._isCompleted = true;
        task._isFaulted = true;
        task._error = value;
        task.runContinuations();

        #if (cpp || neko || java)
            task.mutex.release();
        #end

        return true;
    }

    public function trySetCancelled() : Bool {
        #if (cpp || neko || java)
            task.mutex.acquire();
        #end

        if (task._isCompleted) {
            #if (cpp || neko || java)
                task.mutex.release();
            #end

            return false;
        }

        task._isCompleted = true;
        task._isCancelled = true;
        task.runContinuations();

        #if (cpp || neko || java)
            task.mutex.release();
        #end

        return true;
    }

    public function setResult(value : TResult) : Void {
        if (!trySetResult(value)) {
            throw new IllegalTaskStateException("Cannot set the result of a completed task.");
        }
    }

    public function setError(value : Dynamic = null) : Void {
        if (!trySetError(value)) {
            throw new IllegalTaskStateException("Cannot set the error on a completed task.");
        }
    }

    public function setCancelled() : Void {
        if (!trySetCancelled()) {
            throw new IllegalTaskStateException("Cannot cancel a completed task.");
        }
    }
}
