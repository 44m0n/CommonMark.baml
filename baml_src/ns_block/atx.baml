class AtxHeadingStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "atx_heading"
        }

        function triggers(self) -> string[] throws never {
            ["#"]
        }

        function allow_indented(self) -> bool throws never {
            false
        }

        function try_open(self, context: BlockStartContext) -> StartMatch throws never {
            let parser = internal_block_parser(context);
            if (parser.indented) {
                return StartMatch.None;
            }
            let chars = parser.scan.chars;
            let i = parser.next_nonspace;
            let hashes = 0;
            while (hashes < 7 && chars.at(i) == "#") {
                hashes += 1;
                i += 1;
            }
            if (hashes < 1 || hashes > 6) {
                return StartMatch.None;
            }
            let next = chars.at(i);
            if (next != null && next != " " && next != "\t") {
                return StartMatch.None;
            }
            parser.advance_next_nonspace();
            parser.advance_offset(hashes, false);
            while (true) {
                let c = parser.scan.chars.at(parser.scan.pos);
                if (c == " " || c == "\t") {
                    parser.advance_offset(1, false);
                } else {
                    break;
                }
            }
            parser.close_unmatched();
            let rest = parser.scan.line.slice(parser.scan.pos, parser.scan.line.length());
            let open = open_heading(hashes);
            replace_content(open, strip_atx_closing(rest));
            parser.push_child(open);
            parser.advance_offset(parser.scan.chars.length() - parser.scan.pos, false);
            StartMatch.Leaf
        }
    }
}

function is_space_tab(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        root.scan.is_space_or_tab(c)
    }
}

function strip_trailing_space_tab(s: string) -> string {
    let chars = s.chars();
    let end = chars.length();
    while (end > 0 && is_space_tab(chars.at(end - 1))) {
        end -= 1;
    }
    s.slice(0, end)
}

function strip_atx_closing(s: string) -> string {
    let trimmed = strip_trailing_space_tab(s);
    let chars = trimmed.chars();
    let start = 0;
    while (start < chars.length() && is_space_tab(chars.at(start))) {
        start += 1;
    }
    if (start < chars.length()) {
        let j = start;
        while (j < chars.length() && chars.at(j) == "#") {
            j += 1;
        }
        if (j == chars.length() && j > start) {
            return "";
        }
    }
    let end = chars.length();
    while (end > 0 && chars.at(end - 1) == "#") {
        end -= 1;
    }
    if (end == chars.length() || end == 0) {
        return s;
    }
    let space_end = end;
    while (space_end > 0 && is_space_tab(chars.at(space_end - 1))) {
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

test "atx heading spec" {
    assert.equal(root.spec.spec_failures("ATX headings"), [])
}

test "atx heading trims only spaces and tabs" {
    assert.equal(root.to_html("# foo\u{00A0}\n"), "<h1>foo\u{00A0}</h1>\n")
}
