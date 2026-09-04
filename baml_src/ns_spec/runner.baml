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
) -> SpecExample[] throws baml.errors.Io | baml.errors.ParseError | baml.json.JsonParseError | baml.json.JsonDecodeError {
    baml.json.from_string<SpecExample[]>(baml.fs.read(spec_tests_path()))
}

function examples_in(section: string) -> SpecExample[] {
    load_spec_tests().filter((t) -> {
        t.section == section
    }) catch_all (e) {
        _ => []
    }
}

function spec_failures(section: string) -> int {
    let n = 0;
    for (let t in examples_in(section)) {
        if (root.to_html(t.markdown) != t.html) {
            n += 1
        }
    }
    n
}

test "spec dump has 652 examples" {
    assert.equal(load_spec_tests().length(), 652)
}
