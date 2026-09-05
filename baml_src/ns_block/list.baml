function is_digit_char(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        c.is_ascii_numeric()
    }
}

function rest_is_blank(chars: string[], start: int) -> bool {
    let i = start;
    while (i < chars.length()) {
        let c = chars.at(i);
        if (c != " " && c != "\t") {
            return false;
        }
        i += 1;
    }
    true
}

function parse_list_marker(parser: Parser) -> ListData? {
    if (parser.indent >= 4) {
        return null;
    }
    let chars = parser.scan.chars;
    let i = parser.next_nonspace;
    let c = chars.at(i);
    let interrupts = parser.last_matched().type_name == OpenKind.Paragraph;
    let marker_len = 0;
    let kind: root.ast.ListKind = root.ast.ListKind.Bullet;
    let start = 1;
    let delimiter = "";
    let bullet = "";

    if (c == "*" || c == "-" || c == "+") {
        i += 1;
        marker_len = 1;
        bullet = c ?? "";
        kind = root.ast.ListKind.Bullet;
        let next = chars.at(i);
        if (next != null && next != " " && next != "\t") {
            return null;
        }
        if (interrupts && rest_is_blank(chars, i)) {
            return null;
        }
    } else if (is_digit_char(c)) {
        start = 0;
        let digits = 0;
        while (digits < 9 && is_digit_char(chars.at(i))) {
            start = start * 10 + (chars.at(i)?.code_point_at(0) ?? 48) - 48;
            i += 1;
            digits += 1;
        }
        if (interrupts && start != 1) {
            return null;
        }
        let delim = chars.at(i);
        if (delim != "." && delim != ")") {
            return null;
        }
        i += 1;
        marker_len = i - parser.next_nonspace;
        delimiter = delim ?? "";
        kind = root.ast.ListKind.Ordered;
        let next = chars.at(i);
        if (next != null && next != " " && next != "\t") {
            return null;
        }
        if (interrupts && rest_is_blank(chars, i)) {
            return null;
        }
    } else {
        return null;
    }

    let data = ListData {
        kind: kind,
        start: start,
        delimiter: delimiter,
        bullet_char: bullet,
        padding: 0,
        marker_offset: parser.indent,
    };
    parser.advance_next_nonspace();
    parser.advance_offset(marker_len, true);
    let spaces_start_col = parser.scan.column;
    let spaces_start_pos = parser.scan.pos;
    let saved_partial = parser.partially_consumed_tab;
    while (parser.scan.column - spaces_start_col < 5) {
        let nextc = parser.scan.chars.at(parser.scan.pos);
        if (nextc != " " && nextc != "\t") {
            break;
        }
        parser.advance_offset(1, true);
    }
    let blank_item = parser.scan.chars.at(parser.scan.pos) == null;
    let spaces_after = parser.scan.column - spaces_start_col;
    if (spaces_after >= 5 || spaces_after < 1 || blank_item) {
        data.padding = marker_len + 1;
        parser.scan.column = spaces_start_col;
        parser.scan.pos = spaces_start_pos;
        parser.partially_consumed_tab = saved_partial;
        let sp = parser.scan.chars.at(parser.scan.pos);
        if (sp == " " || sp == "\t") {
            parser.advance_offset(1, true);
        }
    } else {
        data.padding = marker_len + spaces_after;
    }
    data
}

function lists_match(a: ListData?, b: ListData) -> bool {
    if (a == null) {
        false
    } else {
        a.kind == b.kind && a.delimiter == b.delimiter && a.bullet_char == b.bullet_char
    }
}

function open_list(data: ListData) -> Open {
    let items: root.ast.ListItem[] = [];
    let o = make_open(
        OpenKind.List,
        ListOps {  },
        root.ast.List {
            kind: data.kind,
            start: data.start,
            tight: true,
            delimiter: data.delimiter,
            bullet_char: data.bullet_char,
            children: items,
            last_line_blank: false,
        },
    );
    o.list_data = data;
    o
}

function open_list_item(data: ListData) -> Open {
    let children: root.ast.Block[] = [];
    Open {
        type_name: OpenKind.Item,
        ops: ItemOps {  },
        ast: root.ast.ListItem { children: children, last_line_blank: false },
        children: children,
        string_content: "",
        content_parts: [],
        is_fenced: false,
        fence_char: "",
        fence_length: 0,
        fence_offset: 0,
        last_line_blank: false,
        html_type: 0,
        list_data: data,
    }
}

class ListOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            let _ = parser;
            let _ = open;
            ContinueResult.Ok
        }

        function finalize(self, parser: Parser, open: Open) -> void throws never {
            let _ = parser;
            if let list: root.ast.List = open.ast {
                list.tight = compute_list_tight(list);
            }
        }

        function can_contain(self, child: OpenKind) -> bool throws never {
            child == OpenKind.Item
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

function item_continue(parser: Parser, open: Open) -> ContinueResult {
    let data = open.list_data;
    if (data == null) {
        return ContinueResult.Stop;
    }
    let needed = data.marker_offset + data.padding;
    if (parser.blank) {
        if (open.children.length() == 0) {
            ContinueResult.Stop
        } else {
            parser.advance_next_nonspace();
            ContinueResult.Ok
        }
    } else if (parser.indent >= needed) {
        parser.advance_offset(needed, true);
        ContinueResult.Ok
    } else {
        ContinueResult.Stop
    }
}

class ItemOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            item_continue(parser, open)
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

class ListItemStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "list_item"
        }

        function triggers(self) -> string[] throws never {
            ["*", "-", "+", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        }

        function allow_indented(self) -> bool throws never {
            false
        }

        function try_open(self, parser: Parser) -> StartMatch throws never {
            let container = parser.last_matched();
            if (parser.indented && container.type_name != OpenKind.List) {
                return StartMatch.None;
            }
            let data = parse_list_marker(parser);
            if (data == null) {
                return StartMatch.None;
            }
            parser.close_unmatched();
            if (parser.tip().type_name != OpenKind.List || !lists_match(parser.tip().list_data, data)) {
                parser.push_child(open_list(data));
            }
            parser.push_child(open_list_item(data));
            StartMatch.Container
        }
    }
}

function copy_last_line_blank(open: Open) -> void {
    if let p: root.ast.Paragraph = open.ast {
        p.last_line_blank = p.last_line_blank || open.last_line_blank;
    } else if let h: root.ast.Heading = open.ast {
        h.last_line_blank = h.last_line_blank || open.last_line_blank;
    } else if let tb: root.ast.ThematicBreak = open.ast {
        tb.last_line_blank = tb.last_line_blank || open.last_line_blank;
    } else if let c: root.ast.CodeBlock = open.ast {
        c.last_line_blank = c.last_line_blank || open.last_line_blank;
    } else if let html: root.ast.HtmlBlock = open.ast {
        html.last_line_blank = html.last_line_blank || open.last_line_blank;
    } else if let q: root.ast.BlockQuote = open.ast {
        q.last_line_blank = q.last_line_blank || open.last_line_blank;
    } else if let l: root.ast.List = open.ast {
        l.last_line_blank = l.last_line_blank || open.last_line_blank;
    } else if let item: root.ast.ListItem = open.ast {
        item.last_line_blank = item.last_line_blank || open.last_line_blank;
    }
}

function set_block_last_line_blank(b: root.ast.Block, value: bool) -> void {
    match (b) {
        let p: root.ast.Paragraph => {
            p.last_line_blank = value
        },
        let h: root.ast.Heading => {
            h.last_line_blank = value
        },
        let tb: root.ast.ThematicBreak => {
            tb.last_line_blank = value
        },
        let c: root.ast.CodeBlock => {
            c.last_line_blank = value
        },
        let html: root.ast.HtmlBlock => {
            html.last_line_blank = value
        },
        let q: root.ast.BlockQuote => {
            q.last_line_blank = value
        },
        let l: root.ast.List => {
            l.last_line_blank = value
        },
    }
}

function mark_last_child_blank(container: Open) -> void {
    if let list: root.ast.List = container.ast {
        let last = list.children.at(list.children.length() - 1);
        if (last != null) {
            last.last_line_blank = true;
        }
    } else if let item: root.ast.ListItem = container.ast {
        let last = item.children.at(item.children.length() - 1);
        if (last != null) {
            set_block_last_line_blank(last, true);
        }
    } else {
        let last = container.children.at(container.children.length() - 1);
        if (last != null) {
            set_block_last_line_blank(last, true);
        }
    }
}

function record_last_line_blank(parser: Parser, container: Open, container_index: int) -> void {
    if (parser.blank && (container.children.length() > 0 || container.ast is root.ast.List)) {
        mark_last_child_blank(container);
    }
    let ctype = container.type_name;
    let empty_item = ctype == OpenKind.Item && container.children.length() == 0;
    let last_line_blank = parser.blank
        && ctype != OpenKind.BlockQuote
        && ctype != OpenKind.Heading
        && ctype != OpenKind.ThematicBreak
        && !(ctype == OpenKind.CodeBlock && container.is_fenced)
        && !empty_item;
    container.last_line_blank = last_line_blank;
    let i = 0;
    while (i < container_index) {
        parser.stack[i].last_line_blank = false;
        i += 1;
    }
}

function block_last_line_blank(b: root.ast.Block) -> bool {
    match (b) {
        let p: root.ast.Paragraph => p.last_line_blank,
        let h: root.ast.Heading => h.last_line_blank,
        let tb: root.ast.ThematicBreak => tb.last_line_blank,
        let c: root.ast.CodeBlock => c.last_line_blank,
        let html: root.ast.HtmlBlock => html.last_line_blank,
        let q: root.ast.BlockQuote => q.last_line_blank,
        let l: root.ast.List => l.last_line_blank,
    }
}

function ends_with_blank_line(b: root.ast.Block) -> bool {
    let cur: root.ast.Block? = b;
    while (true) {
        if let node: root.ast.Block = cur {
            if let l: root.ast.List = node {
                let last = l.children.at(l.children.length() - 1);
                if let item: root.ast.ListItem = last {
                    let last_b = item.children.at(item.children.length() - 1);
                    if let child: root.ast.Block = last_b {
                        cur = child;
                    } else {
                        return item.last_line_blank;
                    }
                } else {
                    return l.last_line_blank;
                }
            } else {
                return block_last_line_blank(node);
            }
        } else {
            return false;
        }
    }
}

function compute_list_tight(list: root.ast.List) -> bool {
    let i = 0;
    while (i < list.children.length()) {
        let item = list.children[i];
        if (item.last_line_blank && i + 1 < list.children.length()) {
            return false;
        }
        let j = 0;
        while (j < item.children.length()) {
            let sub = item.children[j];
            if (
                (i + 1 < list.children.length() || j + 1 < item.children.length())
                    && ends_with_blank_line(sub)
            ) {
                return false;
            }
            j += 1;
        }
        i += 1;
    }
    true
}

test "bullet list items" {
    assert.equal(root.to_html("- foo\n- bar\n"), "<ul>\n<li>foo</li>\n<li>bar</li>\n</ul>\n")
}

test "ordered list start attribute" {
    assert.equal(root.to_html("10. foo\n"), "<ol start=\"10\">\n<li>foo</li>\n</ol>\n")
}

test "list cannot interrupt paragraph unless ordered start is 1" {
    assert.equal(
        root.to_html("The number of windows in my house is\n14.  The number of doors is 6.\n"),
        "<p>The number of windows in my house is\n14.  The number of doors is 6.</p>\n",
    );
    assert.equal(
        root.to_html("The number of windows in my house is\n1.  The number of doors is 6.\n"),
        "<p>The number of windows in my house is</p>\n<ol>\n<li>The number of doors is 6.</li>\n</ol>\n",
    )
}

test "nested lists" {
    assert.equal(
        root.to_html("- foo\n  - bar\n    - baz\n"),
        "<ul>\n<li>foo\n<ul>\n<li>bar\n<ul>\n<li>baz</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n",
    )
}

test "loose list from blank line between items" {
    assert.equal(
        root.to_html("- a\n- b\n\n- c\n"),
        "<ul>\n<li>\n<p>a</p>\n</li>\n<li>\n<p>b</p>\n</li>\n<li>\n<p>c</p>\n</li>\n</ul>\n",
    )
}

test "tight list item starting with emphasis is not preceded by a newline" {
    assert.equal(
        root.to_html("- **Bold** item\n"),
        "<ul>\n<li><strong>Bold</strong> item</li>\n</ul>\n",
    )
}

test "tight list item starting with a link is not preceded by a newline" {
    assert.equal(root.to_html("- [x](y)\n"), "<ul>\n<li><a href=\"y\">x</a></li>\n</ul>\n")
}

test "tight list item starting with a code span is not preceded by a newline" {
    assert.equal(root.to_html("- `code` x\n"), "<ul>\n<li><code>code</code> x</li>\n</ul>\n")
}

test "list item spec" {
    assert.equal(root.spec.spec_failures("List items"), [])
}

test "lists spec" {
    assert.equal(root.spec.spec_failures("Lists"), [])
}

test "empty list item cannot continue after a blank line" {
    assert.equal(root.to_html("-\n \n foo\n"), "<ul>\n<li></li>\n</ul>\n<p>foo</p>\n")
}

function nested_bullet_markdown(depth: int, text: string) -> string {
    let lines: string[] = [];
    let i = 0;
    while (i < depth) {
        lines.push(`${"  ".repeat(i)}- ${text}`);
        i += 1;
    }
    lines.join("\n")
}

function nested_bullet_html(depth: int, text: string) -> string {
    if (depth <= 0) {
        return "";
    }
    let inner = `<li>${text}</li>\n`;
    let i = depth - 1;
    while (i > 0) {
        inner = `<li>${text}\n<ul>\n${inner}</ul>\n</li>\n`;
        i -= 1;
    }
    `<ul>\n${inner}</ul>\n`
}

test "tight nested lists without extra blanks" {
    assert.equal(
        root.to_html("- a\n  - b\n    - c\n      - d\n"),
        "<ul>\n<li>a\n<ul>\n<li>b\n<ul>\n<li>c\n<ul>\n<li>d</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n",
    )
}

test "deeply nested lists then blank lines close the outer list" {
    let depth = 40;
    let md = `${nested_bullet_markdown(depth, "x")}\n${"\n".repeat(20)}para\n`;
    assert.equal(root.to_html(md), `${nested_bullet_html(depth, "x")}<p>para</p>\n`)
}
