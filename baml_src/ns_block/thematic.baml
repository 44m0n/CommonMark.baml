class ThematicBreakStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "thematic_break"
        }

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (parser.indented) {
                return StartMatch.None;
            }
            if (!looks_like_thematic_break(parser.scan.line, parser.next_nonspace)) {
                return StartMatch.None;
            }
            parser.close_unmatched();
            parser.push_child(open_thematic_break());
            parser.advance_offset(parser.scan.line.length() - parser.scan.pos, false);
            StartMatch.Leaf
        }
    }
}

function looks_like_thematic_break(line: string, start: int) -> bool {
    let marker = line.at(start);
    if (marker != "*" && marker != "-" && marker != "_") {
        return false;
    }
    let count = 0;
    let i = start;
    while (i < line.length()) {
        let c = line.at(i) ?? "";
        if (c == marker) {
            count += 1;
        } else if (c != " " && c != "\t") {
            return false;
        }
        i += 1;
    }
    count >= 3
}

test "thematic break stars dashes underscores" {
    assert.equal(root.to_html("***\n---\n___\n"), "<hr />\n<hr />\n<hr />\n")
}

test "plus and equals are not thematic breaks" {
    assert.equal(root.to_html("+++\n"), "<p>+++</p>\n");
    assert.equal(root.to_html("===\n"), "<p>===</p>\n")
}

test "two markers are not a thematic break" {
    assert.equal(root.to_html("--\n**\n__\n"), "<p>--\n**\n__</p>\n")
}

test "thematic break allows indent up to three" {
    assert.equal(root.to_html(" ***\n  ***\n   ***\n"), "<hr />\n<hr />\n<hr />\n")
}

test "thematic break with internal spaces" {
    assert.equal(root.to_html(" - - -\n"), "<hr />\n");
    assert.equal(root.to_html(" **  * ** * ** * **\n"), "<hr />\n");
    assert.equal(root.to_html("-     -      -      -\n"), "<hr />\n")
}

test "thematic break interrupts a paragraph" {
    assert.equal(root.to_html("Foo\n***\nbar\n"), "<p>Foo</p>\n<hr />\n<p>bar</p>\n")
}

test "thematic break rejects extra characters" {
    assert.equal(
        root.to_html("_ _ _ _ a\n\na------\n\n---a---\n"),
        "<p>_ _ _ _ a</p>\n<p>a------</p>\n<p>---a---</p>\n",
    )
}

test "four-space indent is not a thematic break" {
    assert.equal(looks_like_thematic_break("    ***", 4), true);
    assert.equal(root.to_html("Foo\n    ***\n"), "<p>Foo\n***</p>\n")
}

test "thematic break spec examples that do not need later constructs" {
    root.spec.assert_spec_examples([43, 44, 45, 46, 47, 49, 50, 51, 52, 53, 54, 55, 58])
}
