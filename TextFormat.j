@import <Foundation/Foundation.j>

/*
    Turns problem text as written in YAML into text for display. Authors wrap
    lines at whatever width suits their editor, so within a paragraph lines
    are joined with spaces. Blank lines separate paragraphs.

    - A line starting a list item ("- ", "* ", "1. ") keeps its own line, and
      the indented lines after it, up to the item's text, continue it.
    - Any other indented line is code, and keeps its own line.

    TextFormatBlocks splits text into prose and code, for showing code
    differently; TextFormatReflow keeps it all as one string.
*/

var LIST_ITEM = /^(([-*]|\d+\.)\s+)/;

/*
    The text as an array of blocks, { code: NO, text } for prose and
    { code: YES, text } for code. Prose is reflowed, and consecutive prose
    paragraphs make one block, separated by a blank line. Code has its
    common indentation removed, and code paragraphs separated only by blank
    lines make one block.
*/
function TextFormatBlocks(aString)
{
    var text = (aString || "").replace(/\r\n/g, "\n").replace(/^\s*\n/, "").replace(/\s+$/, ""),
        blocks = [];

    if (!text)
        return blocks;

    var paragraphs = text.split(/\n[ \t]*\n/);
    for (var i = 0; i < paragraphs.length; i++)
    {
        var pieces = _TextFormatParagraph(paragraphs[i]);
        for (var j = 0; j < pieces.length; j++)
        {
            var piece = pieces[j],
                last = blocks[blocks.length - 1];

            // A new paragraph of the same kind continues the block, after a
            // blank line; within a paragraph the pieces alternate anyway.
            if (last && last.code === piece.code && j === 0)
                Array.prototype.push.apply(last.lines, [""].concat(piece.lines));
            else
                blocks.push(piece);
        }
    }

    return blocks.map(function(aBlock)
    {
        return { code: aBlock.code, text: aBlock.code ? _TextFormatDedent(aBlock.lines) : aBlock.lines.join("\n") };
    });
}

// All of it as one string, with code indented by four spaces.
function TextFormatReflow(aString)
{
    return TextFormatBlocks(aString).map(function(aBlock)
    {
        return aBlock.code ? aBlock.text.replace(/^(?=.)/gm, "    ") : aBlock.text;
    }).join("\n\n");
}

// One paragraph's lines, as alternating prose and code pieces of { code, lines }.
function _TextFormatParagraph(aParagraph)
{
    var lines = aParagraph.split("\n"),
        pieces = [],
        itemColumn = nil;   // the column a list item's text starts at, while in one

    for (var i = 0; i < lines.length; i++)
    {
        var line = lines[i],
            indent = line.match(/^[ \t]*/)[0].length,
            item = line.match(LIST_ITEM),
            piece = pieces[pieces.length - 1];

        if (indent > 0 && !(itemColumn !== nil && indent <= itemColumn))
        {
            itemColumn = nil;
            if (piece && piece.code)
                piece.lines.push(line);
            else
                pieces.push({ code: YES, lines: [line] });
            continue;
        }

        if (!piece || piece.code)
            pieces.push(piece = { code: NO, lines: [] });

        if (item)
        {
            itemColumn = item[1].length;
            piece.lines.push(line);
        }
        else if (piece.lines.length)
            piece.lines[piece.lines.length - 1] += " " + line.trim();
        else
            piece.lines.push(line);
    }
    return pieces;
}

function _TextFormatDedent(lines)
{
    var indents = lines.filter(function(l) { return l.trim(); })
                       .map(function(l) { return l.match(/^[ \t]*/)[0].length; }),
        common = indents.length ? Math.min.apply(Math, indents) : 0;

    return lines.map(function(l) { return l.substring(common); }).join("\n");
}
