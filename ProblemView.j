@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "TextFormat.j"

var MARGIN = 24.0,
    MAX_TEXT_WIDTH = 760.0,
    GAP = 14.0,
    BUTTON_HEIGHT = 24.0,
    RADIO_HEIGHT = 22.0;

/*
    The right-hand side: one problem's explanation and its multiple choice
    question. Everything is stacked top to bottom in -layoutSubviews, and the
    view grows to fit so that the enclosing scroll view can scroll it.

    The delegate gets -problemView:didChooseChoiceId: when Check answer is
    pressed, and -problemView:didRequestProblemId: for Previous and Next.
*/
@implementation ProblemView : CPView
{
    id          delegate    @accessors;

    CPTextField titleField;
    CPButton    previousButton;
    CPButton    nextButton;
    CPTextField bodyField;
    CPTextField questionField;
    CPArray     radios;
    CPButton    checkButton;
    CPTextField feedbackField;

    Object      problem;
    BOOL        solved;
}

- (id)initWithFrame:(CGRect)aFrame
{
    if (self = [super initWithFrame:aFrame])
    {
        radios = [];

        titleField = [self _labelWithFont:[CPFont boldSystemFontOfSize:26.0]];
        bodyField = [self _labelWithFont:[CPFont systemFontOfSize:14.0]];
        [bodyField setSelectable:YES];
        questionField = [self _labelWithFont:[CPFont boldSystemFontOfSize:14.0]];
        feedbackField = [self _labelWithFont:[CPFont systemFontOfSize:14.0]];

        previousButton = [self _buttonWithAction:@selector(goPrevious:)];
        nextButton = [self _buttonWithAction:@selector(goNext:)];
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

- (CPButton)_buttonWithAction:(SEL)anAction
{
    var button = [[CPButton alloc] initWithFrame:CGRectMakeZero()];
    [button setTarget:self];
    [button setAction:anAction];
    [self addSubview:button];
    return button;
}

- (void)setProblem:(Object)aProblem solved:(BOOL)isSolved
{
    problem = aProblem;

    [titleField setStringValue:problem.title];
    [bodyField setStringValue:TextFormatReflow(problem.body)];
    [questionField setStringValue:problem.question];
    [feedbackField setStringValue:""];

    [self _setNeighbour:problem.previous ofButton:previousButton format:"\u2190 %@"];
    [self _setNeighbour:problem.next ofButton:nextButton format:"%@ \u2192"];

    for (var i = 0; i < radios.length; i++)
        [radios[i] removeFromSuperview];

    // When a radio is added to a view, Cappuccino groups it with the radios
    // there that share its action, and puts a radio without an action in a
    // group of its own. So the shared action is what makes them exclusive.
    radios = [];
    for (var i = 0; i < problem.choices.length; i++)
    {
        var radio = [[CPRadio alloc] initWithFrame:CGRectMakeZero()];
        [radio setTarget:self];
        [radio setAction:@selector(choiceChanged:)];
        [radio setTitle:problem.choices[i].text];
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
    [feedbackField setTextColor:isCorrect ? [CPColor colorWithHexString:"2E7D32"] : [CPColor colorWithHexString:"C62828"]];
    [feedbackField setStringValue:aMessage];
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
    [feedbackField setStringValue:""];
    [self setNeedsLayout];
}

- (void)check:(id)aSender
{
    var choiceId = [self selectedChoiceId];
    if (!choiceId)
        return [self showFeedback:"Pick an answer first." correct:NO];

    [delegate problemView:self didChooseChoiceId:choiceId];
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

    y = [self _place:bodyField at:y width:width] + GAP;
    y = [self _place:questionField at:y width:width] + GAP / 2;

    for (var i = 0; i < radios.length; i++)
    {
        [radios[i] setFrame:CGRectMake(MARGIN, y, width, RADIO_HEIGHT)];
        y += RADIO_HEIGHT + 4.0;
    }
    y += GAP / 2;

    [checkButton sizeToFit];
    [checkButton setFrameOrigin:CGPointMake(MARGIN, y)];
    y += BUTTON_HEIGHT + GAP;

    y = [self _place:feedbackField at:y width:width] + MARGIN;

    // Grow to fit the content, but never shrink below the visible area.
    var minHeight = [self superview] ? CGRectGetHeight([[self superview] bounds]) : 0;
    var height = MAX(y, minHeight);
    if (height !== CGRectGetHeight([self frame]))
        [self setFrameSize:CGSizeMake(CGRectGetWidth([self frame]), height)];
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
