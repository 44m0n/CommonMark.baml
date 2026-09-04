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

function shift_inline_indices(s: Subject, from: int, delta: int) -> void {
    for (let d in s.delimiters) {
        if (d.inline_index >= from) {
            d.inline_index += delta;
        }
    }
    for (let b in s.brackets) {
        if (b.inline_index >= from) {
            b.inline_index += delta;
        }
    }
}

function replace_inlines(s: Subject, start: int, count: int, repl: root.ast.Inline[]) -> void {
    s.inlines.splice(start, count, repl) catch (e) {
        baml.errors.InvalidArgument => {
            baml.sys.panic("inline splice out of range")
        }
    }
}

function replace_delimiters(s: Subject, start: int, count: int, repl: Delimiter[]) -> void {
    s.delimiters.splice(start, count, repl) catch (e) {
        baml.errors.InvalidArgument => {
            baml.sys.panic("delimiter splice out of range")
        }
    }
}

function remove_inline_at(s: Subject, idx: int) -> void {
    let _ = s.inlines.remove_at(idx);
    shift_inline_indices(s, idx + 1, 0 - 1)
}

function wrap_between(s: Subject, opener: Delimiter, closer: Delimiter, use_delims: int) -> void {
    let oi = opener.inline_index;
    let ci = closer.inline_index;
    let opener_node = s.inlines[oi];
    let closer_node = s.inlines[ci];
    if (opener_node is root.ast.Text) {
        opener_node.literal
            = opener_node.literal.slice(0, opener_node.literal.length() - use_delims);
    }
    if (closer_node is root.ast.Text) {
        closer_node.literal
            = closer_node.literal.slice(0, closer_node.literal.length() - use_delims);
    }
    let kids = s.inlines.slice(oi + 1, ci);
    let wrapped: root.ast.Inline = if (use_delims == 1) {
        root.ast.Emph { children: kids }
    } else {
        root.ast.Strong { children: kids }
    };
    let removed = ci - oi - 1;
    replace_inlines(s, oi + 1, removed, [wrapped]);
    shift_inline_indices(s, ci, 1 - removed);
    opener.count -= use_delims;
    closer.count -= use_delims;
    if (opener.count == 0) {
        remove_inline_at(s, opener.inline_index);
    }
    if (closer.count == 0) {
        remove_inline_at(s, closer.inline_index);
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
                        inline_index: s.inlines.length() - 1,
                    },
                );
                s.last_protected = true;
            }
            true
        }
    }
}
