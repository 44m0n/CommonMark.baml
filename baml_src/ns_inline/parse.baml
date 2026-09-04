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

function consume_plain_text(s: Subject) -> void {
    let start = pos(s);
    while (!is_eof(s)) {
        let n = peek(s) ?? "";
        if (is_inline_special(n)) {
            break;
        }
        let _ = bump(s);
    }
    push_text(s, s.scan.line.slice(start, pos(s)));
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
    while (!is_eof(s)) {
        let ch = peek(s) ?? "";
        if (!is_inline_special(ch)) {
            consume_plain_text(s);
            continue;
        }
        let matched = false;
        for (let rule in rules) {
            if (rule.parse(s)) {
                matched = true;
                break;
            }
        }
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
