function trim_trailing_spaces(s: Subject) -> int {
    flush_text(s);
    if let last: InlineCell = s.tail {
        if let lit: root.ast.Text = last.node {
            let chars = lit.literal.chars();
            let end = chars.length();
            let n = 0;
            while (end > 0 && chars.at(end - 1) == " ") {
                end -= 1;
                n += 1;
            }
            while (end > 0 && is_trailing_ws(chars.at(end - 1) ?? "")) {
                end -= 1;
            }
            lit.literal = lit.literal.slice(0, end);
            if (lit.literal.length() == 0) {
                unlink_cell(s, last);
            }
            n
        } else {
            0
        }
    } else {
        0
    }
}

function is_trailing_ws(ch: string) -> bool {
    ch == " " || ch == "\t"
}

class NewlineRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "newline"
        }

        function parse(self, context: InlineParseContext) -> bool throws never {
            let s = internal_inline_subject(context);
            if (peek(s) != "\n") {
                return false;
            }
            let spaces = trim_trailing_spaces(s);
            let _ = bump(s);
            if (spaces >= 2) {
                push_node(s, root.ast.HardBreak {  });
            } else {
                push_node(s, root.ast.SoftBreak {  });
            }
            skip_spaces_tabs(s);
            true
        }
    }
}

test "trailing tab before a newline is a soft break" {
    assert.equal(root.to_html("foo\t\nbar\n"), "<p>foo\nbar</p>\n");
    assert.equal(root.to_html("foo\t\t\nbar\n"), "<p>foo\nbar</p>\n")
}

test "two trailing spaces before a newline stay a hard break" {
    assert.equal(root.to_html("foo  \nbar\n"), "<p>foo<br />\nbar</p>\n")
}

test "spaces before a trailing tab are a soft break" {
    assert.equal(root.to_html("foo  \t\nbar\n"), "<p>foo\nbar</p>\n");
    assert.equal(root.to_html("foo \t \nbar\n"), "<p>foo\nbar</p>\n")
}

test "two spaces immediately before newline after a tab are a hard break" {
    assert.equal(root.to_html("foo\t  \nbar\n"), "<p>foo<br />\nbar</p>\n")
}
