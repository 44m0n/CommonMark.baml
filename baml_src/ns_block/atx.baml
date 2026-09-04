class AtxHeadingStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "atx_heading"
        }

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (parser.indented) {
                return StartMatch.None;
            }
            let line = parser.scan.line;
            let i = parser.next_nonspace;
            let hashes = 0;
            while (hashes < 7 && line.at(i) == "#") {
                hashes += 1;
                i += 1;
            }
            if (hashes < 1 || hashes > 6) {
                return StartMatch.None;
            }
            let next = line.at(i);
            if (next != null && next != " " && next != "\t") {
                return StartMatch.None;
            }
            parser.advance_next_nonspace();
            parser.advance_offset(hashes, false);
            while (true) {
                let c = parser.scan.line.at(parser.scan.pos);
                if (c == " " || c == "\t") {
                    parser.advance_offset(1, false);
                } else {
                    break;
                }
            }
            parser.close_unmatched();
            let rest = parser.scan.line.slice(parser.scan.pos, parser.scan.line.length());
            let open = open_heading(hashes);
            open.string_content = strip_atx_closing(rest);
            parser.push_child(open);
            parser.advance_offset(parser.scan.line.length() - parser.scan.pos, false);
            StartMatch.Leaf
        }
    }
}

function is_space_tab(c: string?) -> bool {
    c == " " || c == "\t"
}

function strip_trailing_space_tab(s: string) -> string {
    let end = s.length();
    while (end > 0 && is_space_tab(s.at(end - 1))) {
        end -= 1;
    }
    s.slice(0, end)
}

function strip_atx_closing(s: string) -> string {
    let trimmed = strip_trailing_space_tab(s);
    let start = 0;
    while (start < trimmed.length() && is_space_tab(trimmed.at(start))) {
        start += 1;
    }
    if (start < trimmed.length()) {
        let j = start;
        while (j < trimmed.length() && trimmed.at(j) == "#") {
            j += 1;
        }
        if (j == trimmed.length() && j > start) {
            return "";
        }
    }
    let end = trimmed.length();
    while (end > 0 && trimmed.at(end - 1) == "#") {
        end -= 1;
    }
    if (end == trimmed.length() || end == 0) {
        return s;
    }
    let space_end = end;
    while (space_end > 0 && is_space_tab(trimmed.at(space_end - 1))) {
        space_end -= 1;
    }
    if (space_end == end) {
        return s;
    }
    trimmed.slice(0, space_end)
}

test "atx headings levels one through six" {
    assert.equal(
        root.to_html("# foo\n## foo\n### foo\n#### foo\n##### foo\n###### foo\n"),
        "<h1>foo</h1>\n<h2>foo</h2>\n<h3>foo</h3>\n<h4>foo</h4>\n<h5>foo</h5>\n<h6>foo</h6>\n",
    )
}

test "seven hashes is a paragraph" {
    assert.equal(root.to_html("####### foo\n"), "<p>####### foo</p>\n")
}

test "atx requires a space after the hashes" {
    assert.equal(root.to_html("#5 bolt\n\n#hashtag\n"), "<p>#5 bolt</p>\n<p>#hashtag</p>\n")
}

test "atx closing sequence is stripped" {
    assert.equal(root.to_html("## foo ##\n  ###   bar    ###\n"), "<h2>foo</h2>\n<h3>bar</h3>\n")
}

test "atx empty headings" {
    assert.equal(root.to_html("## \n#\n### ###\n"), "<h2></h2>\n<h1></h1>\n<h3></h3>\n")
}

test "atx interrupts a paragraph" {
    assert.equal(
        root.to_html("Foo bar\n# baz\nBar foo\n"),
        "<p>Foo bar</p>\n<h1>baz</h1>\n<p>Bar foo</p>\n",
    )
}

test "atx heading spec examples that do not need later constructs" {
    root.spec.assert_spec_examples([62, 63, 64, 65, 67, 68, 69, 70, 71, 72, 73, 74, 75, 77, 78, 79])
}
