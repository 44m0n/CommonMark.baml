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
