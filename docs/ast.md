# AST reference

Types live in `baml_src/ns_ast/` (`blocks.baml`, `inlines.baml`), namespace `root.ast`. `parse` returns `root.ast.Document`. There are no source offsets.

## Document

```baml
class LinkRef {
    destination: string,
    title: string?,
}

class Document {
    children: Block[],
    refs: map<string, LinkRef>,
}
```

`refs` holds link reference definitions, keyed by the normalized label. Duplicate labels keep the first definition. Definitions are not `Block` nodes and are not rendered.

## Blocks

```baml
type Block = Paragraph | Heading | ThematicBreak | CodeBlock | HtmlBlock | BlockQuote | List;
```

`ListItem` is **not** in `Block`. `List.children` is `ListItem[]`. `ListItem.children` is `Block[]`. `Document` is not a `Block`.

```baml
class Paragraph {
    raw: string,
    children: Inline[],
    last_line_blank: bool,
}

class Heading {
    level: int,
    setext: bool,
    raw: string,
    children: Inline[],
    last_line_blank: bool,
}

class ThematicBreak {
    last_line_blank: bool,
}

class CodeBlock {
    fenced: bool,
    info: string,
    literal: string,
    last_line_blank: bool,
}

class HtmlBlock {
    literal: string,
    last_line_blank: bool,
}

class BlockQuote {
    children: Block[],
    last_line_blank: bool,
}

enum ListKind {
    Bullet,
    Ordered,
}

class List {
    kind: ListKind,
    start: int,
    tight: bool,
    delimiter: string,
    bullet_char: string,
    children: ListItem[],
    last_line_blank: bool,
}

class ListItem {
    children: Block[],
    last_line_blank: bool,
}
```

| Type | Fields |
| --- | --- |
| `Paragraph` | `raw`, `children: Inline[]`, `last_line_blank` |
| `Heading` | `level`, `setext`, `raw`, `children: Inline[]`, `last_line_blank` |
| `ThematicBreak` | `last_line_blank` |
| `CodeBlock` | `fenced`, `info`, `literal`, `last_line_blank` |
| `HtmlBlock` | `literal`, `last_line_blank` |
| `BlockQuote` | `children: Block[]`, `last_line_blank` |
| `List` | `kind: ListKind`, `start`, `tight`, `delimiter`, `bullet_char`, `children: ListItem[]`, `last_line_blank` |
| `ListItem` | `children: Block[]`, `last_line_blank` |

`Heading.level` is 1–6 (ATX) or 1–2 (setext). `Heading.setext` is `false` for ATX, `true` for setext.

`CodeBlock.fenced` is `true` for `` ``` `` / `~~~` fences and `false` for indented code. Fenced `info` is the unescaped info string; indented `info` is `""`.

`List.kind` is `ListKind.Bullet` or `ListKind.Ordered`. For ordered lists, `start` is the marker integer and `delimiter` is `"."` or `")"`. For bullet lists, `bullet_char` is `"*"`, `"-"`, or `"+"`. HTML uses `kind` and `start` only; see [coverage.md](coverage.md).

## Inlines

```baml
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

```baml
class Text {
    literal: string,
}

class SoftBreak {
}

class HardBreak {
}

class CodeSpan {
    literal: string,
}

class Emph {
    children: Inline[],
}

class Strong {
    children: Inline[],
}

class Link {
    destination: string,
    title: string?,
    children: Inline[],
}

class Image {
    destination: string,
    title: string?,
    children: Inline[],
}

class HtmlInline {
    literal: string,
}

class Autolink {
    destination: string,
    email: bool,
}
```

| Type | Fields |
| --- | --- |
| `Text` | `literal` |
| `SoftBreak` | (none) |
| `HardBreak` | (none) |
| `CodeSpan` | `literal` |
| `Emph` | `children: Inline[]` |
| `Strong` | `children: Inline[]` |
| `Link` | `destination`, `title: string?`, `children: Inline[]` |
| `Image` | `destination`, `title: string?`, `children: Inline[]` |
| `HtmlInline` | `literal` |
| `Autolink` | `destination`, `email: bool` |

`Autolink.destination` is the text inside `<>` (no `mailto:` prefix). `email: true` means the renderer prefixes `mailto:` on `href`.

Empty nodes are constructed as `root.ast.SoftBreak {  }` / `root.ast.HardBreak {  }`.

## Constructing and validating ASTs

For manually assembled renderable trees, prefer these helpers from `baml_src/ns_ast/validation.baml`:

```baml
function new_document(
    children: Block[] = [],
    refs: map<string, LinkRef> = {},
) -> Document throws baml.errors.InvalidArgument

function new_heading(
    level: int,
    children: Inline[],
    setext: bool = false,
) -> Heading throws baml.errors.InvalidArgument

function validate_document(document: Document) -> void throws baml.errors.InvalidArgument
```

`new_heading` creates a post-parse heading (`raw: ""`, `last_line_blank: false`) and accepts levels 1–6; setext headings are further limited to levels 1–2. `new_document` validates its initial tree. `render_html` validates every supplied document too, so invalid manually-built headings raise `baml.errors.InvalidArgument` rather than producing invalid tags such as `<h0>`.

```baml
let heading = root.ast.new_heading(2, [root.ast.Text { literal: "Hi" }]);
let doc = root.ast.new_document(children = [heading]);
let html = render_html(doc)
```

## Parser leftover fields

`Paragraph.raw` and `Heading.raw` hold source consumed during inline parse. After `parse()`:

- `raw` is `""` on every `Paragraph` and `Heading`
- `last_line_blank` is `false` on every block and `ListItem`
- `List.tight` is **kept** (already computed at list finalize)

When hand-building trees for `render_html`, set `raw: ""` and `last_line_blank: false`. `List.tight` must be set by the caller if it matters for list item HTML.

## Closed unions

`Block` and `Inline` are closed. Adding a node type requires editing the union **and** the `match` in `ns_html/render.baml` (`push_block_work` / `render_inlines`). Extensions that cannot change those should map onto existing nodes (for example `HtmlInline`). See [extensions.md](extensions.md).

## Walking

Narrow with `if let` or exhaustive `match`. `ListItem` is reached only through `List.children`.

```baml
function heading_level(b: root.ast.Block) -> int? {
    if let h: root.ast.Heading = b {
        h.level
    } else {
        null
    }
}

function walk_inlines(nodes: root.ast.Inline[]) -> string[] {
    let tags: string[] = [];
    for (let n in nodes) {
        tags.push(match (n) {
            let _: root.ast.Text => "text",
            let _: root.ast.SoftBreak => "softbreak",
            let _: root.ast.HardBreak => "hardbreak",
            let _: root.ast.CodeSpan => "code",
            let e: root.ast.Emph => {
                let _ = walk_inlines(e.children);
                "emph"
            },
            let s: root.ast.Strong => {
                let _ = walk_inlines(s.children);
                "strong"
            },
            let l: root.ast.Link => {
                let _ = walk_inlines(l.children);
                "link"
            },
            let i: root.ast.Image => {
                let _ = walk_inlines(i.children);
                "image"
            },
            let _: root.ast.HtmlInline => "html",
            let a: root.ast.Autolink => if (a.email) { "email" } else { "autolink" },
        });
    }
    tags
}

function walk_blocks(blocks: root.ast.Block[]) -> void {
    for (let b in blocks) {
        match (b) {
            let p: root.ast.Paragraph => {
                let _ = walk_inlines(p.children);
            },
            let h: root.ast.Heading => {
                let _ = walk_inlines(h.children);
            },
            let _: root.ast.ThematicBreak => {
            },
            let _: root.ast.CodeBlock => {
            },
            let _: root.ast.HtmlBlock => {
            },
            let q: root.ast.BlockQuote => walk_blocks(q.children),
            let l: root.ast.List => {
                for (let item in l.children) {
                    walk_blocks(item.children);
                }
            },
        }
    }
}
```

Hand-built paragraph for `render_html`:

```baml
root.ast.Paragraph {
    raw: "",
    children: [root.ast.Text { literal: "Hi" }],
    last_line_blank: false,
}
```
