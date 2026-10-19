@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "Config.j"
@import "ApiClient.j"
@import "AuthStore.j"
@import "Passkeys.j"
@import "Router.j"
@import "TopBar.j"
@import "PageView.j"
@import "CourseController.j"

/*
    The top bar, and below it whichever screen the URL hash asks for (see
    Router.j). Also who the learner is: AuthStore keeps the session, and this
    class runs the startup, register, log in and log out flows.
*/
@implementation AppController : CPObject
{
    ApiClient           api;
    AuthStore           auth;
    TopBar              topBar;
    CPView              contentArea;
    CPView              currentContent;
    CourseController    courseController;
    BOOL                ready;
    int                 routeGeneration;
    int                 sessionRestarts;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    var theWindow = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask],
        contentView = [theWindow contentView],
        bounds = [contentView bounds],
        barHeight = [TopBar height];

    topBar = [[TopBar alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(bounds), barHeight)];
    [topBar setAutoresizingMask:CPViewWidthSizable];
    [topBar setDelegate:self];
    [contentView addSubview:topBar];

    contentArea = [[CPView alloc] initWithFrame:CGRectMake(0, barHeight, CGRectGetWidth(bounds), CGRectGetHeight(bounds) - barHeight)];
    [contentArea setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [contentView addSubview:contentArea];

    [theWindow orderFront:self];

    api = [[ApiClient alloc] initWithBaseURL:API_BASE_URL];
    auth = [[AuthStore alloc] initWithStorage:window.localStorage];

    window.addEventListener("hashchange", function()
    {
        [self route];
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
    }, false);

    [self showMessage:"Loading\u2026"];
    [self start];
}

// Startup: make sure we know who we are, then show the screen the URL asks for.

- (void)start
{
    var state = [auth state];

    if (state === "registered" || state === "anonymous")
    {
        [api setToken:[auth token]];
        [api get:"/me" callback:function(status, body)
        {
            if (status === 401)
                return [self sessionWasRejected];
            if (status !== 200)
                return [self showMessage:"Could not reach the server (" + status + ")."];

            [auth setEmail:body.email];
            [self authChanged];
        }];
    }
    else if (state === "loggedOut")
        [self authChanged];
    else
    {
        [api setToken:nil];
        [api post:"/learners" body:nil callback:function(status, body)
        {
            if (status !== 201)
                return [self showMessage:"Could not reach the server (" + status + ")."];

            [auth startAnonymousSession:body.token];
            [self authChanged];
        }];
    }
}

// Who we are changed: update everything that depends on it.
- (void)authChanged
{
    [self authChangedNavigatingTo:nil];
}

// Shows aHash, or the current screen again if nil. Routes exactly once.
- (void)authChangedNavigatingTo:(CPString)aHash
{
    ready = YES;
    [api setToken:[auth token]];
    [topBar setState:[auth state] email:[auth email]];
    courseController = nil; // its progress belonged to the previous learner

    if (aHash && aHash !== window.location.hash)
        window.location.hash = aHash; // the hashchange listener routes
    else
        [self route];
}

- (void)courseControllerLostSession:(CourseController)aController
{
    [self sessionWasRejected];
}

/*
    The server no longer knows our session, e.g. after a database reset:
    start over. But only once per page load. If even a new session is
    rejected, something is wrong on the server, and starting over again
    would create learners in a loop as fast as the server answers.
*/
- (void)sessionWasRejected
{
    if (++sessionRestarts > 1)
        return [self showMessage:"The server keeps rejecting this browser's session. Please reload the page to try again."];

    [auth endSession];
    [self start];
}

// Screens

- (void)route
{
    if (!ready)
        return;

    var route = RouterParse(window.location.hash),
        generation = ++routeGeneration;

    if ([auth state] === "loggedOut" && route.screen !== "register")
        return [self showLoginRequired];

    switch (route.screen)
    {
        case "course":
            return [self showCourse:route.courseId problemId:route.problemId revisionMode:route.revision];
        case "me":
            return [self showProfile:generation];
        case "register":
            return [self showRegister];
        default:
            return [self showMenu:generation];
    }
}

- (void)showContent:(CPView)aView
{
    if (currentContent === aView)
        return;

    [currentContent removeFromSuperview];
    [aView setFrame:[contentArea bounds]];
    [aView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [contentArea addSubview:aView];
    currentContent = aView;
}

- (PageView)showNewPage
{
    var page = PageViewInScrollView([contentArea bounds]);
    [page.page setDelegate:self];
    [self showContent:page.scrollView];
    return page.page;
}

- (void)showMessage:(CPString)aMessage
{
    [[self showNewPage] addText:aMessage];
}

- (void)showMenu:(int)aGeneration
{
    [api get:"/courses" callback:function(status, body)
    {
        if (aGeneration !== routeGeneration)
            return;
        if (status !== 200)
            return [self showMessage:"Could not load the courses (" + status + ")."];

        var page = [self showNewPage];
        [page addHeading:"Courses"];
        for (var i = 0; i < body.length; i++)
            [page addCourse:body[i]];
    }];
}

- (void)showProfile:(int)aGeneration
{
    [api get:"/me" callback:function(status, body)
    {
        if (aGeneration !== routeGeneration)
            return;
        if (status !== 200)
            return [self showMessage:"Could not load your progress (" + status + ")."];

        var page = [self showNewPage];
        [page addHeading:"My progress"];

        if (body.email)
            [page addText:"Logged in as " + body.email + "."];
        else
        {
            [page addText:"You are not registered, so your progress is kept only in this browser. Register with your email and a passkey to keep it, and to log in from other devices."];
            [page addButton:"Register" target:self action:@selector(goToRegister:)];
        }

        if (body.courses.length === 0)
        {
            [page addText:"You have not started a course yet."];
            [page addButton:"Browse courses" target:self action:@selector(goToMenu:)];
        }
        for (var i = 0; i < body.courses.length; i++)
            [page addCourse:body.courses[i]];
    }];
}

- (void)showCourse:(CPString)aCourseId problemId:(CPString)aProblemId revisionMode:(BOOL)isRevision
{
    if (!courseController || [courseController courseId] !== aCourseId)
    {
        courseController = [[CourseController alloc] initWithFrame:[contentArea bounds] api:api courseId:aCourseId];
        [courseController setDelegate:self];
    }
    [self showContent:[courseController view]];
    [courseController showProblemId:aProblemId revisionMode:isRevision];
}

- (void)pageView:(PageView)aPage didOpenCourse:(Object)aCourse revision:(BOOL)isRevision
{
    var next = isRevision ? aCourse.revision.next_problem_id : aCourse.next_problem_id;
    window.location.hash = RouterCoursePath(aCourse.id, next, isRevision);
}

- (void)goToMenu:(id)aSender
{
    window.location.hash = "#/";
}

- (void)goToRegister:(id)aSender
{
    window.location.hash = "#/register";
}

// Account: register

- (void)showRegister
{
    if ([auth state] === "registered")
    {
        window.location.replace("#/me");
        return;
    }

    var page = [self showNewPage];
    [page addHeading:"Register"];
    if ([auth state] === "loggedOut")
        [page addText:"Create a new account with your email and a passkey."];
    else
        [page addText:"Enter your email, then create a passkey for it when your browser asks. Your progress so far is kept. You log in with the passkey from then on, with no password."];

    var emailField = [page addInputWithPlaceholder:"you@example.com"],
        button = [page addButton:"Create passkey" target:self action:@selector(register:)],
        feedback = [page addText:""];

    [feedback setTextColor:[CPColor colorWithHexString:"C62828"]];
    button._emailField = emailField;
    button._feedback = feedback;
    [[emailField window] makeFirstResponder:emailField];
}

- (void)register:(id)aSender
{
    var email = [[aSender._emailField stringValue] stringByTrimmingWhitespace],
        feedback = aSender._feedback,
        fail = function(aMessage) { [feedback setStringValue:aMessage]; [[feedback superview] setNeedsLayout]; };

    if (!email)
        return fail("Enter your email first.");
    fail("");

    // A logged-out browser registers a brand new learner. Its token is only
    // kept once registration succeeds, so that giving up halfway does not
    // leave this browser anonymous.
    var withSession = function(aContinuation)
    {
        if ([auth token])
            return aContinuation([auth token]);

        [api post:"/learners" body:nil callback:function(status, body)
        {
            if (status !== 201)
                return fail("Could not reach the server (" + status + ").");
            aContinuation(body.token);
        }];
    };

    withSession(function(aToken)
    {
        [api setToken:aToken];
        [api post:"/registration/options" body:{ email: email } callback:function(status, options)
        {
            if (status !== 200)
                return fail([self registrationErrorMessage:options && options.error status:status]);

            PasskeysCreate(options, function(credential, error)
            {
                if (error)
                    return fail(error);

                [api post:"/registration" body:{ credential: credential } callback:function(status, body)
                {
                    if (status !== 200)
                        return fail([self registrationErrorMessage:body && body.error status:status]);

                    [auth becomeRegistered:body.email token:aToken];
                    [self authChangedNavigatingTo:"#/me"];
                }];
            });
        }];
    });
}

- (CPString)registrationErrorMessage:(CPString)anError status:(int)aStatus
{
    switch (anError)
    {
        case "email_taken":         return "That email is already registered. Log in instead.";
        case "invalid_email":       return "That does not look like an email address.";
        case "already_registered":  return "You are already registered.";
        case "challenge_expired":   return "That took too long. Please try again.";
        case "invalid_credential":  return "The passkey could not be verified. Please try again.";
        default:                    return "Could not register (" + aStatus + ").";
    }
}

// Account: log in and out

- (void)showLoginRequired
{
    var page = [self showNewPage];
    [page addHeading:"You are logged out"];
    [page addText:"Log in with your passkey to carry on where you left off."];
    [page addButton:"Log in with a passkey" target:self action:@selector(logIn:)];
    [page addText:"Or start again with a new account:"];
    [page addButton:"Create a new account" target:self action:@selector(goToRegister:)];
}

- (void)logIn:(id)aSender
{
    var fail = function(aMessage) { [self alert:aMessage]; };

    [api post:"/login/options" body:nil callback:function(status, options)
    {
        if (status !== 200)
            return fail("Could not reach the server (" + status + ").");

        PasskeysGet(options, function(credential, error)
        {
            if (error)
                return fail(error);

            [api post:"/login" body:{ credential: credential } callback:function(status, body)
            {
                if (status !== 200)
                    return fail(body && body.error === "unknown_passkey" ?
                                "This passkey does not belong to an account here." :
                                "Could not log in (" + status + ").");

                // Any anonymous progress in this browser is left behind.
                [auth becomeRegistered:body.email token:body.token];
                [self authChanged];
            }];
        });
    }];
}

- (void)logOut:(id)aSender
{
    // The session ends locally whatever the server says.
    [api delete:"/session" callback:function(status, body) { }];
    [auth endSession];
    [self authChanged];
}

- (void)alert:(CPString)aMessage
{
    var alert = [[CPAlert alloc] init];
    [alert setMessageText:aMessage];
    [alert addButtonWithTitle:"OK"];
    [alert runModal];
}

- (void)topBar:(TopBar)aBar didChoose:(CPString)aChoice
{
    switch (aChoice)
    {
        case "courses":  return [self goToMenu:aBar];
        case "me":       window.location.hash = "#/me"; return;
        case "register": return [self goToRegister:aBar];
        case "login":    return [self logIn:aBar];
        case "logout":   return [self logOut:aBar];
    }
}

@end
