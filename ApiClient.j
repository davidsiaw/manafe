@import <Foundation/Foundation.j>

/*
    Talks JSON to the backend, sending the session token, if there is one,
    as a bearer token. Callbacks receive (status, body); status is 0 when
    the server could not be reached at all.
*/
@implementation ApiClient : CPObject
{
    CPString    baseURL;
    CPString    token       @accessors;
}

- (id)initWithBaseURL:(CPString)aURL
{
    if (self = [super init])
        baseURL = aURL;
    return self;
}

- (void)get:(CPString)aPath callback:(Function)aCallback
{
    [self _send:"GET" path:aPath body:nil callback:aCallback];
}

- (void)post:(CPString)aPath body:(Object)aBody callback:(Function)aCallback
{
    [self _send:"POST" path:aPath body:aBody callback:aCallback];
}

- (void)delete:(CPString)aPath callback:(Function)aCallback
{
    [self _send:"DELETE" path:aPath body:nil callback:aCallback];
}

- (void)_send:(CPString)aMethod path:(CPString)aPath body:(Object)aBody callback:(Function)aCallback
{
    var request = new XMLHttpRequest();
    request.open(aMethod, baseURL + aPath, true);

    if (token)
        request.setRequestHeader("Authorization", "Bearer " + token);
    if (aBody)
        request.setRequestHeader("Content-Type", "application/json");

    request.onreadystatechange = function()
    {
        if (request.readyState !== 4)
            return;

        var body = nil;
        try { body = JSON.parse(request.responseText); } catch (e) { }

        aCallback(request.status, body);
        // Cappuccino only redraws inside its own run loop.
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
    };

    request.send(aBody ? JSON.stringify(aBody) : null);
}

@end
