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
            push_node(s, root.ast.CodeSpan { literal: strip_code_span_spaces(content) });
            true
        }
    }
}

function code_span_has_non_space(s: string) -> bool {
    let i = 0;
    while (i < s.length()) {
        if (s.at(i) != " ") {
            return true;
        }
        i += 1;
    }
    false
}

function strip_code_span_spaces(content: string) -> string {
    if (content.starts_with(" ") && content.ends_with(" ") && code_span_has_non_space(content)) {
        content.slice(1, content.length() - 1)
    } else {
        content
    }
}

test "code span strips only ascii spaces not unicode whitespace" {
    let nbsp = string.from_code_points([0x00A0]) catch (e) {
        baml.errors.InvalidArgument => ""
    };
    let prefix = "` ";
    let suffix = " `\n";
    assert.equal(root.to_html(`${prefix}${nbsp}${suffix}`), `<p><code>${nbsp}</code></p>\n`)
}

test "code span of only ascii spaces keeps them" {
    assert.equal(root.to_html("`  `\n"), "<p><code>  </code></p>\n")
}
