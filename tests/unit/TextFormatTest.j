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
    [OJAssert assert:"See:\n\n    let x = 5;\n\nthen" equals:TextFormatReflow("See:\n    let x = 5;\nthen")];
}

- (void)testKeepsListItemsOnTheirOwnLinesButJoinsTheirWrappedText
{
    [OJAssert assert:"Methods:\n- one wraps here\n- two"
              equals:TextFormatReflow("Methods:\n- one wraps\nhere\n- two")];
}

- (void)testJoinsIndentedLinesThatContinueAListItem
{
    [OJAssert assert:"Two kinds:\n- one that wraps onto the next line\n- two"
              equals:TextFormatReflow("Two kinds:\n- one that wraps onto\n  the next line\n- two")];
}

// Blocks

- (void)testSplitsProseFromCode
{
    var blocks = TextFormatBlocks("A function:\n\n  fn five() -> i32 {\n      5\n  }\n\nThat is all.");
    [OJAssert assert:[NO, YES, NO] equals:blocks.map(function(b) { return b.code; })];
    [OJAssert assert:"fn five() -> i32 {\n    5\n}" equals:blocks[1].text];
    [OJAssert assert:"That is all." equals:blocks[2].text];
}

- (void)testSplitsCodeOutOfTheMiddleOfAParagraph
{
    var blocks = TextFormatBlocks("See:\n    let x = 5;\nthen more");
    [OJAssert assert:["See:", "let x = 5;", "then more"] equals:blocks.map(function(b) { return b.text; })];
}

- (void)testKeepsProseParagraphsInOneBlock
{
    var blocks = TextFormatBlocks("One\ntwo.\n\nThree.");
    [OJAssert assert:1 equals:blocks.length];
    [OJAssert assert:"One two.\n\nThree." equals:blocks[0].text];
}

- (void)testKeepsCodeSeparatedByBlankLinesInOneBlock
{
    var blocks = TextFormatBlocks("  impl A {\n  }\n\n  impl B {\n  }");
    [OJAssert assert:1 equals:blocks.length];
    [OJAssert assert:"impl A {\n}\n\nimpl B {\n}" equals:blocks[0].text];
}

- (void)testTreatsListContinuationsAsProseButDeeperLinesAsCode
{
    var blocks = TextFormatBlocks("- an item\n  that wraps\n    code_under_it();");
    [OJAssert assert:[NO, YES] equals:blocks.map(function(b) { return b.code; })];
    [OJAssert assert:"- an item that wraps" equals:blocks[0].text];
    [OJAssert assert:"code_under_it();" equals:blocks[1].text];
}

- (void)testKeepsTheIndentationOfCodeThatStartsTheText
{
    var blocks = TextFormatBlocks("    let x = 1;\n\nAfter.");
    [OJAssert assert:[YES, NO] equals:blocks.map(function(b) { return b.code; })];
    [OJAssert assert:"let x = 1;" equals:blocks[0].text];
}

- (void)testHasNoBlocksForNoText
{
    [OJAssert assert:0 equals:TextFormatBlocks(nil).length];
    [OJAssert assert:0 equals:TextFormatBlocks("  \n").length];
}

- (void)testToleratesMissingText
{
    [OJAssert assert:"" equals:TextFormatReflow(nil)];
}

@end
