function parse(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
) -> root.ast.Document {
    //# Parse markdown into a document tree
    root.block.parse_document(markdown, options)
}

function render_html(document: root.ast.Document) -> string {
    //# Render the document tree as HTML
    root.html.render_document(document)
}

function to_html(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
) -> string {
    //# Parse then render
    render_html(parse(markdown, options = options))
}

test "empty document renders as empty string" {
    assert.equal(to_html(""), "")
}
