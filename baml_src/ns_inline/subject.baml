class Subject {
    scan: root.scan.LineScan,
    inlines: root.ast.Inline[],
    refs: map<string, root.ast.LinkRef>,
    delimiters: Delimiter[],
    brackets: Bracket[],
    entities: map<string, string>,
    last_protected: bool,
}

function subject(raw: string) -> Subject {
    Subject {
        scan: root.scan.line_scan(raw),
        inlines: [],
        refs: {},
        delimiters: [],
        brackets: [],
        entities: {},
        last_protected: false,
    }
}

function pos(s: Subject) -> int {
    s.scan.pos
}

function peek(s: Subject) -> string? {
    root.scan.peek(s.scan)
}

function peek_at(s: Subject, offset: int) -> string? {
    s.scan.line.at(s.scan.pos + offset)
}

function bump(s: Subject) -> string? {
    root.scan.bump(s.scan)
}

function is_eof(s: Subject) -> bool {
    root.scan.is_eof(s.scan)
}

function rest(s: Subject) -> string {
    s.scan.line.slice(s.scan.pos, s.scan.line.length())
}

function advance_to(s: Subject, p: int) -> void {
    s.scan.pos = p
}

function skip_spaces_tabs(s: Subject) -> void {
    while (peek(s) == " " || peek(s) == "\t") {
        let _ = bump(s);
    }
}

function push_node(s: Subject, node: root.ast.Inline) -> void {
    s.inlines.push(node);
    s.last_protected = false
}

function push_text(s: Subject, t: string) -> void {
    if (t.length() == 0) {
        return;
    }
    let last_i = s.inlines.length() - 1;
    if (last_i >= 0) {
        let last = s.inlines[last_i];
        if (last is root.ast.Text && !s.last_protected) {
            last.literal = `${last.literal}${t}`;
            return;
        }
    }
    s.inlines.push(root.ast.Text { literal: t });
    s.last_protected = false
}

test "subject starts at position zero" {
    let s = subject("hello");
    assert.equal(pos(s), 0);
    assert.equal(peek(s), "h")
}

test "bump advances position and returns character" {
    let s = subject("ab");
    assert.equal(bump(s), "a");
    assert.equal(pos(s), 1);
    assert.equal(peek(s), "b");
    assert.equal(bump(s), "b");
    assert.equal(pos(s), 2);
    assert.is_true(is_eof(s))
}

test "bump at end returns null" {
    let s = subject("");
    assert.equal(bump(s), null);
    assert.is_true(is_eof(s))
}

test "push_text coalesces adjacent text nodes" {
    let s = subject("");
    push_text(s, "hel");
    push_text(s, "lo");
    assert.equal(s.inlines.length(), 1);
    assert.equal(s.inlines.at(0), root.ast.Text { literal: "hello" })
}

test "push_text does not coalesce into a delimiter marker" {
    let refs: map<string, root.ast.LinkRef> = {};
    let nodes = parse_inlines("*a", refs);
    assert.equal(nodes.length(), 2);
    assert.equal(nodes.at(0), root.ast.Text { literal: "*" });
    assert.equal(nodes.at(1), root.ast.Text { literal: "a" })
}
