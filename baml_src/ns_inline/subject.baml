class Subject {
    scan: root.scan.LineScan,
}

function subject(raw: string) -> Subject {
    Subject { scan: root.scan.line_scan(raw) }
}

function pos(s: Subject) -> int {
    s.scan.pos
}

function peek(s: Subject) -> string? {
    root.scan.peek(s.scan)
}

function bump(s: Subject) -> string? {
    root.scan.bump(s.scan)
}

function is_eof(s: Subject) -> bool {
    root.scan.is_eof(s.scan)
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
