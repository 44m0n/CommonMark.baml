function parse_inlines(raw: string, refs: map<string, root.ast.LinkRef>) -> root.ast.Inline[] {
    let s = subject(raw);
    s.refs = refs;
    let rules = commonmark_inline_rules();
    while (!is_eof(s)) {
        let matched = false;
        for (let rule in rules) {
            if (rule.parse(s)) {
                matched = true;
                break;
            }
        }
        if (!matched) {
            push_text(s, bump(s) ?? "");
        }
    }
    let _ = trim_trailing_spaces(s);
    s.inlines
}

test "parse_inlines returns empty for empty string" {
    let refs: map<string, root.ast.LinkRef> = {};
    assert.equal(parse_inlines("", refs), [])
}

test "parse_inlines coalesces ordinary text" {
    let refs: map<string, root.ast.LinkRef> = {};
    let nodes = parse_inlines("hello *world*", refs);
    assert.equal(nodes.length(), 1);
    assert.equal(nodes.at(0), root.ast.Text { literal: "hello *world*" })
}

test "backslash unescapes ascii punctuation" {
    let refs: map<string, root.ast.LinkRef> = {};
    let nodes = parse_inlines("\\*a", refs);
    assert.equal(nodes.at(0), root.ast.Text { literal: "*a" })
}

test "commonmark_inline_rules includes leaf inline rules" {
    assert.equal(commonmark_inline_rules().length(), 5)
}

test "backslash spec examples that do not need later constructs" {
    root.spec.assert_spec_examples([12, 13, 14, 16, 17, 18, 19, 20, 21, 24])
}

test "code span spec examples that do not need later constructs" {
    root.spec.assert_spec_examples(
        [
            327,
            328,
            329,
            330,
            331,
            332,
            333,
            334,
            335,
            336,
            337,
            338,
            339,
            340,
            341,
            342,
            343,
            344,
            345,
            346,
            347,
            348,
            349,
        ],
    )
}

test "autolink spec" {
    assert.equal(root.spec.spec_failures("Autolinks"), 0)
}

test "raw html spec" {
    assert.equal(root.spec.spec_failures("Raw HTML"), 0)
}

test "hard line breaks spec examples that do not need emphasis" {
    root.spec.assert_spec_examples(
        [633, 634, 635, 636, 637, 640, 641, 642, 643, 644, 645, 646, 647],
    )
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
