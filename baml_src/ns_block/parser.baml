class Parser {
    options: ParseOptions,
    document: root.ast.Document,
    entities: map<string, string>,
    stack: Open[],
    scan: root.scan.LineScan,
    next_nonspace: int,
    next_nonspace_column: int,
    indent: int,
    indented: bool,
    blank: bool,
    partially_consumed_tab: bool,
    all_closed: bool,
    last_matched_index: int,
    blank_continue_index: int,

    function tip(self) -> Open {
        self.stack[self.stack.length() - 1]
    }

    function last_matched(self) -> Open {
        self.stack[self.last_matched_index]
    }

    function find_next_nonspace(self) -> void {
        let i = self.scan.pos;
        let cols = self.scan.column;
        let chars = self.scan.chars;
        while (true) {
            let c = chars.at(i);
            if (c == " ") {
                i += 1;
                cols += 1;
            } else if (c == "\t") {
                i += 1;
                cols += root.scan.tab_spaces(cols);
            } else {
                self.blank = c == null;
                self.next_nonspace = i;
                self.next_nonspace_column = cols;
                self.indent = cols - self.scan.column;
                self.indented = self.indent >= 4;
                break;
            }
        }
    }

    function advance_next_nonspace(self) -> void {
        self.scan.pos = self.next_nonspace;
        self.scan.column = self.next_nonspace_column;
        self.partially_consumed_tab = false;
    }

    function advance_offset(self, count: int, columns: bool) -> void {
        let chars = self.scan.chars;
        let remaining = count;
        while (remaining > 0) {
            let c = chars.at(self.scan.pos);
            if (c == null) {
                break;
            }
            if (c == "\t") {
                let chars_to_tab = root.scan.tab_spaces(self.scan.column);
                if (columns) {
                    self.partially_consumed_tab = chars_to_tab > remaining;
                    let chars_to_advance = if (chars_to_tab > remaining) {
                        remaining
                    } else {
                        chars_to_tab
                    };
                    self.scan.column += chars_to_advance;
                    if (!self.partially_consumed_tab) {
                        self.scan.pos += 1;
                    }
                    remaining = remaining - chars_to_advance;
                } else {
                    self.partially_consumed_tab = false;
                    self.scan.column += chars_to_tab;
                    self.scan.pos += 1;
                    remaining -= 1;
                }
            } else {
                self.partially_consumed_tab = false;
                self.scan.pos += 1;
                self.scan.column += 1;
                remaining -= 1;
            }
        }
    }

    function add_line(self) -> void {
        let t = self.tip();
        if (self.partially_consumed_tab) {
            self.scan.pos += 1;
            let chars_to_tab = root.scan.tab_spaces(self.scan.column);
            append_content(t, " ".repeat(chars_to_tab));
        }
        let rest = self.scan.line.slice(self.scan.pos, self.scan.line.length());
        append_content(t, `${rest}\n`);
    }

    function finalize_tip(self) -> void {
        let node = self.stack.pop();
        if (node != null) {
            copy_last_line_blank(node);
            node.ops.finalize(self, node);
            refresh_blank_continue(self);
        }
    }

    function close_unmatched(self) -> void {
        if (!self.all_closed) {
            while (self.stack.length() - 1 > self.last_matched_index) {
                self.finalize_tip();
            }
            self.all_closed = true;
        }
    }

    function push_child(self, child: Open) -> void {
        while (!self.tip().ops.can_contain(child.type_name)) {
            self.finalize_tip();
        }
        if let item: root.ast.ListItem = child.ast {
            if let list: root.ast.List = self.tip().ast {
                let _ = list.children.push(item);
            }
        } else if let b: root.ast.Block = child.ast {
            let _ = self.tip().children.push(b);
        }
        let _ = self.stack.push(child);
        refresh_blank_continue(self);
    }

    function incorporate_line(self, ln: string) -> void {
        self.scan = root.scan.line_scan(ln);
        self.blank = false;
        self.partially_consumed_tab = false;
        self.find_next_nonspace();
        if (self.blank) {
            incorporate_blank_line(self);
            return;
        }
        //# Continue currently open blocks from the document down
        let all_matched = true;
        self.last_matched_index = 0;
        let i = 1;
        while (i < self.stack.length()) {
            self.find_next_nonspace();
            let node = self.stack[i];
            let r = node.ops.continue_line(self, node);
            if (r == ContinueResult.Done) {
                return;
            }
            if (r == ContinueResult.Stop) {
                all_matched = false;
                self.last_matched_index = i - 1;
                break;
            }
            self.last_matched_index = i;
            i += 1;
        }
        self.all_closed = all_matched;

        let container = self.stack[self.last_matched_index];
        let container_index = self.last_matched_index;
        let matched_leaf = !container.ops.is_interruptible() && container.ops.accepts_lines();
        //# Try each registered block start on the remaining line
        while (!matched_leaf) {
            self.find_next_nonspace();
            let found = false;
            let ch = self.scan.chars.at(self.next_nonspace);
            for (let start in self.options.block_starts) {
                if (!block_start_could_match(start, self, ch)) {
                    continue;
                }
                let res = start.try_open(self);
                if (res == StartMatch.Container) {
                    container = self.tip();
                    container_index = self.stack.length() - 1;
                    found = true;
                    break;
                } else if (res == StartMatch.Leaf) {
                    container = self.tip();
                    container_index = self.stack.length() - 1;
                    matched_leaf = true;
                    found = true;
                    break;
                }
            }
            if (!found) {
                self.advance_next_nonspace();
                break;
            }
        }

        self.find_next_nonspace();
        record_last_line_blank(self, container, container_index);

        if (!self.all_closed && !self.blank && self.tip().ops.allows_lazy()) {
            self.add_line();
        } else {
            self.close_unmatched();
            let t = self.tip();
            if (t.ops.accepts_lines()) {
                self.add_line();
                maybe_close_html_block(self);
            } else if (self.scan.pos < self.scan.line.length() && !self.blank) {
                self.push_child(open_paragraph());
                self.advance_next_nonspace();
                self.add_line();
            }
        }
    }
}

function continues_on_blank(open: Open) -> bool {
    match (open.type_name) {
        OpenKind.Document => true,
        OpenKind.List => true,
        OpenKind.Item => open.children.length() > 0,
        OpenKind.CodeBlock => true,
        OpenKind.HtmlBlock => open.html_type != 6 && open.html_type != 7,
        _ => false,
    }
}

function refresh_blank_continue(parser: Parser) -> void {
    let i = 0;
    let last = 0;
    let n = parser.stack.length();
    while (i < n) {
        if (!continues_on_blank(parser.stack[i])) {
            break;
        }
        last = i;
        i += 1;
    }
    parser.blank_continue_index = last;
}

function incorporate_blank_line(parser: Parser) -> void {
    let n = parser.stack.length();
    let idx = parser.blank_continue_index;
    if (idx >= n) {
        idx = n - 1;
    }
    if (idx < 0) {
        idx = 0;
    }
    parser.last_matched_index = idx;
    parser.all_closed = idx == n - 1;
    let j = 1;
    while (j <= idx) {
        if (parser.stack[j].type_name == OpenKind.Item) {
            parser.advance_next_nonspace();
            break;
        }
        j += 1;
    }
    let matched = parser.stack[idx];
    if (matched.type_name == OpenKind.CodeBlock || matched.type_name == OpenKind.HtmlBlock) {
        let r = matched.ops.continue_line(parser, matched);
        if (r == ContinueResult.Done) {
            return;
        }
    }
    let container = parser.stack[idx];
    record_last_line_blank(parser, container, idx);
    parser.close_unmatched();
    let t = parser.tip();
    if (t.ops.accepts_lines()) {
        parser.add_line();
        maybe_close_html_block(parser);
    }
}

function block_start_could_match(start: BlockStart, parser: Parser, ch: string?) -> bool {
    if (parser.indented) {
        start.allow_indented()
    } else if (start.allow_indented() && start.triggers().length() == 0) {
        false
    } else {
        let trig = start.triggers();
        if (trig.length() == 0) {
            true
        } else if let c: string = ch {
            trig.includes(c)
        } else {
            false
        }
    }
}

function new_parser(
    options: ParseOptions,
    document: root.ast.Document,
    entities: map<string, string>,
) -> Parser {
    let stack: Open[] = [];
    Parser {
        options: options,
        document: document,
        entities: entities,
        stack: stack,
        scan: root.scan.line_scan(""),
        next_nonspace: 0,
        next_nonspace_column: 0,
        indent: 0,
        indented: false,
        blank: false,
        partially_consumed_tab: false,
        all_closed: true,
        last_matched_index: 0,
        blank_continue_index: 0,
    }
}

function parse_document(markdown: string, options: ParseOptions) -> root.ast.Document {
    let input = root.scan.preprocess(markdown);
    let refs: map<string, root.ast.LinkRef> = {};
    let entities = root.inline.load_named_entities();
    let document = root.ast.Document { children: [], refs: refs };
    let p = new_parser(options, document, entities = entities);
    let _ = p.stack.push(make_document_open(document));
    refresh_blank_continue(p);
    //# Grow the document from each input line
    for (let line in input.lines()) {
        p.incorporate_line(line);
    }
    while (p.stack.length() > 0) {
        p.finalize_tip();
    }
    parse_inlines_tree(document, entities = entities, options = options);
    document
}

function parse_inlines_tree(
    document: root.ast.Document,
    entities: map<string, string>,
    options: ParseOptions,
) -> void {
    let rules = options.inline_rules;
    let work: root.ast.Block[] = [];
    for (let b in document.children) {
        work.push(b);
    }
    while (work.length() > 0) {
        if let b: root.ast.Block = work.pop() {
            if let p: root.ast.Paragraph = b {
                p.children
                    = root.inline.parse_inlines(
                        p.raw,
                        document.refs,
                        entities = entities,
                        rules = rules,
                    );
            } else if let h: root.ast.Heading = b {
                h.children
                    = root.inline.parse_inlines(
                        h.raw,
                        document.refs,
                        entities = entities,
                        rules = rules,
                    );
            } else if let q: root.ast.BlockQuote = b {
                for (let c in q.children) {
                    work.push(c);
                }
            } else if let l: root.ast.List = b {
                for (let item in l.children) {
                    for (let c in item.children) {
                        work.push(c);
                    }
                }
            }
            clear_parser_fields(b);
        }
    }
}

function clear_parser_fields(b: root.ast.Block) -> void {
    match (b) {
        let p: root.ast.Paragraph => {
            p.raw = "";
            p.last_line_blank = false;
        },
        let h: root.ast.Heading => {
            h.raw = "";
            h.last_line_blank = false;
        },
        let tb: root.ast.ThematicBreak => {
            tb.last_line_blank = false;
        },
        let c: root.ast.CodeBlock => {
            c.last_line_blank = false;
        },
        let html: root.ast.HtmlBlock => {
            html.last_line_blank = false;
        },
        let q: root.ast.BlockQuote => {
            q.last_line_blank = false;
        },
        let l: root.ast.List => {
            l.last_line_blank = false;
            for (let item in l.children) {
                item.last_line_blank = false;
            }
        },
    }
}
