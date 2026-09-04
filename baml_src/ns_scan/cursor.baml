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

function trim_space_tab(s: string) -> string {
    let start = 0;
    let end = s.length();
    while (start < end && is_space_or_tab(s.at(start) ?? "")) {
        start += 1;
    }
    while (end > start && is_space_or_tab(s.at(end - 1) ?? "")) {
        end -= 1;
    }
    s.slice(start, end)
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

function case_fold_special(code: int) -> string? {
    if (code == 0x00DF || code == 0x1E9E) {
        "ss"
    } else if (code == 0x0130) {
        "i\u{0307}"
    } else if (code == 0x0149) {
        "\u{02BC}n"
    } else if (code == 0x017F) {
        "s"
    } else if (code == 0x01F0) {
        "j\u{030C}"
    } else if (code == 0x0390) {
        "ι\u{0308}\u{0301}"
    } else if (code == 0x03B0) {
        "υ\u{0308}\u{0301}"
    } else if (code == 0x03C2) {
        "σ"
    } else if (code == 0x00B5) {
        "μ"
    } else if (code == 0x03D0) {
        "β"
    } else if (code == 0x03D1) {
        "θ"
    } else if (code == 0x03D5) {
        "φ"
    } else if (code == 0x03D6) {
        "π"
    } else if (code == 0x03F0) {
        "κ"
    } else if (code == 0x03F1) {
        "ρ"
    } else if (code == 0x03F5) {
        "ε"
    } else if (code == 0x0587) {
        "եվ"
    } else if (code == 0xFB00) {
        "ff"
    } else if (code == 0xFB01) {
        "fi"
    } else if (code == 0xFB02) {
        "fl"
    } else if (code == 0xFB03) {
        "ffi"
    } else if (code == 0xFB04) {
        "ffl"
    } else if (code == 0xFB05 || code == 0xFB06) {
        "st"
    } else {
        null
    }
}

function unicode_case_fold(s: string) -> string {
    let parts: string[] = [];
    let i = 0;
    while (i < s.length()) {
        let c = s.at(i) ?? "";
        let code = c.code_point_at(0) ?? 0;
        if let folded: string = case_fold_special(code) {
            parts.push(folded);
        } else {
            parts.push(c.to_lower_case());
        }
        i += 1;
    }
    parts.join("")
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
