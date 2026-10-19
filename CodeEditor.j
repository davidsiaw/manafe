@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

// A function, not a variable: the release build runs this file's top level
// in Node, where AppKit cannot make a font.
function CodeEditorFont()
{
    return [CPFont fontWithName:"Menlo, Consolas, monospace" size:13.0];
}

// The editor script, loaded once, when the first code problem is shown.
var CodeEditorScriptPromise = nil;

function CodeEditorLoadScript()
{
    if (!CodeEditorScriptPromise)
        CodeEditorScriptPromise = new Promise(function(resolve, reject)
        {
            var script = document.createElement("script");
            script.src = [[CPBundle mainBundle] pathForResource:"editors/codemirror/codemirror.js"];
            script.onload = function()
            {
                window.ManabaseCodeEditor ? resolve(window.ManabaseCodeEditor) : reject(new Error("no editor in script"));
            };
            script.onerror = function() { reject(new Error("could not load " + script.src)); };
            document.head.appendChild(script);
        });
    return CodeEditorScriptPromise;
}

/*
    The editor for a learner's program: CodeMirror 6, from
    Resources/editors/codemirror/ (built by editors/codemirror/build; see
    docs/runtimes.md). It is a DOM element inside this view, outside AppKit,
    and is loaded the first time it is needed. Until then, and if it cannot
    be loaded, -code returns what -setCode:language: was given; a plain
    textarea stands in if loading fails, so the learner can still work.

    A plain editor (-initWithFrame:plain:) is for text that is not code, such
    as program output pasted from a terminal.
*/
@implementation CodeEditor : CPView
{
    Object      editor;         // ManabaseCodeEditor's, once loaded
    DOMElement  fallback;       // a textarea, if it could not be
    DOMElement  host;
    CPString    pendingCode;
    CPString    language;
    BOOL        plain       @accessors(readonly, getter=isPlain);
}

- (id)initWithFrame:(CGRect)aFrame
{
    return [self initWithFrame:aFrame plain:NO];
}

- (id)initWithFrame:(CGRect)aFrame plain:(BOOL)isPlain
{
    if (self = [super initWithFrame:aFrame])
    {
        plain = isPlain;
        host = document.createElement("div");
        host.style.position = "absolute";
        host.style.top = host.style.left = "0";
        host.style.width = host.style.height = "100%";
        host.style.boxSizing = "border-box";
        host.style.border = "1px solid #C8CDD3";
        host.style.backgroundColor = "#FBFBFB";
        _DOMElement.appendChild(host);

        // AppKit listens for keys, the mouse, the wheel and the clipboard on
        // the document, and takes the focus and cancels the browser's
        // handling when it sees them. Inside the editor they belong to
        // CodeMirror, which has had them by the time they bubble up here.
        var stop = function(anEvent) { anEvent.stopPropagation(); };
        ["keydown", "keypress", "keyup", "mousedown", "mouseup", "mousemove",
         "mousewheel", "wheel", "DOMMouseScroll", "copy", "cut", "paste"].forEach(function(aType)
        {
            host.addEventListener(aType, stop, false);
        });
    }
    return self;
}

- (CPString)code
{
    if (editor)
        return editor.getCode();
    if (fallback)
        return fallback.value;
    return pendingCode || "";
}

- (void)setCode:(CPString)aCode language:(CPString)aLanguage
{
    if (editor && aLanguage !== language)
    {
        // Highlighting is per language: start a new editor.
        editor.destroy();
        editor = nil;
    }
    language = aLanguage;
    pendingCode = aCode || "";

    if (editor)
        return editor.setCode(pendingCode);
    if (fallback)
        return fallback.value = pendingCode;

    CodeEditorLoadScript().then(function(aFactory)
    {
        if (editor)
            return;
        editor = aFactory.create(host, { code: pendingCode, language: language, plain: plain });
    }, function()
    {
        if (!fallback)
            [self _useFallback];
    });
}

- (void)focus
{
    if (editor)
        editor.focus();
    else if (fallback)
        fallback.focus();
}

- (void)_useFallback
{
    fallback = document.createElement("textarea");
    fallback.spellcheck = false;
    fallback.value = pendingCode;
    fallback.style.cssText = "width: 100%; height: 100%; box-sizing: border-box; border: 0; padding: 6px; " +
                             "resize: none; background: transparent; font: 13px Menlo, Consolas, monospace;";
    host.appendChild(fallback);
}

@end

/*
    A piece of code in problem text, shown read-only and highlighted with
    CodeMirror, as tall as its content. Until the editor script has loaded
    (and if it cannot be), the code is shown plain, in the same font and
    size, so nothing moves when it is replaced.

    -heightForWidth: measures the content; the enclosing views lay it out
    again when the editor arrives.
*/
@implementation CodeBlockView : CPView
{
    DOMElement  host;
    DOMElement  placeholder;
    Object      editor;
    CPString    code;
}

- (id)initWithCode:(CPString)aCode language:(CPString)aLanguage
{
    if (self = [super initWithFrame:CGRectMakeZero()])
    {
        code = aCode;

        host = document.createElement("div");
        host.style.cssText = "position: absolute; top: 0; left: 0; width: 100%; box-sizing: border-box; " +
                             "border: 1px solid #E1E4E8; border-radius: 4px; overflow: hidden; background: #F6F8FA;";
        _DOMElement.appendChild(host);

        placeholder = document.createElement("pre");
        placeholder.style.cssText = "margin: 0; padding: 8px 10px; overflow-x: auto; white-space: pre; " +
                                    "font: 13px/18px Menlo, Consolas, monospace; color: #24292E; tab-size: 4;";
        placeholder.textContent = code;
        host.appendChild(placeholder);

        // Selecting and copying belong to the code, not to AppKit (see
        // CodeEditor). The wheel is left alone, so the page still scrolls
        // with the pointer over a block.
        var stop = function(anEvent) { anEvent.stopPropagation(); };
        ["keydown", "keypress", "keyup", "mousedown", "mouseup", "mousemove", "copy", "cut"].forEach(function(aType)
        {
            host.addEventListener(aType, stop, false);
        });

        CodeEditorLoadScript().then(function(aFactory)
        {
            editor = aFactory.create(host, { code: code, language: aLanguage, readOnly: true });
            host.removeChild(placeholder);
            placeholder = nil;
            [self _heightMayHaveChanged];
        }, function() { /* the placeholder stays */ });
    }
    return self;
}

- (CPString)code
{
    return code;
}

- (float)heightForWidth:(float)aWidth
{
    host.style.width = aWidth + "px";
    var measured = host.offsetHeight;
    if (measured)
        return measured;

    // Not in the document yet, so nothing to measure: the placeholder's
    // size, 18 pixels a line plus padding and border.
    return code.split("\n").length * 18.0 + 18.0;
}

- (void)_heightMayHaveChanged
{
    for (var view = [self superview]; view; view = [view superview])
        [view setNeedsLayout];
    [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
}

@end
