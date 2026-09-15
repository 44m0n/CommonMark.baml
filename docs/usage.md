# Usage

This page covers calling CommonMark.baml from BAML and running the `bamark` CLI. HTML mapping and `safe` mode are in [html.md](html.md). Resource limits are in [Limits](#limits). Compile checks and the spec suite are in [testing.md](testing.md).

## Requirements

`baml.toml` pins BAML nightly 0.19.1-nightly.20260911.a. To select it globally too:

```bash
baml toolchain use 0.19.1-nightly.20260911.a
```

The project is a BAML package: `baml.toml` at the repository root and sources under `baml_src/`.

## Library (from BAML)

Files directly in `baml_src/` are the `root` namespace. Definitions in `baml_src/ns_<name>/` live in namespace `<name>` and are reached as `root.<ns>.<name>`. There are no imports.

```baml
let html = to_html("# Hi\n")
let doc = parse("# Hi\n")
let html2 = render_html(doc)
let html3 = to_html(md, options = root.block.commonmark_options(), safe = true)
```

`parse`, `render_html`, and `to_html` are root functions (`baml_src/main.baml`). `commonmark_options` is `root.block.commonmark_options`.

### Signatures

From `baml_src/main.baml`:

```baml
function parse(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
) -> root.ast.Document

function render_html(document: root.ast.Document, safe: bool = false) -> string

function to_html(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
    safe: bool = false,
) -> string
```

`to_html` is `render_html(parse(markdown, options = options), safe = safe)`.

Defaulted parameters must be passed by name. `parse(md)` and `to_html(md)` are valid; `parse(md, commonmark_options())` is not. To pass options or `safe`, write `options = …` and `safe = …`.

### CommonMark vs a later dialect

Call `parse(md)` or `to_html(md)` for CommonMark (`commonmark_options()` is the default). A future dialect would pass a different `ParseOptions` value by name, for example `parse(md, options = gfm_options())`. This tree does not define `gfm_options`. How to append block starts and inline rules: [extensions.md](extensions.md).

### Walking the AST

`Document.children` is a `Block[]`. `Block` and `Inline` are unions. Walk them with `match` or `if let`:

```baml
function first_heading_text(doc: root.ast.Document) -> string {
    let h = doc.children.at(0);
    if let heading: root.ast.Heading = h {
        let n = heading.children.at(0);
        if let t: root.ast.Text = n {
            t.literal
        } else {
            ""
        }
    } else {
        ""
    }
}

function describe_block(b: root.ast.Block) -> string {
    match (b) {
        let p: root.ast.Paragraph => "paragraph",
        let h: root.ast.Heading => `heading ${h.level}`,
        let _tb: root.ast.ThematicBreak => "thematic-break",
        let c: root.ast.CodeBlock => "code-block",
        let html: root.ast.HtmlBlock => "html-block",
        let q: root.ast.BlockQuote => "blockquote",
        let l: root.ast.List => if (l.kind == root.ast.ListKind.Ordered) {
            "ol"
        } else {
            "ul"
        },
    }
}
```

`Block` is `Paragraph | Heading | ThematicBreak | CodeBlock | HtmlBlock | BlockQuote | List`. `Inline` is `Text | SoftBreak | HardBreak | CodeSpan | Emph | Strong | Link | Image | HtmlInline | Autolink`. List items are `ListItem` (`List.children`), not `Block`. Full field lists: [ast.md](ast.md).

### After `parse()`

After `parse()` returns:

- `Paragraph.raw` and `Heading.raw` are empty strings (source was consumed during inline parse).
- `last_line_blank` is `false` on every node, including list items.
- `List.tight` is already computed.

If you construct an AST yourself and pass it to `render_html`, set `raw: ""` and `last_line_blank: false` on those fields. Set `List.tight` yourself if you care about tight vs loose item HTML ([html.md](html.md)).

### Unsupported surface

`Parser`, `Open`, scanners, spec helpers, and other `ns_*` functions are unsupported internals. They may change without a major version. The supported v1 surface is `parse` / `render_html` / `to_html`, the AST types in `ns_ast`, and `ParseOptions` / `BlockStart` / `InlineParseRule` for dialects.

### Debugging

```bash
baml run to_html -- --markdown '# Hi'
```

`baml run` JSON-quotes the returned string. For raw HTML on stdout, use `bamark` below.

## Limits

`parse`, `render_html`, `to_html`, and `bamark` have no timeout, no max input size, and no nest-depth cap. Callers that accept untrusted Markdown must bound bytes and wall time themselves. `safe` does not do that: it only changes emitted HTML ([html.md](html.md)).

Hot paths scan a materialized `chars()` array rather than indexing the string per character (`String.at(i)` is O(i) in this BAML runtime). CommonMark constructs that are expensive by design (many emphasis delimiters, unmatched `[`, large fenced or HTML blocks) are still valid and will be finished, not refused.

Local scans have spec or engine caps: link labels longer than 1000 characters fail (CommonMark); unquoted destinations nested past 32 parentheses fail. Those do not bound whole-document time or memory.

## CLI (bamark)

Pack the CLI from `baml_src/ns_cli/bamark.baml`:

```bash
baml pack cli.bamark --output ./bamark
```

### Invocation

```
Usage: bamark [options] [file]
```

- If `file` is omitted or is `-`, the program reads `/dev/stdin` (Unix, Git Bash, WSL). Native Windows cmd/PowerShell has no `/dev/stdin`; pass a path.
- `--safe` — same as `to_html(..., safe = true)`. See [html.md](html.md).
- `-h` / `--help` — print usage and exit 0.
- `-V` / `--version` — print `bamark 0.31.2` and exit 0. That string is the CommonMark spec version this engine targets, not a semver of this repository.
- `--` ends option parsing so a filename such as `-weird.md` is not treated as a flag.
- Unknown flags (and extra positional arguments) exit 2.
- I/O errors (including a missing file) exit 1.
- Input must be UTF-8.
- Stdout is raw HTML, not JSON.

Default behavior matches CommonMark: raw HTML and `javascript:` URLs pass through unless `--safe` is set.

### Examples

```bash
printf '%s\n' '# Hi' | ./bamark
./bamark README.md
printf '%s\n' '[x](javascript:alert(1))' | ./bamark --safe
```

### Performance

Cold start of a packed binary is about one second, so a process-per-example spec harness is slow. `baml test` already covers all 652 spec examples; see [testing.md](testing.md).

Parse and render cost scale with the input. The engine has no timeout or size cap; see [Limits](#limits).
