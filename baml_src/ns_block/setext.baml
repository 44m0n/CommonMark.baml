class SetextHeadingStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "setext_heading"
        }

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (parser.indented) {
                return StartMatch.None;
            }
            let container = parser.last_matched();
            if (container.type_name != "paragraph") {
                return StartMatch.None;
            }
            let level = setext_heading_level(parser.scan.line, parser.next_nonspace);
            if (level == null) {
                return StartMatch.None;
            }
            parser.close_unmatched();
            if (is_blank_text(strip_final_newline(container.string_content))) {
                return StartMatch.None;
            }
            convert_paragraph_to_setext(parser, container, level);
            parser.advance_offset(parser.scan.line.length() - parser.scan.pos, false);
            StartMatch.Leaf
        }
    }
}

function setext_heading_level(line: string, start: int) -> int? {
    let marker = line.at(start);
    if (marker != "=" && marker != "-") {
        return null;
    }
    let i = start;
    while (line.at(i) == marker) {
        i += 1;
    }
    if (i == start) {
        return null;
    }
    while (i < line.length()) {
        let c = line.at(i);
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
    let heading = root.ast.Heading { level: level, setext: true, raw: "", children: [] };
    if (parser.stack.length() >= 2) {
        let parent = parser.stack[parser.stack.length() - 2];
        let last = parent.children.length() - 1;
        if (last >= 0) {
            parent.children[last] = heading;
        }
    }
    para.type_name = "heading";
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

test "setext heading spec examples that do not need later constructs" {
    root.spec.assert_spec_examples(
        [83, 84, 85, 86, 87, 88, 89, 90, 95, 96, 97, 98, 100, 103, 104, 105],
    )
}
