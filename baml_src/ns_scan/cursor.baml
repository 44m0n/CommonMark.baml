class LineScan {
    line: string,
    pos: int,
    column: int,
}

function preprocess(input: string) -> string {
    input.replace_all("\r\n", "\n").replace_all("\r", "\n").replace_all("\u{0000}", "\u{FFFD}")
}

function line_scan(line: string) -> LineScan {
    LineScan { line: line, pos: 0, column: 0 }
}

function peek(scan: LineScan) -> string? {
    scan.line.at(scan.pos)
}

function peek_code(scan: LineScan) -> int? {
    scan.line.code_point_at(scan.pos)
}

function is_eof(scan: LineScan) -> bool {
    scan.pos >= scan.line.length()
}

function tab_spaces(column: int) -> int {
    4 - (column % 4)
}

function bump(scan: LineScan) -> string? {
    let ch = scan.line.at(scan.pos);
    if (ch == null) {
        return null;
    }
    scan.pos += 1;
    if (ch == "\t") {
        scan.column += tab_spaces(scan.column)
    } else {
        scan.column += 1
    }
    ch
}

function skip_spaces_and_tabs(scan: LineScan) -> int {
    let start_col = scan.column;
    while (true) {
        let ch = peek(scan);
        if (ch == " " || ch == "\t") {
            let _ = bump(scan);
        } else {
            break;
        }
    }
    scan.column - start_col
}

function is_space_or_tab(ch: string) -> bool {
    ch == " " || ch == "\t"
}

function is_ascii_punctuation(ch: string) -> bool {
    let code = ch.code_point_at(0) ?? -1;
    (code >= 0x21 && code <= 0x2F)
        || (code >= 0x3A && code <= 0x40)
        || (code >= 0x5B && code <= 0x60)
        || (code >= 0x7B && code <= 0x7E)
}

function is_unicode_whitespace(ch: string) -> bool {
    ch == "\t" || ch == "\n" || ch == "\u{000C}" || ch == "\r" || ch.is_whitespace()
}

test "preprocess replaces NUL with replacement character" {
    assert.equal(preprocess("a\u{0000}b"), "a\u{FFFD}b")
}

test "preprocess treats CR and CRLF as line endings" {
    assert.equal(preprocess("a\rb"), "a\nb");
    assert.equal(preprocess("a\r\nb"), "a\nb")
}

test "bare CR is a line ending in a paragraph" {
    assert.equal(root.to_html("a\rb"), "<p>a\nb</p>\n")
}

test "tab at column 0 advances by 4" {
    let s = line_scan("\tfoo");
    assert.equal(bump(s), "\t");
    assert.equal(s.column, 4);
    assert.equal(s.pos, 1)
}

test "tab after one space advances by 3" {
    let s = line_scan(" \t");
    assert.equal(bump(s), " ");
    assert.equal(s.column, 1);
    assert.equal(bump(s), "\t");
    assert.equal(s.column, 4)
}

test "skip_spaces_and_tabs counts virtual indent" {
    let s = line_scan("\t foo");
    assert.equal(skip_spaces_and_tabs(s), 5);
    assert.equal(peek(s), "f")
}
