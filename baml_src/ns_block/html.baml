function strip_trailing_html_blanks(s: string) -> string {
    if (!s.ends_with("\n")) {
        return s;
    }
    let chars = s.chars();
    let end = chars.length();
    while (end > 0) {
        let i = end - 1;
        while (i >= 0 && (chars.at(i) == " " || chars.at(i) == "\t")) {
            i -= 1;
        }
        if (i >= 0 && chars.at(i) == "\n") {
            end = i;
        } else {
            break;
        }
    }
    `${s.slice(0, end)}\n`
}

class HtmlBlockOps {
    implements BlockOps {
        function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never {
            if (parser.blank && (open.html_type == 6 || open.html_type == 7)) {
                ContinueResult.Stop
            } else {
                ContinueResult.Ok
            }
        }

        function finalize(self, parser: Parser, open: Open) -> void throws never {
            let _ = parser;
            if let h: root.ast.HtmlBlock = open.ast {
                h.literal
                    = if (open.html_type >= 1 && open.html_type <= 5) {
                        strip_trailing_html_blanks(content_text(open))
                    } else {
                        content_text(open)
                    };
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

function open_html_block(html_type: int) -> Open {
    let o = make_open(
        OpenKind.HtmlBlock,
        HtmlBlockOps {  },
        root.ast.HtmlBlock { literal: "", last_line_blank: false },
    );
    o.html_type = html_type;
    o
}

function scan_html_tag_name(chars: string[], start: int) -> int? {
    if (!root.scan.is_ascii_letter_char(chars.at(start))) {
        return null;
    }
    let i = start + 1;
    while (root.scan.is_tag_name_char(chars.at(i))) {
        i += 1;
    }
    i
}

function tag_name_from_chars(chars: string[], start: int, end: int) -> string {
    let parts: string[] = [];
    let i = start;
    while (i < end) {
        parts.push(chars.at(i) ?? "");
        i += 1;
    }
    parts.join("")
}

function is_block_html_tag(name: string) -> bool {
    match (name.to_lower_case()) {
        "address"
            | "article"
            | "aside"
            | "base"
            | "basefont"
            | "blockquote"
            | "body"
            | "caption"
            | "center"
            | "col"
            | "colgroup"
            | "dd"
            | "details"
            | "dialog"
            | "dir"
            | "div"
            | "dl"
            | "dt"
            | "fieldset"
            | "figcaption"
            | "figure"
            | "footer"
            | "form"
            | "frame"
            | "frameset"
            | "h1"
            | "h2"
            | "h3"
            | "h4"
            | "h5"
            | "h6"
            | "head"
            | "header"
            | "hr"
            | "html"
            | "iframe"
            | "legend"
            | "li"
            | "link"
            | "main"
            | "menu"
            | "menuitem"
            | "nav"
            | "noframes"
            | "ol"
            | "optgroup"
            | "option"
            | "p"
            | "param"
            | "search"
            | "section"
            | "summary"
            | "table"
            | "tbody"
            | "td"
            | "tfoot"
            | "th"
            | "thead"
            | "title"
            | "tr"
            | "track"
            | "ul" =>
        {
            true
        },
        _ => false,
    }
}

function skip_space_tab(chars: string[], i: int) -> int {
    while (chars.at(i) == " " || chars.at(i) == "\t") {
        i += 1;
    }
    i
}

function parse_unquoted_attr_value(chars: string[], i: int) -> int? {
    let start = i;
    while (i < chars.length()) {
        let c = chars.at(i) ?? "";
        let code = c.code_point_at(0) ?? 0;
        if (c == "\"" || c == "'" || c == "=" || c == "<" || c == ">" || c == "`" || code <= 0x20) {
            break;
        }
        i += 1;
    }
    if (i == start) {
        null
    } else {
        i
    }
}

function parse_quoted_attr_value(chars: string[], i: int, quote: string) -> int? {
    if (chars.at(i) != quote) {
        return null;
    }
    i += 1;
    while (i < chars.length()) {
        if (chars.at(i) == quote) {
            return i + 1;
        }
        i += 1;
    }
    null
}

function parse_attr_value(chars: string[], i: int) -> int? {
    let q = chars.at(i);
    if (q == "\"" || q == "'") {
        parse_quoted_attr_value(chars, i, q ?? "\"")
    } else {
        parse_unquoted_attr_value(chars, i)
    }
}

function parse_attribute(chars: string[], i: int) -> int? {
    let j = skip_space_tab(chars, i);
    if (j == i) {
        return null;
    }
    if (!root.scan.is_attr_name_start(chars.at(j))) {
        return null;
    }
    j += 1;
    while (root.scan.is_attr_name_char(chars.at(j))) {
        j += 1;
    }
    let k = skip_space_tab(chars, j);
    if (chars.at(k) == "=") {
        k = skip_space_tab(chars, k + 1);
        let v = parse_attr_value(chars, k);
        if (v == null) {
            return null;
        }
        v
    } else {
        j
    }
}

function parse_open_tag(chars: string[], i: int) -> int? {
    if (chars.at(i) != "<") {
        return null;
    }
    let name_end = scan_html_tag_name(chars, i + 1);
    if (name_end == null) {
        return null;
    }
    let j = name_end;
    while (true) {
        let next = parse_attribute(chars, j);
        if (next == null) {
            break;
        }
        j = next;
    }
    j = skip_space_tab(chars, j);
    if (chars.at(j) == "/") {
        j += 1;
    }
    if (chars.at(j) == ">") {
        j + 1
    } else {
        null
    }
}

function parse_close_tag(chars: string[], i: int) -> int? {
    if (chars.at(i) != "<" || chars.at(i + 1) != "/") {
        return null;
    }
    let name_end = scan_html_tag_name(chars, i + 2);
    if (name_end == null) {
        return null;
    }
    let j = skip_space_tab(chars, name_end);
    if (chars.at(j) == ">") {
        j + 1
    } else {
        null
    }
}

function rest_only_space_tab(chars: string[], i: int) -> bool {
    while (i < chars.length()) {
        let c = chars.at(i);
        if (c != " " && c != "\t") {
            return false;
        }
        i += 1;
    }
    true
}

function ascii_starts_with_ci(chars: string[], start: int, prefix: string) -> bool {
    let p = prefix.chars();
    let n = p.length();
    if (start + n > chars.length()) {
        return false;
    }
    let i = 0;
    while (i < n) {
        let ca = chars.at(start + i)?.code_point_at(0) ?? 0;
        let cb = p.at(i)?.code_point_at(0) ?? 0;
        if (ca >= 65 && ca <= 90) {
            ca += 32;
        }
        if (cb >= 65 && cb <= 90) {
            cb += 32;
        }
        if (ca != cb) {
            return false;
        }
        i += 1;
    }
    true
}

function chars_match(chars: string[], start: int, literal: string) -> bool {
    let lit = literal.chars();
    let n = lit.length();
    if (start + n > chars.length()) {
        return false;
    }
    let i = 0;
    while (i < n) {
        if (chars.at(start + i) != lit.at(i)) {
            return false;
        }
        i += 1;
    }
    true
}

function type7_open_tag_ok(chars: string[], start: int) -> bool {
    let name_end = scan_html_tag_name(chars, start + 1);
    if (name_end == null) {
        return true;
    }
    let n = tag_name_from_chars(chars, start + 1, name_end).to_lower_case();
    n != "script" && n != "pre" && n != "style" && n != "textarea"
}

function html_block_type(chars: string[], start: int, allow_type7: bool) -> int? {
    if (chars.at(start) != "<") {
        return null;
    }
    if (
        ascii_starts_with_ci(chars, start, "<script")
            || ascii_starts_with_ci(chars, start, "<pre")
            || ascii_starts_with_ci(chars, start, "<style")
            || ascii_starts_with_ci(chars, start, "<textarea")
    ) {
        let name_end = scan_html_tag_name(chars, start + 1);
        if (name_end != null) {
            let n = tag_name_from_chars(chars, start + 1, name_end).to_lower_case();
            if (n == "script" || n == "pre" || n == "style" || n == "textarea") {
                let after = chars.at(name_end);
                if (after == null || after == " " || after == "\t" || after == ">") {
                    return 1;
                }
            }
        }
    }
    if (chars_match(chars, start, "<!--")) {
        return 2;
    }
    if (chars_match(chars, start, "<?")) {
        return 3;
    }
    if (chars_match(chars, start, "<!") && root.scan.is_ascii_letter_char(chars.at(start + 2))) {
        return 4;
    }
    if (chars_match(chars, start, "<![CDATA[")) {
        return 5;
    }
    let i = start + 1;
    if (chars.at(start + 1) == "/") {
        i = start + 2;
    }
    let name_end = scan_html_tag_name(chars, i);
    if (name_end != null) {
        if (is_block_html_tag(tag_name_from_chars(chars, i, name_end))) {
            let after = chars.at(name_end);
            if (after == null || after == " " || after == "\t" || after == ">") {
                return 6;
            }
            if (after == "/" && chars.at(name_end + 1) == ">") {
                return 6;
            }
        }
    }
    if (allow_type7) {
        let end = parse_open_tag(chars, start);
        let opened = end != null;
        if (end == null) {
            end = parse_close_tag(chars, start);
        }
        if (end != null) {
            if (rest_only_space_tab(chars, end) && (!opened || type7_open_tag_ok(chars, start))) {
                return 7;
            }
        }
    }
    null
}

function html_block_closes(html_type: int, line: string) -> bool {
    let lower = line.to_lower_case();
    if (html_type == 1) {
        lower.includes("</script>")
            || lower.includes("</pre>")
            || lower.includes("</style>")
            || lower.includes("</textarea>")
    } else if (html_type == 2) {
        line.includes("-->")
    } else if (html_type == 3) {
        line.includes("?>")
    } else if (html_type == 4) {
        line.includes(">")
    } else if (html_type == 5) {
        line.includes("]]>")
    } else {
        false
    }
}

function maybe_close_html_block(parser: Parser) -> void {
    let t = parser.tip();
    if (t.type_name == OpenKind.HtmlBlock && t.html_type >= 1 && t.html_type <= 5) {
        if (
            html_block_closes(t.html_type, parser.scan.line.slice(parser.scan.pos, parser.scan.line.length()))
        ) {
            parser.finalize_tip();
        }
    }
}

class HtmlBlockStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "html_block"
        }

        function triggers(self) -> string[] throws never {
            ["<"]
        }

        function allow_indented(self) -> bool throws never {
            false
        }

        function try_open(self, context: BlockStartContext) -> StartMatch throws never {
            let parser = internal_block_parser(context);
            if (parser.indented) {
                return StartMatch.None;
            }
            if (parser.scan.chars.at(parser.next_nonspace) != "<") {
                return StartMatch.None;
            }
            let allow_type7 = parser.last_matched().type_name != OpenKind.Paragraph
                && !(
                    !parser.all_closed
                        && !parser.blank
                        && parser.tip().type_name == OpenKind.Paragraph
                );
            let html_type = html_block_type(parser.scan.chars, parser.next_nonspace, allow_type7);
            if (html_type == null) {
                return StartMatch.None;
            }
            parser.close_unmatched();
            parser.push_child(open_html_block(html_type));
            StartMatch.Leaf
        }
    }
}

test "html block type 6 until blank line" {
    assert.equal(root.to_html("<div>\n*foo*\n\n*bar*\n"), "<div>\n*foo*\n<p><em>bar</em></p>\n")
}

test "html comment block" {
    assert.equal(
        root.to_html("<!-- Foo\n\nbar\n   baz -->\nokay\n"),
        "<!-- Foo\n\nbar\n   baz -->\n<p>okay</p>\n",
    )
}

test "html block type 7 does not interrupt a paragraph" {
    assert.equal(
        root.to_html("Foo\n<a href=\"bar\">\nbaz\n"),
        "<p>Foo\n<a href=\"bar\">\nbaz</p>\n",
    )
}

test "html block spec" {
    assert.equal(root.spec.spec_failures("HTML blocks"), [])
}

test "html type 7 excludes script pre style textarea open tags" {
    assert.equal(root.to_html("<script/>\n"), "<p><script/></p>\n");
    assert.equal(root.to_html("<pre/>\n"), "<p><pre/></p>\n")
}

test "unclosed html comment drops trailing blank lines" {
    assert.equal(root.to_html("<!-- foo\n\n\n"), "<!-- foo\n")
}
