@import <Foundation/Foundation.j>

var TOKEN_KEY = "manabase.token",
    EMAIL_KEY = "manabase.email",
    HAS_LOGGED_IN_KEY = "manabase.hasLoggedIn";

/*
    Who this browser is, kept in localStorage (or any object with getItem,
    setItem and removeItem, for tests).

    - anonymous:  a session for a learner with no email
    - registered: a session for a learner with an email
    - loggedOut:  no session, and this browser has been registered or logged
                  in before. Such a browser does not quietly become anonymous
                  again: it has to log in, or create a new account.
    - fresh:      no session and never logged in; becomes anonymous
*/
@implementation AuthStore : CPObject
{
    Object storage;
}

- (id)initWithStorage:(Object)aStorage
{
    if (self = [super init])
        storage = aStorage;
    return self;
}

- (CPString)token
{
    return storage.getItem(TOKEN_KEY);
}

- (CPString)email
{
    return storage.getItem(EMAIL_KEY);
}

- (CPString)state
{
    if ([self token])
        return [self email] ? "registered" : "anonymous";
    return storage.getItem(HAS_LOGGED_IN_KEY) ? "loggedOut" : "fresh";
}

- (void)startAnonymousSession:(CPString)aToken
{
    storage.setItem(TOKEN_KEY, aToken);
    storage.removeItem(EMAIL_KEY);
}

// After registering, or after logging in with a new token.
- (void)becomeRegistered:(CPString)anEmail token:(CPString)aToken
{
    if (aToken)
        storage.setItem(TOKEN_KEY, aToken);
    storage.setItem(EMAIL_KEY, anEmail);
    storage.setItem(HAS_LOGGED_IN_KEY, "1");
}

// The server's view of who we are, from GET /me.
- (void)setEmail:(CPString)anEmail
{
    if (anEmail)
        [self becomeRegistered:anEmail token:nil];
    else
        storage.removeItem(EMAIL_KEY);
}

// Logging out, or a session the server no longer knows.
- (void)endSession
{
    storage.removeItem(TOKEN_KEY);
    storage.removeItem(EMAIL_KEY);
}

@end
