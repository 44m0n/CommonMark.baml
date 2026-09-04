class FencedCodeStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "fenced_code"
        }

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (parser.indented) {
                return StartMatch.None;
            }
            let fence = scan_opening_fence(parser.scan.line, parser.next_nonspace);
            if (fence == null) {
                return StartMatch.None;
            }
            parser.close_unmatched();
            parser.push_child(open_fenced_code(fence.fence_char, fence.fence_length, parser.indent));
            parser.advance_next_nonspace();
            parser.advance_offset(fence.fence_length, false);
            StartMatch.Leaf
        }
    }
}

class FenceScan {
    fence_char: string,
    fence_length: int,
}

function scan_opening_fence(line: string, start: int) -> FenceScan? {
    let ch = line.at(start);
    if (ch != "`" && ch != "~") {
        return null;
    }
    let i = start;
    while (line.at(i) == ch) {
        i += 1;
    }
    let length = i - start;
    if (length < 3) {
        return null;
    }
    if (ch == "`") {
        let j = i;
        while (j < line.length()) {
            if (line.at(j) == "`") {
                return null;
            }
            j += 1;
        }
    }
    FenceScan { fence_char: ch ?? "", fence_length: length }
}

function is_closing_fence(parser: Parser, open: Open) -> bool {
    if (parser.indent > 3) {
        return false;
    }
    let line = parser.scan.line;
    let i = parser.next_nonspace;
    if (line.at(i) != open.fence_char) {
        return false;
    }
    let len = 0;
    while (line.at(i) == open.fence_char) {
        len += 1;
        i += 1;
    }
    if (len < open.fence_length) {
        return false;
    }
    while (i < line.length()) {
        let c = line.at(i);
        if (c != " " && c != "\t") {
            return false;
        }
        i += 1;
    }
    true
}

function skip_fence_indent(parser: Parser, fence_offset: int) -> void {
    let i = fence_offset;
    while (i > 0) {
        let c = parser.scan.line.at(parser.scan.pos);
        if (c == " " || c == "\t") {
            parser.advance_offset(1, true);
            i -= 1;
        } else {
            break;
        }
    }
}

function fenced_info_and_literal(
    content: string,
    table: map<string, string>,
) -> root.ast.CodeBlock {
    let nl = content.index_of("\n");
    if (nl == null) {
        root.ast.CodeBlock {
            fenced: true,
            info: root.block.unescape_string(content.trim(), table = table),
            literal: "",
            last_line_blank: false,
        }
    } else {
        let first = content.slice(0, nl);
        let rest = content.slice(nl + 1, content.length());
        root.ast.CodeBlock {
            fenced: true,
            info: root.block.unescape_string(first.trim(), table = table),
            literal: rest,
            last_line_blank: false,
        }
    }
}

test "backtick and tilde fences" {
    assert.equal(root.to_html("```\n<\n >\n```\n"), "<pre><code>&lt;\n &gt;\n</code></pre>\n");
    assert.equal(root.to_html("~~~\n<\n >\n~~~\n"), "<pre><code>&lt;\n &gt;\n</code></pre>\n")
}

test "two backticks are a code span not a fence" {
    assert.equal(root.to_html("``\nfoo\n``\n"), "<p><code>foo</code></p>\n")
}

test "fenced code can interrupt a paragraph" {
    assert.equal(
        root.to_html("foo\n```\nbar\n```\nbaz\n"),
        "<p>foo</p>\n<pre><code>bar\n</code></pre>\n<p>baz</p>\n",
    )
}

test "fenced code info string becomes a language class" {
    assert.equal(
        root.to_html("```ruby\ndef foo(x)\n  return 3\nend\n```\n"),
        "<pre><code class=\"language-ruby\">def foo(x)\n  return 3\nend\n</code></pre>\n",
    )
}

test "fenced info language splits on tab" {
    assert.equal(
        root.to_html("```js\tmeta\nx\n```\n"),
        "<pre><code class=\"language-js\">x\n</code></pre>\n",
    )
}

test "closing fence must be at least as long and unindented past three" {
    assert.equal(root.to_html("```\naaa\n    ```\n"), "<pre><code>aaa\n    ```\n</code></pre>\n")
}

test "fenced code spec" {
    assert.equal(root.spec.spec_failures("Fenced code blocks"), 0)
}
