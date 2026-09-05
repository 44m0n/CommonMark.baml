class LinkRef {
    destination: string,
    title: string?,
}

class Document {
    children: Block[],
    refs: map<string, LinkRef>,
}

class Paragraph {
    // Source consumed during inline parse; empty after parse().
    raw: string,
    children: Inline[],
    // Parser tightness flag; false after parse(). Set false when building trees.
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

type Block = Paragraph | Heading | ThematicBreak | CodeBlock | HtmlBlock | BlockQuote | List;
