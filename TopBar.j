@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

var BAR_HEIGHT = 44.0,
    PADDING = 12.0;

/*
    Navigation along the top: Courses and My progress on the left; on the
    right, who you are and the account actions that make sense for that.
    The delegate gets -topBar:didChoose: with "courses", "me", "register",
    "login" or "logout".
*/
@implementation TopBar : CPView
{
    id          delegate    @accessors;
    CPArray     leftButtons;
    CPArray     rightViews;
}

+ (float)height
{
    return BAR_HEIGHT;
}

- (id)initWithFrame:(CGRect)aFrame
{
    if (self = [super initWithFrame:aFrame])
    {
        [self setBackgroundColor:[CPColor colorWithHexString:"1F3A5F"]];
        leftButtons = [[self _button:"Courses" choice:"courses"], [self _button:"My progress" choice:"me"]];
        rightViews = [];
        [self setState:"fresh" email:nil];
    }
    return self;
}

- (CPButton)_button:(CPString)aTitle choice:(CPString)aChoice
{
    var button = [CPButton buttonWithTitle:aTitle];
    [button setTarget:self];
    [button setAction:@selector(choose:)];
    button._choice = aChoice;
    [self addSubview:button];
    return button;
}

// One of AuthStore's states.
- (void)setState:(CPString)aState email:(CPString)anEmail
{
    for (var i = 0; i < rightViews.length; i++)
        [rightViews[i] removeFromSuperview];

    rightViews = [];
    if (aState === "registered")
    {
        var label = [CPTextField labelWithTitle:anEmail];
        [label setTextColor:[CPColor whiteColor]];
        [self addSubview:label];
        rightViews = [label, [self _button:"Log out" choice:"logout"]];
    }
    else if (aState === "loggedOut")
        rightViews = [[self _button:"Log in" choice:"login"]];
    else
        rightViews = [[self _button:"Register" choice:"register"], [self _button:"Log in" choice:"login"]];

    [self setNeedsLayout];
}

- (void)choose:(id)aSender
{
    [delegate topBar:self didChoose:aSender._choice];
}

- (void)layoutSubviews
{
    var x = PADDING;
    for (var i = 0; i < leftButtons.length; i++)
    {
        [leftButtons[i] sizeToFit];
        [leftButtons[i] setFrameOrigin:CGPointMake(x, (BAR_HEIGHT - CGRectGetHeight([leftButtons[i] frame])) / 2)];
        x += CGRectGetWidth([leftButtons[i] frame]) + 8.0;
    }

    var right = CGRectGetWidth([self bounds]) - PADDING;
    for (var i = rightViews.length - 1; i >= 0; i--)
    {
        [rightViews[i] sizeToFit];
        var frame = [rightViews[i] frame];
        right -= CGRectGetWidth(frame);
        [rightViews[i] setFrameOrigin:CGPointMake(right, (BAR_HEIGHT - CGRectGetHeight(frame)) / 2)];
        right -= 8.0;
    }
}

@end
