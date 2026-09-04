# CommonMark.baml

A CommonMark 0.31.2 parser in [BAML](https://docs.boundaryml.com): Markdown → typed AST → HTML. No GFM in this tree. The engine is rule-table driven so a later dialect can append block starts (`ParseOptions.block_starts`) and inline rules (`ParseOptions.inline_rules`) without rewriting phase 1/2. `commonmark_options()` fills both tables. Extra inline rules implement `InlineParseRule` and declare `triggers()` so their starter characters are not swallowed as plain text.

## Public API

```baml
function parse(markdown: string, options: ParseOptions = commonmark_options()) -> Document
function render_html(document: Document, safe: bool = false) -> string
function to_html(markdown: string, options: ParseOptions = commonmark_options(), safe: bool = false) -> string
```

Call `parse(md)` / `to_html(md)` for CommonMark. A future dialect would pass `options` by name: `parse(md, options = gfm_options())`.

`to_html` is **not** safe for untrusted Markdown: raw HTML and URL schemes such as `javascript:` pass through, matching CommonMark. Pass `safe = true` to omit raw HTML (`<!-- raw HTML omitted -->`) and to empty `javascript:`, `vbscript:`, and `data:` `href`/`src` values.

## CLI

```bash
baml pack cli.bamark --output ./bamark
printf '%s\n' '# Hi' | ./bamark
# <h1>Hi</h1>
```

`bamark` reads all of stdin as Markdown and writes raw HTML (not JSON). That matches `spec_tests.py --program`. It reads `/dev/stdin`, which is the portable path on Unix and on Windows Git Bash / WSL.

`baml run to_html -- --markdown '# Hi'` is fine for debugging; it JSON-quotes the string.

## Tests

```bash
baml test
python3 vendor/commonmark-0.31.2/spec_tests.py \
  --spec vendor/commonmark-0.31.2/spec.txt \
  --program ./bamark
```

Fixtures are CommonMark 0.31.2 (`vendor/commonmark-0.31.2/`; spec text is [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)). 652/652 examples.

## Layout

- `baml_src/main.baml` — public functions
- `ns_ast/` — document tree
- `ns_scan/` — line cursor (tab stop 4, NUL → U+FFFD)
- `ns_block/` — phase 1, `ParseOptions.block_starts`
- `ns_inline/` — phase 2, `ParseOptions.inline_rules`
- `ns_html/` — HTML renderer
- `ns_cli/` — `bamark`
- `ns_spec/` — JSON spec runner
