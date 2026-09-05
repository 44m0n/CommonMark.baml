# CommonMark coverage

This tree implements [CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/) only. It does not implement GitHub Flavored Markdown (GFM): no tables, task lists, strikethrough, autolinks without `<>`, footnotes, or other GFM extensions.

All **652** examples in `vendor/commonmark-0.31.2/` pass (`baml test`; see [testing.md](testing.md)).

## Preprocessing

`root.scan.preprocess` in `baml_src/ns_scan/cursor.baml` runs before block parse:

- `\r\n` and `\r` → `\n`
- NUL `U+0000` → `U+FFFD`

Tabs are not rewritten to spaces. Column counting uses tab stop **4** (`4 - (column % 4)`).

## Blocks

| Spec section | Source |
| --- | --- |
| Tabs | `ns_scan/cursor.baml` (tab stop 4; spec tests in `ns_inline/parse.baml`) |
| ATX headings | `ns_block/atx.baml` |
| Setext headings | `ns_block/setext.baml` |
| Thematic breaks | `ns_block/thematic.baml` |
| Block quotes | `ns_block/quote.baml` |
| Fenced code blocks | `ns_block/fenced.baml` |
| Indented code blocks | `ns_block/indented.baml` |
| HTML blocks (types 1–7) | `ns_block/html.baml` |
| List items, Lists | `ns_block/list.baml` |
| Link reference definitions | `ns_block/refs.baml` |
| Paragraphs, Blank lines | `ns_block/paragraph.baml` |

## Inlines

Inline spec tests live mostly in `ns_inline/parse.baml`. Rule implementations:

| Spec section | Source |
| --- | --- |
| Backslash escapes | `ns_inline/escape.baml` |
| Entity and numeric character references | `ns_inline/entities.baml` plus `ns_inline/named_entities_json.baml` (WHATWG named-character table) |
| Code spans | `ns_inline/code.baml` |
| Emphasis and strong emphasis | `ns_inline/emphasis.baml` plus `ns_inline/delimiter.baml` |
| Links, Images | `ns_inline/link.baml` |
| Autolinks | `ns_inline/autolink.baml` (angle-bracket CommonMark autolinks only) |
| Raw HTML | `ns_inline/html.baml` |
| Hard line breaks, Soft line breaks | `ns_inline/breaks.baml` |
| Textual content, Precedence, Inlines, Tabs | `ns_inline/parse.baml` (tests); tabs also `ns_scan/cursor.baml` |

## Construct → AST → HTML

Types are in `root.ast` ([ast.md](ast.md)). HTML is produced by `ns_html/render.baml` ([html.md](html.md)).

| Construct | AST | HTML |
| --- | --- | --- |
| Document | `Document { children: Block[], refs }` | concatenation of child HTML |
| ATX heading | `Heading { level: 1–6, setext: false, children }` | `<h{level}>…</h{level}>\n` |
| Setext heading | `Heading { level: 1 or 2, setext: true, children }` | same `<h1>` / `<h2>` as ATX; `setext` is not rendered |
| Thematic break | `ThematicBreak` | `<hr />\n` |
| Block quote | `BlockQuote { children: Block[] }` | `<blockquote>\n` … `</blockquote>\n` |
| Fenced code | `CodeBlock { fenced: true, info, literal }` | `<pre><code>` … `</code></pre>\n`; if the first word of `info` (split on space or tab) is non-empty, ` class="language-{word}"` on `<code>` |
| Indented code | `CodeBlock { fenced: false, info: "", literal }` | same `<pre><code>` wrapper; `info` is empty so no language class |
| HTML block | `HtmlBlock { literal }` | `literal` unescaped; `safe = true` → `<!-- raw HTML omitted -->\n` |
| Bullet list | `List { kind: ListKind.Bullet, bullet_char, children: ListItem[] }` | `<ul>\n` … `</ul>\n`. `bullet_char` (`*`, `-`, or `+`) is not in the HTML |
| Ordered list | `List { kind: ListKind.Ordered, start, delimiter, children }` | `<ol>\n` or `<ol start="{start}">\n` when `start != 1`. `delimiter` (`.` or `)`) is not in the HTML |
| List item | `ListItem { children: Block[] }` (not a `Block`) | `<li>` … `</li>\n` |
| Tight list | `List.tight == true` | item `Paragraph` children omit `<p>` wrappers |
| Loose list | `List.tight == false` | item `Paragraph` children wrap as `<p>…</p>\n` |
| Link reference definition | no block node; `Document.refs: map<string, LinkRef>` | not rendered |
| Paragraph | `Paragraph { children: Inline[] }` | `<p>…</p>\n` (except tight-list items, above) |
| Blank line | no node; used during parse for tightness | no output |
| Text | `Text { literal }` | HTML-escaped text |
| Soft line break | `SoftBreak` | `\n` |
| Hard line break | `HardBreak` | `<br />\n` |
| Code span | `CodeSpan { literal }` | `<code>` … `</code>` |
| Emphasis | `Emph { children }` | `<em>` … `</em>` |
| Strong | `Strong { children }` | `<strong>` … `</strong>` |
| Link | `Link { destination, title, children }` | `<a href="…">` … `</a>`; optional ` title="…"` |
| Image | `Image { destination, title, children }` | `<img src="…" alt="…" />`; optional ` title="…"`. `alt` is the flattened text of `children` |
| Raw HTML (inline) | `HtmlInline { literal }` | `literal` unescaped; `safe = true` → `<!-- raw HTML omitted -->` |
| Autolink (URI) | `Autolink { destination, email: false }` | `<a href="{destination}">` escaped destination `</a>` |
| Autolink (email) | `Autolink { destination, email: true }` | `<a href="mailto:{destination}">` escaped destination `</a>` |

`List.tight` is computed when the list is finalized and is **kept** after `parse()`. `Heading.setext` and `CodeBlock.fenced` are similarly kept; they distinguish source form, not HTML tag choice.

## Out of scope

- GFM (tables, task lists, strikethrough, bare autolinks, footnotes, …)
- MDX
- Front matter
- Smart punctuation
- Source maps / positions (the AST has no source offsets)
