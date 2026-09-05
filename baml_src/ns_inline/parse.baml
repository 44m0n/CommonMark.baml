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

function consume_plain_text(s: Subject, extra: string) -> void {
    let line = s.scan.line;
    let chars = s.scan.chars;
    let extra_chars = extra.chars();
    let start = s.scan.pos;
    let n = chars.length();
    let i = start;
    let probe = start + 64;
    if (probe > n) {
        probe = n;
    }
    while (i < probe) {
        let c = chars.at(i) ?? "";
        if (is_inline_special(c) || (extra_chars.length() > 0 && extra_chars.includes(c))) {
            break;
        }
        i += 1;
    }
    if (
        i < n
            && i == probe
            && !is_inline_special(chars.at(i) ?? "")
            && !(extra_chars.length() > 0 && extra_chars.includes(chars.at(i) ?? ""))
    ) {
        let rest = line.slice(i, n);
        let skip = first_special_index(rest);
        let j = 0;
        while (j < extra_chars.length()) {
            skip = consider_index(rest.index_of(extra_chars.at(j) ?? ""), skip);
            j += 1;
        }
        i += skip;
    }
    if (i > start) {
        push_text(s, line.slice(start, i));
        s.scan.pos = i;
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
    run_inline_parse(s, rules);
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

class PercentSpanRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "percent_span"
        }

        function triggers(self) -> string[] throws never {
            ["%"]
        }

        function parse(self, s: Subject) -> bool throws never {
            if (peek(s) != "%") {
                return false;
            }
            let start = pos(s);
            let _ = bump(s);
            let i = pos(s);
            let line = s.scan.line;
            let chars = s.scan.chars;
            while (i < chars.length()) {
                if (chars.at(i) == "%") {
                    let inner = line.slice(pos(s), i);
                    advance_to(s, i + 1);
                    push_node(s, root.ast.HtmlInline { literal: "<span>" });
                    push_text(s, inner);
                    push_node(s, root.ast.HtmlInline { literal: "</span>" });
                    return true;
                }
                i += 1;
            }
            advance_to(s, start);
            false
        }
    }
}

test "extra inline rule is unused without options" {
    assert.equal(root.to_html("hello %x%"), "<p>hello %x%</p>\n")
}

test "extra inline rule matches a new trigger" {
    let options = root.block.commonmark_options();
    options.inline_rules.push(PercentSpanRule {  });
    assert.equal(
        root.to_html("hello %x% *y*", options = options),
        "<p>hello <span>x</span> <em>y</em></p>\n",
    )
}

test "unclosed extra trigger stays text" {
    let options = root.block.commonmark_options();
    options.inline_rules.push(PercentSpanRule {  });
    assert.equal(root.to_html("a %b", options = options), "<p>a %b</p>\n")
}

test "backslash spec" {
    assert.equal(root.spec.spec_failures("Backslash escapes"), [])
}

test "code spans spec" {
    assert.equal(root.spec.spec_failures("Code spans"), [])
}

test "autolink spec" {
    assert.equal(root.spec.spec_failures("Autolinks"), [])
}

test "raw html spec" {
    assert.equal(root.spec.spec_failures("Raw HTML"), [])
}

test "hard line breaks spec" {
    assert.equal(root.spec.spec_failures("Hard line breaks"), [])
}

test "soft line breaks spec" {
    assert.equal(root.spec.spec_failures("Soft line breaks"), [])
}

test "textual content spec" {
    assert.equal(root.spec.spec_failures("Textual content"), [])
}

test "precedence spec" {
    assert.equal(root.spec.spec_failures("Precedence"), [])
}

test "entity spec" {
    assert.equal(root.spec.spec_failures("Entity and numeric character references"), [])
}

test "emphasis spec" {
    assert.equal(root.spec.spec_failures("Emphasis and strong emphasis"), [])
}

test "links spec" {
    assert.equal(root.spec.spec_failures("Links"), [])
}

test "images spec" {
    assert.equal(root.spec.spec_failures("Images"), [])
}

test "inlines spec" {
    assert.equal(root.spec.spec_failures("Inlines"), [])
}

test "tabs spec" {
    assert.equal(root.spec.spec_failures("Tabs"), [])
}
