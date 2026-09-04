interface BlockStart {
  function name(self) -> string throws never
  function try_open(self, line: string) -> bool throws never
}

interface InlineRule {
  function name(self) -> string throws never
}

class ParseOptions {
    block_starts: BlockStart[],
    inline_rules: InlineRule[],
}

function commonmark_options() -> ParseOptions {
    ParseOptions { block_starts: [], inline_rules: [] }
}

function parse_document(markdown: string, options: ParseOptions) -> root.ast.Document {
    let _ = options;
    let _ = markdown;
    let refs: map<string, root.ast.LinkRef> = {};
    root.ast.Document { children: [], refs: refs }
}
