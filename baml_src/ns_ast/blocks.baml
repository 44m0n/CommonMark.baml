class LinkRef {
    destination: string,
    title: string?,
}

class Document {
    children: Block[],
    refs: map<string, LinkRef>,
}

class Paragraph {
    raw: string,
    children: Inline[],
}

class Heading {
    level: int,
    setext: bool,
    raw: string,
    children: Inline[],
}

class ThematicBreak {
}

class CodeBlock {
    fenced: bool,
    info: string,
    literal: string,
}

class HtmlBlock {
    html_type: int,
    literal: string,
}

class BlockQuote {
    children: Block[],
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
}

class ListItem {
    children: Block[],
}

type Block = Paragraph | Heading | ThematicBreak | CodeBlock | HtmlBlock | BlockQuote | List;
