# CommonMark.baml

A CommonMark 0.31.2 parser in [BAML](https://docs.boundaryml.com): Markdown → typed AST → HTML. No GFM in this tree. Copyright 2026 Ramon C Horomnea. Licensed under the [Apache License 2.0](LICENSE); keep [NOTICE](NOTICE) with the code. Vendored spec fixtures are [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

The engine is rule-table driven so a later dialect can append block starts (`ParseOptions.block_starts`) and inline rules (`ParseOptions.inline_rules`) without rewriting phase 1/2. `commonmark_options()` fills both tables. Extra block starts implement `BlockStart` and declare `triggers()` / `allow_indented()`. Extra inline rules implement `InlineParseRule` and declare `triggers()` so their starter characters are not swallowed as plain text.

Tested on **BAML toolchain 0.18.0** (`baml toolchain use 0.18.0`).

## Public API

BAML cannot hide namespaces. The **supported** v1 surface is:

```baml
function parse(markdown: string, options: ParseOptions = commonmark_options()) -> Document
function render_html(document: Document, safe: bool = false) -> string
function to_html(markdown: string, options: ParseOptions = commonmark_options(), safe: bool = false) -> string
```

plus the AST types in `ns_ast` (`Document`, `Block`, `Inline`, and their classes) and `ParseOptions` / `BlockStart` / `InlineParseRule` for dialects.

`Parser`, `Open`, scanners, spec helpers, and other `ns_*` functions are **unsupported** internals: they may change without a major version.

Call `parse(md)` / `to_html(md)` for CommonMark. A future dialect would pass `options` by name: `parse(md, options = gfm_options())`.

After `parse()`, `Paragraph.raw` / `Heading.raw` are empty and `last_line_blank` is false on every node (`List.tight` is already computed). When you build an AST for `render_html`, set `raw: ""` and `last_line_blank: false`.

### `safe` mode

`to_html` is **not** safe for untrusted Markdown by default: raw HTML and URL schemes such as `javascript:` pass through, matching CommonMark.

Pass `safe = true` to:

- omit raw HTML (`<!-- raw HTML omitted -->`)
- empty `href` / `src` values whose scheme is `javascript:`, `vbscript:`, `data:`, or `file:` (case-insensitive, after leading space/tab)

That is HTML/script mitigation, not a general sanitizer: `http:` / `https:` / relative URLs still pass, and attributes are not rewritten because raw HTML is dropped wholesale. `safe` does not bound CPU; adversarial documents can still be expensive.

## CLI

```bash
baml pack cli.bamark --output ./bamark
printf '%s\n' '# Hi' | ./bamark
# <h1>Hi</h1>
printf '%s\n' '[x](javascript:alert(1))' | ./bamark --safe
```

`bamark` reads all of stdin as Markdown and writes raw HTML (not JSON). That matches `spec_tests.py --program`. It reads `/dev/stdin` (Unix and Windows Git Bash / WSL). Stdin must be UTF-8.

- `--safe` — same as `to_html(..., safe = true)`
- `-h` / `--help`, `-V` / `--version` (`bamark 0.31.2` is the CommonMark spec this engine targets)

`baml run to_html -- --markdown '# Hi'` is fine for debugging; it JSON-quotes the string. Cold start of a packed binary is about a second, so the process-per-example spec harness is slow; `baml test` already covers all 652 examples.

## Tests

```bash
baml toolchain use 0.18.0
baml check
baml test
python3 vendor/commonmark-0.31.2/spec_tests.py \
  --spec vendor/commonmark-0.31.2/spec.txt \
  --program ./bamark
```

Fixtures are CommonMark 0.31.2 (`vendor/commonmark-0.31.2/`). 652/652 examples.

## Layout

- `baml_src/main.baml` — public functions
- `ns_ast/` — document tree
- `ns_scan/` — line cursor (tab stop 4, NUL → U+FFFD; indexes a `chars` array)
- `ns_block/` — phase 1, `ParseOptions.block_starts`
- `ns_inline/` — phase 2, `ParseOptions.inline_rules`
- `ns_html/` — HTML renderer
- `ns_cli/` — `bamark`
- `ns_spec/` — JSON spec runner
