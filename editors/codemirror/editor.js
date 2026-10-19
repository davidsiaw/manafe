/*
    The code editor for Manabase's code problems: CodeMirror 6, bundled into
    one script (Resources/editors/codemirror/codemirror.js) by ./build.

    CodeEditor.j loads it when the first code problem is shown, and uses only
    this API, so the rest of the app knows nothing about CodeMirror:

      ManabaseCodeEditor.create(parent, { code, language, plain, readOnly }) -> editor

    plain is for text that is not code, such as pasted program output: no
    line numbers, highlighting or bracket handling. readOnly is for showing
    code in problem text: highlighted and selectable, but not editable, and
    as tall as its content.
      editor.getCode() / editor.setCode(code) / editor.focus() / editor.destroy()
*/
import { EditorView, keymap, lineNumbers, highlightActiveLine, highlightActiveLineGutter, drawSelection } from "@codemirror/view";
import { EditorState } from "@codemirror/state";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import { StreamLanguage, indentOnInput, indentUnit, bracketMatching, syntaxHighlighting, defaultHighlightStyle } from "@codemirror/language";
import { closeBrackets, closeBracketsKeymap } from "@codemirror/autocomplete";
import { ruby } from "@codemirror/legacy-modes/mode/ruby";
import { rust } from "@codemirror/legacy-modes/mode/rust";
import { shell } from "@codemirror/legacy-modes/mode/shell";
import { zig } from "./zig-mode.js";

// Syntax highlighting per problem language; unknown languages get none.
const LANGUAGES = {
    ruby: () => StreamLanguage.define(ruby),
    rust: () => StreamLanguage.define(rust),
    shell: () => StreamLanguage.define(shell),
    zig: () => StreamLanguage.define(zig)
};

const theme = EditorView.theme({
    "&": { height: "100%", fontSize: "13px", backgroundColor: "#FBFBFB" },
    ".cm-scroller": { fontFamily: "Menlo, Consolas, monospace", overflow: "auto" },
    "&.cm-focused": { outline: "none" }
});

// Must match the placeholder CodeEditor.j shows until this script loads,
// so that the page does not jump when it is replaced.
const readOnlyTheme = EditorView.theme({
    "&": { fontSize: "13px", backgroundColor: "#F6F8FA" },
    ".cm-scroller": { fontFamily: "Menlo, Consolas, monospace", lineHeight: "18px", overflowX: "auto" },
    ".cm-content": { padding: "8px 0" },
    ".cm-line": { padding: "0 10px" },
    "&.cm-focused": { outline: "none" }
});

function readOnlyExtensions(language)
{
    const extensions = [
        EditorState.readOnly.of(true),
        EditorView.editable.of(false),
        syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
        EditorState.tabSize.of(4),
        readOnlyTheme
    ];
    if (LANGUAGES[language])
        extensions.push(LANGUAGES[language]());
    return extensions;
}

function plainExtensions()
{
    return [drawSelection(), history(), keymap.of([...defaultKeymap, ...historyKeymap]), theme];
}

function extensionsFor(language)
{
    const extensions = [
        lineNumbers(),
        highlightActiveLineGutter(),
        highlightActiveLine(),
        drawSelection(),
        history(),
        indentOnInput(),
        bracketMatching(),
        closeBrackets(),
        syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
        indentUnit.of("  "),
        EditorState.tabSize.of(2),
        // Tab indents. Escape, then Tab, leaves the editor (CodeMirror's
        // answer to the keyboard trap an indenting Tab would be).
        keymap.of([...closeBracketsKeymap, ...defaultKeymap, ...historyKeymap, indentWithTab]),
        theme
    ];
    if (LANGUAGES[language])
        extensions.push(LANGUAGES[language]());
    return extensions;
}

window.ManabaseCodeEditor = {
    create(parent, options)
    {
        const extensions = options.readOnly ? readOnlyExtensions(options.language)
            : options.plain ? plainExtensions() : extensionsFor(options.language),
            view = new EditorView({
                parent,
                state: EditorState.create({ doc: options.code || "", extensions })
            });

        return {
            getCode: () => view.state.doc.toString(),
            // A new state, so undo does not go back into the previous problem.
            setCode: (code) => view.setState(EditorState.create({ doc: code || "", extensions })),
            focus: () => view.focus(),
            destroy: () => view.destroy()
        };
    }
};
