@import <Foundation/Foundation.j>

/*
    What the course screen needs to know about running a learner's code,
    without touching the browser: where a language's runtime is, and what to
    show for a run. CodeRunner.j does the running.
*/

// Seconds a program may run before it is stopped.
CODE_RUN_TIMEOUT_SECONDS = 5;

// Characters of output shown; a long backtrace or a printing loop is cut.
CODE_RUN_MAX_SHOWN = 20000;

/*
    The worker for a language, as a path inside the app's Resources: every
    runtime lives in Resources/runtimes/<language>/ and is only downloaded
    when a problem in that language is run. nil for a name that is not a
    plain slug, so a problem cannot point the app at another path.
*/
function CodeRunWorkerResource(aLanguage)
{
    if (typeof aLanguage !== "string" || !/^[a-z0-9][a-z0-9_-]*$/.test(aLanguage))
        return nil;
    return "runtimes/" + aLanguage + "/worker.js";
}

/*
    A run's result is { status, stdout, stderr, truncated }, where status is
    "ok", "error" (the program failed; stderr says why), "timeout" or
    "unavailable" (the runtime could not be loaded). Returns the text to show.
*/
function CodeRunOutputText(aResult)
{
    if (aResult.status === "unavailable")
        return "Could not start the runtime for this language. Reload the page and try again.";

    var parts = [];
    if (aResult.stdout)
        parts.push(aResult.stdout.replace(/\n$/, ""));
    if (aResult.stderr)
        parts.push(aResult.stderr.replace(/\n$/, ""));

    var text = parts.join("\n"),
        cut = aResult.truncated || text.length > CODE_RUN_MAX_SHOWN;
    text = text.substring(0, CODE_RUN_MAX_SHOWN);

    var notes = [];
    if (cut)
        notes.push("(Output cut short.)");
    if (aResult.status === "timeout")
        notes.push("Your program ran for more than " + CODE_RUN_TIMEOUT_SECONDS + " seconds and was stopped. Is there a loop that never ends?");
    if (!text && !notes.length)
        notes.push("(Your program printed nothing.)");

    return [text].concat(notes).filter(function(s) { return s; }).join("\n");
}
