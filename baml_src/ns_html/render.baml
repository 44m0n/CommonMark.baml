function render_document(document: root.ast.Document) -> string {
    document.children
        .map((b) -> {
            render_block(b)
        })
        .join("")
}

function render_block(block: root.ast.Block) -> string {
    match (block) {
        let p: root.ast.Paragraph => render_paragraph(p),
        let h: root.ast.Heading => render_heading(h),
        let _tb: root.ast.ThematicBreak => "<hr />\n",
        let c: root.ast.CodeBlock => render_code_block(c),
        let h: root.ast.HtmlBlock => h.literal,
        let q: root.ast.BlockQuote => render_block_quote(q),
        let l: root.ast.List => render_list(l),
    }
}

function render_paragraph(p: root.ast.Paragraph) -> string {
    `<p>${render_inlines(p.children)}</p>\n`
}

function render_heading(h: root.ast.Heading) -> string {
    `<h${h.level}>${render_inlines(h.children)}</h${h.level}>\n`
}

function first_info_word(info: string) -> string {
    let i = 0;
    while (i < info.length()) {
        let c = info.at(i) ?? "";
        if (c == " " || c == "\t") {
            break;
        }
        i += 1;
    }
    info.slice(0, i)
}

function render_code_block(c: root.ast.CodeBlock) -> string {
    let lang = first_info_word(c.info);
    let info = if (lang) {
        ` class="language-${escape_html(lang)}"`
    } else {
        ""
    };
    `<pre><code${info}>${escape_html(c.literal)}</code></pre>\n`
}

function render_block_quote(q: root.ast.BlockQuote) -> string {
    `<blockquote>\n${q.children.map((b) -> { render_block(b) }).join("")}</blockquote>\n`
}

function render_list(list: root.ast.List) -> string {
    let inner = list.children
        .map((item) -> {
            render_list_item(item, list.tight)
        })
        .join("");
    if (list.kind == root.ast.ListKind.Ordered) {
        let start_attr = if (list.start == 1) {
            ""
        } else {
            ` start="${list.start}"`
        };
        `<ol${start_attr}>\n${inner}</ol>\n`
    } else {
        `<ul>\n${inner}</ul>\n`
    }
}

function render_list_item(item: root.ast.ListItem, tight: bool) -> string {
    let parts: string[] = [];
    let inner_ends_nl = false;
    let i = 0;
    while (i < item.children.length()) {
        let b = item.children[i];
        let tight_para = tight && b is root.ast.Paragraph;
        let chunk = if (tight && b is root.ast.Paragraph) {
            let text = render_inlines(b.children);
            if (i + 1 < item.children.length()) {
                `${text}\n`
            } else {
                text
            }
        } else {
            render_block(b)
        };
        if (!tight_para && chunk.starts_with("<") && !inner_ends_nl) {
            parts.push("\n");
        }
        parts.push(chunk);
        inner_ends_nl = chunk.ends_with("\n");
        i += 1;
    }
    `<li>${parts.join("")}</li>\n`
}

function render_inlines(inlines: root.ast.Inline[]) -> string {
    inlines
        .map((n) -> {
            render_inline(n)
        })
        .join("")
}

function render_inline(node: root.ast.Inline) -> string {
    match (node) {
        let t: root.ast.Text => escape_html(t.literal),
        let _sb: root.ast.SoftBreak => "\n",
        let _hb: root.ast.HardBreak => "<br />\n",
        let c: root.ast.CodeSpan => `<code>${escape_html(c.literal)}</code>`,
        let e: root.ast.Emph => `<em>${render_inlines(e.children)}</em>`,
        let s: root.ast.Strong => `<strong>${render_inlines(s.children)}</strong>`,
        let l: root.ast.Link => render_link(l),
        let i: root.ast.Image => render_image(i),
        let h: root.ast.HtmlInline => h.literal,
        let a: root.ast.Autolink => render_autolink(a),
    }
}

function render_link(l: root.ast.Link) -> string {
    let title = if let t: string = l.title {
        ` title="${escape_html(t)}"`
    } else {
        ""
    };
    `<a href="${escape_href(l.destination)}"${title}>${render_inlines(l.children)}</a>`
}

function render_image(i: root.ast.Image) -> string {
    let title = if let t: string = i.title {
        ` title="${escape_html(t)}"`
    } else {
        ""
    };
    `<img src="${escape_href(i.destination)}" alt="${escape_html(i.children.map((n) -> { root.inline.image_plain(n) }).join(""))}"${title} />`
}

function render_autolink(a: root.ast.Autolink) -> string {
    let href = if (a.email) {
        `mailto:${a.destination}`
    } else {
        a.destination
    };
    `<a href="${escape_href(href)}">${escape_html(a.destination)}</a>`
}

function escape_html(s: string) -> string {
    if (
        s.index_of("&") == null
            && s.index_of("<") == null
            && s.index_of(">") == null
            && s.index_of("\"") == null
    ) {
        return s;
    }
    let parts: string[] = [];
    let i = 0;
    let start = 0;
    let n = s.length();
    while (i < n) {
        let c = s.at(i) ?? "";
        let repl = if (c == "&") {
            "&amp;"
        } else if (c == "<") {
            "&lt;"
        } else if (c == ">") {
            "&gt;"
        } else if (c == "\"") {
            "&quot;"
        } else {
            ""
        };
        if (repl.length() > 0) {
            if (i > start) {
                parts.push(s.slice(start, i));
            }
            parts.push(repl);
            i += 1;
            start = i;
        } else {
            i += 1;
        }
    }
    if (start < n) {
        parts.push(s.slice(start, n));
    }
    parts.join("")
}

function href_keep_ascii(code: int) -> bool {
    (code >= 65 && code <= 90)
        || (code >= 97 && code <= 122)
        || (code >= 48 && code <= 57)
        || code == 45
        || code == 95
        || code == 46
        || code == 33
        || code == 126
        || code == 42
        || code == 39
        || code == 40
        || code == 41
        || code == 59
        || code == 47
        || code == 63
        || code == 58
        || code == 64
        || code == 38
        || code == 61
        || code == 43
        || code == 36
        || code == 44
        || code == 35
}

function percent_encode_char(ch: string) -> string {
    let hex = ch.to_utf8().to_hex().to_upper_case();
    let parts: string[] = [];
    let i = 0;
    while (i < hex.length()) {
        parts.push(`%${hex.slice(i, i + 2)}`);
        i += 2;
    }
    parts.join("")
}

function escape_href(s: string) -> string {
    let parts: string[] = [];
    let i = 0;
    let n = s.length();
    while (i < n) {
        let ch = s.at(i) ?? "";
        if (ch == "%") {
            let n1 = s.at(i + 1) ?? "";
            let n2 = s.at(i + 2) ?? "";
            if (n1.is_ascii_hex() && n2.is_ascii_hex()) {
                parts.push(`%${n1}${n2}`);
                i += 3;
                continue;
            }
        }
        let code = ch.code_point_at(0) ?? 0;
        if (ch == "&") {
            parts.push("&amp;");
        } else if (href_keep_ascii(code)) {
            parts.push(ch);
        } else {
            parts.push(percent_encode_char(ch));
        }
        i += 1;
    }
    parts.join("")
}
