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
}

interface BlockOps {
  function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never
  function finalize(self, parser: Parser, open: Open) -> void throws never
  function can_contain(self, child_name: string) -> bool throws never
  function accepts_lines(self) -> bool throws never
  function is_interruptible(self) -> bool throws never
  function allows_lazy(self) -> bool throws never
}

interface InlineRule {
  function name(self) -> string throws never
}

class ParseOptions {
    block_starts: BlockStart[],
    inline_rules: InlineRule[],
}

function commonmark_options() -> ParseOptions {
    ParseOptions {
        block_starts: [
            BlockQuoteStart {  },
            AtxHeadingStart {  },
            FencedCodeStart {  },
            SetextHeadingStart {  },
            ThematicBreakStart {  },
            IndentedCodeStart {  },
        ],
        inline_rules: [],
    }
}
