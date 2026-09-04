class Open {
    type_name: string,
    ops: BlockOps,
    ast: root.ast.Block?,
    children: root.ast.Block[],
    string_content: string,
    is_fenced: bool,
    fence_char: string,
    fence_length: int,
    fence_offset: int,
}

function make_open(type_name: string, ops: BlockOps, ast: root.ast.Block?) -> Open {
    let children: root.ast.Block[] = [];
    Open {
        type_name: type_name,
        ops: ops,
        ast: ast,
        children: children,
        string_content: "",
        is_fenced: false,
        fence_char: "",
        fence_length: 0,
        fence_offset: 0,
    }
}

function make_document_open(doc: root.ast.Document) -> Open {
    Open {
        type_name: "document",
        ops: DocumentOps {  },
        ast: null,
        children: doc.children,
        string_content: "",
        is_fenced: false,
        fence_char: "",
        fence_length: 0,
        fence_offset: 0,
    }
}

function open_paragraph() -> Open {
    make_open("paragraph", ParagraphOps {  }, root.ast.Paragraph { raw: "", children: [] })
}

function open_thematic_break() -> Open {
    make_open("thematic_break", ThematicBreakOps {  }, root.ast.ThematicBreak {  })
}

function open_heading(level: int) -> Open {
    make_open(
        "heading",
        HeadingOps {  },
        root.ast.Heading { level: level, setext: false, raw: "", children: [] },
    )
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

        function can_contain(self, child_name: string) -> bool throws never {
            child_name != "item"
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
            let raw = strip_final_newline(open.string_content);
            if let p: root.ast.Paragraph = open.ast {
                p.raw = raw;
                p.children = root.inline.parse_inlines(raw, parser.document.refs);
            }
        }

        function can_contain(self, child_name: string) -> bool throws never {
            let _ = child_name;
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

        function can_contain(self, child_name: string) -> bool throws never {
            let _ = child_name;
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
            let raw = open.string_content.trim();
            if let h: root.ast.Heading = open.ast {
                h.raw = raw;
                h.children = root.inline.parse_inlines(raw, parser.document.refs);
            }
        }

        function can_contain(self, child_name: string) -> bool throws never {
            let _ = child_name;
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
