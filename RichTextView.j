@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "CodeEditor.j"
@import "TextFormat.j"

var CODE_GAP = 6.0;

/*
    Problem text: prose in labels, and the code in it (its indented lines,
    see TextFormat.j) in highlighted CodeBlockViews, stacked top to bottom.

    The owner lays it out with -layoutForWidth:, which sizes and places the
    pieces, sets this view's height and returns it. Labels pad their text by
    4 pixels, so the owner places this view 4 pixels left of where the text
    should start, and 8 pixels wider, as it would a label.
*/
@implementation RichTextView : CPView
{
    CPFont      font;
    CPColor     textColor;
    BOOL        selectable;
    CPArray     pieces;
}

- (id)initWithFont:(CPFont)aFont
{
    if (self = [super initWithFrame:CGRectMakeZero()])
    {
        font = aFont;
        textColor = [CPColor blackColor];
        pieces = [];
    }
    return self;
}

- (void)setSelectable:(BOOL)isSelectable
{
    selectable = isSelectable;
}

- (void)setTextColor:(CPColor)aColor
{
    textColor = aColor;
    for (var i = 0; i < pieces.length; i++)
        if ([pieces[i] isKindOfClass:CPTextField])
            [pieces[i] setTextColor:aColor];
}

// Code in the text is highlighted as aLanguage, if the editor knows it.
- (void)setText:(CPString)aText language:(CPString)aLanguage
{
    for (var i = 0; i < pieces.length; i++)
        [pieces[i] removeFromSuperview];

    pieces = TextFormatBlocks(aText).map(function(aBlock)
    {
        var piece = aBlock.code ? [[CodeBlockView alloc] initWithCode:aBlock.text language:aLanguage]
                                : [self _labelWithText:aBlock.text];
        [self addSubview:piece];
        return piece;
    });
    [self setNeedsLayout];
}

- (CPTextField)_labelWithText:(CPString)aText
{
    var field = [[CPTextField alloc] initWithFrame:CGRectMakeZero()];
    [field setFont:font];
    [field setTextColor:textColor];
    [field setLineBreakMode:CPLineBreakByWordWrapping];
    [field setSelectable:selectable];
    [field setStringValue:aText];
    return field;
}

- (float)layoutForWidth:(float)aWidth
{
    var y = 0.0;
    for (var i = 0; i < pieces.length; i++)
    {
        var piece = pieces[i];
        if ([piece isKindOfClass:CodeBlockView])
        {
            // Line the code's border up with the text, inside the labels'
            // padding.
            y += CODE_GAP;
            var height = [piece heightForWidth:aWidth - 8.0];
            [piece setFrame:CGRectMake(4.0, y, aWidth - 8.0, height)];
            y += height + CODE_GAP;
        }
        else
        {
            var size = [[piece stringValue] sizeWithFont:font inWidth:aWidth - 8.0];
            [piece setFrame:CGRectMake(0.0, y, aWidth, size.height + 8.0)];
            y += size.height + 8.0;
        }
    }
    [self setFrameSize:CGSizeMake(aWidth, y)];
    return y;
}

@end
