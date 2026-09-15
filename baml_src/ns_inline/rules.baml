interface InlineParseRule {
    function name(self) -> string throws never;
    function parse(self, context: InlineParseContext) -> bool throws never;
    function triggers(self) -> string[] throws never {
        let none: string[] = [];
        none
    }
}

function apply_inline_rules(s: Subject, rules: InlineParseRule[]) -> bool {
    for (let rule in rules) {
        if (rule.parse(inline_parse_context(s))) {
            return true;
        }
    }
    false
}

function run_inline_parse(s: Subject, rules: InlineParseRule[]) -> void {
    let extra = extra_trigger_chars(rules);
    while (!is_eof(s)) {
        let ch = peek(s) ?? "";
        if (is_inline_special(ch) || (extra.length() > 0 && extra.includes(ch))) {
            if (!apply_inline_rules(s, rules)) {
                let start = pos(s);
                let _ = bump(s);
                push_text(s, s.scan.line.slice(start, pos(s)));
            }
        } else {
            consume_plain_text(s, extra);
        }
    }
    let _ = trim_trailing_spaces(s);
    flush_text(s);
    process_emphasis(s, 0);
}

function extra_trigger_chars(rules: InlineParseRule[]) -> string {
    let out = "";
    for (let rule in rules) {
        for (let t in rule.triggers()) {
            let ch = t.at(0) ?? "";
            if (ch.length() > 0 && !out.includes(ch)) {
                out = `${out}${ch}`;
            }
        }
    }
    out
}

function commonmark_inline_rules() -> InlineParseRule[] {
    [
        BackslashRule {  },
        NewlineRule {  },
        CodeSpanRule {  },
        EntityRule {  },
        AutolinkRule {  },
        HtmlInlineRule {  },
        BangRule {  },
        OpenBracketRule {  },
        CloseBracketRule {  },
        EmphasisRule {  },
    ]
}
