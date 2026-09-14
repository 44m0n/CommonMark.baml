class SpecExample {
    markdown: string,
    html: string,
    example: int,
    start_line: int,
    end_line: int,
    section: string,
}

function spec_tests_path() -> string {
    "vendor/commonmark-0.31.2/spec-tests.json"
}

function load_spec_tests(
) -> SpecExample[] throws baml.errors.Io | baml.errors.ParseError | baml.json.ParseError | baml.json.DecodeError {
    baml.json.from_string<SpecExample[]>(baml.fs.read(spec_tests_path()))
}

function examples_in(
    section: string,
) -> SpecExample[] throws baml.errors.Io | baml.errors.ParseError | baml.json.ParseError | baml.json.DecodeError {
    load_spec_tests().filter((t) -> {
        t.section == section
    })
}

function spec_example(
    n: int,
) -> SpecExample? throws baml.errors.Io | baml.errors.ParseError | baml.json.ParseError | baml.json.DecodeError {
    load_spec_tests().find((t) -> {
        t.example == n
    })
}

function spec_failures(
    section: string,
) -> int[] throws baml.errors.Io | baml.errors.ParseError | baml.json.ParseError | baml.json.DecodeError {
    let examples = examples_in(section);
    //# Reject unknown spec sections
    if (examples.length() == 0) {
        baml.sys.panic(`unknown CommonMark spec section: ${section}`)
    }
    let failed: int[] = [];
    for (let t in examples) {
        if (root.to_html(t.markdown) != t.html) {
            let _ = failed.push(t.example);
        }
    }
    failed
}

function assert_spec_examples(
    nums: int[],
) -> void throws baml.errors.Io | baml.errors.ParseError | baml.json.ParseError | baml.json.DecodeError {
    for (let n in nums) {
        let t = spec_example(n);
        if let ex: SpecExample = t {
            assert.equal(root.to_html(ex.markdown), ex.html)
        } else {
            assert.is_true(false)
        }
    }
}

test "spec dump has 652 examples" {
    assert.equal(load_spec_tests().length(), 652);
    assert.is_true(examples_in("Tabs").length() > 0)
}
