@import <Foundation/Foundation.j>

@import "CodeRun.j"

/*
    Runs a learner's program in the browser, in a Web Worker per language
    (Resources/runtimes/<language>/worker.js; docs/runtimes.md). A runtime is
    downloaded the first time a program in its language runs, and its worker
    is kept for the next run.

    One program runs at a time. Starting another, or -stop, terminates the
    worker of the one before, and its callback is never called. So does a
    program that runs longer than CODE_RUN_TIMEOUT_SECONDS; its callback gets
    status "timeout". The clock starts when the program starts, not while the
    runtime is downloading.

    The callback gets { status, stdout, stderr, truncated } (CodeRun.j).
*/
@implementation CodeRunner : CPObject
{
    Object      workers;    // language -> Worker
    Object      current;    // the run in progress: { id, language, callback, timer }
    int         lastId;
}

- (id)init
{
    if (self = [super init])
    {
        workers = {};
        lastId = 0;
    }
    return self;
}

- (void)run:(CPString)aCode language:(CPString)aLanguage callback:(Function)aCallback
{
    [self stop];

    var worker = [self _workerFor:aLanguage];
    if (!worker)
        return [self _finish:aCallback result:{ status: "unavailable" }];

    current = { id: ++lastId, language: aLanguage, callback: aCallback, timer: nil };
    worker.postMessage({ id: current.id, code: aCode });
}

- (BOOL)isRunning
{
    return !!current;
}

// Abandons the program in progress, if there is one.
- (void)stop
{
    if (!current)
        return;
    [self _discardWorkerFor:current.language];
    [self _endCurrent];
}

- (Object)_workerFor:(CPString)aLanguage
{
    if (workers[aLanguage])
        return workers[aLanguage];

    var resource = CodeRunWorkerResource(aLanguage);
    if (!resource)
        return nil;

    var worker;
    try
    {
        worker = new Worker([[CPBundle mainBundle] pathForResource:resource]);
    }
    catch (e)
    {
        return nil;
    }

    worker.onmessage = function(anEvent) { [self _worker:worker language:aLanguage said:anEvent.data]; };
    // A worker script that fails to load or throws while starting.
    worker.onerror = function(anEvent)
    {
        anEvent.preventDefault();
        [self _worker:worker language:aLanguage said:{ type: "failed", message: anEvent.message }];
    };

    workers[aLanguage] = worker;
    return worker;
}

- (void)_worker:(Object)aWorker language:(CPString)aLanguage said:(Object)aMessage
{
    if (workers[aLanguage] !== aWorker)
        return; // terminated already

    if (aMessage.type === "failed")
    {
        [self _discardWorkerFor:aLanguage];
        if (current && current.language === aLanguage)
            [self _finishCurrentWith:{ status: "unavailable" }];
        return;
    }

    if (!current || aMessage.id !== current.id)
        return;

    if (aMessage.type === "started")
    {
        current.timer = window.setTimeout(function()
        {
            [self _discardWorkerFor:aLanguage];
            [self _finishCurrentWith:{ status: "timeout", stdout: "", stderr: "" }];
        }, CODE_RUN_TIMEOUT_SECONDS * 1000);
    }
    else if (aMessage.type === "done")
    {
        [self _finishCurrentWith:{
            status: aMessage.status === 0 ? "ok" : "error",
            stdout: aMessage.stdout,
            stderr: aMessage.stderr,
            truncated: aMessage.truncated
        }];
    }
}

- (void)_discardWorkerFor:(CPString)aLanguage
{
    if (workers[aLanguage])
        workers[aLanguage].terminate();
    delete workers[aLanguage];
}

- (void)_endCurrent
{
    if (current && current.timer)
        window.clearTimeout(current.timer);
    current = nil;
}

- (void)_finishCurrentWith:(Object)aResult
{
    var callback = current.callback;
    [self _endCurrent];
    [self _finish:callback result:aResult];
}

- (void)_finish:(Function)aCallback result:(Object)aResult
{
    aCallback(aResult);
    // Called from worker events and timers: Cappuccino only redraws inside
    // its own run loop.
    [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
}

@end
