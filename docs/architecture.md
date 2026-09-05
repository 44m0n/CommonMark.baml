# Architecture

The engine is a two-phase CommonMark parse: a line-oriented block phase, then an inline phase over paragraph and heading source. Rule tables on `ParseOptions` (`block_starts`, `inline_rules`) drive both phases. `commonmark_options()` fills those tables for 0.31.2.

Call `parse` / `to_html` as in [usage.md](usage.md). Dialects append starts and rules; see [extensions.md](extensions.md). Node shapes are in [ast.md](ast.md). HTML emission is in [html.md](html.md). Resource limits (no timeout, no max size) are in [usage.md](usage.md#limits). Spec coverage is in [coverage.md](coverage.md) and [testing.md](testing.md).

## Phase 1 — blocks (`ns_block`)

`root.block.parse_document`:

1. `root.scan.preprocess(markdown)` (`\r\n` / `\r` → `\n`; `U+0000` → `U+FFFD`)
2. For each line, `Parser.incorporate_line`
3. Finalize the open-block stack (`finalize_tip` until empty)
4. Phase 2 (`parse_inlines_tree`)

Tab columns use stop 4. `advance_offset` can consume only part of a tab and expand the remainder to spaces when appending a line.

Each line is a `LineScan`: the line string plus a materialized `chars()` array. Block and inline scanners index that array. In this BAML runtime `String.at(i)` is O(i), so a per-character walk of the string was quadratic on long lines.

`incorporate_line` (non-blank):

1. **Continue** open blocks from the document down via `BlockOps.continue_line` → `ContinueResult.Ok` / `Stop` / `Done`. `Done` ends the line. `Stop` records `last_matched_index` and stops matching further parents.
2. **Start** new blocks: try `options.block_starts` in order, skipping via `block_start_could_match` (indent + `triggers()`). A start returns `StartMatch.None`, `Container`, or `Leaf`. `Container` (block quote, list item) keeps the start loop going so nested starts can fire on the same line. `Leaf` (heading, fence, thematic break, HTML block, indented code) stops further starts.
3. **Remainder:** lazy continuation of a paragraph (`allows_lazy`), or `add_line` onto a leaf that `accepts_lines`, or open a paragraph.

Blank lines take a shorter path (`incorporate_blank_line`) so lists, fenced code, and HTML blocks can keep consuming blanks where the spec requires it.

## Phase 2 — inlines (`ns_inline`)

`parse_inlines_tree` walks the block tree with an explicit work stack (`BlockQuote.children`, then each `ListItem.children`). For each `Paragraph` and `Heading` it sets `children = root.inline.parse_inlines(raw, document.refs, …)` using `options.inline_rules`. Then `clear_parser_fields`: `raw = ""` on `Paragraph` and `Heading`; `last_line_blank = false` on every `Block` and `ListItem`. `List.tight` is not cleared.

## Block start order

`commonmark_options().block_starts`:

1. `BlockQuoteStart` (`>`) — `StartMatch.Container`
2. `AtxHeadingStart` (`#`) — `Leaf`
3. `FencedCodeStart` (`` ` ``, `~`) — `Leaf`
4. `HtmlBlockStart` (`<`) — `Leaf` (HTML block types 1–7)
5. `SetextHeadingStart` (`=`, `-`) — `Leaf` (only when the last matched open is a paragraph)
6. `ThematicBreakStart` (`*`, `-`, `_`) — `Leaf`
7. `ListItemStart` (`*`, `-`, `+`, `0`–`9`) — `Container` (opens a `List` if needed, then a `ListItem`)
8. `IndentedCodeStart` — `Leaf`; `allow_indented() == true`, empty `triggers()`

## `block_start_could_match`

From `ns_block/parser.baml`:

- if `parser.indented`: only starts with `allow_indented()` (so indented code can run; ATX/quotes/etc. do not)
- else if `allow_indented()` and `triggers()` is empty: **false** (indented code does not fire when the line is not indented)
- else if `triggers()` is empty: always try
- else the first nonspace character must be in `triggers()`

## Inline rule order

`commonmark_inline_rules()`:

1. `BackslashRule`
2. `NewlineRule`
3. `CodeSpanRule`
4. `EntityRule`
5. `AutolinkRule`
6. `HtmlInlineRule`
7. `BangRule`
8. `OpenBracketRule`
9. `CloseBracketRule`
10. `EmphasisRule`

`run_inline_parse` scans the subject. A character is special if `is_inline_special` or it appears in `extra_trigger_chars(rules)` (first character of each rule’s `triggers()`). Special characters go through `apply_inline_rules`; if no rule consumes them, they become `Text`. Everything else is coalesced as plain text.

`is_inline_special` characters: `\`, `` ` ``, `*`, `_`, `[`, `]`, `!`, `<`, `&`, `\n`. Extra trigger characters exist so a dialect rule on e.g. `%` is not swallowed as plain text.

## `baml_src/` layout

BAML namespaces are `ns_*` directories under `baml_src/`. No imports: files in the same folder share a scope. Cross-namespace names are `root.<ns>.<Name>`. Files directly in `baml_src/` are the `root` namespace.

| Path | Namespace | Role |
| --- | --- | --- |
| `baml_src/main.baml` | `root` | `parse`, `render_html`, `to_html` |
| `ns_ast/` | `root.ast` | `Document`, `Block`, `Inline`, … |
| `ns_scan/` | `root.scan` | `preprocess`, `LineScan` (`chars()` array), tab stop 4 |
| `ns_block/` | `root.block` | phase 1, `ParseOptions`, `BlockStart` |
| `ns_inline/` | `root.inline` | phase 2, `InlineParseRule` |
| `ns_html/` | `root.html` | HTML renderer |
| `ns_cli/` | `root.cli` | `bamark` |
| `ns_spec/` | `root.spec` | spec JSON runner |

## Public vs internals

BAML cannot hide namespaces. The **supported** v1 surface is:

```baml
function parse(markdown: string, options: ParseOptions = commonmark_options()) -> Document
function render_html(document: Document, safe: bool = false) -> string
function to_html(markdown: string, options: ParseOptions = commonmark_options(), safe: bool = false) -> string
```

plus AST types in `root.ast`, and `ParseOptions` / `BlockStart` / `InlineParseRule` / `commonmark_options` for dialects.

**Unsupported** internals (may change without a major version): `Parser`, `Open`, `OpenKind`, `BlockOps`, `LineScan`, `Subject`, the spec runner (`ns_spec`), `bamark` helpers (`ns_cli`), and other `ns_*` functions not listed above.

`BlockStart.try_open` and `InlineParseRule.parse` still take `Parser` / `Subject`. Those parameter types are internals; the interfaces are the dialect hook.

## Fork vs plugin

A **new block kind that continues across lines** must change:

- `OpenKind` (`ns_block/open.baml`)
- a `BlockOps` implementor (`continue_line`, `finalize`, `can_contain`, …)
- the `Block` union (`ns_ast/blocks.baml`)
- the `match` in `ns_html/render.baml`

That is a fork, not a plugin.

**Leaf** blocks that reuse existing nodes (`ThematicBreak`, `CodeBlock`, …) can be plugins: implement `BlockStart`, `push_child` an existing opener, append to `ParseOptions.block_starts`. `PercentBreakStart` in `ns_block/options.baml` is the in-tree example (`%%%` → `ThematicBreak`). Inline extras that cannot add union variants should emit existing nodes such as `HtmlInline`.

## HTML renderer

`ns_html/render.baml` is iterative: `HtmlJob` stacks for block sequences, list items, and tight-item children; `InlineJob` stacks for `Emph` / `Strong` / `Link` children. Nested lists, quotes, and emphasis do not recurse in BAML call frames. `escape_html` / `escape_href` also walk `chars()` arrays.

## See also

- [usage.md](usage.md) — `parse`, `to_html`, `safe`, [limits](usage.md#limits)
- [extensions.md](extensions.md) — `BlockStart`, `InlineParseRule`
- [ast.md](ast.md) — node types
- [html.md](html.md) — renderer and escaping
- [testing.md](testing.md) — spec fixtures
- [coverage.md](coverage.md) — 0.31.2 construct map
