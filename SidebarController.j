@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "CourseTree.j"

var SidebarRowInset = 3.0,
    SidebarRowMarkWidth = 16.0;

/*
    A row of the tree: the mark in a field of its own, so that a tick can be
    green, then the rest of the label. Takes the label from the data source
    as its object value. Passes the selected state on to its fields, so that
    both turn white on the selection.
*/
@implementation SidebarRowView : CPView
{
    CPTextField _mark;
    CPTextField _text;
    CPString    _label;
}

- (id)initWithFrame:(CGRect)aFrame
{
    if (self = [super initWithFrame:aFrame])
    {
        var height = CGRectGetHeight(aFrame);
        _mark = [self _fieldWithFrame:CGRectMake(SidebarRowInset, 0, SidebarRowMarkWidth, height)];
        var textX = SidebarRowInset + SidebarRowMarkWidth;
        _text = [self _fieldWithFrame:CGRectMake(textX, 0, CGRectGetWidth(aFrame) - textX, height)];
        [_text setAutoresizingMask:CPViewWidthSizable];
        [_text setLineBreakMode:CPLineBreakByTruncatingTail];
    }
    return self;
}

- (CPTextField)_fieldWithFrame:(CGRect)aFrame
{
    var field = [[CPTextField alloc] initWithFrame:aFrame];
    [field setEditable:NO];
    [field setBezeled:NO];
    [field setDrawsBackground:NO];
    [field setVerticalAlignment:CPCenterVerticalTextAlignment];
    [self addSubview:field];
    return field;
}

- (id)objectValue
{
    return _label;
}

- (void)setObjectValue:(id)aValue
{
    _label = aValue;
    var parts = CourseTreeSplitMark(String(aValue || ""));
    [_mark setStringValue:parts[0]];
    [_mark setTextColor:parts[0] == "\u2713" ? [CPColor colorWithHexString:"2E9E44"] : [CPColor grayColor]];
    [_text setStringValue:parts[1]];
}

- (BOOL)setThemeState:(ThemeState)aState
{
    [_mark setThemeState:aState];
    [_text setThemeState:aState];
    return [super setThemeState:aState];
}

- (BOOL)unsetThemeState:(ThemeState)aState
{
    [_mark unsetThemeState:aState];
    [_text unsetThemeState:aState];
    return [super unsetThemeState:aState];
}

@end

/*
    The collapsible problem tree on the left. Tells its delegate when the
    student picks a problem with -sidebar:didSelectProblemId:.
*/
@implementation SidebarController : CPObject
{
    CPOutlineView   outlineView @accessors(readonly);
    CPScrollView    scrollView  @accessors(readonly);
    CourseTree      tree;
    id              delegate    @accessors;
    BOOL            revisionMode @accessors;
    BOOL            _selectingProgrammatically;
}

- (id)initWithFrame:(CGRect)aFrame
{
    if (self = [super init])
    {
        scrollView = [[CPScrollView alloc] initWithFrame:aFrame];
        [scrollView setAutohidesScrollers:YES];
        [scrollView setHasHorizontalScroller:NO];

        outlineView = [[CPOutlineView alloc] initWithFrame:[[scrollView contentView] bounds]];
        [outlineView setAutoresizingMask:CPViewWidthSizable];
        var column = [[CPTableColumn alloc] initWithIdentifier:"title"];
        [column setWidth:CGRectGetWidth(aFrame)];
        [column setResizingMask:CPTableColumnAutoresizingMask];
        [outlineView addTableColumn:column];
        [outlineView setOutlineTableColumn:column];
        [outlineView setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
        [outlineView setHeaderView:nil];
        [outlineView setCornerView:nil];
        [outlineView setRowHeight:22.0];
        [outlineView setDataSource:self];
        [outlineView setDelegate:self];

        [scrollView setDocumentView:outlineView];
    }
    return self;
}

- (void)setTree:(CourseTree)aTree
{
    tree = aTree;
    [outlineView reloadData];
    // Top-level sections start open, like the first level on HDLBits.
    var roots = [tree rootNodes];
    for (var i = 0; i < roots.length; i++)
        [outlineView expandItem:roots[i]];
}

// After progress changed: redraw the rows, keeping what is open.
- (void)refresh
{
    _selectingProgrammatically = YES;
    var row = [outlineView selectedRow];
    [outlineView reloadData];
    if (row >= 0)
        [outlineView selectRowIndexes:[CPIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    _selectingProgrammatically = NO;
}

/*
    All of it is guarded, not just the selection: opening a section above
    the selected row moves the selection, and CPOutlineView reports that as
    a change, which would otherwise navigate back to the old problem.
*/
- (void)selectProblemId:(CPString)anId
{
    var node = [tree nodeForProblemId:anId],
        ancestors = [tree ancestorsOfNode:node];

    _selectingProgrammatically = YES;
    for (var i = 0; i < ancestors.length; i++)
        [outlineView expandItem:ancestors[i]];

    var row = [outlineView rowForItem:node];
    [outlineView selectRowIndexes:[CPIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    _selectingProgrammatically = NO;
    [outlineView scrollRowToVisible:row];
}

// CPOutlineView data source

- (int)outlineView:(CPOutlineView)anOutlineView numberOfChildrenOfItem:(id)anItem
{
    if (!tree)
        return 0;
    return anItem ? [[anItem children] count] : [[tree rootNodes] count];
}

- (id)outlineView:(CPOutlineView)anOutlineView child:(int)anIndex ofItem:(id)anItem
{
    return anItem ? [anItem children][anIndex] : [tree rootNodes][anIndex];
}

- (BOOL)outlineView:(CPOutlineView)anOutlineView isItemExpandable:(id)anItem
{
    return ![anItem isProblem];
}

- (id)outlineView:(CPOutlineView)anOutlineView objectValueForTableColumn:(CPTableColumn)aColumn byItem:(id)anItem
{
    if (![anItem isProblem])
        return CourseTreeSectionLabel([anItem title], [anItem solvedProblemCount], [anItem problemCount]);
    return CourseTreeProblemLabel([anItem title], [anItem isSolved], [anItem timesSolved], revisionMode);
}

// CPOutlineView delegate

- (CPView)outlineView:(CPOutlineView)anOutlineView viewForTableColumn:(CPTableColumn)aColumn item:(id)anItem
{
    // Not makeViewWithIdentifier:, which looks for a cib of that name first.
    return [[SidebarRowView alloc] initWithFrame:CGRectMake(0, 0, [aColumn width], [anOutlineView rowHeight])];
}

- (BOOL)outlineView:(CPOutlineView)anOutlineView shouldSelectItem:(id)anItem
{
    // Clicking a section opens or closes it instead of selecting it. That
    // moves the selected row too, which is not the learner choosing it.
    if ([anItem isProblem])
        return YES;

    _selectingProgrammatically = YES;
    if ([anOutlineView isItemExpanded:anItem])
        [anOutlineView collapseItem:anItem];
    else
        [anOutlineView expandItem:anItem];
    _selectingProgrammatically = NO;
    return NO;
}

- (void)outlineViewSelectionDidChange:(CPNotification)aNotification
{
    if (_selectingProgrammatically)
        return;

    var item = [outlineView itemAtRow:[outlineView selectedRow]];
    if (item && [item isProblem])
        [delegate sidebar:self didSelectProblemId:[item problemId]];
}

@end
