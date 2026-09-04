function trim_trailing_spaces(s: Subject) -> int {
    if let last: InlineCell = s.tail {
        if let lit: root.ast.Text = last.node {
            let n = 0;
            while (lit.literal.ends_with(" ") || lit.literal.ends_with("\t")) {
                if (lit.literal.ends_with(" ")) {
                    n += 1;
                }
                lit.literal = lit.literal.slice(0, lit.literal.length() - 1);
            }
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

class NewlineRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "newline"
        }

        function parse(self, s: Subject) -> bool throws never {
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
