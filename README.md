# CommonMark.baml

A [CommonMark](https://spec.commonmark.org/0.31.2/) 0.31.2 parser in [BAML](https://docs.boundaryml.com): Markdown → typed AST → HTML. This tree does not implement GFM. Copyright 2026 Ramon C Horomnea. Licensed under the [Apache License 2.0](LICENSE); keep [NOTICE](NOTICE) with the code. Vendored spec fixtures are [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). HTML named character references are from WHATWG (see NOTICE).

Tested on BAML toolchain 0.18.0 (`baml toolchain use 0.18.0`). 652/652 CommonMark examples pass.

## Features

- CommonMark 0.31.2 only (no GFM in this tree)
- `parse` → typed `Document`; `render_html` / `to_html` → HTML
- Optional `safe` mode: HTML/script mitigation, not a general sanitizer
- Rule-table dialects via `ParseOptions.block_starts` and `ParseOptions.inline_rules`
- Packed CLI `bamark` (file or stdin → raw HTML)

## Quick start

```bash
baml toolchain use 0.18.0
```

Library (defaulted parameters must be passed by name):

```bash
baml run -e 'to_html("# Hi\n")'
```

```baml
to_html("# Hi\n")
let doc = parse("# Hi\n");
render_html(doc)
to_html("[x](javascript:alert(1))\n", safe = true)
```

`parse(md)` / `to_html(md)` use `commonmark_options()`. A later dialect would pass `options` by name: `parse(md, options = …)`.

CLI:

```bash
baml pack cli.bamark --output ./bamark
printf '%s\n' '# Hi' | ./bamark
./bamark README.md
printf '%s\n' '[x](javascript:alert(1))' | ./bamark --safe
```

`bamark` reads Markdown from a file or stdin and writes raw HTML. Input must be UTF-8. `-` or an omitted file reads `/dev/stdin` (Unix, Git Bash, WSL). Native Windows cmd/PowerShell has no `/dev/stdin`; pass a path. `-h` / `--help` and `-V` / `--version` (`bamark 0.31.2` is the CommonMark spec this engine targets). `--safe` is the same as `to_html(..., safe = true)`.

`baml run to_html -- --markdown '# Hi'` is fine for debugging; it JSON-quotes the string. Cold start of a packed binary is about a second, so the process-per-example spec harness is slow; `baml test` already covers all 652 examples.

## Public API

BAML cannot hide namespaces. The supported v1 surface is:

```baml
function parse(markdown: string, options: ParseOptions = commonmark_options()) -> Document
function render_html(document: Document, safe: bool = false) -> string
function to_html(markdown: string, options: ParseOptions = commonmark_options(), safe: bool = false) -> string
```

plus the AST types in `ns_ast` (`Document`, `Block`, `Inline`, and their classes) and `ParseOptions` / `BlockStart` / `InlineParseRule` for dialects. Field-level AST notes are in [docs/ast.md](docs/ast.md).

`Parser`, `Open`, scanners, spec helpers, and other `ns_*` functions are unsupported internals: they may change without a major version.

After `parse()`, `Paragraph.raw` / `Heading.raw` are empty; `last_line_blank` is false on every node; `List.tight` is already computed. When building an AST for `render_html`, set `raw: ""` and `last_line_blank: false`.

## Safe mode

`to_html` is not safe for untrusted Markdown by default: raw HTML and URL schemes such as `javascript:` pass through, matching CommonMark.

Pass `safe = true` to omit raw HTML as `<!-- raw HTML omitted -->` and to empty `href` / `src` values whose scheme is `javascript:`, `vbscript:`, `data:`, or `file:` (case-insensitive, after leading space/tab including other C0). That is HTML/script mitigation, not a general sanitizer: `http:` / `https:` / relative URLs still pass; attributes are not rewritten; CPU is not bounded.

Details: [docs/html.md](docs/html.md).

## Extensions

The engine is rule-table driven. `ParseOptions.block_starts` and `ParseOptions.inline_rules` are the extension points; `commonmark_options()` fills both. Extra `BlockStart` implementors provide `triggers()`, `allow_indented()`, and `try_open()`. Extra `InlineParseRule` implementors provide `triggers()` so starter characters are not swallowed as plain text.

This tree ships CommonMark only. Details: [docs/extensions.md](docs/extensions.md).

## Tests

```bash
baml toolchain use 0.18.0
baml check
baml test
python3 vendor/commonmark-0.31.2/spec_tests.py --spec vendor/commonmark-0.31.2/spec.txt --program ./bamark
```

Fixtures are CommonMark 0.31.2 (`vendor/commonmark-0.31.2/`). 652/652 examples. The Python harness needs a packed `./bamark`. More: [docs/testing.md](docs/testing.md).

## Layout

- `baml_src/main.baml` — public functions
- `ns_ast/` — document tree
- `ns_scan/` — line cursor (tab stop 4, NUL → U+FFFD)
- `ns_block/` — phase 1
- `ns_inline/` — phase 2
- `ns_html/` — HTML renderer
- `ns_cli/` — `bamark`
- `ns_spec/` — JSON spec runner
- `docs/` — usage, coverage, AST, extensions, architecture

Namespaces live under `baml_src/`. [docs/architecture.md](docs/architecture.md) walks the two-phase parse.

## Documentation

- [docs/README.md](docs/README.md) — documentation index
- [docs/usage.md](docs/usage.md) — library and CLI
- [docs/coverage.md](docs/coverage.md) — CommonMark 0.31.2 conformance
- [docs/ast.md](docs/ast.md) — `Document` / `Block` / `Inline`
- [docs/extensions.md](docs/extensions.md) — `ParseOptions`, `BlockStart`, `InlineParseRule`
- [docs/architecture.md](docs/architecture.md) — two-phase engine and layout
- [docs/html.md](docs/html.md) — renderer and `safe` mode
- [docs/testing.md](docs/testing.md) — `baml test` and `spec_tests.py`

## License

Copyright 2026 Ramon C Horomnea.

Licensed under the [Apache License 2.0](LICENSE). Keep [NOTICE](NOTICE) with the code.

Vendored CommonMark specification and conformance fixtures (`vendor/commonmark-0.31.2/`) are [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). HTML named character references are from WHATWG; see NOTICE for the entity-data licenses.
