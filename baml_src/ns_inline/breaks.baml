function trim_trailing_spaces(s: Subject) -> int {
    if (s.inlines.length() == 0) {
        return 0;
    }
    let last = s.inlines[s.inlines.length() - 1];
    if (last is root.ast.Text) {
        let n = 0;
        while (last.literal.ends_with(" ")) {
            last.literal = last.literal.slice(0, last.literal.length() - 1);
            n += 1;
        }
        if (last.literal.length() == 0) {
            let _ = s.inlines.pop();
        }
        n
    } else {
        0
    }
}

class NewlineRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "newline"
        }

        function parse(self, s: Subject) -> bool throws never {
            if (peek(s) != "\n") {
                return false;
            }
            let spaces = trim_trailing_spaces(s);
            let _ = bump(s);
            if (spaces >= 2) {
                push_node(s, root.ast.HardBreak {  });
            } else {
                push_node(s, root.ast.SoftBreak {  });
            }
            skip_spaces_tabs(s);
            true
        }
    }
}
