@import <Foundation/Foundation.j>
@import <OJUnit/OJTestCase.j>
@import <OJUnit/OJAssert.j>

@import "../../TextFormat.j"

@implementation TextFormatTest : OJTestCase

- (void)testJoinsWrappedLinesOfAParagraph
{
    [OJAssert assert:"one two three" equals:TextFormatReflow("one two\nthree\n")];
}

- (void)testKeepsParagraphsApart
{
    [OJAssert assert:"one two\n\nthree" equals:TextFormatReflow("one\ntwo\n\nthree")];
}

- (void)testKeepsIndentedCodeLinesAsTheyAre
{
    var text = "A function:\n\n    fn add(a: u32) -> u32 {\n        a\n    }\n\nAfter.";
    [OJAssert assert:text equals:TextFormatReflow(text)];
}

- (void)testDoesNotJoinTextOntoACodeLine
{
    [OJAssert assert:"See:\n    let x = 5;\nthen" equals:TextFormatReflow("See:\n    let x = 5;\nthen")];
}

- (void)testKeepsListItemsOnTheirOwnLinesButJoinsTheirWrappedText
{
    [OJAssert assert:"Methods:\n- one wraps here\n- two"
              equals:TextFormatReflow("Methods:\n- one wraps\nhere\n- two")];
}

- (void)testToleratesMissingText
{
    [OJAssert assert:"" equals:TextFormatReflow(nil)];
}

@end
