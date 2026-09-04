function is_escapable(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        root.scan.is_ascii_punctuation(c)
    }
}

function unescape_string(s: string, table: map<string, string>) -> string {
    root.inline.unescape_markdown(s, table = table)
}

function skip_spaces_tabs(s: string, i: int) -> int {
    while (s.at(i) == " " || s.at(i) == "\t") {
        i += 1;
    }
    i
}

function skip_spnl(s: string, i: int) -> int {
    i = skip_spaces_tabs(s, i);
    if (s.at(i) == "\n") {
        i = skip_spaces_tabs(s, i + 1);
    }
    i
}

function at_line_end(s: string, i: int) -> int? {
    i = skip_spaces_tabs(s, i);
    if (i >= s.length()) {
        i
    } else if (s.at(i) == "\n") {
        i + 1
    } else {
        null
    }
}

function parse_link_label(s: string, i: int) -> int? {
    if (s.at(i) != "[") {
        return null;
    }
    let j = i + 1;
    while (j < s.length()) {
        if (j - i > 1000) {
            return null;
        }
        let c = s.at(j) ?? "";
        if (c == "\\") {
            j += 1;
            if (j < s.length()) {
                j += 1;
            }
        } else if (c == "[") {
            return null;
        } else if (c == "]") {
            return j + 1;
        } else {
            j += 1;
        }
    }
    null
}

class ScanPiece {
    end: int,
    value: string,
}

function parse_link_destination(s: string, i: int, table: map<string, string>) -> ScanPiece? {
    if (s.at(i) == "<") {
        let j = i + 1;
        while (j < s.length()) {
            let c = s.at(j) ?? "";
            if (c == "\n" || c == "<") {
                return null;
            }
            if (c == "\\") {
                j += 1;
                if (j < s.length()) {
                    j += 1;
                }
            } else if (c == ">") {
                return ScanPiece { end: j + 1, value: unescape_string(s.slice(i + 1, j), table = table) };
            } else {
                j += 1;
            }
        }
        return null;
    }
    let save = i;
    let open_parens = 0;
    while (i < s.length()) {
        let c = s.at(i) ?? "";
        if (c == "\\" && is_escapable(s.at(i + 1))) {
            i += 2;
        } else if (c == "(") {
            open_parens += 1;
            i += 1;
        } else if (c == ")") {
            if (open_parens < 1) {
                break;
            }
            open_parens -= 1;
            i += 1;
        } else if (c == " " || c == "\t" || c == "\n") {
            break;
        } else {
            i += 1;
        }
    }
    if (i == save || open_parens != 0) {
        return null;
    }
    ScanPiece { end: i, value: unescape_string(s.slice(save, i), table = table) }
}

function parse_link_title(s: string, i: int, table: map<string, string>) -> ScanPiece? {
    let opener = s.at(i);
    if (opener != "\"" && opener != "'" && opener != "(") {
        return null;
    }
    let closer = if (opener == "(") {
        ")"
    } else {
        opener ?? "\""
    };
    let j = i + 1;
    while (j < s.length()) {
        let c = s.at(j) ?? "";
        if (c == "\n" && s.at(j + 1) == "\n") {
            return null;
        }
        if (c == "\\") {
            j += 1;
            if (j < s.length()) {
                j += 1;
            }
        } else if (c == closer) {
            return ScanPiece { end: j + 1, value: unescape_string(s.slice(i + 1, j), table = table) };
        } else {
            j += 1;
        }
    }
    null
}

function normalize_reference(raw_label: string) -> string {
    let inner = raw_label.slice(1, raw_label.length() - 1);
    let parts: string[] = [];
    let i = 0;
    let last_space = false;
    let started = false;
    while (i < inner.length()) {
        let c = inner.at(i) ?? "";
        if (c == " " || c == "\t" || c == "\n") {
            if (started) {
                last_space = true;
            }
            i += 1;
        } else {
            if (last_space) {
                parts.push(" ");
                last_space = false;
            }
            let start = i;
            i += 1;
            while (i < inner.length()) {
                let n = inner.at(i) ?? "";
                if (n == " " || n == "\t" || n == "\n") {
                    break;
                }
                i += 1;
            }
            parts.push(inner.slice(start, i));
            started = true;
        }
    }
    parts.join("").to_lower_case().replace_all("ß", "ss")
}

function parse_one_reference(
    s: string,
    refs: map<string, root.ast.LinkRef>,
    table: map<string, string>,
) -> int {
    if (s.at(0) != "[") {
        return 0;
    }
    let label_end = parse_link_label(s, 0);
    if (label_end == null) {
        return 0;
    }
    if (s.at(label_end) != ":") {
        return 0;
    }
    let after_colon = skip_spnl(s, label_end + 1);
    let dest = parse_link_destination(s, after_colon, table = table);
    if let d: ScanPiece = dest {
        let dest_end = d.end;
        let destination = d.value;
        let before_title = dest_end;
        let i = skip_spnl(s, dest_end);
        let title: string? = null;
        if (i != before_title) {
            let t = parse_link_title(s, i, table = table);
            if let tv: ScanPiece = t {
                i = tv.end;
                title = tv.value;
            }
        }
        if (title == null) {
            i = before_title;
        }
        let end = at_line_end(s, i);
        if (end == null) {
            if (title != null) {
                title = null;
                end = at_line_end(s, before_title);
            }
        }
        if let consumed: int = end {
            let raw_label = s.slice(0, label_end);
            let norm = normalize_reference(raw_label);
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
    while (rest.at(0) == "[") {
        let n = parse_one_reference(rest, refs, table = table);
        if (n == 0) {
            break;
        }
        rest = rest.slice(n, rest.length());
    }
    rest
}

function unlink_block(parser: Parser, ast: (root.ast.Block | root.ast.ListItem)?) -> void {
    if (parser.stack.length() == 0) {
        return;
    }
    let parent = parser.tip();
    if let item: root.ast.ListItem = parent.ast {
        if let b: root.ast.Block = ast {
            let last = item.children.length() - 1;
            if (last >= 0 && item.children[last] == b) {
                let _ = item.children.pop();
            }
        }
    } else if let b: root.ast.Block = ast {
        let last = parent.children.length() - 1;
        if (last >= 0 && parent.children[last] == b) {
            let _ = parent.children.pop();
        }
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
    assert.equal(root.spec.spec_failures("Link reference definitions"), 0)
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
