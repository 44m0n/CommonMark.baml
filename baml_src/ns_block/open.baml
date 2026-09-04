class ListData {
    kind: root.ast.ListKind,
    start: int,
    delimiter: string,
    bullet_char: string,
    padding: int,
    marker_offset: int,
}

enum OpenKind {
    Document,
    Paragraph,
    Heading,
    ThematicBreak,
    CodeBlock,
    HtmlBlock,
    BlockQuote,
    List,
    Item,
}

class Open {
    type_name: OpenKind,
    ops: BlockOps,
    ast: (root.ast.Block | root.ast.ListItem)?,
    children: root.ast.Block[],
    string_content: string,
    content_parts: string[],
    is_fenced: bool,
    fence_char: string,
    fence_length: int,
    fence_offset: int,
    last_line_blank: bool,
    html_type: int,
    list_data: ListData?,
}

function make_open(
    type_name: OpenKind,
    ops: BlockOps,
    ast: (root.ast.Block | root.ast.ListItem)?,
) -> Open {
    let children: root.ast.Block[] = [];
    Open {
        type_name: type_name,
        ops: ops,
        ast: ast,
        children: children,
        string_content: "",
        content_parts: [],
        is_fenced: false,
        fence_char: "",
        fence_length: 0,
        fence_offset: 0,
        last_line_blank: false,
        html_type: 0,
        list_data: null,
    }
}

function make_document_open(doc: root.ast.Document) -> Open {
    Open {
        type_name: OpenKind.Document,
        ops: DocumentOps {  },
        ast: null,
        children: doc.children,
        string_content: "",
        content_parts: [],
        is_fenced: false,
        fence_char: "",
        fence_length: 0,
        fence_offset: 0,
        last_line_blank: false,
        html_type: 0,
        list_data: null,
    }
}

function open_paragraph() -> Open {
    make_open(
        OpenKind.Paragraph,
        ParagraphOps {  },
        root.ast.Paragraph { raw: "", children: [], last_line_blank: false },
    )
}

function open_thematic_break() -> Open {
    make_open(
        OpenKind.ThematicBreak,
        ThematicBreakOps {  },
        root.ast.ThematicBreak { last_line_blank: false },
    )
}

function open_heading(level: int) -> Open {
    make_open(
        OpenKind.Heading,
        HeadingOps {  },
        root.ast.Heading {
            level: level,
            setext: false,
            raw: "",
            children: [],
            last_line_blank: false,
        },
    )
}

function open_indented_code() -> Open {
    make_open(
        OpenKind.CodeBlock,
        CodeBlockOps {  },
        root.ast.CodeBlock { fenced: false, info: "", literal: "", last_line_blank: false },
    )
}

function open_fenced_code(fence_char: string, fence_length: int, fence_offset: int) -> Open {
    let o = make_open(
        OpenKind.CodeBlock,
        CodeBlockOps {  },
        root.ast.CodeBlock { fenced: true, info: "", literal: "", last_line_blank: false },
    );
    o.is_fenced = true;
    o.fence_char = fence_char;
    o.fence_length = fence_length;
    o.fence_offset = fence_offset;
    o
}

function open_block_quote() -> Open {
    let children: root.ast.Block[] = [];
    Open {
        type_name: OpenKind.BlockQuote,
        ops: BlockQuoteOps {  },
        ast: root.ast.BlockQuote { children: children, last_line_blank: false },
        children: children,
        string_content: "",
        content_parts: [],
        is_fenced: false,
        fence_char: "",
        fence_length: 0,
        fence_offset: 0,
        last_line_blank: false,
        html_type: 0,
        list_data: null,
    }
}

function content_text(open: Open) -> string {
    if (open.content_parts.length() == 0) {
        open.string_content
    } else if (open.string_content.length() == 0) {
        open.content_parts.join("")
    } else {
        `${open.string_content}${open.content_parts.join("")}`
    }
}

function replace_content(open: Open, text: string) -> void {
    open.string_content = text;
    if (open.content_parts.length() > 0) {
        let empty: string[] = [];
        open.content_parts = empty;
    }
}

function append_content(open: Open, chunk: string) -> void {
    open.content_parts.push(chunk)
}

function strip_final_newline(s: string) -> string {
    if (s.ends_with("\n")) {
        s.slice(0, s.length() - 1)
    } else {
        s
    }
}

class DocumentOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            let _ = parser;
            let _ = open;
            ContinueResult.Ok
        }

        function finalize(self, parser: Parser, open: Open) -> void throws never {
            let _ = parser;
            let _ = open;
        }

        function can_contain(self, child: OpenKind) -> bool throws never {
            child != OpenKind.Item
        }

        function accepts_lines(self) -> bool throws never {
            false
        }

        function is_interruptible(self) -> bool throws never {
            false
        }

        function allows_lazy(self) -> bool throws never {
            false
        }
    }
}

class BlockQuoteOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            let _ = open;
            if (!parser.indented && parser.scan.line.at(parser.next_nonspace) == ">") {
                consume_quote_marker(parser);
                ContinueResult.Ok
            } else {
                ContinueResult.Stop
            }
        }

        function finalize(self, parser: Parser, open: Open) -> void throws never {
            let _ = parser;
            let _ = open;
        }

        function can_contain(self, child: OpenKind) -> bool throws never {
            child != OpenKind.Item
        }

        function accepts_lines(self) -> bool throws never {
            false
        }

        function is_interruptible(self) -> bool throws never {
            false
        }

        function allows_lazy(self) -> bool throws never {
            false
        }
    }
}

class ParagraphOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            let _ = open;
            if (parser.blank) {
                ContinueResult.Stop
            } else {
                ContinueResult.Ok
            }
        }

        function finalize(self, parser: Parser, open: Open) -> void throws never {
            let remaining = consume_link_reference_definitions(content_text(open), parser.document.refs, table = parser.entities);
            if (is_blank_text(strip_final_newline(remaining))) {
                unlink_block(parser, open.ast);
                return;
            }
            let raw = strip_final_newline(remaining);
            if let p: root.ast.Paragraph = open.ast {
                p.raw = raw;
            }
        }

        function can_contain(self, child: OpenKind) -> bool throws never {
            let _ = child;
            false
        }

        function accepts_lines(self) -> bool throws never {
            true
        }

        function is_interruptible(self) -> bool throws never {
            true
        }

        function allows_lazy(self) -> bool throws never {
            true
        }
    }
}

class ThematicBreakOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            let _ = parser;
            let _ = open;
            ContinueResult.Stop
        }

        function finalize(self, parser: Parser, open: Open) -> void throws never {
            let _ = parser;
            let _ = open;
        }

        function can_contain(self, child: OpenKind) -> bool throws never {
            let _ = child;
            false
        }

        function accepts_lines(self) -> bool throws never {
            false
        }

        function is_interruptible(self) -> bool throws never {
            false
        }

        function allows_lazy(self) -> bool throws never {
            false
        }
    }
}

class HeadingOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            let _ = parser;
            let _ = open;
            ContinueResult.Stop
        }

        function finalize(self, parser: Parser, open: Open) -> void throws never {
            let raw = root.scan.trim_space_tab(strip_final_newline(content_text(open)));
            if let h: root.ast.Heading = open.ast {
                h.raw = raw;
            }
        }

        function can_contain(self, child: OpenKind) -> bool throws never {
            let _ = child;
            false
        }

        function accepts_lines(self) -> bool throws never {
            false
        }

        function is_interruptible(self) -> bool throws never {
            false
        }

        function allows_lazy(self) -> bool throws never {
            false
        }
    }
}

function is_blank_text(s: string) -> bool {
    let i = 0;
    while (i < s.length()) {
        let c = s.at(i);
        if (c != " " && c != "\t") {
            return false;
        }
        i += 1;
    }
    true
}

function indented_code_literal(content: string) -> string {
    let lines = content.split("\n");
    while (lines.length() > 0) {
        let last = lines[lines.length() - 1];
        if (is_blank_text(last)) {
            let _ = lines.pop();
        } else {
            break;
        }
    }
    `${lines.join("\n")}\n`
}

class CodeBlockOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            if (open.is_fenced) {
                if (is_closing_fence(parser, open)) {
                    parser.finalize_tip();
                    return ContinueResult.Done;
                }
                skip_fence_indent(parser, open.fence_offset);
                return ContinueResult.Ok;
            }
            if (parser.indent >= 4) {
                parser.advance_offset(4, true);
                ContinueResult.Ok
            } else if (parser.blank) {
                parser.advance_next_nonspace();
                ContinueResult.Ok
            } else {
                ContinueResult.Stop
            }
        }

        function finalize(self, parser: Parser, open: Open) -> void throws never {
            if let c: root.ast.CodeBlock = open.ast {
                if (open.is_fenced) {
                    let parsed = fenced_info_and_literal(content_text(open), table = parser.entities);
                    c.fenced = true;
                    c.info = parsed.info;
                    c.literal = parsed.literal;
                } else {
                    c.literal = indented_code_literal(content_text(open));
                }
            }
        }

        function can_contain(self, child: OpenKind) -> bool throws never {
            let _ = child;
            false
        }

        function accepts_lines(self) -> bool throws never {
            true
        }

        function is_interruptible(self) -> bool throws never {
            false
        }

        function allows_lazy(self) -> bool throws never {
            false
        }
    }
}
