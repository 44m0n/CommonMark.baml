function unescape_string(s: string, table: map<string, string>) -> string {
    root.inline.unescape_markdown(s, table = table)
}

function skip_spnl_chars(chars: string[], i: int) -> int {
    i = root.scan.skip_space_tab_chars(chars, i);
    if (chars.at(i) == "\n") {
        i = root.scan.skip_space_tab_chars(chars, i + 1);
    }
    i
}

function at_line_end_chars(chars: string[], i: int) -> int? {
    i = root.scan.skip_space_tab_chars(chars, i);
    if (i >= chars.length()) {
        i
    } else if (chars.at(i) == "\n") {
        i + 1
    } else {
        null
    }
}

function parse_one_reference(
    s: string,
    refs: map<string, root.ast.LinkRef>,
    table: map<string, string>,
) -> int {
    let chars = s.chars();
    if (chars.at(0) != "[") {
        return 0;
    }
    let label_end = root.inline.parse_link_label_chars(chars, 0);
    if (label_end == null) {
        return 0;
    }
    if (chars.at(label_end) != ":") {
        return 0;
    }
    let after_colon = skip_spnl_chars(chars, label_end + 1);
    let dest = root.inline.parse_link_destination_chars(s, chars, after_colon, table = table);
    if let d: root.inline.ScanPiece = dest {
        let dest_end = d.end;
        let destination = d.value;
        let before_title = dest_end;
        let i = skip_spnl_chars(chars, dest_end);
        let title: string? = null;
        if (i != before_title) {
            let t = root.inline.parse_link_title_chars(s, chars, i, table = table);
            if let tv: root.inline.ScanPiece = t {
                i = tv.end;
                title = tv.value;
            }
        }
        if (title == null) {
            i = before_title;
        }
        let end = at_line_end_chars(chars, i);
        if (end == null) {
            if (title != null) {
                title = null;
                end = at_line_end_chars(chars, before_title);
            }
        }
        if let consumed: int = end {
            let raw_label = s.slice(0, label_end);
            let norm = root.inline.normalize_reference(raw_label);
            if (norm.length() == 0) {
                return 0;
            }
            if (refs.get(norm) == null) {
                let _ = refs.set(norm, root.ast.LinkRef { destination: destination, title: title });
            }
            consumed
        } else {
            0
        }
    } else {
        0
    }
}

function consume_link_reference_definitions(
    s: string,
    refs: map<string, root.ast.LinkRef>,
    table: map<string, string>,
) -> string {
    let rest = s;
    while (rest.starts_with("[")) {
        let n = parse_one_reference(rest, refs, table = table);
        if (n == 0) {
            break;
        }
        rest = rest.slice(n, rest.length());
    }
    rest
}

function unlink_block(parser: Parser) -> void {
    if (parser.stack.length() == 0) {
        return;
    }
    let parent = parser.tip();
    if (parent.children.length() > 0) {
        let _ = parent.children.pop();
    }
}

test "link definition alone produces empty document" {
    assert.equal(root.to_html("[foo]: /url\n"), "")
}

test "remainder after a definition stays a paragraph" {
    assert.equal(root.to_html("[\nfoo\n]: /url\nbar\n"), "<p>bar</p>\n")
}

test "junk after a title is not a definition" {
    assert.equal(
        root.to_html("[foo]: /url \"title\" ok\n"),
        "<p>[foo]: /url &quot;title&quot; ok</p>\n",
    )
}

test "link definitions cannot interrupt a paragraph" {
    assert.equal(
        root.to_html("Foo\n[bar]: /baz\n\n[bar]\n"),
        "<p>Foo\n[bar]: /baz</p>\n<p>[bar]</p>\n",
    )
}

test "link reference spec" {
    assert.equal(root.spec.spec_failures("Link reference definitions"), [])
}

test "reference labels match after unicode case folding" {
    assert.equal(root.to_html("[Σ]: /u\n[ς]\n"), "<p><a href=\"/u\">ς</a></p>\n");
    assert.equal(root.to_html("[ẞ]: /u\n[ss]\n"), "<p><a href=\"/u\">ss</a></p>\n")
}

test "link labels allow 999 characters but not 1000" {
    let ok = "x".repeat(999);
    assert.equal(root.to_html(`[${ok}]: /u\n[${ok}]\n`), `<p><a href="/u">${ok}</a></p>\n`);
    let too_long = "x".repeat(1000);
    assert.equal(
        root.to_html(`[${too_long}]: /u\n[${too_long}]\n`),
        `<p>[${too_long}]: /u\n[${too_long}]</p>\n`,
    )
}

test "link destination allows three nested parentheses" {
    assert.equal(
        root.to_html("[link](foo(and(bar(baz))))\n"),
        `<p><a href="foo(and(bar(baz)))">link</a></p>\n`,
    )
}

test "link destination allows 32 nested parentheses but not 33" {
    let depth = root.inline.max_dest_paren_depth();
    let ok = `${"(".repeat(depth)}x${")".repeat(depth)}`;
    assert.equal(root.to_html(`[a](${ok})\n`), `<p><a href="${ok}">a</a></p>\n`);
    let too = `${"(".repeat(depth + 1)}x${")".repeat(depth + 1)}`;
    assert.equal(root.to_html(`[a](${too})\n`), `<p>[a](${too})</p>\n`)
}

test "repeated unmatched link parens stay text" {
    let bomb = "[a](".repeat(400);
    assert.equal(root.to_html(bomb), `<p>${bomb}</p>\n`)
}

test "parenthesized title rejects an unescaped opening paren" {
    assert.equal(root.to_html("[a](/u (ti(tle))\n"), "<p>[a](/u (ti(tle))</p>\n");
    assert.equal(
        root.to_html("[a](/u (ti\\(tle))\n"),
        "<p><a href=\"/u\" title=\"ti(tle\">a</a></p>\n",
    )
}

test "bare destination rejects ascii control characters" {
    let del = string.from_code_points([127]) catch (e) {
        baml.errors.InvalidArgument => "?"
    };
    assert.equal(root.to_html(`[a](/u${del}x)\n`), `<p>[a](/u${del}x)</p>\n`)
}
