@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "ApiClient.j"
@import "CourseTree.j"
@import "Router.j"
@import "SidebarController.j"
@import "ProblemView.j"
@import "TextFormat.j"

var SIDEBAR_WIDTH = 260.0,
    HEADER_HEIGHT = 88.0,
    HELP_WIDTH = 300.0,
    HELP_PADDING = 14.0,
    REVISION_HELP = "Revision mode lets you go through the course again from the start, to practise what you " +
        "have learned. It is often said that you need to do an exercise three times before you truly know it.\n\n" +
        "Your first time through is kept: switch revision mode off to see it and carry on with it.\n\n" +
        "In a revision the answers are shuffled, so that you have to know the answer rather than remember " +
        "where it was.\n\n" +
        "The \u00D7N next to a problem shows how many times you have solved it. Start over begins a new " +
        "revision; an unfinished one is left behind.";

/*
    One course: the problem tree on the left and the selected problem on the
    right. Selecting a problem changes the URL; the app's router then calls
    -showProblemId:revisionMode:, so the back button and links work.

    Above the tree, a switch for revision mode: going through the course again
    from nothing, as many times as the learner likes, while round 1 (their
    first time through) is kept. The URL says which mode is shown
    (#/courses/... or #/revise/...).

    The delegate gets -courseControllerLostSession: when the server rejects
    the session.
*/
@implementation CourseController : CPObject
{
    id                  delegate    @accessors;
    CPString            courseId    @accessors(readonly);
    CPView              view        @accessors(readonly);

    ApiClient           api;
    CourseTree          tree;
    Object              progress;
    BOOL                revisionMode;
    BOOL                startingRevision;

    SidebarController   sidebar;
    ProblemView         problemView;
    CPCheckBox          revisionCheckBox;
    CPPopover           revisionHelp;
    CPTextField         roundField;
    CPButton            startOverButton;
    CPTextField         statusField;

    CPString            currentProblemId;
    CPString            wantedProblemId;
}

- (id)initWithFrame:(CGRect)aFrame api:(ApiClient)anApi courseId:(CPString)aCourseId
{
    if (self = [super init])
    {
        api = anApi;
        courseId = aCourseId;

        var splitView = [[CPSplitView alloc] initWithFrame:aFrame];
        [splitView setVertical:YES];
        [splitView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

        [splitView addSubview:[self _leftColumnWithHeight:CGRectGetHeight(aFrame)]];
        [splitView addSubview:[self _problemColumnWithFrame:CGRectMake(0, 0, CGRectGetWidth(aFrame) - SIDEBAR_WIDTH, CGRectGetHeight(aFrame))]];
        [splitView setPosition:SIDEBAR_WIDTH ofDividerAtIndex:0];
        view = splitView;

        [self load];
    }
    return self;
}

- (CPView)_leftColumnWithHeight:(float)aHeight
{
    var column = [[CPView alloc] initWithFrame:CGRectMake(0, 0, SIDEBAR_WIDTH, aHeight)],
        header = [[CPView alloc] initWithFrame:CGRectMake(0, 0, SIDEBAR_WIDTH, HEADER_HEIGHT)];

    [header setAutoresizingMask:CPViewWidthSizable];
    [header setBackgroundColor:[CPColor colorWithHexString:"EEF2F7"]];

    revisionCheckBox = [CPCheckBox checkBoxWithTitle:"Revision mode"];
    [revisionCheckBox setFrameOrigin:CGPointMake(10.0, 10.0)];
    [revisionCheckBox setTarget:self];
    [revisionCheckBox setAction:@selector(toggleRevisionMode:)];
    [revisionCheckBox setEnabled:NO];
    [header addSubview:revisionCheckBox];

    var helpButton = [CPButton buttonWithTitle:"?"];
    [helpButton sizeToFit];
    [helpButton setFrameOrigin:CGPointMake(CGRectGetMaxX([revisionCheckBox frame]) + 6.0, 7.0)];
    [helpButton setTarget:self];
    [helpButton setAction:@selector(showRevisionHelp:)];
    [header addSubview:helpButton];

    roundField = [CPTextField labelWithTitle:""];
    [roundField setFont:[CPFont systemFontOfSize:12.0]];
    [roundField setFrame:CGRectMake(10.0, 34.0, SIDEBAR_WIDTH - 20.0, 18.0)];
    [roundField setAutoresizingMask:CPViewWidthSizable];
    [header addSubview:roundField];

    startOverButton = [CPButton buttonWithTitle:"Start over"];
    [startOverButton setFrameOrigin:CGPointMake(10.0, 56.0)];
    [startOverButton setTarget:self];
    [startOverButton setAction:@selector(startOver:)];
    [startOverButton setHidden:YES];
    [header addSubview:startOverButton];

    sidebar = [[SidebarController alloc] initWithFrame:CGRectMake(0, HEADER_HEIGHT, SIDEBAR_WIDTH, aHeight - HEADER_HEIGHT)];
    [sidebar setDelegate:self];
    [[sidebar scrollView] setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    [column addSubview:header];
    [column addSubview:[sidebar scrollView]];
    return column;
}

- (CPView)_problemColumnWithFrame:(CGRect)aFrame
{
    var problemScroll = [[CPScrollView alloc] initWithFrame:aFrame];
    [problemScroll setAutohidesScrollers:YES];
    [problemScroll setHasHorizontalScroller:NO];
    [problemScroll setBackgroundColor:[CPColor whiteColor]];

    problemView = [[ProblemView alloc] initWithFrame:[[problemScroll contentView] bounds]];
    [problemView setAutoresizingMask:CPViewWidthSizable];
    [problemView setDelegate:self];
    [problemScroll setDocumentView:problemView];

    statusField = [CPTextField labelWithTitle:"Loading\u2026"];
    [statusField setFont:[CPFont systemFontOfSize:14.0]];
    [statusField setFrame:CGRectMake(24.0, 24.0, 600.0, 24.0)];
    [[problemScroll contentView] addSubview:statusField];
    return problemScroll;
}

- (void)load
{
    [api get:"/courses/" + encodeURIComponent(courseId) callback:function(status, body)
    {
        if (status !== 200)
            return [self showStatus:status === 404 ? "There is no such course." : "Could not load the course (" + status + ")."];

        tree = [[CourseTree alloc] initWithJSON:body];
        [api get:"/courses/" + encodeURIComponent(courseId) + "/progress" callback:function(status, body)
        {
            if (status === 401)
                return [delegate courseControllerLostSession:self];
            if (status !== 200)
                return [self showStatus:"Could not load your progress (" + status + ")."];

            progress = body;
            [sidebar setTree:tree];
            [revisionCheckBox setEnabled:YES];
            [statusField setHidden:YES];
            [self showProblemId:wantedProblemId revisionMode:revisionMode];
        }];
    }];
}

- (void)showStatus:(CPString)aMessage
{
    [statusField setStringValue:aMessage];
    [statusField setHidden:NO];
}

// Showing a problem

/*
    nil means wherever the learner should carry on: the first problem not
    solved in the round shown. Revision mode without a revision starts one.
*/
- (void)showProblemId:(CPString)anId revisionMode:(BOOL)isRevision
{
    var modeChanged = isRevision !== revisionMode;
    wantedProblemId = anId;
    revisionMode = isRevision;
    if (!tree || !progress)
        return; // -load comes back here

    if (isRevision && !progress.revision)
        return [self startRevision];

    if (modeChanged || !currentProblemId)
        [self applyProgress];

    if (!anId || ![tree nodeForProblemId:anId])
    {
        // Put the problem in the URL; the router then comes back here.
        window.location.replace(RouterCoursePath(courseId, [tree firstUnsolvedProblemId], revisionMode));
        return;
    }
    if (anId === currentProblemId && !modeChanged)
        return;

    currentProblemId = anId;
    [sidebar selectProblemId:anId];

    var round = [self round],
        path = "/courses/" + encodeURIComponent(courseId) + "/problems/" + encodeURIComponent(anId) +
               (round > 1 ? "?round=" + round : "");

    [api get:path callback:function(status, body)
    {
        // A slower, earlier request may answer after the student moved on.
        if (anId !== currentProblemId || round !== [self round])
            return;
        if (status !== 200)
            return [self showStatus:"Could not load this problem (" + status + ")."];

        [problemView setProblem:body solved:[[tree nodeForProblemId:anId] isSolved]];
        [[problemView enclosingScrollView] scrollToBeginningOfDocument:self];
    }];
}

// The round answers go to: 1, or the current revision's number.
- (int)round
{
    return revisionMode && progress && progress.revision ? progress.revision.number : 1;
}

// Draws the tree and the header for the round shown.
- (void)applyProgress
{
    [tree applyProgress:progress revisionMode:revisionMode];
    [sidebar setRevisionMode:revisionMode];
    [sidebar refresh];

    [revisionCheckBox setState:revisionMode ? CPOnState : CPOffState];
    [startOverButton setHidden:!revisionMode];

    var total = [[tree problemIds] count],
        times = progress.times_completed;
    if (revisionMode)
        [roundField setStringValue:"Revision " + (progress.revision.number - 1) + ": " + [tree solvedCount] + " / " + total + " solved"];
    else
        [roundField setStringValue:times === 0 ? "Not completed yet" :
                                   "Completed " + times + (times === 1 ? " time" : " times")];
}

- (void)_navigateToProblemId:(CPString)anId revisionMode:(BOOL)isRevision
{
    window.location.hash = RouterCoursePath(courseId, anId, isRevision);
}

- (void)sidebar:(SidebarController)aSidebar didSelectProblemId:(CPString)anId
{
    [self _navigateToProblemId:anId revisionMode:revisionMode];
}

- (void)problemView:(ProblemView)aView didRequestProblemId:(CPString)anId
{
    [self _navigateToProblemId:anId revisionMode:revisionMode];
}

// Revisions

- (void)toggleRevisionMode:(id)aSender
{
    // The URL decides; going to the first unsolved problem of the other round.
    // -applyProgress then sets the checkbox to match.
    [self _navigateToProblemId:nil revisionMode:!revisionMode];
}

// Explains revision mode, next to the button. Closes on any click outside it.
- (void)showRevisionHelp:(id)aSender
{
    if (!revisionHelp)
    {
        var font = [CPFont systemFontOfSize:13.0],
            textWidth = HELP_WIDTH - 2 * HELP_PADDING,
            textSize = [REVISION_HELP sizeWithFont:font inWidth:textWidth],
            content = [[CPView alloc] initWithFrame:CGRectMake(0, 0, HELP_WIDTH, textSize.height + 2 * HELP_PADDING + 8.0)],
            text = [[CPTextField alloc] initWithFrame:CGRectMake(HELP_PADDING - 4.0, HELP_PADDING, textWidth + 8.0, textSize.height + 8.0)];

        [text setFont:font];
        [text setLineBreakMode:CPLineBreakByWordWrapping];
        [text setStringValue:REVISION_HELP];
        [content addSubview:text];

        var controller = [[CPViewController alloc] init];
        [controller setView:content];

        revisionHelp = [[CPPopover alloc] init];
        [revisionHelp setContentViewController:controller];
        [revisionHelp setBehavior:CPPopoverBehaviorTransient];
    }

    if ([revisionHelp isShown])
        [revisionHelp close];
    else
        [revisionHelp showRelativeToRect:nil ofView:aSender preferredEdge:CPMaxXEdge];
}

- (void)startRevision
{
    if (startingRevision)
        return;
    startingRevision = YES;

    [api post:"/courses/" + encodeURIComponent(courseId) + "/revisions" body:nil callback:function(status, body)
    {
        startingRevision = NO;
        if (status === 401)
            return [delegate courseControllerLostSession:self];
        if (status !== 201)
            return [self showStatus:"Could not start a revision (" + status + ")."];

        progress = body;
        currentProblemId = nil;
        // To the first problem in revision mode, through the router if the
        // URL changes (it then comes back here), or directly if it does not.
        var path = RouterCoursePath(courseId, nil, YES);
        if (window.location.hash === path)
            [self showProblemId:nil revisionMode:YES];
        else
            window.location.replace(path);
    }];
}

- (void)startOver:(id)aSender
{
    if ([tree solvedCount] === 0)
        return; // nothing to lose, and nothing to gain

    var alert = [[CPAlert alloc] init],
        finished = [tree solvedCount] === [[tree problemIds] count];
    [alert setMessageText:finished ? "Start another revision?" : "Start this revision over?"];
    [alert setInformativeText:finished ? "You go through the course again from the start." :
                              "This revision is left unfinished, and you go through the course again from the start. Your other progress is kept."];
    [alert addButtonWithTitle:"Start again"];
    [alert addButtonWithTitle:"Cancel"];
    [alert runModalWithDidEndBlock:function(anAlert, aReturnCode)
    {
        if (aReturnCode === 0)
            [self startRevision];
    }];
}

// Answering

- (void)problemView:(ProblemView)aView didChooseChoiceId:(CPString)aChoiceId
{
    var problemId = currentProblemId,
        round = [self round],
        path = "/courses/" + encodeURIComponent(courseId) + "/problems/" + encodeURIComponent(problemId) + "/answer";

    [api post:path body:{ choice: aChoiceId, round: round } callback:function(status, body)
    {
        if (status === 401)
            return [delegate courseControllerLostSession:self];
        if (status === 409)
            return [aView showFeedback:"This revision was replaced by a newer one. Reload the page to carry on." correct:NO];
        if (status !== 200)
            return [aView showFeedback:"Could not check your answer (" + status + ")." correct:NO];
        if (problemId !== currentProblemId || round !== [self round])
            return;

        if (!body.correct)
            return [aView showFeedback:"Not quite. Try again." correct:NO];

        var timesBefore = progress.times_completed;
        progress = body.progress;
        [self applyProgress];
        [aView setSolved:YES];

        var message = "Correct! " + TextFormatReflow(body.explanation);
        if (progress.times_completed > timesBefore)
            message += "\n\n" + (revisionMode ? "Revision complete! " : "Course complete! ") +
                       "You have completed this course " + progress.times_completed +
                       (progress.times_completed === 1 ? " time." : " times.");
        [aView showFeedback:message correct:YES];
    }];
}

@end
