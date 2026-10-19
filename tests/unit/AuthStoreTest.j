@import <Foundation/Foundation.j>
@import <OJUnit/OJTestCase.j>
@import <OJUnit/OJAssert.j>

@import "../../AuthStore.j"

@implementation AuthStoreTest : OJTestCase
{
    Object      storage;
    AuthStore   store;
}

- (void)setUp
{
    var items = {};
    storage = {
        getItem: function(k) { return items.hasOwnProperty(k) ? items[k] : null; },
        setItem: function(k, v) { items[k] = String(v); },
        removeItem: function(k) { delete items[k]; }
    };
    store = [[AuthStore alloc] initWithStorage:storage];
}

- (void)testAFreshBrowserIsFresh
{
    [OJAssert assert:"fresh" equals:[store state]];
}

- (void)testAnonymousAfterStartingASession
{
    [store startAnonymousSession:"t1"];
    [OJAssert assert:["anonymous", "t1"] equals:[[store state], [store token]]];
}

- (void)testRegisteringKeepsTheSession
{
    [store startAnonymousSession:"t1"];
    [store becomeRegistered:"a@example.com" token:nil];
    [OJAssert assert:["registered", "t1", "a@example.com"] equals:[[store state], [store token], [store email]]];
}

- (void)testLoggingOutAfterRegisteringNeedsALogin
{
    [store startAnonymousSession:"t1"];
    [store becomeRegistered:"a@example.com" token:nil];
    [store endSession];
    [OJAssert assert:["loggedOut", nil] equals:[[store state], [store token]]];
}

- (void)testLoggingInReplacesTheAnonymousSession
{
    [store startAnonymousSession:"anon"];
    [store becomeRegistered:"a@example.com" token:"t2"];
    [OJAssert assert:["registered", "t2"] equals:[[store state], [store token]]];
}

- (void)testAnAnonymousSessionThatEndsIsFreshAgain
{
    [store startAnonymousSession:"t1"];
    [store endSession];
    [OJAssert assert:"fresh" equals:[store state]];
}

- (void)testServerSaysRegisteredMarksTheBrowser
{
    [store startAnonymousSession:"t1"];
    [store setEmail:"a@example.com"];
    [store endSession];
    [OJAssert assert:"loggedOut" equals:[store state]];
}

@end
