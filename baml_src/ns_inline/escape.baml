class BackslashRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "backslash"
        }

        function parse(self, context: InlineParseContext) -> bool throws never {
            let s = internal_inline_subject(context);
            if (peek(s) != "\\") {
                return false;
            }
            let _ = bump(s);
            let next = peek(s);
            if (next == "\n") {
                let _ = bump(s);
                push_node(s, root.ast.HardBreak {  });
                skip_spaces_tabs(s);
                return true;
            }
            if (next != null) {
                if (root.scan.is_ascii_punctuation(next)) {
                    let _ = bump(s);
                    push_text(s, next);
                    return true;
                }
            }
            push_text(s, "\\");
            true
        }
    }
}
