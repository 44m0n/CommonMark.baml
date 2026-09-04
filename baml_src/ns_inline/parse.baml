function parse_inlines(raw: string, refs: map<string, root.ast.LinkRef>) -> root.ast.Inline[] {
    let _ = refs;
    if (raw.length() == 0) {
        []
    } else {
        [root.ast.Text { literal: raw }]
    }
}

test "parse_inlines returns empty for empty string" {
    let refs: map<string, root.ast.LinkRef> = {};
    assert.equal(parse_inlines("", refs), [])
}

test "parse_inlines wraps non-empty raw as single Text node" {
    let refs: map<string, root.ast.LinkRef> = {};
    let nodes = parse_inlines("hello *world*", refs);
    assert.equal(nodes.length(), 1);
    assert.equal(nodes.at(0), root.ast.Text { literal: "hello *world*" })
}

test "commonmark_inline_rules is empty for now" {
    assert.equal(commonmark_inline_rules().length(), 0)
}
