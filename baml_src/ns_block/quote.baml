class BlockQuoteStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "block_quote"
        }

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (parser.indented) {
                return StartMatch.None;
            }
            if (parser.scan.line.at(parser.next_nonspace) != ">") {
                return StartMatch.None;
            }
            consume_quote_marker(parser);
            parser.close_unmatched();
            parser.push_child(open_block_quote());
            StartMatch.Container
        }
    }
}

function consume_quote_marker(parser: Parser) -> void {
    parser.advance_next_nonspace();
    parser.advance_offset(1, false);
    let c = parser.scan.line.at(parser.scan.pos);
    if (c == " " || c == "\t") {
        parser.advance_offset(1, true);
    }
}

test "block quote wraps nested heading and paragraph" {
    assert.equal(
        root.to_html("> # Foo\n> bar\n> baz\n"),
        "<blockquote>\n<h1>Foo</h1>\n<p>bar\nbaz</p>\n</blockquote>\n",
    )
}

test "block quote allows lazy continuation" {
    assert.equal(root.to_html("> foo\nbar\n"), "<blockquote>\n<p>foo\nbar</p>\n</blockquote>\n")
}

test "setext underline is not lazy inside a quote" {
    assert.equal(root.to_html("> Foo\n---\n"), "<blockquote>\n<p>Foo</p>\n</blockquote>\n<hr />\n")
}

test "blank line splits two block quotes" {
    assert.equal(
        root.to_html("> foo\n\n> bar\n"),
        "<blockquote>\n<p>foo</p>\n</blockquote>\n<blockquote>\n<p>bar</p>\n</blockquote>\n",
    )
}

test "block quote spec" {
    assert.equal(root.spec.spec_failures("Block quotes"), 0)
}
