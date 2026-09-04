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
                h.html_type = open.html_type;
                h.literal = open.string_content;
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
            false
        }

        function allows_lazy(self) -> bool throws never {
            false
        }
    }
}

function open_html_block(html_type: int) -> Open {
    let o = make_open(
        "html_block",
        HtmlBlockOps {  },
        root.ast.HtmlBlock { html_type: html_type, literal: "", last_line_blank: false },
    );
    o.html_type = html_type;
    o
}

function is_ascii_letter_char(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        let code = c.code_point_at(0) ?? 0;
        (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
    }
}

function is_tag_name_char(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        c.is_ascii_alphanumeric() || c == "-"
    }
}

function is_attr_name_start(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        is_ascii_letter_char(c) || c == "_" || c == ":"
    }
}

function is_attr_name_char(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        is_attr_name_start(c) || c.is_ascii_numeric() || c == "." || c == "-"
    }
}

function html_block_tag_names() -> string[] {
    [
        "address",
        "article",
        "aside",
        "base",
        "basefont",
        "blockquote",
        "body",
        "caption",
        "center",
        "col",
        "colgroup",
        "dd",
        "details",
        "dialog",
        "dir",
        "div",
        "dl",
        "dt",
        "fieldset",
        "figcaption",
        "figure",
        "footer",
        "form",
        "frame",
        "frameset",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "head",
        "header",
        "hr",
        "html",
        "iframe",
        "legend",
        "li",
        "link",
        "main",
        "menu",
        "menuitem",
        "nav",
        "noframes",
        "ol",
        "optgroup",
        "option",
        "p",
        "param",
        "search",
        "section",
        "summary",
        "table",
        "tbody",
        "td",
        "tfoot",
        "th",
        "thead",
        "title",
        "tr",
        "track",
        "ul",
    ]
}

function read_html_tag_name(s: string, start: int) -> string? {
    if (!is_ascii_letter_char(s.at(start))) {
        return null;
    }
    let i = start + 1;
    while (is_tag_name_char(s.at(i))) {
        i += 1;
    }
    s.slice(start, i)
}

function is_block_html_tag(name: string) -> bool {
    let lower = name.to_lower_case();
    html_block_tag_names().includes(lower)
}

function skip_space_tab(s: string, i: int) -> int {
    while (s.at(i) == " " || s.at(i) == "\t") {
        i += 1;
    }
    i
}

function parse_unquoted_attr_value(s: string, i: int) -> int? {
    let start = i;
    while (i < s.length()) {
        let c = s.at(i) ?? "";
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

function parse_quoted_attr_value(s: string, i: int, quote: string) -> int? {
    if (s.at(i) != quote) {
        return null;
    }
    i += 1;
    while (i < s.length()) {
        if (s.at(i) == quote) {
            return i + 1;
        }
        i += 1;
    }
    null
}

function parse_attr_value(s: string, i: int) -> int? {
    let q = s.at(i);
    if (q == "\"" || q == "'") {
        parse_quoted_attr_value(s, i, q ?? "\"")
    } else {
        parse_unquoted_attr_value(s, i)
    }
}

function parse_attribute(s: string, i: int) -> int? {
    let j = skip_space_tab(s, i);
    if (j == i) {
        return null;
    }
    if (!is_attr_name_start(s.at(j))) {
        return null;
    }
    j += 1;
    while (is_attr_name_char(s.at(j))) {
        j += 1;
    }
    let k = skip_space_tab(s, j);
    if (s.at(k) == "=") {
        k = skip_space_tab(s, k + 1);
        let v = parse_attr_value(s, k);
        if (v == null) {
            return null;
        }
        v
    } else {
        j
    }
}

function parse_open_tag(s: string, i: int) -> int? {
    if (s.at(i) != "<") {
        return null;
    }
    let name = read_html_tag_name(s, i + 1);
    if (name == null) {
        return null;
    }
    let j = i + 1 + name.length();
    while (true) {
        let next = parse_attribute(s, j);
        if (next == null) {
            break;
        }
        j = next;
    }
    j = skip_space_tab(s, j);
    if (s.at(j) == "/") {
        j += 1;
    }
    if (s.at(j) == ">") {
        j + 1
    } else {
        null
    }
}

function parse_close_tag(s: string, i: int) -> int? {
    if (s.at(i) != "<" || s.at(i + 1) != "/") {
        return null;
    }
    let name = read_html_tag_name(s, i + 2);
    if (name == null) {
        return null;
    }
    let j = skip_space_tab(s, i + 2 + name.length());
    if (s.at(j) == ">") {
        j + 1
    } else {
        null
    }
}

function rest_only_space_tab(s: string, i: int) -> bool {
    while (i < s.length()) {
        let c = s.at(i);
        if (c != " " && c != "\t") {
            return false;
        }
        i += 1;
    }
    true
}

function html_block_type(s: string, allow_type7: bool) -> int? {
    if (s.at(0) != "<") {
        return null;
    }
    let lower = s.to_lower_case();
    if (
        lower.starts_with("<script")
            || lower.starts_with("<pre")
            || lower.starts_with("<style")
            || lower.starts_with("<textarea")
    ) {
        let name = read_html_tag_name(s, 1) ?? "";
        let n = name.to_lower_case();
        if (n == "script" || n == "pre" || n == "style" || n == "textarea") {
            let after = s.at(1 + name.length());
            if (after == null || after == " " || after == "\t" || after == ">") {
                return 1;
            }
        }
    }
    if (s.starts_with("<!--")) {
        return 2;
    }
    if (s.starts_with("<?")) {
        return 3;
    }
    if (s.starts_with("<!") && is_ascii_letter_char(s.at(2))) {
        return 4;
    }
    if (s.starts_with("<![CDATA[")) {
        return 5;
    }
    let i = 1;
    if (s.at(1) == "/") {
        i = 2;
    }
    let name = read_html_tag_name(s, i);
    if (name != null) {
        if (is_block_html_tag(name)) {
            let after = s.at(i + name.length());
            if (after == null || after == " " || after == "\t" || after == ">") {
                return 6;
            }
            if (after == "/" && s.at(i + name.length() + 1) == ">") {
                return 6;
            }
        }
    }
    if (allow_type7) {
        let end = parse_open_tag(s, 0);
        if (end == null) {
            end = parse_close_tag(s, 0);
        }
        if (end != null) {
            if (rest_only_space_tab(s, end)) {
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
    if (t.type_name == "html_block" && t.html_type >= 1 && t.html_type <= 5) {
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

        function try_open(self, parser: Parser) -> StartMatch throws never {
            if (parser.indented) {
                return StartMatch.None;
            }
            if (parser.scan.line.at(parser.next_nonspace) != "<") {
                return StartMatch.None;
            }
            let allow_type7 = parser.last_matched().type_name != "paragraph"
                && !(!parser.all_closed && !parser.blank && parser.tip().type_name == "paragraph");
            let s = parser.scan.line.slice(parser.next_nonspace, parser.scan.line.length());
            let html_type = html_block_type(s, allow_type7);
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
    assert.equal(root.to_html("<div>\n*foo*\n\n*bar*\n"), "<div>\n*foo*\n<p>*bar*</p>\n")
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
        "<p>Foo\n&lt;a href=&quot;bar&quot;&gt;\nbaz</p>\n",
    )
}

test "html block spec examples that do not need inlines" {
    root.spec.assert_spec_examples(
        [
            149,
            150,
            151,
            153,
            154,
            156,
            157,
            158,
            159,
            160,
            161,
            162,
            163,
            164,
            165,
            166,
            169,
            170,
            171,
            172,
            173,
            174,
            175,
            178,
            179,
            180,
            181,
            182,
            183,
            184,
            185,
            186,
            189,
            190,
            191,
        ],
    )
}
