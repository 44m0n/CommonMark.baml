# Extending the parser

The engine is rule-table driven. Phase 1 walks `ParseOptions.block_starts`; phase 2 walks `ParseOptions.inline_rules`. A dialect appends (or, if it must preempt CommonMark, inserts) entries on those arrays. It does not rewrite `incorporate_line` or `run_inline_parse`.

`commonmark_options()` fills both tables for CommonMark 0.31.2. See [Architecture](architecture.md) for the two-phase pipeline, [AST](ast.md) for node types, [HTML](html.md) for rendering, and [Usage](usage.md) for `parse` / `to_html`.

This page is the supported way to add syntax. `BlockStartContext` and `InlineParseContext` are the stable extension boundaries. `Parser`, `Open`, `BlockOps`, and `Subject` remain internals and may change.

## ParseOptions

```baml
class ParseOptions {
    block_starts: BlockStart[],
    inline_rules: root.inline.InlineParseRule[],
}
```

Defined in `baml_src/ns_block/options.baml`. `commonmark_options()` returns a **new** `ParseOptions` each call:

```baml
function commonmark_options() -> ParseOptions {
    ParseOptions {
        block_starts: [
            BlockQuoteStart {  },
            AtxHeadingStart {  },
            FencedCodeStart {  },
            HtmlBlockStart {  },
            SetextHeadingStart {  },
            ThematicBreakStart {  },
            ListItemStart {  },
            IndentedCodeStart {  },
        ],
        inline_rules: root.inline.commonmark_inline_rules(),
    }
}
```

Public entry points (`baml_src/main.baml`) default `options` to that factory:

```baml
function parse(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
) -> root.ast.Document

function to_html(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
    safe: bool = false,
) -> string
```

Defaulted parameters must be passed by name:

```baml
parse(md, options = my_options())
to_html(md, options = my_options())
to_html(md, options = my_options(), safe = true)
```

`parse(md, my_options())` does not compile.

## BlockStart

`baml_src/ns_block/options.baml`:

```baml
enum StartMatch {
    None,
    Container,
    Leaf,
}

interface BlockStartContext {
    function is_indented(self) -> bool
    function line_chars(self) -> string[]
    function next_nonspace(self) -> int
    function emit_thematic_break(self) -> void
    function consume_rest(self) -> void
}

interface BlockStart {
    function name(self) -> string
    function try_open(self, context: BlockStartContext) -> StartMatch
    function triggers(self) -> string[] { [] }
    function allow_indented(self) -> bool { false }
}
```

`name()` is for debugging. Dispatch uses `triggers()` and `allow_indented()`, not `name()`. The test `"custom block start dispatches on triggers not name"` in the same file asserts that `PercentBreakStart.name()` is not `"indented_code"` and that matching still depends on `"%"`.

### How the parser picks a start

For each remaining line position, `Parser.incorporate_line` (`baml_src/ns_block/parser.baml`) does:

1. `find_next_nonspace()`
2. For each `start` in `options.block_starts` **in array order**
3. Skip if `block_start_could_match` is false
4. Call `start.try_open(parser)`
5. First non-`None` wins that round

`StartMatch.Container` means a nestable opener was pushed (block quote, list item). The outer loop keeps looking for further starts on the same line (quote containing a list containing a heading). `StartMatch.Leaf` means a leaf was pushed (ATX heading, fence, thematic break); the start loop stops. If every start returns `None`, the remainder becomes a paragraph (or lazy continuation).

`block_start_could_match(start, parser, ch)` — `ch` is the first non-space character:

| Line | Start | Tried? |
| --- | --- | --- |
| Indented (`parser.indent >= 4`) | `allow_indented()` is true | Yes (triggers are **not** consulted) |
| Indented | `allow_indented()` is false | No |
| Not indented | `allow_indented()` **and** empty `triggers()` | No — this is the `IndentedCodeStart` pattern, so indented code does not fire on a flush-left line |
| Not indented | empty `triggers()` | Yes |
| Not indented | non-empty `triggers()` | Yes only if `ch` is in `triggers()` |

So: **matching is on `triggers()`, not `name()`**. Empty `triggers()` plus `allow_indented() == true` is how indented code opts into indented lines and out of flush-left ones.

### Typical `try_open` (leaf)

Use the context rather than parser fields. The stable block context intentionally exposes only the operations needed by the supported leaf extension path:

- Check `context.is_indented()` and inspect `context.line_chars()` from `context.next_nonspace()`.
- If it is not your syntax, return `StartMatch.None` without emitting a node.
- `context.emit_thematic_break()` closes unmatched nodes and emits a `ThematicBreak`.
- `context.consume_rest()` consumes the remaining characters on the line.
- Return `StartMatch.Leaf`.

The context currently supports custom thematic-break syntax. New containers and other block node forms require an engine change because they need `Open` / `BlockOps`, which are intentionally not public extension dependencies.

### Built-in starts

Order is the `commonmark_options()` array. Later starts run only if every earlier `try_open` returned `None` (or was skipped by `block_start_could_match`).

| Start | `triggers()` | `allow_indented()` | Match |
| --- | --- | --- | --- |
| `BlockQuoteStart` | `>` | false | `Container` |
| `AtxHeadingStart` | `#` | false | `Leaf` |
| `FencedCodeStart` | `` ` `` `~` | false | `Leaf` |
| `HtmlBlockStart` | `<` | false | `Leaf` |
| `SetextHeadingStart` | `=` `-` | false | `Leaf` (needs an open paragraph as `last_matched()`) |
| `ThematicBreakStart` | `*` `-` `_` | false | `Leaf` |
| `ListItemStart` | `*` `-` `+` `0`–`9` | false | `Container` |
| `IndentedCodeStart` | `[]` | true | `Leaf` |

Append custom starts at the **end** unless you need to preempt CommonMark. Inserting earlier can steal lines from quotes, fences, lists, and thematic breaks and break spec conformance.

`SetextHeadingStart` is an in-tree parser rule that inspects internal parser state before it converts a paragraph. That kind of context-sensitive block transformation is intentionally outside the stable extension boundary.

### Worked example: `PercentBreakStart`

Already in `baml_src/ns_block/options.baml`. A line of three or more `%` characters, with spaces or tabs allowed between them, becomes a thematic break (`<hr />`) through `BlockStartContext.emit_thematic_break()` — no new `Block` variant.

```baml
class PercentBreakStart {
    implements BlockStart {
        function name(self) -> string throws never {
            "percent_break"
        }

        function triggers(self) -> string[] throws never {
            ["%"]
        }

        function allow_indented(self) -> bool throws never {
            false
        }

        function try_open(self, context: BlockStartContext) -> StartMatch throws never {
            if (context.is_indented()) {
                return StartMatch.None;
            }
            if (!looks_like_percent_break(context.line_chars(), context.next_nonspace())) {
                return StartMatch.None;
            }
            context.emit_thematic_break();
            context.consume_rest();
            StartMatch.Leaf
        }
    }
}
```

`looks_like_percent_break` counts `%` from `next_nonspace` to end of line and rejects any other non-space/tab. Need `count >= 3`.

Append it:

```baml
let options = commonmark_options();
options.block_starts.push(PercentBreakStart {  });
to_html("%%%\n", options = options)  // "<hr />\n"
```

From `ns_block` tests the call is `root.to_html(..., options = options)` because `to_html` lives in the root namespace. Without `options`, `%%%` is a paragraph (`<p>%%%</p>\n`). `%foo` stays a paragraph even with the start registered.

## InlineParseRule

`baml_src/ns_inline/rules.baml`:

```baml
interface InlineParseContext {
    function peek(self) -> string?
    function peek_at(self, offset: int) -> string?
    function bump(self) -> string?
    function position(self) -> int
    function input(self) -> string
    function chars(self) -> string[]
    function advance_to(self, position: int) -> void
    function push_node(self, node: root.ast.Inline) -> void
    function push_text(self, text: string) -> void
}

interface InlineParseRule {
    function name(self) -> string throws never
    function parse(self, context: InlineParseContext) -> bool throws never
    function triggers(self) -> string[] throws never {
        let none: string[] = [];
        none
    }
}
```

`parse` returns `true` if it consumed input. If it looks at the context and bails, it must restore the cursor (`context.advance_to(start)`) and return `false`.

`run_inline_parse` walks the subject. For each character:

- If `is_inline_special(ch)` **or** `ch` is in `extra_trigger_chars(rules)`, it tries **every** rule in `inline_rules` order via `apply_inline_rules`. The first `parse` that returns `true` wins. If all return `false`, that one character becomes text.
- Otherwise `consume_plain_text` swallows a run of ordinary characters, **including** any character you forgot to declare as a trigger.

Built-in special characters (`is_inline_special` in `baml_src/ns_inline/parse.baml`):

```
\ ` * _ [ ] ! < & newline
```

`extra_trigger_chars(rules)` concatenates the **first character** of each string in each rule’s `triggers()`. Those characters are not swallowed by `consume_plain_text`.

If you add a rule for `%span%` you **must** declare `triggers() = ["%"]`. Otherwise `%` is never offered to `parse()`.

Built-in rules (`commonmark_inline_rules()`) do **not** set `triggers()`. They rely on `is_inline_special`:

`BackslashRule`, `NewlineRule`, `CodeSpanRule`, `EntityRule`, `AutolinkRule`, `HtmlInlineRule`, `BangRule`, `OpenBracketRule`, `CloseBracketRule`, `EmphasisRule`.

Push custom rules at the end so CommonMark still sees `\`, `` ` ``, `*`, `_`, `[`, `]`, `!`, `<`, `&`, and newlines first. Order among custom rules matters the same way: first `true` wins.

### `InlineParseContext`

`InlineParseContext` is the stable API for rules. Its methods are the operations a rule needs without exposing delimiter, bracket, reference, or linked-list state:

| Method | Role |
| --- | --- |
| `peek()` / `peek_at(offset)` | Read the current character or a lookahead |
| `bump()` | Consume one character |
| `position()` / `advance_to(p)` | Read or set the cursor; restore it on a failed match |
| `input()` / `chars()` | Read the source line and its materialized characters |
| `push_node(node)` | Emit a finished `root.ast.Inline` |
| `push_text(text)` | Buffer text, coalesced by the parser |

From another namespace implement `root.inline.InlineParseRule` with a `root.inline.InlineParseContext` parameter. `Subject` and its helper functions are unsupported internals.

### Worked example: `PercentSpanRule`

Already in `baml_src/ns_inline/parse.baml`. `%inner%` emits `HtmlInline { literal: "<span>" }`, then the inner text, then `HtmlInline { literal: "</span>" }`. The HTML renderer needs no new `Inline` variant.

```baml
class PercentSpanRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "percent_span"
        }

        function triggers(self) -> string[] throws never {
            ["%"]
        }

        function parse(self, context: InlineParseContext) -> bool throws never {
            if (context.peek() != "%") {
                return false;
            }
            let start = context.position();
            let _ = context.bump();
            let i = context.position();
            let line = context.input();
            let chars = context.chars();
            while (i < chars.length()) {
                if (chars.at(i) == "%") {
                    let inner = line.slice(context.position(), i);
                    context.advance_to(i + 1);
                    context.push_node(root.ast.HtmlInline { literal: "<span>" });
                    context.push_text(inner);
                    context.push_node(root.ast.HtmlInline { literal: "</span>" });
                    return true;
                }
                i += 1;
            }
            context.advance_to(start);
            false
        }
    }
}
```

```baml
let options = root.block.commonmark_options();
options.inline_rules.push(PercentSpanRule {  });
to_html("hello %x% *y*", options = options)
// <p>hello <span>x</span> <em>y</em></p>
```

Unclosed `%b` restores the cursor and returns `false`; the `%` is then emitted as text. Without `options`, `hello %x%` stays a paragraph of text.

Those `HtmlInline` nodes are omitted when `safe = true` (renderer-only; the AST is unchanged):

```baml
to_html("hello %x%", options = options, safe = true)
// <p>hello <!-- raw HTML omitted -->x<!-- raw HTML omitted --></p>
```

## AST constraint

`Block` and `Inline` are **closed unions**. The HTML renderer `match`es them exhaustively (`push_block_work` / `render_inlines` in `baml_src/ns_html/render.baml`). A plugin cannot add `Strikethrough` or `Table` nodes without editing:

- `baml_src/ns_ast/blocks.baml` or `baml_src/ns_ast/inlines.baml`
- `baml_src/ns_html/render.baml`
- for multi-line blocks, `OpenKind` and a `BlockOps` implementor in `ns_block`

The supported plugin strategy is to **map new syntax onto existing nodes**: `ThematicBreak`, `HtmlInline`, `HtmlBlock`, `CodeBlock`, `Paragraph`, `Heading`, `Emph`, `Strong`, and so on. `PercentBreakStart` and `PercentSpanRule` are the in-tree models.

Current unions (`baml_src/ns_ast/`):

```baml
type Block = Paragraph | Heading | ThematicBreak | CodeBlock | HtmlBlock | BlockQuote | List;

type Inline = Text
    | SoftBreak
    | HardBreak
    | CodeSpan
    | Emph
    | Strong
    | Link
    | Image
    | HtmlInline
    | Autolink;
```

`ListItem` is not a `Block`. It only appears as `List.children`. It has `children` and `last_line_blank` — no `checked` field.

### Hypothetical: GFM strikethrough `~~x~~`

Implement `InlineParseRule` with `triggers() = ["~"]`. Tilde is **not** in `is_inline_special`; without `triggers()`, `consume_plain_text` never calls your `parse`.

`~` **is** a fenced-code trigger at **block** level (`FencedCodeStart` triggers `` ` `` and `~`). A line of `~~~` opens a `CodeBlock` and never reaches inline parse. `~~x~~` on its own line (only two tildes at the start) can still become a paragraph and then an inline rule.

Emit existing nodes, for example `HtmlInline { literal: "<del>" }` … text … `HtmlInline { literal: "</del>" }`, or fork the `Inline` union to add `Strike { children: Inline[] }` and teach the renderer. The first is a plugin; the second is a language change.

### Hypothetical: task lists

`ListItem` has no checked field. A `- [x] item` plugin cannot store a checkbox on the item without AST changes. Mapping the marker to `HtmlInline` inside the item’s paragraph is possible but crude (and subject to `safe` mode; see below). Treat real task lists as an AST + renderer change, not a `BlockStart`-only plugin.

### Hypothetical: tables

A table is a new `Block` variant plus `BlockOps` (continue row lines, `finalize`, `can_contain`) plus `OpenKind`. That is not a `BlockStart`-only plugin. A `BlockStart` can recognize the delimiter row, but without ops and a node type there is nowhere to keep cells across lines.

## BlockOps / Open — not a stable extension API

Continuing containers are driven by `BlockOps` and `OpenKind` (`baml_src/ns_block/options.baml`, `open.baml`):

```baml
interface BlockOps {
  function continue_line(self, parser: Parser, open: Open) -> ContinueResult throws never
  function finalize(self, parser: Parser, open: Open) -> void throws never
  function can_contain(self, child: OpenKind) -> bool throws never
  function accepts_lines(self) -> bool throws never
  function is_interruptible(self) -> bool throws never
  function allows_lazy(self) -> bool throws never
}

enum OpenKind {
    Document,
    Paragraph,
    Heading,
    ThematicBreak,
    CodeBlock,
    HtmlBlock,
    BlockQuote,
    List,
    Item,
}
```

`ContinueResult` is `Ok | Stop | Done`. Treat `Open`, `BlockOps`, and `OpenKind` as internals. New containers and any feature that needs those types are engine changes, not stable plugins.

### Internal parser state

Do not depend on `Parser` fields or methods from dialect code. The stable `BlockStartContext` deliberately exposes only indentation, the materialized current line, the first non-space index, thematic-break emission, and consuming the remaining input. Request additional context methods only when a use case cannot be expressed with that boundary.

## Gotchas

- **Visibility.** BAML cannot hide namespaces. Everything under `baml_src/` is callable. Only the README surface (`parse`, `render_html`, `to_html`, AST types, `ParseOptions` / `BlockStart` / `InlineParseRule`) is supported.
- **`name()` vs `triggers()`.** Matching uses `triggers()` (and `allow_indented()`). `name()` is unused by the dispatcher.
- **Rule order.** First matching block start wins that round; first inline `parse` that returns `true` wins that character. Append unless you intend to preempt CommonMark.
- **Indented-code trick.** `allow_indented() == true` and empty `triggers()` → tried only on indented lines.
- **`safe` is renderer-only.** `to_html(..., safe = true)` / `render_html(doc, safe = true)` omit `HtmlInline` and `HtmlBlock` as `<!-- raw HTML omitted -->`. They do not change the parse. `PercentSpanRule` therefore loses its `<span>` tags under `safe` — the same path as a literal `<span>`. Map onto `Emph`, `ThematicBreak`, `CodeSpan`, or `Text` if the dialect must survive safe mode. Safe mode also empties `javascript:` / `vbscript:` / `data:` / `file:` URLs; it is not a general sanitizer. It does not cap parse cost; see [Limits](usage.md#limits).
- **Block starts in other namespaces.** Implement `root.block.BlockStart` with a `root.block.BlockStartContext` parameter. Do not depend on `Parser`, `Open`, or `open_*` helpers.
- **Inline rules in other namespaces.** Implement `root.inline.InlineParseRule` with a `root.inline.InlineParseContext` parameter. Do not depend on `Subject` or its helper functions.
- **After `parse`.** Do not rely on `Paragraph.raw` / `Heading.raw` or `last_line_blank`. They are cleared. See [Usage](usage.md).
- **Do not stash and mutate one `commonmark_options()` forever.** Classes are reference types; `.push` mutates the arrays on **that** object. Each `commonmark_options()` call is a fresh `ParseOptions`, so pushing onto a local is fine and the next call is pristine. If you keep the same object and push again, you accumulate rules.

## Copy-paste dialect

Drop this next to the starts in `baml_src/ns_block/` (same namespace as `ParseOptions` and `PercentBreakStart`):

```baml
function extra_options() -> ParseOptions {
    let options = commonmark_options();
    options.block_starts.push(PercentBreakStart {  });
    options.inline_rules.push(root.inline.PercentSpanRule {  });
    options
}
```

In `ns_block` (or a `ns_block` test) call `root.to_html`. From the root namespace, pass `options = root.block.extra_options()`.

```baml
root.to_html("%%%\n\nhello %x% *y*\n", options = extra_options())
// <hr />
// <p>hello <span>x</span> <em>y</em></p>
```

If the helper lives in the root namespace instead, qualify the types: `root.block.ParseOptions`, `root.block.commonmark_options()`, `root.block.PercentBreakStart`, `root.inline.PercentSpanRule`.

`PercentBreakStart` and `PercentSpanRule` already exist in this tree. A new dialect is the same shape: a `BlockStart` and/or `InlineParseRule`, `triggers()` for any character that is not already special, existing AST nodes, then `push` onto a copy of `commonmark_options()`.

## See also

- [Architecture](architecture.md) — phase 1 / phase 2
- [AST](ast.md) — `Document`, `Block`, `Inline`
- [HTML](html.md) — renderer and `safe`
- [Usage](usage.md) — `parse` / `to_html` call shape
- [Testing](testing.md) — `PercentBreakStart` / `PercentSpanRule` tests
