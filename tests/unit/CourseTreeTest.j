@import <Foundation/Foundation.j>
@import <OJUnit/OJTestCase.j>
@import <OJUnit/OJAssert.j>

@import "../../CourseTree.j"

@implementation CourseTreeTest : OJTestCase
{
    CourseTree tree;
}

- (void)setUp
{
    // Same shape as GET /courses/:id: First has a problem and a subsection.
    tree = [[CourseTree alloc] initWithJSON:{
        title: "Sample",
        sections: [
            { title: "First", problems: [{ id: "one", title: "One" }],
              sections: [{ title: "Nested", problems: [{ id: "two", title: "Two" }], sections: [] }] },
            { title: "Second", problems: [{ id: "three", title: "Three" }], sections: [] }
        ]
    }];
}

- (void)testOrdersProblemsAsTheSidebarShowsThem
{
    [OJAssert assert:["one", "two", "three"] equals:[tree problemIds]];
}

- (void)testPutsASectionsProblemsBeforeItsSubsections
{
    var first = [tree rootNodes][0];
    [OJAssert assert:"One" equals:[[first children][0] title]];
    [OJAssert assert:"Nested" equals:[[first children][1] title]];
}

- (void)testListsAncestorsOutermostFirst
{
    var ancestors = [tree ancestorsOfNode:[tree nodeForProblemId:"two"]];
    [OJAssert assert:2 equals:ancestors.length];
    [OJAssert assert:"First" equals:[ancestors[0] title]];
    [OJAssert assert:"Nested" equals:[ancestors[1] title]];
}

- (void)testMarksSolvedProblemsAndIgnoresUnknownIds
{
    [tree markSolved:["two", "deleted"]];
    [OJAssert assertTrue:[[tree nodeForProblemId:"two"] isSolved]];
    [OJAssert assertFalse:[[tree nodeForProblemId:"one"] isSolved]];
}

- (void)testFirstUnsolvedSkipsSolvedProblems
{
    [tree markSolved:["one"]];
    [OJAssert assert:"two" equals:[tree firstUnsolvedProblemId]];
}

- (void)testFirstUnsolvedFallsBackToTheFirstProblemWhenAllAreSolved
{
    [tree markSolved:["one", "two", "three"]];
    [OJAssert assert:"one" equals:[tree firstUnsolvedProblemId]];
}

- (void)testSectionsAreNotProblems
{
    [OJAssert assertFalse:[[tree rootNodes][0] isProblem]];
    [OJAssert assertTrue:[[tree nodeForProblemId:"one"] isProblem]];
}

- (void)testShowsRound1OrTheRevision
{
    var progress = { solved: ["one", "two"], revision: { number: 2, solved: ["three"] },
                     times_solved: { one: 1, two: 2, three: 2 }, times_completed: 0 };
    [tree applyProgress:progress revisionMode:NO];
    [OJAssert assert:2 equals:[tree solvedCount]];

    [tree applyProgress:progress revisionMode:YES];
    [OJAssert assert:1 equals:[tree solvedCount]];
    [OJAssert assertFalse:[[tree nodeForProblemId:"one"] isSolved]];
    [OJAssert assert:2 equals:[[tree nodeForProblemId:"two"] timesSolved]];
}

- (void)testRevisionModeNeedsARevision
{
    var progress = { solved: [], revision: null, times_solved: {}, times_completed: 0 };
    [OJAssert assertFalse:[tree applyProgress:progress revisionMode:YES]];
    [OJAssert assertTrue:[tree applyProgress:progress revisionMode:NO]];
}

- (void)testSectionsCountTheProblemsUnderThem
{
    var first = [tree rootNodes][0],
        nested = [first children][1];
    [tree markSolved:["two"]];
    [OJAssert assert:2 equals:[first problemCount]];
    [OJAssert assert:1 equals:[first solvedProblemCount]];
    [OJAssert assert:1 equals:[nested solvedProblemCount]];
}

- (void)testASectionIsSolvedWhenEverythingUnderItIs
{
    var first = [tree rootNodes][0],
        nested = [first children][1];
    [tree markSolved:["two"]];
    [OJAssert assertTrue:[nested isSolved]];
    [OJAssert assertFalse:[first isSolved]];

    [tree markSolved:["one"]];
    [OJAssert assertTrue:[first isSolved]];
}

- (void)testAnEmptySectionIsNotSolved
{
    var empty = [[[CourseTree alloc] initWithJSON:{
        title: "Empty", sections: [{ title: "Nothing", problems: [], sections: [] }]
    }] rootNodes][0];
    [OJAssert assertFalse:[empty isSolved]];
}

- (void)testSectionLabels
{
    [OJAssert assert:"\u25CB Basics  1/3" equals:CourseTreeSectionLabel("Basics", 1, 3)];
    [OJAssert assert:"\u2713 Basics  3/3" equals:CourseTreeSectionLabel("Basics", 3, 3)];
}

- (void)testSplitsTheMarkFromALabel
{
    [OJAssert assert:["\u2713", "Ints  \u00D73"] equals:CourseTreeSplitMark("\u2713 Ints  \u00D73")];
    [OJAssert assert:["\u25CB", "Basics  1/3"] equals:CourseTreeSplitMark("\u25CB Basics  1/3")];
    [OJAssert assert:["", "Plain"] equals:CourseTreeSplitMark("Plain")];
}

- (void)testProblemLabels
{
    [OJAssert assert:"\u25CB Ints" equals:CourseTreeProblemLabel("Ints", NO, 0, NO)];
    [OJAssert assert:"\u2713 Ints" equals:CourseTreeProblemLabel("Ints", YES, 1, NO)];
    [OJAssert assert:"\u2713 Ints  \u00D73" equals:CourseTreeProblemLabel("Ints", YES, 3, NO)];
    // In a revision, solved before but not yet this time:
    [OJAssert assert:"\u25CB Ints  \u00D71" equals:CourseTreeProblemLabel("Ints", NO, 1, YES)];
}

@end
