function is_unicode_punct(ch: string) -> bool {
    if (root.scan.is_ascii_punctuation(ch)) {
        true
    } else if (ch.is_whitespace() || ch.is_alphanumeric() || ch.is_control() || ch.is_alphabetic()) {
        false
    } else if (!ch.is_graphic()) {
        false
    } else {
        let code = ch.code_point_at(0) ?? 0;
        !root.scan.is_unicode_mark(code) && !root.scan.is_unicode_format(code)
    }
}

function flanking_char(chars: string[], i: int) -> string {
    if (i < 0 || i >= chars.length()) {
        "\n"
    } else {
        chars.at(i) ?? "\n"
    }
}

class DelimScan {
    count: int,
    can_open: bool,
    can_close: bool,
}

function scan_delims(s: Subject, marker: string) -> DelimScan {
    let start = s.scan.pos;
    let n = 0;
    while (peek(s) == marker) {
        let _ = bump(s);
        n += 1;
    }
    advance_to(s, start);
    let before = flanking_char(s.scan.chars, start - 1);
    let after = flanking_char(s.scan.chars, start + n);
    let after_ws = root.scan.is_unicode_whitespace(after);
    let before_ws = root.scan.is_unicode_whitespace(before);
    let after_punct = is_unicode_punct(after);
    let before_punct = is_unicode_punct(before);
    let left = !after_ws && (!after_punct || before_ws || before_punct);
    let right = !before_ws && (!before_punct || after_ws || after_punct);
    if (marker == "_") {
        DelimScan {
            count: n,
            can_open: left && (!right || before_punct),
            can_close: right && (!left || after_punct),
        }
    } else {
        DelimScan { count: n, can_open: left, can_close: right }
    }
}

function trim_delim_text(cell: InlineCell, use_delims: int) -> void {
    if let t: root.ast.Text = cell.node {
        t.literal = t.literal.slice(0, t.literal.length() - use_delims);
    }
}

function wrap_between(s: Subject, opener: Delimiter, closer: Delimiter, use_delims: int) -> void {
    trim_delim_text(opener.cell, use_delims);
    trim_delim_text(closer.cell, use_delims);
    let kids = take_between(opener.cell, closer.cell);
    let wrapped: root.ast.Inline = if (use_delims == 1) {
        root.ast.Emph { children: kids }
    } else {
        root.ast.Strong { children: kids }
    };
    let _ = insert_after(s, opener.cell, wrapped);
    opener.count -= use_delims;
    closer.count -= use_delims;
    if (opener.count == 0) {
        unlink_cell(s, opener.cell);
    }
    if (closer.count == 0) {
        unlink_cell(s, closer.cell);
    }
}

function openers_bottom_index(kind: string, closer: Delimiter) -> int {
    let base = if (kind == "_") {
        0
    } else {
        6
    };
    let extra = if (closer.can_open) {
        3
    } else {
        0
    };
    base + extra + (closer.orig_count % 3)
}

function unlink_between(s: Subject, opener: Delimiter, closer: Delimiter) -> void {
    let delim = closer.prev;
    while (true) {
        if let d: Delimiter = delim {
            if (d.ord == opener.ord) {
                break;
            }
            let prev = d.prev;
            unlink_delim(s, d);
            delim = prev;
        } else {
            break;
        }
    }
}

function insert_emph(s: Subject, opener: Delimiter, closer: Delimiter) -> Delimiter? {
    let use_delims = if (closer.count >= 2 && opener.count >= 2) {
        2
    } else {
        1
    };
    wrap_between(s, opener, closer, use_delims);
    unlink_between(s, opener, closer);
    let next_closer: Delimiter? = closer;
    if (opener.count == 0) {
        unlink_delim(s, opener);
    }
    if (closer.count == 0) {
        next_closer = closer.next;
        unlink_delim(s, closer);
    }
    next_closer
}

function process_emphasis(s: Subject, stack_bottom: int) -> void {
    flush_text(s);
    let openers_bottom: int[] = [];
    let i = 0;
    while (i < 12) {
        openers_bottom.push(stack_bottom);
        i += 1;
    }
    let closer = s.delimiters.at(stack_bottom);
    while (true) {
        if let c: Delimiter = closer {
            if ((c.kind == "*" || c.kind == "_") && c.can_close) {
                let obi = openers_bottom_index(c.kind, c);
                let opener = c.prev;
                let found: Delimiter? = null;
                while (true) {
                    if let o: Delimiter = opener {
                        if (o.ord < stack_bottom || o.ord < openers_bottom[obi]) {
                            break;
                        }
                        let odd_match = (c.can_open || o.can_close)
                            && c.orig_count % 3 != 0
                            && (o.orig_count + c.orig_count) % 3 == 0;
                        if (o.kind == c.kind && o.can_open && !odd_match) {
                            found = o;
                            break;
                        }
                        opener = o.prev;
                    } else {
                        break;
                    }
                }
                if let o: Delimiter = found {
                    closer = insert_emph(s, o, c);
                } else {
                    openers_bottom[obi] = c.ord;
                    closer = c.next;
                    if (!c.can_open) {
                        unlink_delim(s, c);
                    }
                }
            } else {
                closer = c.next;
            }
        } else {
            break;
        }
    }
    let d = s.delim_tail;
    while (true) {
        if let cur: Delimiter = d {
            if (cur.ord < stack_bottom) {
                break;
            }
            let prev = cur.prev;
            unlink_delim(s, cur);
            d = prev;
        } else {
            break;
        }
    }
    while (s.delimiters.length() > stack_bottom) {
        let _ = s.delimiters.pop();
    }
}

class EmphasisRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "emphasis"
        }

        function parse(self, s: Subject) -> bool throws never {
            let ch = peek(s);
            if (ch != "*" && ch != "_") {
                return false;
            }
            let info = scan_delims(s, ch ?? "*");
            let start = s.scan.pos;
            let n = 0;
            while (n < info.count) {
                let _ = bump(s);
                n += 1;
            }
            let lit = s.scan.line.slice(start, start + info.count);
            let node = root.ast.Text { literal: lit };
            push_node(s, node);
            if (info.can_open || info.can_close) {
                push_delim(
                    s,
                    Delimiter {
                        kind: ch ?? "*",
                        count: info.count,
                        orig_count: info.count,
                        can_open: info.can_open,
                        can_close: info.can_close,
                        cell: s.tail ?? dummy_cell(),
                        ord: 0,
                        prev: null,
                        next: null,
                    },
                );
                s.last_protected = true;
            }
            true
        }
    }
}

test "zero-width space is not unicode punctuation for emphasis" {
    let zwsp = string.from_code_points([0x200B]) catch (e) {
        baml.errors.InvalidArgument => ""
    };
    assert.equal(root.to_html(`a*${zwsp}b*\n`), `<p>a<em>${zwsp}b</em></p>\n`)
}
