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

interface BlockStart {
  function name(self) -> string throws never
  function try_open(self, parser: Parser) -> StartMatch throws never
  function triggers(self) -> string[] throws never {
    let none: string[] = [];
    none
  }
  function allow_indented(self) -> bool throws never {
    false
  }
}

interface BlockOps {
  function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never
  function finalize(self, parser: Parser, open: Open) -> void throws never
  function can_contain(self, child: OpenKind) -> bool throws never
  function accepts_lines(self) -> bool throws never
  function is_interruptible(self) -> bool throws never
  function allows_lazy(self) -> bool throws never
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

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (parser.indented) {
                return StartMatch.None;
            }
            if (!looks_like_percent_break(parser.scan.chars, parser.next_nonspace)) {
                return StartMatch.None;
            }
            parser.close_unmatched();
            parser.push_child(open_thematic_break());
            parser.advance_offset(parser.scan.chars.length() - parser.scan.pos, false);
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
