function is_unicode_punct(ch: string) -> bool {
    if (root.scan.is_ascii_punctuation(ch)) {
        true
    } else if (ch.is_whitespace() || ch.is_alphanumeric() || ch.is_control()) {
        false
    } else {
        true
    }
}

function flanking_char(line: string, i: int) -> string {
    if (i < 0 || i >= line.length()) {
        "\n"
    } else {
        line.at(i) ?? "\n"
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
    let before = flanking_char(s.scan.line, start - 1);
    let after = flanking_char(s.scan.line, start + n);
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

function replace_delimiters(s: Subject, start: int, count: int, repl: Delimiter[]) -> void {
    s.delimiters.splice(start, count, repl) catch (e) {
        baml.errors.InvalidArgument => {
            baml.sys.panic("delimiter splice out of range")
        }
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

function process_emphasis(s: Subject, stack_bottom: int) -> void {
    let openers_bottom: int[] = [];
    let i = 0;
    while (i < 12) {
        openers_bottom.push(stack_bottom - 1);
        i += 1;
    }
    let ci = stack_bottom;
    while (ci < s.delimiters.length()) {
        let closer = s.delimiters[ci];
        if (closer.kind != "*" && closer.kind != "_") {
            ci += 1;
            continue;
        }
        if (!closer.can_close) {
            ci += 1;
            continue;
        }
        let obi = openers_bottom_index(closer.kind, closer);
        let oi = ci - 1;
        let opener_found = false;
        let opener_i = -1;
        while (oi >= stack_bottom && oi > openers_bottom[obi]) {
            let opener = s.delimiters[oi];
            let odd_match = (closer.can_open || opener.can_close)
                && closer.orig_count % 3 != 0
                && (opener.orig_count + closer.orig_count) % 3 == 0;
            if (opener.kind == closer.kind && opener.can_open && !odd_match) {
                opener_found = true;
                opener_i = oi;
                break;
            }
            oi -= 1;
        }
        if (!opener_found) {
            openers_bottom[obi] = ci - 1;
            if (!closer.can_open) {
                let _ = s.delimiters.remove_at(ci);
            } else {
                ci += 1;
            }
        } else {
            let opener = s.delimiters[opener_i];
            let use_delims = if (closer.count >= 2 && opener.count >= 2) {
                2
            } else {
                1
            };
            wrap_between(s, opener, closer, use_delims);
            replace_delimiters(s, opener_i + 1, ci - opener_i - 1, []);
            let closer_i = opener_i + 1;
            if (opener.count == 0) {
                let _ = s.delimiters.remove_at(opener_i);
                closer_i -= 1;
            }
            if (closer.count == 0) {
                let _ = s.delimiters.remove_at(closer_i);
                ci = closer_i;
            } else {
                ci = closer_i;
            }
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
                s.delimiters.push(
                    Delimiter {
                        kind: ch ?? "*",
                        count: info.count,
                        orig_count: info.count,
                        active: true,
                        can_open: info.can_open,
                        can_close: info.can_close,
                        cell: s.tail ?? dummy_cell(),
                    },
                );
                s.last_protected = true;
            }
            true
        }
    }
}
