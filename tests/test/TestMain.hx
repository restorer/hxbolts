package ;

import massive.munit.TestRunner;
import massive.munit.client.HTTPClient;
import massive.munit.client.RichPrintClient;
import massive.munit.client.SummaryReportClient;

// import massive.munit.client.PrintClient;
// import massive.munit.client.JUnitReportClient;
// import massive.munit.client.SummaryReportClient;

#if js
    import js.Lib;
#end

class TestMain {
    public function new() {
        var suites : Array<Class<massive.munit.TestSuite>> = [
            TestSuite
        ];

        #if MCOVER
            var client = new mcover.coverage.munit.client.MCoverPrintClient();
            var httpClient = new HTTPClient(new mcover.coverage.munit.client.MCoverSummaryReportClient());
        #else
            var client = new RichPrintClient();
            var httpClient = new HTTPClient(new SummaryReportClient());
        #end

        var runner : TestRunner = new TestRunner(client);
        runner.addResultClient(httpClient);

        runner.completionHandler = completionHandler;
        runner.run(suites);
    }

    private function completionHandler(successful : Bool) : Void {
        try {
            #if flash
                flash.external.ExternalInterface.call("testResult", successful);
            #elseif js
                js.Lib.eval("testResult(" + successful + ");");
            #elseif sys
                Sys.exit(0);
            #end
        } catch (e : Dynamic) {
        }
    }

    public static function main() : Void {
        new TestMain();
    }
}
