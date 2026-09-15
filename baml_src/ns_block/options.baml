enum StartMatch {
    None,
    Container,
    Leaf,
}

enum ContinueResult {
    Ok,
    Stop,
    Done,
}

// Stable extension boundary for block-start rules. Parser stays internal.
interface BlockStartContext {
    function is_indented(self) -> bool throws never;
    function line_chars(self) -> string[] throws never;
    function next_nonspace(self) -> int throws never;
    function emit_thematic_break(self) -> void throws never;
    function consume_rest(self) -> void throws never;
}

interface BlockStart {
    function name(self) -> string throws never;
    function try_open(self, context: BlockStartContext) -> StartMatch throws never;
    function triggers(self) -> string[] throws never {
        let none: string[] = [];
        none
    }
    function allow_indented(self) -> bool throws never {
        false
    }
}

class ParserBlockStartContext {
    parser: Parser,
    implements BlockStartContext {
        function is_indented(self) -> bool throws never {
            self.parser.indented
        }

        function line_chars(self) -> string[] throws never {
            self.parser.scan.chars
        }

        function next_nonspace(self) -> int throws never {
            self.parser.next_nonspace
        }

        function emit_thematic_break(self) -> void throws never {
            self.parser.close_unmatched();
            self.parser.push_child(open_thematic_break())
        }

        function consume_rest(self) -> void throws never {
            self.parser.advance_offset(
                self.parser.scan.chars.length() - self.parser.scan.pos,
                false,
            )
        }
    }
}

function block_start_context(parser: Parser) -> BlockStartContext {
    ParserBlockStartContext { parser: parser }
}

function internal_block_parser(context: BlockStartContext) -> Parser {
    if let internal: ParserBlockStartContext = context {
        internal.parser
    } else {
        baml.sys.panic("BlockStartContext was not created by this parser")
    }
}

interface BlockOps {
    function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never;
    function finalize(self, parser: Parser, open: Open) -> void throws never;
    function can_contain(self, child: OpenKind) -> bool throws never;
    function accepts_lines(self) -> bool throws never;
    function is_interruptible(self) -> bool throws never;
    function allows_lazy(self) -> bool throws never;
}

class ParseOptions {
    block_starts: BlockStart[],
    inline_rules: root.inline.InlineParseRule[],
}

function commonmark_options() -> ParseOptions {
    ParseOptions {
        block_starts: [
            BlockQuoteStart {  },
            AtxHeadingStart {  },
            FencedCodeStart {  },
            HtmlBlockStart {  },
            SetextHeadingStart {  },
            ThematicBreakStart {  },
            ListItemStart {  },
            IndentedCodeStart {  },
        ],
        inline_rules: root.inline.commonmark_inline_rules(),
    }
}

class PercentBreakStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "percent_break"
        }

        function triggers(self) -> string[] throws never {
            ["%"]
        }

        function allow_indented(self) -> bool throws never {
            false
        }

        function try_open(self, context: BlockStartContext) -> StartMatch throws never {
            if (context.is_indented()) {
                return StartMatch.None;
            }
            if (!looks_like_percent_break(context.line_chars(), context.next_nonspace())) {
                return StartMatch.None;
            }
            context.emit_thematic_break();
            context.consume_rest();
            StartMatch.Leaf
        }
    }
}

function looks_like_percent_break(chars: string[], start: int) -> bool {
    if (chars.at(start) != "%") {
        return false;
    }
    let count = 0;
    let i = start;
    while (i < chars.length()) {
        let c = chars.at(i) ?? "";
        if (c == "%") {
            count += 1;
        } else if (c != " " && c != "\t") {
            return false;
        }
        i += 1;
    }
    count >= 3
}

test "custom block start dispatches on triggers not name" {
    let start = PercentBreakStart {  };
    assert.is_true(start.name() != "indented_code");
    let options = commonmark_options();
    options.block_starts.push(start);
    assert.equal(root.to_html("%%%\n", options = options), "<hr />\n");
    assert.equal(root.to_html("%foo\n", options = options), "<p>%foo</p>\n");
    assert.equal(root.to_html("%%%\n"), "<p>%%%</p>\n")
}
