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

    public function new() : Void {
        this.task = new Task<TResult>();
    }

    public function trySetResult(result : TResult) : Bool {
        if (task.isCompleted) {
            return false;
        }

        task.isCompleted = true;
        task.result = result;
        task.runContinuations();

        return true;
    }

    public function trySetError(e : Dynamic) : Bool {
        if (task.isCompleted) {
            return false;
        }

        task.isCompleted = true;
        task.error = e;
        task.runContinuations();

        return true;
    }

    public function trySetCancelled() : Bool {
        if (task.isCompleted) {
            return false;
        }

        task.isCompleted = true;
        task.isCancelled = true;
        task.runContinuations();

        return true;
    }

    public function setResult(result : TResult) : Void {
        if (!trySetResult(result)) {
            throw new IllegalTaskStateException("Cannot set the result of a completed task.");
        }
    }

    public function setError(e : Dynamic) : Void {
        if (!trySetError(e)) {
            throw new IllegalTaskStateException("Cannot set the error on a completed task.");
        }
    }

    public function setCancelled() : Void {
        if (!trySetCancelled()) {
            throw new IllegalTaskStateException("Cannot cancel a completed task.");
        }
    }
}
