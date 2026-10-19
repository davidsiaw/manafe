@import <Foundation/Foundation.j>

/*
    Turns problem text as written in YAML into text for display. Authors wrap
    lines at whatever width suits their editor, so within a paragraph lines
    are joined with spaces. Lines that are indented (code) or start a list
    item ("- ", "* ", "1. ") keep their own line. Blank lines separate
    paragraphs.
*/
function TextFormatReflow(aString)
{
    var paragraphs = (aString || "").replace(/\r\n/g, "\n").trim().split(/\n[ \t]*\n/),
        result = [];

    for (var i = 0; i < paragraphs.length; i++)
    {
        var lines = paragraphs[i].split("\n"),
            out = [];

        for (var j = 0; j < lines.length; j++)
        {
            var line = lines[j],
                keepsOwnLine = /^\s/.test(line) || /^([-*]|\d+\.)\s/.test(line);

            if (out.length && !keepsOwnLine && !/^\s/.test(out[out.length - 1]))
                out[out.length - 1] += " " + line;
            else
                out.push(line);
        }
        result.push(out.join("\n"));
    }
    return result.join("\n\n");
}
