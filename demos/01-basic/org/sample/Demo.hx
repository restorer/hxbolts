package org.sample;

import haxe.Json;
import haxe.Timer;
import hxbolts.Nothing;
import hxbolts.Task;
import hxbolts.TaskCompletionSource;

using StringTools;

class Demo {
    private static var deletedCommentsIds = new Array<Int>();

    private static function makeRequestAsync(url : String, callback : String -> Void) : Void {
        var result : String;

        if (url == "http://blog.tld/api/authorize?user=me") {
            result = "{\"token\":\"12345\"}";
        } else if (url == "http://blog.tld/api/postsIds?token=12345") {
            result = "[1,2,3]";
        } else if (url.startsWith("http://blog.tld/api/commentsIds?token=12345&postId=")) {
            var prefix = url.substr("http://blog.tld/api/commentsIds?token=12345&postId=".length);
            result = '[${prefix}1,${prefix}2,${prefix}3]';
        } else if (url.startsWith("http://blog.tld/api/deleteComment?token=12345&commentId=")) {
            deletedCommentsIds.push(Std.parseInt(url.substr("http://blog.tld/api/deleteComment?token=12345&commentId=".length)));
            result = "true";
        } else {
            result = "false";
        }

        Timer.delay(function() : Void {
            callback(result);
        }, Math.floor(Math.random() * 50) + 10);
    }

    private static function makeRequestTask(url : String) : Task<String> {
        var tcs = new TaskCompletionSource<String>();

        makeRequestAsync(url, function(result : String) : Void {
            tcs.setResult(result);
        });

        return tcs.task;
    }

    public static function process() : Void {
        var token : String = null;

        makeRequestTask("http://blog.tld/api/authorize?user=me").onSuccessTask(function(task : Task<String>) : Task<String> {
            token = Reflect.field(Json.parse(task.result), "token");
            return makeRequestTask('http://blog.tld/api/postsIds?token=${token}');
        }).onSuccessTask(function(task : Task<String>) : Task<Array<String>> {
            var tasks = new Array<Task<String>>();

            for (id in (cast Json.parse(task.result) : Array<Int>)) {
                tasks.push(makeRequestTask('http://blog.tld/api/commentsIds?token=${token}&postId=${id}'));
            }

            return Task.whenAllResult(tasks);
        }).onSuccessTask(function(task : Task<Array<String>>) : Task<Nothing> {
            var tasks = new Array<Task<String>>();

            for (response in task.result) {
                for (id in (cast Json.parse(response) : Array<Int>)) {
                    tasks.push(makeRequestTask('http://blog.tld/api/deleteComment?token=${token}&commentId=${id}'));
                }
            }

            return Task.whenAll(tasks);
        }).continueWith(function(task : Task<Nothing>) : Nothing {
            if (task.isSuccessed) {
                trace("Everything is good");
                trace(deletedCommentsIds);
            } else {
                trace("Error occurred : " + Std.string(task.error));
            }

            return null;
        });
    }

    public static function main() : Void {
        process();
    }
}
