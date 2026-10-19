@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "TextFormat.j"

var MARGIN = 24.0,
    MAX_WIDTH = 760.0,
    GAP = 18.0;

/*
    A page of headings, text, buttons, inputs and course cards, stacked top
    to bottom. Every screen except a course itself is one of these. A course
    card has the course title as a button, its description, and progress when
    known; the delegate gets -pageView:didOpenCourse:revision: with the course
    summary from the API.

    Lives inside a scroll view (see PageViewInScrollView) and grows to fit.
*/
@implementation PageView : CPView
{
    id          delegate    @accessors;
    CPArray     rows;       // views, in order, with a height each
}

- (id)initWithFrame:(CGRect)aFrame
{
    if (self = [super initWithFrame:aFrame])
    {
        rows = [];
        [self setAutoresizingMask:CPViewWidthSizable];
    }
    return self;
}

- (void)removeAllRows
{
    for (var i = 0; i < rows.length; i++)
        [rows[i].view removeFromSuperview];
    rows = [];
    [self setNeedsLayout];
}

- (CPTextField)addHeading:(CPString)aString
{
    return [self addText:aString font:[CPFont boldSystemFontOfSize:24.0]];
}

- (CPTextField)addText:(CPString)aString
{
    return [self addText:aString font:[CPFont systemFontOfSize:14.0]];
}

- (CPTextField)addText:(CPString)aString font:(CPFont)aFont
{
    var field = [[CPTextField alloc] initWithFrame:CGRectMakeZero()];
    [field setFont:aFont];
    [field setLineBreakMode:CPLineBreakByWordWrapping];
    [field setStringValue:aString];
    return [self _addRow:field kind:"text"];
}

- (CPButton)addButton:(CPString)aTitle target:(id)aTarget action:(SEL)anAction
{
    var button = [CPButton buttonWithTitle:aTitle];
    [button setTarget:aTarget];
    [button setAction:anAction];
    [self _addRow:button kind:"button"];
    rows[rows.length - 1].gapAfter = GAP;
    return button;
}

// aSummary: an entry from GET /courses or GET /me.
- (void)addCourse:(Object)aSummary
{
    var title = [CPButton buttonWithTitle:aSummary.title];
    [title setBordered:NO];
    [title setFont:[CPFont boldSystemFontOfSize:18.0]];
    [title setTextColor:[CPColor colorWithHexString:"1F5FAF"]];
    [title setTarget:self];
    [title setAction:@selector(openCourse:)];
    title._course = aSummary;
    [self _addRow:title kind:"button"];

    if (aSummary.description)
        [self addText:TextFormatReflow(aSummary.description)];

    if (aSummary.solved_count !== nil && aSummary.solved_count !== undefined)
    {
        var times = aSummary.times_completed,
            completed = times ? " \u00B7 completed " + times + (times === 1 ? " time" : " times") : "";
        [self addText:aSummary.solved_count + " / " + aSummary.problem_count + " solved" + completed
                 font:[CPFont systemFontOfSize:12.0]];

        var bar = [[CPProgressIndicator alloc] initWithFrame:CGRectMake(0, 0, 200, 16)];
        [bar setStyle:CPProgressIndicatorBarStyle];
        [bar setIndeterminate:NO];
        [bar setMinValue:0];
        [bar setMaxValue:aSummary.problem_count || 1];
        [bar setDoubleValue:aSummary.solved_count];
        [self _addRow:bar kind:"bar"];

        if (aSummary.revision)
        {
            [self addText:"Revision " + (aSummary.revision.number - 1) + ": " + aSummary.revision.solved_count +
                          " / " + aSummary.problem_count + " solved" font:[CPFont systemFontOfSize:12.0]];
            var revise = [CPButton buttonWithTitle:"Continue revision of " + aSummary.title];
            [revise setTarget:self];
            [revise setAction:@selector(openRevision:)];
            revise._course = aSummary;
            [self _addRow:revise kind:"button"];
        }
    }
    rows[rows.length - 1].gapAfter = GAP;
}

- (void)openCourse:(id)aSender
{
    [delegate pageView:self didOpenCourse:aSender._course revision:NO];
}

- (void)openRevision:(id)aSender
{
    [delegate pageView:self didOpenCourse:aSender._course revision:YES];
}

- (CPTextField)addInputWithPlaceholder:(CPString)aPlaceholder
{
    var field = [CPTextField textFieldWithStringValue:"" placeholder:aPlaceholder width:320.0];
    return [self _addRow:field kind:"input"];
}

- (id)_addRow:(CPView)aView kind:(CPString)aKind
{
    [self addSubview:aView];
    rows.push({ view: aView, kind: aKind, gapAfter: 6.0 });
    [self setNeedsLayout];
    return aView;
}

- (void)layoutSubviews
{
    var width = MIN(MAX(CGRectGetWidth([self bounds]) - 2 * MARGIN, 100.0), MAX_WIDTH),
        y = MARGIN;

    for (var i = 0; i < rows.length; i++)
    {
        var row = rows[i],
            view = row.view;

        if (row.kind === "text")
        {
            var size = [([view stringValue] || " ") sizeWithFont:[view font] inWidth:width];
            [view setFrame:CGRectMake(MARGIN - 4.0, y, width + 8.0, size.height + 8.0)];
        }
        else if (row.kind === "input")
            [view setFrame:CGRectMake(MARGIN - 4.0, y, MIN(width, 320.0), 30.0)];
        else if (row.kind === "bar")
            [view setFrame:CGRectMake(MARGIN, y, MIN(width, 300.0), 16.0)];
        else
        {
            [view sizeToFit];
            [view setFrameOrigin:CGPointMake(row.kind === "button" && ![view isBordered] ? MARGIN - 4.0 : MARGIN, y)];
        }
        y += CGRectGetHeight([view frame]) + row.gapAfter;
    }

    var minHeight = [self superview] ? CGRectGetHeight([[self superview] bounds]) : 0,
        height = MAX(y + MARGIN, minHeight);
    if (height !== CGRectGetHeight([self frame]))
        [self setFrameSize:CGSizeMake(CGRectGetWidth([self frame]), height)];
}

@end

// A PageView in a scroll view. Returns both.
function PageViewInScrollView(aFrame)
{
    var scroll = [[CPScrollView alloc] initWithFrame:aFrame];
    [scroll setAutohidesScrollers:YES];
    [scroll setHasHorizontalScroller:NO];
    [scroll setBackgroundColor:[CPColor whiteColor]];
    [scroll setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    var page = [[PageView alloc] initWithFrame:[[scroll contentView] bounds]];
    [scroll setDocumentView:page];
    return { scrollView: scroll, page: page };
}
