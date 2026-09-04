interface InlineParseRule {
    function name(self) -> string throws never
    function parse(self, subject: Subject) -> bool throws never
}

function commonmark_inline_rules() -> InlineParseRule[] {
    []
}
