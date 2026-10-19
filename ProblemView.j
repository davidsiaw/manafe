@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "CodeEditor.j"
@import "CodeRun.j"
@import "CodeRunner.j"
@import "RichTextView.j"

var SharedCodeRunner = nil;

var MARGIN = 24.0,
    MAX_TEXT_WIDTH = 760.0,
    GAP = 14.0,
    BUTTON_HEIGHT = 24.0,
    RADIO_HEIGHT = 22.0,
    EDITOR_HEIGHT = 260.0,
    PASTE_HEIGHT = 140.0;

/*
    The right-hand side: one problem's explanation and its exercise, either
    a multiple choice question or, for type "code", an editor whose program
    runs in the browser (CodeRunner). A code problem with run "local" is
    run on the learner's computer instead: the code can be copied, and what
    it printed is pasted back. Everything is stacked top to bottom in
    -layoutSubviews, and the view grows to fit so that the enclosing scroll
    view can scroll it.

    The delegate gets -problemView:didChooseChoiceId: when Check answer is
    pressed on a multiple choice question, -problemView:didSubmitOutput: with
    what the program printed (or what was pasted) when it is pressed on a
    code problem, and
    -problemView:didRequestProblemId: for Previous and Next.
*/
@implementation ProblemView : CPView
{
    id          delegate    @accessors;

    CPTextField titleField;
    CPButton    previousButton;
    CPButton    nextButton;
    RichTextView bodyText;
    RichTextView questionText;
    CPArray     radios;
    CodeEditor  editor;
    CPButton    runButton;
    CPButton    copyButton;
    CPTextField pasteLabel;
    CodeEditor  pasteEditor;
    CPButton    checkButton;
    CPView      outputBox;
    CPTextField outputField;
    RichTextView feedbackText;

    Object      problem;
    BOOL        solved;
    BOOL        running;
}

- (id)initWithFrame:(CGRect)aFrame
{
    if (self = [super initWithFrame:aFrame])
    {
        radios = [];

        titleField = [self _labelWithFont:[CPFont boldSystemFontOfSize:26.0]];
        // Problem text can contain code, shown highlighted (RichTextView).
        bodyText = [self _richTextWithFont:[CPFont systemFontOfSize:14.0]];
        [bodyText setSelectable:YES];
        questionText = [self _richTextWithFont:[CPFont boldSystemFontOfSize:14.0]];
        feedbackText = [self _richTextWithFont:[CPFont systemFontOfSize:14.0]];

        editor = [[CodeEditor alloc] initWithFrame:CGRectMake(0, 0, MAX_TEXT_WIDTH, EDITOR_HEIGHT)];
        [self addSubview:editor];
        // A label draws no background, so the output sits on a box.
        outputBox = [[CPView alloc] initWithFrame:CGRectMakeZero()];
        [outputBox setBackgroundColor:[CPColor colorWithHexString:"F1F3F5"]];
        [self addSubview:outputBox];
        outputField = [self _labelWithFont:CodeEditorFont()];
        [outputField setSelectable:YES];

        pasteLabel = [self _labelWithFont:[CPFont boldSystemFontOfSize:14.0]];
        [pasteLabel setStringValue:"What your program printed:"];
        pasteEditor = [[CodeEditor alloc] initWithFrame:CGRectMake(0, 0, MAX_TEXT_WIDTH, PASTE_HEIGHT) plain:YES];
        [self addSubview:pasteEditor];

        previousButton = [self _buttonWithAction:@selector(goPrevious:)];
        nextButton = [self _buttonWithAction:@selector(goNext:)];
        runButton = [self _buttonWithAction:@selector(run:)];
        [runButton setTitle:"Run"];
        copyButton = [self _buttonWithAction:@selector(copyCode:)];
        [copyButton setTitle:"Copy code"];
        checkButton = [self _buttonWithAction:@selector(check:)];
        [checkButton setTitle:"Check answer"];

        [self setHidden:YES];
    }
    return self;
}

- (CPTextField)_labelWithFont:(CPFont)aFont
{
    var field = [[CPTextField alloc] initWithFrame:CGRectMakeZero()];
    [field setFont:aFont];
    [field setLineBreakMode:CPLineBreakByWordWrapping];
    [self addSubview:field];
    return field;
}

- (RichTextView)_richTextWithFont:(CPFont)aFont
{
    var view = [[RichTextView alloc] initWithFont:aFont];
    [self addSubview:view];
    return view;
}

- (CPButton)_buttonWithAction:(SEL)anAction
{
    var button = [[CPButton alloc] initWithFrame:CGRectMakeZero()];
    [button setTarget:self];
    [button setAction:anAction];
    [self addSubview:button];
    return button;
}

// Runs code problems. Shared by every ProblemView, so that a runtime is
// downloaded once per page load.
+ (CodeRunner)codeRunner
{
    if (!SharedCodeRunner)
        SharedCodeRunner = [[CodeRunner alloc] init];
    return SharedCodeRunner;
}

- (BOOL)isCodeProblem
{
    return problem && problem.type === "code";
}

// Run on the learner's computer, not in the browser.
- (BOOL)isLocalCodeProblem
{
    return [self isCodeProblem] && problem.run === "local";
}

- (void)setProblem:(Object)aProblem solved:(BOOL)isSolved
{
    // A program still running belongs to the problem before.
    [self _stopRunning];
    problem = aProblem;

    var isCode = [self isCodeProblem],
        isLocal = [self isLocalCodeProblem];
    [titleField setStringValue:problem.title];
    [bodyText setText:problem.body language:problem.language];
    [questionText setText:problem.question language:problem.language];
    [feedbackText setText:"" language:nil];
    [outputField setStringValue:""];

    [editor setHidden:!isCode];
    [runButton setHidden:!isCode || isLocal];
    [copyButton setHidden:!isLocal];
    [pasteLabel setHidden:!isLocal];
    [pasteEditor setHidden:!isLocal];
    [outputField setHidden:YES];
    [outputBox setHidden:YES];
    if (isCode)
        [editor setCode:problem.starter_code language:problem.language];
    if (isLocal)
        [pasteEditor setCode:"" language:nil];

    [self _setNeighbour:problem.previous ofButton:previousButton format:"\u2190 %@"];
    [self _setNeighbour:problem.next ofButton:nextButton format:"%@ \u2192"];

    for (var i = 0; i < radios.length; i++)
        [radios[i] removeFromSuperview];

    // When a radio is added to a view, Cappuccino groups it with the radios
    // there that share its action, and puts a radio without an action in a
    // group of its own. So the shared action is what makes them exclusive.
    radios = [];
    var choices = problem.choices || [];
    for (var i = 0; i < choices.length; i++)
    {
        var radio = [[CPRadio alloc] initWithFrame:CGRectMakeZero()];
        [radio setTarget:self];
        [radio setAction:@selector(choiceChanged:)];
        [radio setTitle:choices[i].text];
        [radio setTag:i];
        [radio setState:CPOffState];
        [self addSubview:radio];
        radios.push(radio);
    }

    [self setSolved:isSolved];
    [self setHidden:NO];
    [self setNeedsLayout];
}

- (void)_setNeighbour:(Object)aNeighbour ofButton:(CPButton)aButton format:(CPString)aFormat
{
    [aButton setHidden:!aNeighbour];
    if (aNeighbour)
        [aButton setTitle:[CPString stringWithFormat:aFormat, aNeighbour.title]];
}

- (void)setSolved:(BOOL)isSolved
{
    solved = isSolved;
    [titleField setTextColor:solved ? [CPColor colorWithHexString:"2E7D32"] : [CPColor blackColor]];
    [titleField setStringValue:problem.title + (solved ? "  \u2713" : "")];
    [self setNeedsLayout];
}

- (void)showFeedback:(CPString)aMessage correct:(BOOL)isCorrect
{
    [feedbackText setTextColor:isCorrect ? [CPColor colorWithHexString:"2E7D32"] : [CPColor colorWithHexString:"C62828"]];
    [feedbackText setText:aMessage language:problem.language];
    [self setNeedsLayout];
}

- (CPString)selectedChoiceId
{
    for (var i = 0; i < radios.length; i++)
        if ([radios[i] state] === CPOnState)
            return problem.choices[i].id;
    return nil;
}

// Actions

- (void)choiceChanged:(id)aSender
{
    // An old "Not quite" no longer applies to the new choice.
    if (solved)
        return;
    [feedbackText setText:"" language:nil];
    [self setNeedsLayout];
}

- (void)check:(id)aSender
{
    if ([self isLocalCodeProblem])
        return [self _submitPastedOutput];
    if ([self isCodeProblem])
        return [self _runThenSubmit:YES];

    var choiceId = [self selectedChoiceId];
    if (!choiceId)
        return [self showFeedback:"Pick an answer first." correct:NO];

    [delegate problemView:self didChooseChoiceId:choiceId];
}

- (void)_submitPastedOutput
{
    var pasted = [pasteEditor code];
    if (!pasted.trim())
        return [self showFeedback:"Run the program on your computer and paste what it printed first." correct:NO];

    [feedbackText setText:"" language:nil];
    [delegate problemView:self didSubmitOutput:pasted];
}

// Copies the code in the editor, as the learner may have changed it.
- (void)copyCode:(id)aSender
{
    var code = [editor code],
        done = function(aMessage)
        {
            [self showFeedback:aMessage correct:YES];
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        },
        failed = function()
        {
            [self showFeedback:"Could not copy it for you: select the code in the editor and copy it." correct:NO];
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        };

    if (!navigator.clipboard || !navigator.clipboard.writeText)
        return failed();
    navigator.clipboard.writeText(code).then(function() { done("Copied. Paste it into src/main.rs."); }, failed);
}

- (void)run:(id)aSender
{
    [self _runThenSubmit:NO];
}

/*
    Runs the program in the editor and shows what it printed. To check the
    answer, the output is then sent to the delegate, but only if the program
    ran to the end: the backend compares it with the expected output.
*/
- (void)_runThenSubmit:(BOOL)shouldSubmit
{
    var runProblem = problem;
    [self _setRunning:YES];
    [feedbackText setText:"" language:nil];
    [self _showOutput:"Running\u2026"];

    var progress = function(aMessage)
    {
        if (problem === runProblem)
            [self _showOutput:aMessage];
    };

    [[ProblemView codeRunner] run:[editor code] language:problem.language progress:progress callback:function(aResult)
    {
        if (problem !== runProblem)
            return;
        [self _setRunning:NO];
        [self _showOutput:CodeRunOutputText(aResult)];

        if (!shouldSubmit)
            return;
        if (aResult.status === "ok")
            [delegate problemView:self didSubmitOutput:aResult.stdout];
        else if (aResult.status === "error")
            [self showFeedback:"Your program stopped with an error. Fix it and try again." correct:NO];
    }];
}

- (void)_setRunning:(BOOL)isRunning
{
    running = isRunning;
    [runButton setEnabled:!running];
    [checkButton setEnabled:!running];
}

- (void)_stopRunning
{
    if (running)
        [[ProblemView codeRunner] stop];
    [self _setRunning:NO];
}

- (void)_showOutput:(CPString)aText
{
    [outputField setStringValue:aText];
    [outputField setHidden:NO];
    [outputBox setHidden:NO];
    [self setNeedsLayout];
}

- (void)goPrevious:(id)aSender
{
    [delegate problemView:self didRequestProblemId:problem.previous.id];
}

- (void)goNext:(id)aSender
{
    [delegate problemView:self didRequestProblemId:problem.next.id];
}

// Layout

- (void)layoutSubviews
{
    if (!problem)
        return;

    var width = MIN(MAX(CGRectGetWidth([self bounds]) - 2 * MARGIN, 100.0), MAX_TEXT_WIDTH),
        y = MARGIN;

    y = [self _place:titleField at:y width:width] + 4.0;

    [previousButton sizeToFit];
    [nextButton sizeToFit];
    [previousButton setFrameOrigin:CGPointMake(MARGIN, y)];
    [nextButton setFrameOrigin:CGPointMake(MARGIN + width - CGRectGetWidth([nextButton frame]), y)];
    y += BUTTON_HEIGHT + GAP;

    y = [self _placeRichText:bodyText at:y width:width] + GAP;
    y = [self _placeRichText:questionText at:y width:width] + GAP / 2;

    for (var i = 0; i < radios.length; i++)
    {
        [radios[i] setFrame:CGRectMake(MARGIN, y, width, RADIO_HEIGHT)];
        y += RADIO_HEIGHT + 4.0;
    }
    y += GAP / 2;

    var buttonX = MARGIN;
    if ([self isCodeProblem])
    {
        // Code to copy is shown whole, up to the usual height; past that,
        // and for code written here, the editor scrolls.
        var editorHeight = EDITOR_HEIGHT;
        if ([self isLocalCodeProblem])
            editorHeight = MIN(EDITOR_HEIGHT, MAX(100.0, (problem.starter_code || "").split("\n").length * 19.0 + 16.0));
        [editor setFrame:CGRectMake(MARGIN, y, width, editorHeight)];
        y += editorHeight + GAP;

        var sideButton = [self isLocalCodeProblem] ? copyButton : runButton;
        [sideButton sizeToFit];
        [sideButton setFrameOrigin:CGPointMake(MARGIN, y)];
        buttonX += CGRectGetWidth([sideButton frame]) + 8.0;
    }

    // Copy code, then where the output goes, then Check answer below it.
    if ([self isLocalCodeProblem])
    {
        y += BUTTON_HEIGHT + GAP;
        y = [self _place:pasteLabel at:y width:width] + GAP / 2;
        [pasteEditor setFrame:CGRectMake(MARGIN, y, width, PASTE_HEIGHT)];
        y += PASTE_HEIGHT + GAP;
        buttonX = MARGIN;
    }

    [checkButton sizeToFit];
    [checkButton setFrameOrigin:CGPointMake(buttonX, y)];
    y += BUTTON_HEIGHT + GAP;

    if (![outputField isHidden])
    {
        var top = y;
        y = [self _place:outputField at:y + 6.0 width:width - 12.0] + 6.0;
        [outputField setFrameOrigin:CGPointMake(MARGIN + 2.0, top + 6.0)];
        [outputBox setFrame:CGRectMake(MARGIN, top, width, y - top)];
        y += GAP;
    }

    y = [self _placeRichText:feedbackText at:y width:width] + MARGIN;

    // Grow to fit the content, but never shrink below the visible area.
    var minHeight = [self superview] ? CGRectGetHeight([[self superview] bounds]) : 0;
    var height = MAX(y, minHeight);
    if (height !== CGRectGetHeight([self frame]))
        [self setFrameSize:CGSizeMake(CGRectGetWidth([self frame]), height)];
}

// Lays out problem text at the given width, as _place: does a label;
// returns its bottom.
- (float)_placeRichText:(RichTextView)aView at:(float)y width:(float)aWidth
{
    [aView setFrameOrigin:CGPointMake(MARGIN - 4.0, y)];
    return y + [aView layoutForWidth:aWidth + 8.0];
}

// Sizes a wrapping label to its text at the given width; returns its bottom.
- (float)_place:(CPTextField)aField at:(float)y width:(float)aWidth
{
    var text = [aField stringValue] || " ",
        size = [text sizeWithFont:[aField font] inWidth:aWidth];

    // CPTextField pads its text by a few pixels on each side.
    [aField setFrame:CGRectMake(MARGIN - 4.0, y, aWidth + 8.0, size.height + 8.0)];
    return y + size.height + 8.0;
}

@end
