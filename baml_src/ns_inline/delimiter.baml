class Delimiter {
    kind: string,
    count: int,
    orig_count: int,
    can_open: bool,
    can_close: bool,
    cell: InlineCell,
    ord: int,
    prev: Delimiter?,
    next: Delimiter?,
}

function push_delim(s: Subject, d: Delimiter) -> void {
    d.ord = s.delimiters.length();
    d.prev = s.delim_tail;
    d.next = null;
    if let t: Delimiter = s.delim_tail {
        t.next = d;
    }
    s.delim_tail = d;
    s.delimiters.push(d);
}

function unlink_delim(s: Subject, d: Delimiter) -> void {
    let prev = d.prev;
    let next = d.next;
    if let p: Delimiter = prev {
        p.next = next;
    }
    if let n: Delimiter = next {
        n.prev = prev;
    } else {
        s.delim_tail = prev;
    }
    d.prev = null;
    d.next = null;
}

class Bracket {
    image: bool,
    active: bool,
    bracket_after: bool,
    cell: InlineCell,
    opener_pos: int,
    delim_bottom: int,
}

test "delimiter records open and close flags" {
    let d = Delimiter {
        kind: "[",
        count: 1,
        orig_count: 1,
        can_open: true,
        can_close: false,
        cell: dummy_cell(),
        ord: 0,
        prev: null,
        next: null,
    };
    assert.is_true(d.can_open);
    assert.equal(d.can_close, false)
}
