function validate_heading(heading: Heading) -> void throws baml.errors.InvalidArgument {
    if (heading.level < 1 || heading.level > 6) {
        throw baml.errors.InvalidArgument {
            message: `heading level must be between 1 and 6, got ${heading.level}`,
        };
    }
    if (heading.setext && heading.level > 2) {
        throw baml.errors.InvalidArgument {
            message: `setext heading level must be 1 or 2, got ${heading.level}`,
        };
    }
}

// Validate render-relevant public AST invariants without recursive calls.
function validate_document(document: Document) -> void throws baml.errors.InvalidArgument {
    let work: Block[] = [];
    for (let block in document.children) {
        work.push(block);
    }
    while (work.length() > 0) {
        if let block: Block = work.pop() {
            match (block) {
                let heading: Heading => validate_heading(heading),
                let quote: BlockQuote => {
                    for (let child in quote.children) {
                        work.push(child);
                    }
                },
                let list: List => {
                    for (let item in list.children) {
                        for (let child in item.children) {
                            work.push(child);
                        }
                    }
                },
                _ => {},
            }
        }
    }
}

function new_document(
    children: Block[] = [],
    refs: map<string, LinkRef> = {},
) -> Document throws baml.errors.InvalidArgument {
    let document = Document { children: children, refs: refs };
    validate_document(document);
    document
}

function new_heading(
    level: int,
    children: Inline[],
    setext: bool = false,
) -> Heading throws baml.errors.InvalidArgument {
    let heading = Heading { level: level, setext: setext, raw: "", children: children, last_line_blank: false };
    validate_heading(heading);
    heading
}

test "new AST helpers create a renderable heading" {
    let heading = new_heading(3, [Text { literal: "Hi" }]);
    let document = new_document(children = [heading]);
    assert.equal(heading.level, 3);
    assert.equal(heading.raw, "");
    assert.equal(heading.last_line_blank, false);
    assert.equal(root.render_html(document), "<h3>Hi</h3>\n")
}

test "renderer rejects an invalid manually built heading" {
    let document = Document {
        children: [Heading { level: 0, setext: false, raw: "", children: [], last_line_blank: false }],
        refs: {},
    };
    let message = root.render_html(document) catch (error) {
        baml.errors.InvalidArgument => error.message,
    };
    assert.equal(message, "heading level must be between 1 and 6, got 0")
}
