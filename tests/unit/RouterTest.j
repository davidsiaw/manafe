@import <Foundation/Foundation.j>
@import <OJUnit/OJTestCase.j>
@import <OJUnit/OJAssert.j>

@import "../../Router.j"

@implementation RouterTest : OJTestCase

- (void)testEmptyAndRootAreTheMenu
{
    [OJAssert assert:"menu" equals:RouterParse("").screen];
    [OJAssert assert:"menu" equals:RouterParse("#/").screen];
}

- (void)testACourse
{
    var route = RouterParse("#/courses/rust-basics");
    [OJAssert assert:["course", "rust-basics", nil] equals:[route.screen, route.courseId, route.problemId]];
}

- (void)testAProblem
{
    var route = RouterParse("#/courses/rust-basics/as-casting");
    [OJAssert assert:["course", "rust-basics", "as-casting"] equals:[route.screen, route.courseId, route.problemId]];
}

- (void)testRevisionMode
{
    var route = RouterParse("#/revise/rust-basics/as-casting");
    [OJAssert assert:["course", "rust-basics", "as-casting", true]
              equals:[route.screen, route.courseId, route.problemId, route.revision]];
    [OJAssert assertFalse:RouterParse("#/courses/rust-basics").revision];
    [OJAssert assert:"#/revise/rust-basics/x" equals:RouterCoursePath("rust-basics", "x", YES)];
}

- (void)testOwnPageAndRegistration
{
    [OJAssert assert:"me" equals:RouterParse("#/me").screen];
    [OJAssert assert:"register" equals:RouterParse("#/register").screen];
}

- (void)testAnythingElseIsTheMenu
{
    [OJAssert assert:"menu" equals:RouterParse("#integers").screen];
    [OJAssert assert:"menu" equals:RouterParse("#/courses").screen];
    [OJAssert assert:"menu" equals:RouterParse("#/courses/a/b/c").screen];
}

- (void)testBuildsPathsTheParserReads
{
    var route = RouterParse(RouterCoursePath("rust basics", "a/b"));
    [OJAssert assert:["rust basics", "a/b"] equals:[route.courseId, route.problemId]];
    [OJAssert assert:"#/courses/git-basics" equals:RouterCoursePath("git-basics", nil)];
}

@end
