# CommonMark.baml

**CommonMark.baml** is a [CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/) parser and HTML renderer written in [BAML](https://docs.boundaryml.com). Markdown goes in; a typed `Document` AST comes out; that tree can be walked or rendered as HTML. The engine is this repository (`baml_src/`), not a binding around cmark or another C library.

This tree implements CommonMark only. It does not implement GitHub Flavored Markdown (tables, task lists, strikethrough, autolinks without `<>`, footnotes, and so on).

| | |
| --- | --- |
| Project version | **v0.9.1** ([changelog](CHANGELOG.md); GitHub release tag) |
| Spec | CommonMark **0.31.2** (`bamark --version` reports both versions) |
| Conformance | **652/652** examples in `vendor/commonmark-0.31.2/` |
| Toolchain | BAML **0.19.1-nightly.20260911.a** (pinned in `baml.toml`) |
| License | [Apache 2.0](LICENSE) |

## What this repository is

This is a BAML *project*: `baml.toml` at the root, sources under `baml_src/`, tests in those same files, and the CommonMark spec vendored under `vendor/`. There is no separate published npm or PyPI package named CommonMark.baml. You clone this tree and use the [BAML CLI](https://docs.boundaryml.com) against it.

It ships two ways to run the engine:

1. **Library** — `parse`, `render_html`, and `to_html` in the `root` namespace (`baml_src/main.baml`). Call them from BAML (`baml run`, `baml test`, or another file in this project).
2. **CLI** — pack `bamark` (`baml_src/ns_cli/bamark.baml`) to a binary that reads Markdown from a file or stdin and writes raw HTML to stdout.

`baml.toml` also declares Python and TypeScript generators. `baml generate` can emit typed `baml_sdk` packages under `generated/`; that output is not committed, and those packages need the matching language bridge for this toolchain. Day-to-day use of the repo is the BAML library and `bamark`.

BAML has no package registry for this kind of library. To reuse the parser from another BAML project, vendor `baml_src/` (or the namespaces you need) into that project’s `baml_src/`. Files in `ns_<name>/` become namespace `<name>`; there are no imports.

## What it is not

- **Not GFM, MDX, or “Markdown plus extras.”** No tables, task lists, strikethrough, bare autolinks, footnotes, front matter, or smart punctuation.
- **Not a sanitizer.** Default HTML matches CommonMark: raw HTML and `javascript:`, `vbscript:`, `data:`, and `file:` URLs pass through. `safe` is HTML/script mitigation only; see [Safe mode](#safe-mode).
- **Not resource-bounded.** There is no timeout, max input size, or nest-depth cap. Callers that accept untrusted Markdown must bound bytes and wall time themselves.
- **Not a source map.** The AST has no line/column offsets.

Details: [docs/coverage.md](docs/coverage.md).

## Requirements

Install the BAML CLI, then pin the toolchain this tree is tested on:

```bash
# macOS
brew install baml

# or
curl -fsSL https://pkg.boundaryml.com/install.sh | sh -s

baml toolchain use 0.19.1-nightly.20260911.a
```

`baml.toml` pins the project toolchain. Confirm with `baml --version` / `baml toolchain list`. CI (`.github/workflows/test.yml`) selects the same version and runs `baml check` then `baml test`.

## Install the CLI

End users can install the prebuilt `bamark` CLI without installing BAML or cloning this repository. Releases contain platform-specific binaries, `LICENSE`, `NOTICE`, and SHA-256 checksums.

On Linux (including WSL) or macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/44m0n/CommonMark.baml/main/install.sh | sh
```

On Windows PowerShell:

```powershell
iex (irm https://raw.githubusercontent.com/44m0n/CommonMark.baml/main/install.ps1)
```

The installers use the latest GitHub Release by default. Pin the `v0.9.1` release with `BAMARK_VERSION`:

```bash
curl -fsSL https://raw.githubusercontent.com/44m0n/CommonMark.baml/main/install.sh \
  | BAMARK_VERSION=v0.9.1 sh
```

The Unix installer installs to `~/.local/bin` by default and does not modify shell profiles. If it reports that PATH was not modified, make `bamark` available in the current shell with:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

For future shells, add the same export to your shell profile. The PowerShell installer installs to `%LOCALAPPDATA%\Programs\bamark` and adds that directory to the user PATH; open a new shell if needed. Both installers print a `bamark --help` verification command after installation. Supported release targets are Linux x86_64, macOS x86_64, macOS arm64, and Windows x86_64.

### Using the installed CLI

Verify the installation and inspect all options:

```bash
bamark --help
bamark --version
```

Choose the input source and output destination with these common forms. The `<` and `>` operators are handled by your shell; `bamark` always writes rendered HTML to stdout:

```bash
# File -> stdout
bamark README.md

# Stdin -> stdout: pipe a file, or run `bamark` and type Markdown, then Ctrl-D
cat README.md | bamark                  # Linux, macOS, Git Bash, or WSL
bamark                                   # Linux, macOS, Git Bash, or WSL

# File -> file
bamark README.md > README.html

# Stdin -> file
bamark < README.md > README.html
```

Use safe mode or `--` for special cases:

```bash
bamark --safe README.md > README.safe.html
bamark -- -weird.md > output.html
```

Errors are written to stderr. Do not redirect output to the input path, such as `bamark README.md > README.md`, because the shell truncates the input before `bamark` reads it. The CLI accepts at most one input file. Native Windows PowerShell and `cmd.exe` should use a file path; `/dev/stdin` is supported on Linux, macOS, Git Bash, and WSL.

`bamark --version` prints the application version and the target specification:

```text
bamark 0.9.1 (CommonMark 0.31.2)
```

## Quick start

From the repository root, after the toolchain pin:

```bash
baml run -e 'to_html("# Hi\n")'
```

That evaluates an expression in the `root` namespace and prints a JSON-quoted string (`"<h1>Hi</h1>\n"`). For raw HTML on stdout, pack the CLI:

```bash
baml pack cli.bamark --output ./bamark
printf '%s\n' '# Hi' | ./bamark
# <h1>Hi</h1>
```

`baml run to_html -- --markdown '# Hi'` also works; it still JSON-quotes the result. Packed `bamark` cold-starts in about a second.

## Library

`parse`, `render_html`, and `to_html` live in `baml_src/main.baml` (namespace `root`). `to_html` is `render_html(parse(markdown, options = options), safe = safe)`.

Defaulted parameters must be passed **by name**. `parse(md)` and `to_html(md)` are valid; `parse(md, commonmark_options())` is not.

```baml
to_html("# Hi\n")
// "<h1>Hi</h1>\n"

let doc = parse("# Hi\n");
render_html(doc)

to_html("[x](javascript:alert(1))\n", safe = true)
// "<p><a href=\"\">x</a></p>\n"
```

`parse(md)` / `to_html(md)` use `root.block.commonmark_options()`. A later dialect would pass a different `ParseOptions` by name: `parse(md, options = …)`. This tree does not define `gfm_options()`.

Full signatures and AST walking: [docs/usage.md](docs/usage.md). Node fields: [docs/ast.md](docs/ast.md).

### Public API

BAML cannot hide namespaces, so internals are visible. The supported v1 surface is:

```baml
function parse(markdown: string, options: ParseOptions = commonmark_options()) -> Document
function render_html(document: Document, safe: bool = false) -> string throws baml.errors.InvalidArgument
function to_html(markdown: string, options: ParseOptions = commonmark_options(), safe: bool = false) -> string throws baml.errors.InvalidArgument
```

plus the AST types in `ns_ast` (`Document`, `Block`, `Inline`, and their classes) and `ParseOptions` / `BlockStart` / `BlockStartContext` / `InlineParseRule` / `InlineParseContext` / `commonmark_options` for dialects.

Everything else — `Parser`, `Open`, scanners, spec helpers, `bamark` argument parsing, and other `ns_*` functions — is unsupported and may change without a major version.

### Walking the AST

`Document.children` is a `Block[]`. `Block` and `Inline` are unions. `ListItem` is not a `Block`; it lives on `List.children`. Walk with `match` or `if let`:

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
```

`Block` is `Paragraph | Heading | ThematicBreak | CodeBlock | HtmlBlock | BlockQuote | List`.

`Inline` is `Text | SoftBreak | HardBreak | CodeSpan | Emph | Strong | Link | Image | HtmlInline | Autolink`.

After `parse()` returns:

- `Paragraph.raw` and `Heading.raw` are empty (phase 2 consumed the source).
- `last_line_blank` is `false` on every node, including list items.
- `List.tight` is already computed (and kept).

If you build an AST yourself, prefer `root.ast.new_document(...)` and `root.ast.new_heading(...)`; they initialize parser-only fields and reject invalid heading levels. `render_html` also validates the full tree and throws `baml.errors.InvalidArgument` rather than generating invalid HTML. For manually built non-heading nodes, set `raw: ""` and `last_line_blank: false`; set `List.tight` if you care about tight vs loose item HTML.

### HTML output

The renderer emits CommonMark-style HTML: `<h1>…</h1>\n`, `<hr />\n`, `<br />\n`, tight list items without `<p>` wrappers, `class="language-{word}"` on fenced code when the info string has a first word. Text and attribute values escape `& < > "`. Link `href` / image `src` percent-encode as in [docs/html.md](docs/html.md).

## CLI (`bamark`)

```bash
baml pack cli.bamark --output ./bamark
```

```
Usage: bamark [options] [file]
```

- Markdown from `file`, or `/dev/stdin` if the file is omitted or is `-` (Unix, Git Bash, WSL). Native Windows cmd/PowerShell has no `/dev/stdin`; pass a path.
- Stdout is **rendered HTML**, not JSON; errors are written to stderr.
- Save HTML with shell redirection; `<` and `>` are shell operators, not `bamark` options.
- Input must be UTF-8.
- `--safe` — same as `to_html(..., safe = true)`.
- `-h` / `--help` — usage, exit 0.
- `-V` / `--version` — print `bamark 0.9.1 (CommonMark 0.31.2)`, exit 0. The release tag is `v0.9.1`; the CommonMark target is `0.31.2`.
- `--` ends option parsing so a name like `-weird.md` is a file, not a flag.
- Unknown flags and extra positionals exit 2. I/O errors (missing file) exit 1.
- Do not redirect output to the input path; the shell truncates it before reading.

The four common input/output combinations are:

```bash
# File -> stdout
./bamark README.md

# Stdin -> stdout
cat README.md | ./bamark                  # Linux, macOS, Git Bash, or WSL
./bamark                                    # type Markdown, then Ctrl-D

# File -> file
./bamark README.md > README.html

# Stdin -> file
./bamark < README.md > README.html
```

For other cases:

```bash
printf '%s\n' '[x](javascript:alert(1))' | ./bamark --safe > safe.html
./bamark -- -weird.md > output.html
```

Default matches CommonMark: raw HTML and `javascript:`, `vbscript:`, `data:`, and `file:` URLs pass through unless `--safe` is set.

## CommonMark coverage

Preprocess: `\r\n` / `\r` → `\n`; NUL `U+0000` → `U+FFFD`. Tabs are not rewritten to spaces; column counting uses tab stop **4**.

**Blocks:** ATX and setext headings, thematic breaks, block quotes, fenced and indented code, HTML blocks (types 1–7), bullet and ordered lists (tight/loose, nesting), link reference definitions, paragraphs, blank lines.

**Inlines:** backslash escapes, named and numeric character references (WHATWG table, embedded so `bamark` works off the repo root), code spans, emphasis and strong, links and images, angle-bracket autolinks (URI and email), raw HTML, hard and soft line breaks.

Link reference definitions are stored on `Document.refs` (normalized label → destination/title). They are not block nodes and are not rendered. Duplicate labels keep the first definition.

Construct → AST → HTML map: [docs/coverage.md](docs/coverage.md).

## How the engine works

Two phases, both driven by tables on `ParseOptions`:

1. **Blocks** (`ns_block`) — preprocess, then a line loop over an open-block stack. Each line tries to *continue* open containers, then *start* new blocks from `block_starts` in order, then treats the remainder as lazy paragraph continuation, leaf content, or a new paragraph.
2. **Inlines** (`ns_inline`) — walk paragraphs and headings with an explicit stack (so nested lists/quotes do not recurse in BAML call frames). `inline_rules` consume special characters; everything else coalesces as `Text`. Emphasis and links use a delimiter stack so later reference definitions still resolve.

`commonmark_options()` fills both tables for 0.31.2. HTML rendering (`ns_html`) is also iterative (`HtmlJob` / `InlineJob` stacks).

Hot paths scan a materialized `chars()` array on each line. In this BAML runtime `String.at(i)` is O(i); walking the string per character was quadratic on long lines.

A new *leaf* that reuses an existing AST node can be a plugin (`BlockStart` / `InlineParseRule`). A new block *kind* that continues across lines is a fork: `OpenKind`, `BlockOps`, the `Block` union, and the HTML `match` all have to change. In-tree examples: `PercentBreakStart` (`%%%` → `<hr />`) and `PercentSpanRule` (`%x%` → `<span>x</span>`).

Walkthrough: [docs/architecture.md](docs/architecture.md). Writing a rule: [docs/extensions.md](docs/extensions.md).

## Safe mode

`to_html` is not safe for untrusted Markdown by default.

Pass `safe = true` (CLI: `bamark --safe`) to:

- Replace raw HTML (`HtmlBlock` / `HtmlInline`) with `<!-- raw HTML omitted -->` (`HtmlBlock` keeps a trailing newline; `HtmlInline` does not).
- Empty `href` / `src` when, after leading C0 controls, spaces, and tabs (code points `<= 0x20`), the remainder is a `javascript:`, `vbscript:`, `data:`, or `file:` URL. The scheme check is case-insensitive (`FILE:foo` is emptied). The attribute is still written (`href=""` / `src=""`).

`http:`, `https:`, and relative URLs still pass. Attributes are not rewritten. `safe` does not change the parse, does not filter HTML tag-by-tag, and does not cap parse or render cost.

## Limits

`parse`, `render_html`, `to_html`, and `bamark` have no timeout, no max input size, and no nest-depth cap. `safe` does not add those.

CommonMark constructs that are expensive by design (many emphasis delimiters, unmatched `[`, large fenced or HTML blocks) are valid and will be finished, not refused. Local scans have spec or engine caps — link labels longer than 1000 characters fail; unquoted destinations nested past 32 parentheses fail — but those do not bound whole-document time or memory.

Callers that accept untrusted Markdown must bound bytes and wall time themselves. More: [docs/usage.md](docs/usage.md#limits).

## Tests

```bash
baml toolchain use 0.19.1-nightly.20260911.a
baml check          # type-check
baml test           # unit tests + all 652 spec examples
```

`baml test` is the day-to-day suite. Each CommonMark section is a test that calls `spec_failures(section)` (`baml_src/ns_spec/runner.baml`) and asserts an empty list of failing example numbers. The runner reads `vendor/commonmark-0.31.2/spec-tests.json` (length asserted to be 652). Spec comparison uses default `to_html` (`safe = false`).

The upstream process-per-example harness still works against a packed binary. Cold start is ~1s per example, so it is slow; prefer `baml test`:

```bash
baml pack cli.bamark --output ./bamark
python3 vendor/commonmark-0.31.2/spec_tests.py \
  --spec vendor/commonmark-0.31.2/spec.txt \
  --program ./bamark
```

GitHub Actions (`.github/workflows/test.yml`) runs `baml check` and `baml test` on every push and pull request. More: [docs/testing.md](docs/testing.md).

## Repository layout

```
baml.toml                 BAML package + Python/TypeScript generators
baml_src/main.baml        parse, render_html, to_html (namespace root)
baml_src/ns_ast/          Document, Block, Inline, ListItem, LinkRef
baml_src/ns_scan/         preprocess, LineScan (tab stop 4, chars() array)
baml_src/ns_block/        phase 1: open stack, BlockStartContext rule table
baml_src/ns_inline/       phase 2: Subject + InlineParseContext rule table
baml_src/ns_html/         HTML renderer (iterative) and escaping
baml_src/ns_cli/          bamark
baml_src/ns_spec/         JSON spec runner used by baml test
docs/                     usage, AST, extensions, architecture, HTML, testing
vendor/commonmark-0.31.2/ spec.txt, spec-tests.json, spec_tests.py
vendor/html5-entities.json WHATWG named-character table (also embedded in-tree)
.github/workflows/         validation and tagged-release packaging on the pinned BAML nightly
CHANGELOG.md              tagged releases
generated/                created by baml generate; not committed
```

Namespaces are `ns_*` directories under `baml_src/`. Files in the same folder share a scope. Cross-namespace names are `root.<ns>.<Name>` (for example `root.ast.Document`, `root.block.commonmark_options`).

## Language bridges (optional)

```bash
baml generate
```

That writes `generated/python/baml_sdk` and `generated/typescript/baml_sdk` from the `[generator.python]` and `[generator.typescript]` blocks in `baml.toml`. Consumers install the matching runtime (`baml-bridge` / `@boundaryml/baml-bridge`) for this toolchain and import the generated package. The engine itself stays in BAML.

## Documentation

- [CHANGELOG.md](CHANGELOG.md) — tagged releases; current release `v0.9.1`
- [docs/README.md](docs/README.md) — documentation index
- [docs/usage.md](docs/usage.md) — library, CLI, and [limits](docs/usage.md#limits)
- [docs/coverage.md](docs/coverage.md) — CommonMark 0.31.2 construct map and out of scope
- [docs/ast.md](docs/ast.md) — `Document` / `Block` / `Inline` fields
- [docs/extensions.md](docs/extensions.md) — `ParseOptions`, `BlockStart`, `InlineParseRule`
- [docs/architecture.md](docs/architecture.md) — two-phase engine and `baml_src/` map
- [docs/html.md](docs/html.md) — renderer, escaping, and `safe` mode
- [docs/testing.md](docs/testing.md) — `baml test` and `spec_tests.py`

## License

Copyright 2026 Ramon C Horomnea.

Licensed under the [Apache License 2.0](LICENSE). Keep [NOTICE](NOTICE) with the code.

Vendored CommonMark specification and conformance fixtures (`vendor/commonmark-0.31.2/`) are [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). `spec_tests.py` is BSD-2-Clause. HTML named character references are from WHATWG; see NOTICE for the entity-data licenses.
