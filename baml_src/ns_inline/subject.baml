class InlineCell {
    id: int,
    node: root.ast.Inline,
    prev: InlineCell?,
    next: InlineCell?,
}

class Subject {
    scan: root.scan.LineScan,
    head: InlineCell?,
    tail: InlineCell?,
    next_cell_id: int,
    refs: map<string, root.ast.LinkRef>,
    delimiters: Delimiter[],
    delim_tail: Delimiter?,
    brackets: Bracket[],
    entities: map<string, string>,
    last_protected: bool,
    text_parts: string[],
}

function subject(raw: string) -> Subject {
    Subject {
        scan: root.scan.line_scan(raw),
        head: null,
        tail: null,
        next_cell_id: 1,
        refs: {},
        delimiters: [],
        delim_tail: null,
        brackets: [],
        entities: {},
        last_protected: false,
        text_parts: [],
    }
}

function pos(s: Subject) -> int {
    s.scan.pos
}

function peek(s: Subject) -> string? {
    root.scan.peek(s.scan)
}

function peek_at(s: Subject, offset: int) -> string? {
    s.scan.chars.at(s.scan.pos + offset)
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

function dummy_cell() -> InlineCell {
    InlineCell { id: 0, node: root.ast.Text { literal: "" }, prev: null, next: null }
}

function flatten_inlines(s: Subject) -> root.ast.Inline[] {
    flush_text(s);
    let out: root.ast.Inline[] = [];
    let c = s.head;
    while (true) {
        if let cell: InlineCell = c {
            out.push(cell.node);
            c = cell.next;
        } else {
            break;
        }
    }
    out
}

function append_cell(s: Subject, node: root.ast.Inline) -> InlineCell {
    let cell = InlineCell { id: s.next_cell_id, node: node, prev: s.tail, next: null };
    s.next_cell_id += 1;
    if let t: InlineCell = s.tail {
        t.next = cell;
    } else {
        s.head = cell;
    }
    s.tail = cell;
    s.last_protected = false;
    cell
}

function unlink_cell(s: Subject, cell: InlineCell) -> void {
    let prev = cell.prev;
    let next = cell.next;
    if let p: InlineCell = prev {
        p.next = next;
    } else {
        s.head = next;
    }
    if let n: InlineCell = next {
        n.prev = prev;
    } else {
        s.tail = prev;
    }
    cell.prev = null;
    cell.next = null
}

function insert_after(s: Subject, after: InlineCell, node: root.ast.Inline) -> InlineCell {
    let nxt = after.next;
    let cell = InlineCell { id: s.next_cell_id, node: node, prev: after, next: nxt };
    s.next_cell_id += 1;
    after.next = cell;
    if let n: InlineCell = nxt {
        n.prev = cell;
    } else {
        s.tail = cell;
    }
    cell
}

function take_between(opener: InlineCell, closer: InlineCell) -> root.ast.Inline[] {
    let kids: root.ast.Inline[] = [];
    let c = opener.next;
    while (true) {
        if let cell: InlineCell = c {
            if (cell.id == closer.id) {
                break;
            }
            kids.push(cell.node);
            c = cell.next;
        } else {
            break;
        }
    }
    opener.next = closer;
    closer.prev = opener;
    kids
}

function take_after(s: Subject, cell: InlineCell) -> root.ast.Inline[] {
    let kids: root.ast.Inline[] = [];
    let c = cell.next;
    while (true) {
        if let cur: InlineCell = c {
            kids.push(cur.node);
            c = cur.next;
        } else {
            break;
        }
    }
    cell.next = null;
    s.tail = cell;
    kids
}

function push_node(s: Subject, node: root.ast.Inline) -> void {
    flush_text(s);
    let _ = append_cell(s, node);
}

function push_text(s: Subject, t: string) -> void {
    if (t.length() == 0) {
        return;
    }
    s.text_parts.push(t);
}

function flush_text(s: Subject) -> void {
    if (s.text_parts.length() == 0) {
        return;
    }
    let t = s.text_parts.join("");
    s.text_parts.clear();
    if (t.length() == 0) {
        return;
    }
    if let last: InlineCell = s.tail {
        if let lit: root.ast.Text = last.node {
            if (!s.last_protected) {
                lit.literal = `${lit.literal}${t}`;
                return;
            }
        }
    }
    let _ = append_cell(s, root.ast.Text { literal: t });
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
    let nodes = flatten_inlines(s);
    assert.equal(nodes.length(), 1);
    assert.equal(nodes.at(0), root.ast.Text { literal: "hello" })
}

test "push_text does not coalesce into a delimiter marker" {
    let refs: map<string, root.ast.LinkRef> = {};
    let nodes = parse_inlines("*a", refs);
    assert.equal(nodes.length(), 2);
    assert.equal(nodes.at(0), root.ast.Text { literal: "*" });
    assert.equal(nodes.at(1), root.ast.Text { literal: "a" })
}
