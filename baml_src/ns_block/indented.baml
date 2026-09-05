class IndentedCodeStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "indented_code"
        }

        function triggers(self) -> string[] throws never {
            let none: string[] = [];
            none
        }

        function allow_indented(self) -> bool throws never {
            true
        }

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (!(parser.indented && !parser.tip().ops.is_interruptible() && !parser.blank)) {
                return StartMatch.None;
            }
            parser.advance_offset(4, true);
            parser.close_unmatched();
            parser.push_child(open_indented_code());
            StartMatch.Leaf
        }
    }
}

test "indented code strips one level of indent" {
    assert.equal(
        root.to_html("    a simple\n      indented code block\n"),
        "<pre><code>a simple\n  indented code block\n</code></pre>\n",
    )
}

test "indented code cannot interrupt a paragraph" {
    assert.equal(root.to_html("Foo\n    bar\n\n"), "<p>Foo\nbar</p>\n")
}

test "indented code preserves trailing spaces" {
    assert.equal(root.to_html("    foo  \n"), "<pre><code>foo  \n</code></pre>\n")
}

test "indented code spec" {
    assert.equal(root.spec.spec_failures("Indented code blocks"), [])
}
