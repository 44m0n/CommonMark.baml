# HTML renderer

`render_html` walks a `Document` and writes CommonMark HTML. `to_html` parses then renders. Signatures, named defaults, and the `bamark --safe` flag are in [usage.md](usage.md). Behavior below is from `baml_src/ns_html/render.baml`. Nested lists, quotes, and emphasis are walked with `HtmlJob` / `InlineJob` stacks so rendering does not recurse in BAML call frames.

`to_html` is not safe for untrusted Markdown by default. Pass `safe = true` (or `bamark --safe`) for the mitigations in [Safe mode](#safe-mode). That mode is still not a sanitizer.

## Output mapping

### Blocks

| Node | HTML |
| --- | --- |
| `Paragraph` | `<p>…</p>\n` |
| `Heading` | `<h{level}>…</h{level}>\n` |
| `ThematicBreak` | `<hr />\n` |
| `CodeBlock` | `<pre><code>escaped literal</code></pre>\n`, or with ` class="language-{word}"` on `<code>` when `info` has a first word |
| `HtmlBlock` | the block’s `literal`, unchanged |
| `BlockQuote` | `<blockquote>\n` then children then `</blockquote>\n` |
| `List` (bullet) | `<ul>\n` … `</ul>\n` |
| `List` (ordered) | `<ol>\n` … `</ol>\n`, or `<ol start="N">\n` when `start != 1` |

The `class="language-…"` attribute on a code block is omitted when the info string has no first word (empty, or only spaces/tabs). The first word is the run of characters up to the first space or tab; it is HTML-escaped in the class value. The code `literal` is HTML-escaped.

`HtmlBlock` in safe mode is replaced by `<!-- raw HTML omitted -->\n` (trailing newline included).

List items are wrapped as `<li>…</li>\n`. In a tight list (`List.tight == true`), a `Paragraph` that is a direct child of an item is rendered without `<p>` wrappers. Other blocks inside items keep their usual tags.

### Inlines

Text in `Text`, `CodeSpan`, autolink display, and attribute values is escaped: `&` `<` `>` `"` become `&amp;` `&lt;` `&gt;` `&quot;`.

| Node | HTML |
| --- | --- |
| `Text` | escaped `literal` |
| `SoftBreak` | a newline |
| `HardBreak` | `<br />\n` |
| `CodeSpan` | `<code>escaped literal</code>` |
| `Emph` | `<em>…</em>` |
| `Strong` | `<strong>…</strong>` |
| `Link` | `<a href="…">` or `<a href="…" title="…">` — `title` is omitted when it is `null` |
| `Image` | `<img src="…" alt="…" />` or with `title="…"` when title is non-null |
| `HtmlInline` | the inline’s `literal`, unchanged |
| `Autolink` | `<a href="…">escaped destination</a>` |

Image `alt` is the plain text of the image’s children (`image_plain_nodes` in `ns_inline`): `Text` / `CodeSpan` literals, autolink destinations, nested `Emph` / `Strong` / `Link` / `Image` children, and newlines for `SoftBreak` / `HardBreak`. `HtmlInline` contributes nothing.

`HtmlInline` in safe mode is replaced by `<!-- raw HTML omitted -->` with no trailing newline (unlike `HtmlBlock`).

For `Autolink`, the `href` is `mailto:` plus the destination when `email` is true; otherwise it is the destination. The element’s text is always the escaped destination, not the `mailto:` form.

## Href and src encoding

Link `href` and image `src` (and autolink `href`) are encoded as follows:

- An existing `%` followed by two hexadecimal digits is copied as `%HH`.
- `&` is written as `&amp;`.
- ASCII letters, digits, and `-_.!~*'();/?:@=+$,#` are copied as-is.
- Every other character is percent-encoded as uppercase UTF-8 `%HH` sequences.

## Safe mode

Pass `safe = true` to `render_html` or `to_html` (CLI: `bamark --safe`).

When `safe` is true:

- Raw HTML is omitted: `HtmlBlock` becomes `<!-- raw HTML omitted -->\n`; `HtmlInline` becomes `<!-- raw HTML omitted -->`.
- `href` and `src` are emptied when, after leading C0 controls, spaces, and tabs (code points `<= 0x20`), the remainder is a `javascript:`, `vbscript:`, `data:`, or `file:` URL. The scheme check is case-insensitive (`FILE:foo` is emptied). The empty value is still written as `href=""` / `src=""`.

`http:`, `https:`, and relative URLs are not emptied. Attributes are not rewritten; raw HTML is dropped wholesale rather than filtered. `safe` does not bound CPU. Adversarial documents can still be expensive to parse and render.

The default is `safe = false`, matching CommonMark: raw HTML and those URL schemes pass through.

Do not feed untrusted Markdown to `to_html` or `bamark` unless you pass `safe = true`, and do not treat `safe` as a complete HTML sanitizer. Spec tests use the default (unsafe) renderer; see [testing.md](testing.md).
