function skip_spnl_sub(s: Subject) -> void {
    skip_spaces_tabs(s);
    if (peek(s) == "\n") {
        let _ = bump(s);
        skip_spaces_tabs(s);
    }
}

function whitespace_before(s: Subject) -> bool {
    let p = s.scan.pos;
    if (p == 0) {
        false
    } else {
        let c = s.scan.line.at(p - 1) ?? "";
        c == " " || c == "\t" || c == "\n"
    }
}

function try_inline_link(s: Subject) -> root.ast.LinkRef? {
    if (peek(s) != "(") {
        return null;
    }
    let save = s.scan.pos;
    let _ = bump(s);
    skip_spnl_sub(s);
    let dest = "";
    if (peek(s) == ")") {
        dest = "";
    } else {
        let d = root.block.parse_link_destination(s.scan.line, s.scan.pos, table = s.entities);
        if (d == null) {
            advance_to(s, save);
            return null;
        }
        dest = d.value;
        advance_to(s, d.end);
    }
    skip_spnl_sub(s);
    let title: string? = null;
    if (whitespace_before(s) || peek(s) == ")") {
        if (peek(s) != ")") {
            let t = root.block.parse_link_title(s.scan.line, s.scan.pos, table = s.entities);
            if let tv: root.block.ScanPiece = t {
                title = tv.value;
                advance_to(s, tv.end);
                skip_spnl_sub(s);
            }
        }
    }
    if (peek(s) != ")") {
        advance_to(s, save);
        return null;
    }
    let _ = bump(s);
    root.ast.LinkRef { destination: dest, title: title }
}

function try_reference_link(s: Subject, opener: Bracket, closer_pos: int) -> root.ast.LinkRef? {
    let save = s.scan.pos;
    let label_end = root.block.parse_link_label(s.scan.line, s.scan.pos);
    let n = 0;
    if (label_end != null) {
        n = label_end - save;
    }
    let reflabel = "";
    if (n > 2) {
        reflabel = s.scan.line.slice(save, label_end ?? save);
        advance_to(s, label_end ?? save);
    } else if (!opener.bracket_after) {
        reflabel = s.scan.line.slice(opener.opener_pos, closer_pos);
        if (label_end != null) {
            advance_to(s, label_end);
        }
    }
    if (label_end == null) {
        advance_to(s, save);
    }
    if (reflabel.length() == 0) {
        return null;
    }
    let norm = root.block.normalize_reference(reflabel);
    s.refs.get(norm)
}

function deactivate_link_openers(s: Subject) -> void {
    for (let b in s.brackets) {
        if (!b.image) {
            b.active = false;
        }
    }
}

function wrap_link(s: Subject, opener: Bracket, dest: string, title: string?, image: bool) -> void {
    process_emphasis(s, opener.delim_bottom);
    let kids = take_after(s, opener.cell);
    let wrapped: root.ast.Inline = if (image) {
        root.ast.Image { destination: dest, title: title, children: kids }
    } else {
        root.ast.Link { destination: dest, title: title, children: kids }
    };
    let _ = insert_after(s, opener.cell, wrapped);
    unlink_cell(s, opener.cell);
    let _ = s.brackets.pop();
    if (!image) {
        deactivate_link_openers(s);
    }
}

class BangRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "bang"
        }

        function parse(self, s: Subject) -> bool throws never {
            if (peek(s) != "!") {
                return false;
            }
            if (peek_at(s, 1) != "[") {
                return false;
            }
            let _ = bump(s);
            let opener_pos = s.scan.pos;
            let _ = bump(s);
            if (s.brackets.length() > 0) {
                let prev = s.brackets[s.brackets.length() - 1];
                prev.bracket_after = true;
            }
            push_node(s, root.ast.Text { literal: "![" });
            s.brackets.push(
                Bracket {
                    image: true,
                    active: true,
                    bracket_after: false,
                    cell: s.tail ?? dummy_cell(),
                    opener_pos: opener_pos,
                    delim_bottom: s.delimiters.length(),
                },
            );
            s.last_protected = true;
            true
        }
    }
}

class OpenBracketRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "open_bracket"
        }

        function parse(self, s: Subject) -> bool throws never {
            if (peek(s) != "[") {
                return false;
            }
            let opener_pos = s.scan.pos;
            let _ = bump(s);
            if (s.brackets.length() > 0) {
                let prev = s.brackets[s.brackets.length() - 1];
                prev.bracket_after = true;
            }
            push_node(s, root.ast.Text { literal: "[" });
            s.brackets.push(
                Bracket {
                    image: false,
                    active: true,
                    bracket_after: false,
                    cell: s.tail ?? dummy_cell(),
                    opener_pos: opener_pos,
                    delim_bottom: s.delimiters.length(),
                },
            );
            s.last_protected = true;
            true
        }
    }
}

class CloseBracketRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "close_bracket"
        }

        function parse(self, s: Subject) -> bool throws never {
            if (peek(s) != "]") {
                return false;
            }
            let _ = bump(s);
            let closer_pos = s.scan.pos;
            if (s.brackets.length() == 0) {
                push_text(s, "]");
                return true;
            }
            let opener = s.brackets[s.brackets.length() - 1];
            if (!opener.active) {
                let _ = s.brackets.pop();
                push_text(s, "]");
                return true;
            }
            let save = s.scan.pos;
            let found = try_inline_link(s);
            if (found == null) {
                found = try_reference_link(s, opener, closer_pos);
            }
            if let link: root.ast.LinkRef = found {
                wrap_link(s, opener, link.destination, link.title, opener.image);
                true
            } else {
                let _ = s.brackets.pop();
                advance_to(s, save);
                push_text(s, "]");
                true
            }
        }
    }
}

function image_plain(node: root.ast.Inline) -> string {
    match (node) {
        let t: root.ast.Text => t.literal,
        let _sb: root.ast.SoftBreak => "\n",
        let _hb: root.ast.HardBreak => "\n",
        let c: root.ast.CodeSpan => c.literal,
        let e: root.ast.Emph => {
            e.children
                .map((n) -> {
                    image_plain(n)
                })
                .join("")
        },
        let st: root.ast.Strong => {
            st.children
                .map((n) -> {
                    image_plain(n)
                })
                .join("")
        },
        let l: root.ast.Link => {
            l.children
                .map((n) -> {
                    image_plain(n)
                })
                .join("")
        },
        let im: root.ast.Image => {
            im.children
                .map((n) -> {
                    image_plain(n)
                })
                .join("")
        },
        let _h: root.ast.HtmlInline => "",
        let a: root.ast.Autolink => a.destination,
    }
}
