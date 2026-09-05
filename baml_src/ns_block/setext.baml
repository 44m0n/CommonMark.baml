class SetextHeadingStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "setext_heading"
        }

        function triggers(self) -> string[] throws never {
            ["=", "-"]
        }

        function allow_indented(self) -> bool throws never {
            false
        }

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (parser.indented) {
                return StartMatch.None;
            }
            let container = parser.last_matched();
            if (container.type_name != OpenKind.Paragraph) {
                return StartMatch.None;
            }
            let level = setext_heading_level(parser.scan.chars, parser.next_nonspace);
            if (level == null) {
                return StartMatch.None;
            }
            parser.close_unmatched();
            let remaining = consume_link_reference_definitions(content_text(container), parser.document.refs, table = parser.entities);
            if (is_blank_text(strip_final_newline(remaining))) {
                return StartMatch.None;
            }
            replace_content(container, remaining);
            convert_paragraph_to_setext(parser, container, level);
            parser.advance_offset(parser.scan.chars.length() - parser.scan.pos, false);
            StartMatch.Leaf
        }
    }
}

function setext_heading_level(chars: string[], start: int) -> int? {
    let marker = chars.at(start);
    if (marker != "=" && marker != "-") {
        return null;
    }
    let i = start;
    while (chars.at(i) == marker) {
        i += 1;
    }
    if (i == start) {
        return null;
    }
    while (i < chars.length()) {
        let c = chars.at(i);
        if (c != " " && c != "\t") {
            return null;
        }
        i += 1;
    }
    if (marker == "=") {
        1
    } else {
        2
    }
}

function convert_paragraph_to_setext(parser: Parser, para: Open, level: int) -> void {
    let heading = root.ast.Heading { level: level, setext: true, raw: "", children: [], last_line_blank: false };
    if (parser.stack.length() >= 2) {
        let parent = parser.stack[parser.stack.length() - 2];
        let last = parent.children.length() - 1;
        if (last >= 0) {
            parent.children[last] = heading;
        }
    }
    para.type_name = OpenKind.Heading;
    para.ops = HeadingOps {  };
    para.ast = heading;
}

test "setext headings levels one and two" {
    assert.equal(
        root.to_html("Foo\n=========================\n\nFoo\n-----\n"),
        "<h1>Foo</h1>\n<h2>Foo</h2>\n",
    )
}

test "setext underline indent up to three" {
    assert.equal(root.to_html("Foo\n   ----      \n"), "<h2>Foo</h2>\n")
}

test "four-space indent is not a setext underline" {
    assert.equal(root.to_html("Foo\n    ---\n"), "<p>Foo\n---</p>\n")
}

test "setext vs thematic break with internal spaces" {
    assert.equal(root.to_html("Foo\n= =\n\nFoo\n--- -\n"), "<p>Foo\n= =</p>\n<p>Foo</p>\n<hr />\n")
}

test "multiline paragraph becomes one setext heading" {
    assert.equal(root.to_html("Foo\nBar\n---\n"), "<h2>Foo\nBar</h2>\n")
}

test "setext heading spec" {
    assert.equal(root.spec.spec_failures("Setext headings"), [])
}
