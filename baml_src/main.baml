function parse(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
) -> root.ast.Document {
    //# Parse markdown into a document tree
    root.block.parse_document(markdown, options)
}

function render_html(
    document: root.ast.Document,
    safe: bool = false,
) -> string throws baml.errors.InvalidArgument {
    //# Validate then render the document tree as HTML
    root.ast.validate_document(document);
    root.html.render_document(document, safe = safe)
}

function to_html(
    markdown: string,
    options: root.block.ParseOptions = root.block.commonmark_options(),
    safe: bool = false,
) -> string throws baml.errors.InvalidArgument {
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
    assert.equal(to_html("[x](javascript:alert(1))\n", safe = true), "<p><a href=\"\">x</a></p>\n");
    assert.equal(to_html("[x](file:///etc/passwd)\n", safe = true), "<p><a href=\"\">x</a></p>\n");
    assert.equal(to_html("[x](FILE:foo)\n", safe = true), "<p><a href=\"\">x</a></p>\n")
}

test "without safe file urls pass through" {
    assert.equal(
        to_html("[x](file:///etc/passwd)\n"),
        "<p><a href=\"file:///etc/passwd\">x</a></p>\n",
    )
}

test "parse clears raw source after inlines" {
    let doc = parse("# Hi\n\npara\n");
    let h = doc.children.at(0);
    if let heading: root.ast.Heading = h {
        assert.equal(heading.raw, "");
        assert.equal(heading.last_line_blank, false);
    } else {
        assert.is_true(false);
    }
    let p = doc.children.at(1);
    if let para: root.ast.Paragraph = p {
        assert.equal(para.raw, "");
        assert.equal(para.last_line_blank, false);
    } else {
        assert.is_true(false);
    }
}
