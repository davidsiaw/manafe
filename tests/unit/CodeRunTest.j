@import <Foundation/Foundation.j>
@import <OJUnit/OJTestCase.j>
@import <OJUnit/OJAssert.j>

@import "../../CodeRun.j"

@implementation CodeRunTest : OJTestCase

- (void)testFindsALanguagesWorkerInItsOwnDirectory
{
    [OJAssert assert:"runtimes/ruby/worker.js" equals:CodeRunWorkerResource("ruby")];
}

- (void)testRefusesLanguageNamesThatAreNotSlugs
{
    [OJAssert assert:nil equals:CodeRunWorkerResource("../secrets")];
    [OJAssert assert:nil equals:CodeRunWorkerResource("Ruby")];
    [OJAssert assert:nil equals:CodeRunWorkerResource(nil)];
}

- (void)testShowsWhatTheProgramPrinted
{
    [OJAssert assert:"hello\n3" equals:CodeRunOutputText({ status: "ok", stdout: "hello\n3\n", stderr: "" })];
}

- (void)testShowsAnErrorAfterTheOutputBeforeIt
{
    [OJAssert assert:"1\nmain.rb:2: boom (RuntimeError)"
              equals:CodeRunOutputText({ status: "error", stdout: "1\n", stderr: "main.rb:2: boom (RuntimeError)\n" })];
}

- (void)testSaysWhenNothingWasPrinted
{
    [OJAssert assert:"(Your program printed nothing.)" equals:CodeRunOutputText({ status: "ok", stdout: "", stderr: "" })];
}

- (void)testExplainsATimeout
{
    var text = CodeRunOutputText({ status: "timeout", stdout: "", stderr: "" });
    [OJAssert assertTrue:text.indexOf("more than 5 seconds") !== -1];
    [OJAssert assertTrue:text.indexOf("printed nothing") === -1];
}

- (void)testCutsLongOutputAndSaysSo
{
    var long = new Array(CODE_RUN_MAX_SHOWN + 10).join("x"),
        text = CodeRunOutputText({ status: "ok", stdout: long, stderr: "" });
    [OJAssert assert:CODE_RUN_MAX_SHOWN + "\n(Output cut short.)".length equals:text.length];
}

- (void)testSaysWhenTheWorkerCutTheOutput
{
    [OJAssert assert:"xx\n(Output cut short.)" equals:CodeRunOutputText({ status: "ok", stdout: "xx", stderr: "", truncated: true })];
}

- (void)testSaysWhenTheRuntimeIsMissing
{
    [OJAssert assertTrue:CodeRunOutputText({ status: "unavailable" }).indexOf("Could not start") === 0];
}

@end
