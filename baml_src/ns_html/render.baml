class InlineJob {
    nodes: root.ast.Inline[],
    i: int,
    close: string,
}

class HtmlJob {
    mode: string,
    blocks: root.ast.Block[],
    items: root.ast.ListItem[],
    i: int,
    close: string,
    tight: bool,
    inner_ends_nl: bool,
}

function html_seq(blocks: root.ast.Block[], close: string) -> HtmlJob {
    let items: root.ast.ListItem[] = [];
    HtmlJob {
        mode: "seq",
        blocks: blocks,
        items: items,
        i: 0,
        close: close,
        tight: false,
        inner_ends_nl: false,
    }
}

function html_items(items: root.ast.ListItem[], tight: bool, close: string) -> HtmlJob {
    let blocks: root.ast.Block[] = [];
    HtmlJob {
        mode: "items",
        blocks: blocks,
        items: items,
        i: 0,
        close: close,
        tight: tight,
        inner_ends_nl: false,
    }
}

function html_item_kids(blocks: root.ast.Block[], tight: bool) -> HtmlJob {
    let items: root.ast.ListItem[] = [];
    HtmlJob {
        mode: "item",
        blocks: blocks,
        items: items,
        i: 0,
        close: "</li>\n",
        tight: tight,
        inner_ends_nl: false,
    }
}

function last_chunk_ends_nl(out: string[]) -> bool {
    if let last: string = out.at(out.length() - 1) {
        last.ends_with("\n")
    } else {
        false
    }
}

function list_open_tag(list: root.ast.List) -> string {
    if (list.kind == root.ast.ListKind.Ordered) {
        let start_attr = if (list.start == 1) {
            ""
        } else {
            ` start="${list.start}"`
        };
        `<ol${start_attr}>\n`
    } else {
        "<ul>\n"
    }
}

function list_close_tag(list: root.ast.List) -> string {
    if (list.kind == root.ast.ListKind.Ordered) {
        "</ol>\n"
    } else {
        "</ul>\n"
    }
}

function render_document(document: root.ast.Document, safe: bool = false) -> string {
    render_html_jobs(html_seq(document.children, ""), safe)
}

function push_block_work(out: string[], jobs: HtmlJob[], b: root.ast.Block, safe: bool) -> void {
    match (b) {
        let p: root.ast.Paragraph => {
            out.push(`<p>${render_inlines(p.children, safe = safe)}</p>\n`)
        },
        let h: root.ast.Heading => {
            out.push(`<h${h.level}>${render_inlines(h.children, safe = safe)}</h${h.level}>\n`)
        },
        let _tb: root.ast.ThematicBreak => {
            out.push("<hr />\n")
        },
        let c: root.ast.CodeBlock => {
            out.push(render_code_block(c))
        },
        let html: root.ast.HtmlBlock => {
            if (safe) {
                out.push("<!-- raw HTML omitted -->\n")
            } else {
                out.push(html.literal)
            }
        },
        let q: root.ast.BlockQuote => {
            out.push("<blockquote>\n");
            jobs.push(html_seq(q.children, "</blockquote>\n"));
        },
        let l: root.ast.List => {
            out.push(list_open_tag(l));
            jobs.push(html_items(l.children, l.tight, list_close_tag(l)));
        },
    }
}

function render_html_jobs(start: HtmlJob, safe: bool) -> string {
    let out: string[] = [];
    let jobs: HtmlJob[] = [];
    jobs.push(start);
    while (jobs.length() > 0) {
        let job = jobs[jobs.length() - 1];
        if (job.mode == "seq") {
            if (job.i >= job.blocks.length()) {
                if (job.close.length() > 0) {
                    out.push(job.close);
                }
                let _ = jobs.pop();
            } else {
                let b = job.blocks[job.i];
                job.i += 1;
                push_block_work(out, jobs, b, safe);
            }
        } else if (job.mode == "items") {
            if (job.i >= job.items.length()) {
                out.push(job.close);
                let _ = jobs.pop();
            } else {
                let item = job.items[job.i];
                job.i += 1;
                out.push("<li>");
                jobs.push(html_item_kids(item.children, job.tight));
            }
        } else if (job.i >= job.blocks.length()) {
            out.push(job.close);
            let _ = jobs.pop();
        } else {
            let b = job.blocks[job.i];
            let more = job.i + 1 < job.blocks.length();
            job.i += 1;
            if (job.tight && b is root.ast.Paragraph) {
                if let p: root.ast.Paragraph = b {
                    let text = render_inlines(p.children, safe = safe);
                    let chunk = if (more) {
                        `${text}\n`
                    } else {
                        text
                    };
                    out.push(chunk);
                    job.inner_ends_nl = chunk.ends_with("\n");
                }
            } else {
                if (!job.inner_ends_nl && !last_chunk_ends_nl(out)) {
                    out.push("\n");
                }
                push_block_work(out, jobs, b, safe);
                job.inner_ends_nl = last_chunk_ends_nl(out);
            }
        }
    }
    out.join("")
}

function first_info_word(info: string) -> string {
    let chars = info.chars();
    let i = 0;
    while (i < chars.length()) {
        let c = chars[i];
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

function render_inlines(inlines: root.ast.Inline[], safe: bool = false) -> string {
    let out: string[] = [];
    let jobs: InlineJob[] = [];
    jobs.push(InlineJob { nodes: inlines, i: 0, close: "" });
    while (jobs.length() > 0) {
        let job = jobs[jobs.length() - 1];
        if (job.i >= job.nodes.length()) {
            if (job.close.length() > 0) {
                out.push(job.close);
            }
            let _ = jobs.pop();
        } else {
            let node = job.nodes[job.i];
            job.i += 1;
            match (node) {
                let t: root.ast.Text => {
                    out.push(escape_html(t.literal))
                },
                let _sb: root.ast.SoftBreak => {
                    out.push("\n")
                },
                let _hb: root.ast.HardBreak => {
                    out.push("<br />\n")
                },
                let c: root.ast.CodeSpan => {
                    out.push(`<code>${escape_html(c.literal)}</code>`)
                },
                let e: root.ast.Emph => {
                    out.push("<em>");
                    jobs.push(InlineJob { nodes: e.children, i: 0, close: "</em>" });
                },
                let s: root.ast.Strong => {
                    out.push("<strong>");
                    jobs.push(InlineJob { nodes: s.children, i: 0, close: "</strong>" });
                },
                let l: root.ast.Link => {
                    let title = if let t: string = l.title {
                        ` title="${escape_html(t)}"`
                    } else {
                        ""
                    };
                    out.push(`<a href="${safe_href(l.destination, safe)}"${title}>`);
                    jobs.push(InlineJob { nodes: l.children, i: 0, close: "</a>" });
                },
                let im: root.ast.Image => {
                    out.push(render_image(im, safe = safe))
                },
                let h: root.ast.HtmlInline => {
                    if (safe) {
                        out.push("<!-- raw HTML omitted -->")
                    } else {
                        out.push(h.literal)
                    }
                },
                let a: root.ast.Autolink => {
                    out.push(render_autolink(a, safe = safe))
                },
            }
        }
    }
    out.join("")
}

function render_image(i: root.ast.Image, safe: bool = false) -> string {
    let title = if let t: string = i.title {
        ` title="${escape_html(t)}"`
    } else {
        ""
    };
    `<img src="${safe_href(i.destination, safe)}" alt="${escape_html(root.inline.image_plain_nodes(i.children))}"${title} />`
}

function render_autolink(a: root.ast.Autolink, safe: bool = false) -> string {
    let href = if (a.email) {
        `mailto:${a.destination}`
    } else {
        a.destination
    };
    `<a href="${safe_href(href, safe)}">${escape_html(a.destination)}</a>`
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
    let chars = s.chars();
    let parts: string[] = [];
    let i = 0;
    let start = 0;
    let n = chars.length();
    while (i < n) {
        let c = chars.at(i) ?? "";
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
    let hex = ch.to_utf8().to_hex().to_upper_case().chars();
    let parts: string[] = [];
    let i = 0;
    while (i < hex.length()) {
        parts.push(`%${hex.at(i) ?? ""}${hex.at(i + 1) ?? ""}`);
        i += 2;
    }
    parts.join("")
}

function escape_href(s: string) -> string {
    let chars = s.chars();
    let parts: string[] = [];
    let i = 0;
    let n = chars.length();
    while (i < n) {
        let ch = chars.at(i) ?? "";
        if (ch == "%") {
            let n1 = chars.at(i + 1) ?? "";
            let n2 = chars.at(i + 2) ?? "";
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

function dangerous_url(url: string) -> bool {
    let chars = url.chars();
    let i = 0;
    while (i < chars.length() && (chars[i].code_point_at(0) ?? 0) <= 0x20) {
        i += 1;
    }
    let rest = url.slice(i, url.length()).to_lower_case();
    rest.starts_with("javascript:")
        || rest.starts_with("vbscript:")
        || rest.starts_with("data:")
        || rest.starts_with("file:")
}

function safe_href(url: string, safe: bool) -> string {
    if (safe && dangerous_url(url)) {
        ""
    } else {
        escape_href(url)
    }
}

test "deep nested lists render" {
    let md = `${"- ".repeat(80)}a\n`;
    let html = root.to_html(md);
    assert.is_true(html.includes("<ul>"));
    assert.is_true(html.includes("a"));
    assert.is_true(html.includes("</ul>"))
}

test "deep nested quotes render" {
    let md = `${"> ".repeat(80)}a\n`;
    let html = root.to_html(md);
    assert.is_true(html.includes("<blockquote>"));
    assert.is_true(html.includes("a"))
}

test "deep nested emphasis renders" {
    let n = 200;
    let md = `${"*".repeat(n)}a${"*".repeat(n)}\n`;
    let html = root.to_html(md);
    assert.is_true(html.includes("<strong>"));
    assert.is_true(html.includes("a"));
    assert.is_true(html.includes("</strong>"))
}

test "deep nested images render" {
    let n = 80;
    let md = `${"![".repeat(n)}a${"](u)".repeat(n)}\n`;
    let html = root.to_html(md);
    assert.is_true(html.includes("<img"));
    assert.is_true(html.includes("alt=\"a\""))
}

test "dangerous_url rejects file javascript vbscript data" {
    let soh = string.from_code_points([0x01]) catch (e) {
        baml.errors.InvalidArgument => ""
    };
    assert.is_true(dangerous_url("file:///etc/passwd"));
    assert.is_true(dangerous_url("FILE:foo"));
    assert.is_true(dangerous_url(" javascript:alert(1)"));
    assert.is_true(dangerous_url("\tvbscript:x"));
    assert.is_true(dangerous_url("data:text/html,x"));
    assert.is_true(dangerous_url(`${soh}javascript:alert(1)`));
    assert.is_true(dangerous_url("\n\t javascript:x"));
    assert.equal(dangerous_url("http://example.com"), false);
    assert.equal(dangerous_url("/etc/passwd"), false)
}

test "safe_href empties file urls only when safe" {
    let soh = string.from_code_points([0x01]) catch (e) {
        baml.errors.InvalidArgument => ""
    };
    assert.equal(safe_href("file:///etc/passwd", true), "");
    assert.equal(safe_href("FILE:foo", true), "");
    assert.equal(safe_href("javascript:alert(1)", true), "");
    assert.equal(safe_href(`${soh}javascript:alert(1)`, true), "");
    assert.equal(safe_href("file:///etc/passwd", false), "file:///etc/passwd");
    assert.equal(safe_href("FILE:foo", false), "FILE:foo")
}

test "render_inlines safe empties file href" {
    let kids: root.ast.Inline[] = [root.ast.Text { literal: "x" }];
    let file_link = root.ast.Link { destination: "file:///etc/passwd", title: null, children: kids };
    let file_nodes: root.ast.Inline[] = [file_link];
    assert.equal(render_inlines(file_nodes, safe = true), "<a href=\"\">x</a>");
    assert.equal(render_inlines(file_nodes, safe = false), "<a href=\"file:///etc/passwd\">x</a>");
    let js_kids: root.ast.Inline[] = [root.ast.Text { literal: "x" }];
    let js_link = root.ast.Link { destination: "javascript:alert(1)", title: null, children: js_kids };
    let js_nodes: root.ast.Inline[] = [js_link];
    assert.equal(render_inlines(js_nodes, safe = true), "<a href=\"\">x</a>");
    let file_upper = root.ast.Link {
        destination: "FILE:foo",
        title: null,
        children: [root.ast.Text { literal: "x" }],
    };
    assert.equal(render_inlines([file_upper], safe = true), "<a href=\"\">x</a>")
}

test "safe mode empties file and javascript urls" {
    assert.equal(
        root.to_html("[x](file:///etc/passwd)\n", safe = true),
        "<p><a href=\"\">x</a></p>\n",
    );
    assert.equal(root.to_html("[x](FILE:foo)\n", safe = true), "<p><a href=\"\">x</a></p>\n");
    assert.equal(
        root.to_html("[x](javascript:alert(1))\n", safe = true),
        "<p><a href=\"\">x</a></p>\n",
    )
}

test "without safe file urls pass through" {
    assert.equal(
        root.to_html("[x](file:///etc/passwd)\n"),
        "<p><a href=\"file:///etc/passwd\">x</a></p>\n",
    );
    assert.equal(root.to_html("[x](FILE:foo)\n"), "<p><a href=\"FILE:foo\">x</a></p>\n")
}

test "tight list item html block is preceded by a newline" {
    assert.equal(root.to_html("-\n   <div>\n"), "<ul>\n<li>\n <div>\n</li>\n</ul>\n")
}

test "escape_html encodes specials via chars" {
    assert.equal(escape_html("a&b<c>d\"e"), "a&amp;b&lt;c&gt;d&quot;e");
    assert.equal(escape_html("plain"), "plain")
}

test "escape_href keeps percent sequences and encodes space" {
    assert.equal(escape_href("%2Fok"), "%2Fok");
    assert.equal(escape_href("a b"), "a%20b")
}
