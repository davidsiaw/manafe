@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "CourseTree.j"

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
    var row = [outlineView selectedRow];
    [outlineView reloadData];
    _selectingProgrammatically = YES;
    if (row >= 0)
        [outlineView selectRowIndexes:[CPIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    _selectingProgrammatically = NO;
}

- (void)selectProblemId:(CPString)anId
{
    var node = [tree nodeForProblemId:anId],
        ancestors = [tree ancestorsOfNode:node];

    for (var i = 0; i < ancestors.length; i++)
        [outlineView expandItem:ancestors[i]];

    var row = [outlineView rowForItem:node];
    _selectingProgrammatically = YES;
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
        return [anItem title];
    return CourseTreeProblemLabel([anItem title], [anItem isSolved], [anItem timesSolved], revisionMode);
}

// CPOutlineView delegate

- (BOOL)outlineView:(CPOutlineView)anOutlineView shouldSelectItem:(id)anItem
{
    // Clicking a section opens or closes it instead of selecting it.
    if ([anItem isProblem])
        return YES;

    if ([anOutlineView isItemExpanded:anItem])
        [anOutlineView collapseItem:anItem];
    else
        [anOutlineView expandItem:anItem];
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
