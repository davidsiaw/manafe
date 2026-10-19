@import <Foundation/Foundation.j>

/*
    One row of the sidebar: either a section (has children, no problemId) or
    a problem (has a problemId, no children).
*/
@implementation CourseNode : CPObject
{
    CPString    title       @accessors;
    CPString    problemId   @accessors;
    CPArray     children    @accessors;
    CourseNode  parent      @accessors;
    BOOL        solved      @accessors(getter=isSolved);  // in the round being shown
    int         timesSolved @accessors;                     // in how many rounds, all told
}

- (BOOL)isProblem
{
    return problemId != nil;
}

// A section is solved when it has problems and every one under it is solved.
- (BOOL)isSolved
{
    if ([self isProblem])
        return solved;
    var total = [self problemCount];
    return total > 0 && [self solvedProblemCount] == total;
}

// Problems in this node and below: 1 for a problem.
- (int)problemCount
{
    if ([self isProblem])
        return 1;
    var count = 0;
    for (var i = 0; i < children.length; i++)
        count += [children[i] problemCount];
    return count;
}

- (int)solvedProblemCount
{
    if ([self isProblem])
        return solved ? 1 : 0;
    var count = 0;
    for (var i = 0; i < children.length; i++)
        count += [children[i] solvedProblemCount];
    return count;
}

@end

/*
    The sidebar tree built from GET /courses/:id, plus which problems are
    solved. Pure logic, so it is covered by tests/unit/CourseTreeTest.j.
*/
@implementation CourseTree : CPObject
{
    CPString        title       @accessors(readonly);
    CPArray         rootNodes   @accessors(readonly);
    CPArray         problemIds  @accessors(readonly);  // in sidebar order
    CPDictionary    _byProblemId;
}

- (id)initWithJSON:(Object)json
{
    if (self = [super init])
    {
        title = json.title;
        problemIds = [];
        _byProblemId = @{};
        rootNodes = [self _nodesForSections:json.sections parent:nil];
    }
    return self;
}

- (CPArray)_nodesForSections:(Array)sections parent:(CourseNode)aParent
{
    var nodes = [];
    for (var i = 0; i < sections.length; i++)
    {
        var section = sections[i],
            node = [[CourseNode alloc] init],
            children = [];

        [node setTitle:section.title];
        [node setParent:aParent];

        // A section's own problems come before its subsections, as on the server.
        for (var j = 0; j < section.problems.length; j++)
            children.push([self _nodeForProblem:section.problems[j] parent:node]);

        children = children.concat([self _nodesForSections:section.sections parent:node]);
        [node setChildren:children];
        nodes.push(node);
    }
    return nodes;
}

- (CourseNode)_nodeForProblem:(Object)problem parent:(CourseNode)aParent
{
    var node = [[CourseNode alloc] init];
    [node setTitle:problem.title];
    [node setProblemId:problem.id];
    [node setChildren:[]];
    [node setParent:aParent];
    problemIds.push(problem.id);
    [_byProblemId setObject:node forKey:problem.id];
    return node;
}

- (CourseNode)nodeForProblemId:(CPString)anId
{
    return [_byProblemId objectForKey:anId];
}

// Ids the server does not know about any more are ignored.
- (void)markSolved:(CPArray)ids
{
    for (var i = 0; i < ids.length; i++)
        [[self nodeForProblemId:ids[i]] setSolved:YES];
}

/*
    Applies progress from the API (GET /courses/:id/progress), showing either
    round 1 or the current revision. Returns NO when revision mode is asked
    for but no revision has been started.
*/
- (BOOL)applyProgress:(Object)aProgress revisionMode:(BOOL)isRevision
{
    if (isRevision && !aProgress.revision)
        return NO;

    for (var i = 0; i < problemIds.length; i++)
    {
        var node = [self nodeForProblemId:problemIds[i]];
        [node setSolved:NO];
        [node setTimesSolved:aProgress.times_solved[problemIds[i]] || 0];
    }
    [self markSolved:isRevision ? aProgress.revision.solved : aProgress.solved];
    return YES;
}

- (int)solvedCount
{
    var count = 0;
    for (var i = 0; i < problemIds.length; i++)
        if ([[self nodeForProblemId:problemIds[i]] isSolved])
            count++;
    return count;
}

- (CPString)firstUnsolvedProblemId
{
    for (var i = 0; i < problemIds.length; i++)
        if (![[self nodeForProblemId:problemIds[i]] isSolved])
            return problemIds[i];

    return problemIds[0];
}

// Outermost first, so that expanding them in order reveals the node.
- (CPArray)ancestorsOfNode:(CourseNode)aNode
{
    var result = [],
        current = [aNode parent];

    while (current)
    {
        result.unshift(current);
        current = [current parent];
    }
    return result;
}

@end

/*
    A problem's row in the sidebar: a tick or a circle for the round being
    shown, then how many rounds it has been solved in. The count shows from
    two rounds on; in revision mode also at one, which marks the problems
    that were solved before.
*/
function CourseTreeProblemLabel(aTitle, isSolved, aTimesSolved, isRevision)
{
    var mark = isSolved ? "\u2713 " : "\u25CB ",
        showCount = aTimesSolved >= 2 || (isRevision && aTimesSolved >= 1);
    return mark + aTitle + (showCount ? "  \u00D7" + aTimesSolved : "");
}

/*
    A section's row: ticked when every problem under it is solved in the
    round being shown, then how many of them are.
*/
function CourseTreeSectionLabel(aTitle, aSolvedCount, aProblemCount)
{
    var mark = aProblemCount > 0 && aSolvedCount == aProblemCount ? "\u2713 " : "\u25CB ";
    return mark + aTitle + "  " + aSolvedCount + "/" + aProblemCount;
}

// [mark, rest] of a row label, so that the sidebar can colour the mark.
function CourseTreeSplitMark(aLabel)
{
    var first = aLabel.charAt(0);
    if ((first == "\u2713" || first == "\u25CB") && aLabel.charAt(1) == " ")
        return [first, aLabel.substring(2)];
    return ["", aLabel];
}
