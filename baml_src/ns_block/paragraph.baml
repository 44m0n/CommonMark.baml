test "blank lines spec" {
    assert.equal(root.spec.spec_failures("Blank lines"), 0)
}

test "consecutive non-blank lines form one paragraph" {
    assert.equal(root.to_html("aaa\nbbb\n\nccc\nddd\n"), "<p>aaa\nbbb</p>\n<p>ccc\nddd</p>\n")
}

test "paragraphs strip leading indent" {
    assert.equal(
        root.to_html("aaa\n             bbb\n                                       ccc\n"),
        "<p>aaa\nbbb\nccc</p>\n",
    )
}

test "paragraph spec examples that do not need later constructs" {
    root.spec.assert_spec_examples([219, 220, 221, 222, 223, 224, 225])
}
