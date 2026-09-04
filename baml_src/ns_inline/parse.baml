function is_inline_special(c: string) -> bool {
    c == "\\"
        || c == "`"
        || c == "*"
        || c == "_"
        || c == "["
        || c == "]"
        || c == "!"
        || c == "<"
        || c == "&"
        || c == "\n"
}

function consider_index(found: int?, best: int) -> int {
    if let i: int = found {
        if (i < best) {
            i
        } else {
            best
        }
    } else {
        best
    }
}

function first_special_index(s: string) -> int {
    let best = s.length();
    best = consider_index(s.index_of("\\"), best);
    best = consider_index(s.index_of("`"), best);
    best = consider_index(s.index_of("*"), best);
    best = consider_index(s.index_of("_"), best);
    best = consider_index(s.index_of("["), best);
    best = consider_index(s.index_of("]"), best);
    best = consider_index(s.index_of("!"), best);
    best = consider_index(s.index_of("<"), best);
    best = consider_index(s.index_of("&"), best);
    consider_index(s.index_of("\n"), best)
}

function consume_plain_text(s: Subject) -> void {
    let line = s.scan.line;
    let start = s.scan.pos;
    let n = line.length();
    let i = start;
    let probe = start + 64;
    if (probe > n) {
        probe = n;
    }
    while (i < probe) {
        let c = line.at(i) ?? "";
        if (is_inline_special(c)) {
            break;
        }
        i += 1;
    }
    if (i < n && i == probe && !is_inline_special(line.at(i) ?? "")) {
        let extra = first_special_index(line.slice(i, n));
        i += extra;
    }
    if (i > start) {
        push_text(s, line.slice(start, i));
        s.scan.pos = i;
    }
}

function try_inline_special(s: Subject, ch: string) -> bool {
    match (ch) {
        "\\" => BackslashRule {  }.parse(s),
        "\n" => NewlineRule {  }.parse(s),
        "`" => CodeSpanRule {  }.parse(s),
        "&" => EntityRule {  }.parse(s),
        "<" => {
            if (AutolinkRule {  }.parse(s)) {
                true
            } else {
                HtmlInlineRule {  }.parse(s)
            }
        },
        "!" => BangRule {  }.parse(s),
        "[" => OpenBracketRule {  }.parse(s),
        "]" => CloseBracketRule {  }.parse(s),
        "*" | "_" => EmphasisRule {  }.parse(s),
        _ => false,
    }
}

function parse_inlines(
    raw: string,
    refs: map<string, root.ast.LinkRef>,
    entities: map<string, string> = load_named_entities(),
    rules: InlineParseRule[] = commonmark_inline_rules(),
) -> root.ast.Inline[] {
    let s = subject(raw);
    s.refs = refs;
    s.entities = entities;
    let _ = rules;
    while (!is_eof(s)) {
        let ch = peek(s) ?? "";
        if (!is_inline_special(ch)) {
            consume_plain_text(s);
            continue;
        }
        let matched = try_inline_special(s, ch);
        if (!matched) {
            let start = pos(s);
            let _ = bump(s);
            push_text(s, s.scan.line.slice(start, pos(s)));
        }
    }
    let _ = trim_trailing_spaces(s);
    process_emphasis(s, 0);
    flatten_inlines(s)
}

test "parse_inlines returns empty for empty string" {
    let refs: map<string, root.ast.LinkRef> = {};
    assert.equal(parse_inlines("", refs), [])
}

test "parse_inlines coalesces ordinary text" {
    let refs: map<string, root.ast.LinkRef> = {};
    let nodes = parse_inlines("hello world", refs);
    assert.equal(nodes.length(), 1);
    assert.equal(nodes.at(0), root.ast.Text { literal: "hello world" })
}

test "backslash unescapes ascii punctuation" {
    let refs: map<string, root.ast.LinkRef> = {};
    let nodes = parse_inlines("\\*a", refs);
    assert.equal(nodes.at(0), root.ast.Text { literal: "*a" })
}

test "commonmark_inline_rules includes leaf inline rules" {
    assert.equal(commonmark_inline_rules().length(), 10)
}

test "backslash spec" {
    assert.equal(root.spec.spec_failures("Backslash escapes"), 0)
}

test "code spans spec" {
    assert.equal(root.spec.spec_failures("Code spans"), 0)
}

test "autolink spec" {
    assert.equal(root.spec.spec_failures("Autolinks"), 0)
}

test "raw html spec" {
    assert.equal(root.spec.spec_failures("Raw HTML"), 0)
}

test "hard line breaks spec" {
    assert.equal(root.spec.spec_failures("Hard line breaks"), 0)
}

test "soft line breaks spec" {
    assert.equal(root.spec.spec_failures("Soft line breaks"), 0)
}

test "textual content spec" {
    assert.equal(root.spec.spec_failures("Textual content"), 0)
}

test "precedence spec" {
    assert.equal(root.spec.spec_failures("Precedence"), 0)
}

test "entity spec" {
    assert.equal(root.spec.spec_failures("Entity and numeric character references"), 0)
}

test "emphasis spec" {
    assert.equal(root.spec.spec_failures("Emphasis and strong emphasis"), 0)
}

test "links spec" {
    assert.equal(root.spec.spec_failures("Links"), 0)
}

test "images spec" {
    assert.equal(root.spec.spec_failures("Images"), 0)
}

test "inlines spec" {
    assert.equal(root.spec.spec_failures("Inlines"), 0)
}

test "tabs spec" {
    assert.equal(root.spec.spec_failures("Tabs"), 0)
}
