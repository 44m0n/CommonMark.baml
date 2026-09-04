function parse(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
) -> root.ast.Document {
    //# Parse markdown into a document tree
    root.block.parse_document(markdown, options)
}

function render_html(document: root.ast.Document, safe: bool = false) -> string {
    //# Render the document tree as HTML
    root.html.render_document(document, safe = safe)
}

function to_html(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
    safe: bool = false,
) -> string {
    //# Parse then render
    render_html(parse(markdown, options = options), safe = safe)
}

test "empty document renders as empty string" {
    assert.equal(to_html(""), "")
}

test "safe render omits raw html and dangerous urls" {
    assert.equal(to_html("<div>x</div>\n", safe = true), "<!-- raw HTML omitted -->\n");
    assert.equal(
        to_html("a <b>c</b>\n", safe = true),
        "<p>a <!-- raw HTML omitted -->c<!-- raw HTML omitted --></p>\n",
    );
    assert.equal(to_html("[x](javascript:alert(1))\n", safe = true), "<p><a href=\"\">x</a></p>\n")
}
