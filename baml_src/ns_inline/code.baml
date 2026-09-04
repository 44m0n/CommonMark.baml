class CodeSpanRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "code_span"
        }

        function parse(self, s: Subject) -> bool throws never {
            if (peek(s) != "`") {
                return false;
            }
            let n = 0;
            while (peek(s) == "`") {
                let _ = bump(s);
                n += 1;
            }
            let line = s.scan.line;
            let i = s.scan.pos;
            let found = -1;
            while (i < line.length()) {
                if (line.at(i) == "`") {
                    let j = i;
                    while (line.at(j) == "`") {
                        j += 1;
                    }
                    if (j - i == n) {
                        found = i;
                        break;
                    }
                    i = j;
                } else {
                    i += 1;
                }
            }
            if (found < 0) {
                push_text(s, "`".repeat(n));
                return true;
            }
            let content = line.slice(s.scan.pos, found).replace_all("\n", " ");
            advance_to(s, found + n);
            if (content.starts_with(" ") && content.ends_with(" ") && content.trim().length() > 0) {
                content = content.slice(1, content.length() - 1);
            }
            push_node(s, root.ast.CodeSpan { literal: content });
            true
        }
    }
}
