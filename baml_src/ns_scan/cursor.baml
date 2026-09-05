class LineScan {
    line: string,
    chars: string[],
    pos: int,
    column: int,
}

function preprocess(input: string) -> string {
    input.replace_all("\r\n", "\n").replace_all("\r", "\n").replace_all("\u{0000}", "\u{FFFD}")
}

function line_scan(line: string) -> LineScan {
    LineScan { line: line, chars: line.chars(), pos: 0, column: 0 }
}

function peek(scan: LineScan) -> string? {
    scan.chars.at(scan.pos)
}

function peek_code(scan: LineScan) -> int? {
    scan.chars.at(scan.pos)?.code_point_at(0)
}

function char_at(scan: LineScan, i: int) -> string? {
    scan.chars.at(i)
}

function is_eof(scan: LineScan) -> bool {
    scan.pos >= scan.chars.length()
}

function tab_spaces(column: int) -> int {
    4 - (column % 4)
}

function bump(scan: LineScan) -> string? {
    let ch = scan.chars.at(scan.pos);
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

function skip_space_tab_chars(chars: string[], i: int) -> int {
    while (is_space_or_tab(chars.at(i) ?? "")) {
        i += 1;
    }
    i
}

function skip_space_tab_index(s: string, i: int) -> int {
    skip_space_tab_chars(s.chars(), i)
}

function trim_space_tab(s: string) -> string {
    let chars = s.chars();
    let start = 0;
    let end = chars.length();
    while (start < end && is_space_or_tab(chars.at(start) ?? "")) {
        start += 1;
    }
    while (end > start && is_space_or_tab(chars.at(end - 1) ?? "")) {
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

function is_escapable(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        is_ascii_punctuation(c)
    }
}

function is_ascii_letter_char(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        let code = c.code_point_at(0) ?? 0;
        (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
    }
}

function is_tag_name_char(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        c.is_ascii_alphanumeric() || c == "-"
    }
}

function is_attr_name_start(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        is_ascii_letter_char(c) || c == "_" || c == ":"
    }
}

function is_attr_name_char(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        is_attr_name_start(c) || c.is_ascii_numeric() || c == "." || c == "-"
    }
}

function is_hebrew_arabic_mark(code: int) -> bool {
    (code >= 0x0591 && code <= 0x05BD)
        || code == 0x05BF
        || (code >= 0x05C1 && code <= 0x05C2)
        || (code >= 0x05C4 && code <= 0x05C5)
        || code == 0x05C7
        || (code >= 0x0610 && code <= 0x061A)
        || (code >= 0x064B && code <= 0x065F)
        || code == 0x0670
        || (code >= 0x06D6 && code <= 0x06DC)
        || (code >= 0x06DF && code <= 0x06E8)
        || (code >= 0x06EA && code <= 0x06ED)
        || (code >= 0x0897 && code <= 0x08FF)
        || code == 0xFB1E
}

function is_indic_mark(code: int) -> bool {
    (code >= 0x0900 && code <= 0x0963)
        || (code >= 0x0981 && code <= 0x09E3)
        || code == 0x09FE
        || (code >= 0x0A01 && code <= 0x0A75)
        || (code >= 0x0A81 && code <= 0x0AE3)
        || (code >= 0x0AFA && code <= 0x0AFF)
        || (code >= 0x0B01 && code <= 0x0B63)
        || (code >= 0x0B82 && code <= 0x0BD7)
        || (code >= 0x0C00 && code <= 0x0C63)
        || (code >= 0x0C81 && code <= 0x0C83)
        || (code >= 0x0CBC && code <= 0x0CF3)
        || (code >= 0x0D00 && code <= 0x0D4D)
        || (code >= 0x0D57 && code <= 0x0D63)
        || (code >= 0x0D81 && code <= 0x0DF3)
        || (code >= 0xA8E0 && code <= 0xA8F1)
}

function is_sea_mark(code: int) -> bool {
    (code >= 0x0E31 && code <= 0x0E3A)
        || (code >= 0x0E47 && code <= 0x0E4E)
        || (code >= 0x0EB1 && code <= 0x0ECE)
        || (code >= 0x0F18 && code <= 0x0F19)
        || code == 0x0F35
        || code == 0x0F37
        || code == 0x0F39
        || (code >= 0x0F3E && code <= 0x0F84)
        || (code >= 0x0F86 && code <= 0x0FBC)
        || code == 0x0FC6
        || (code >= 0x102B && code <= 0x103E)
        || (code >= 0x1056 && code <= 0x109D)
        || code == 0xA9E5
        || (code >= 0xAA7B && code <= 0xAA7D)
        || (code >= 0x17B4 && code <= 0x17D3)
        || code == 0x17DD
}

function is_extra_combining_mark(code: int) -> bool {
    (code >= 0x0483 && code <= 0x0489)
        || (code >= 0x1CD0 && code <= 0x1CD2)
        || (code >= 0x1CD4 && code <= 0x1CF9)
        || (code >= 0x2DE0 && code <= 0x2DFF)
}

function is_unicode_mark(code: int) -> bool {
    (code >= 0x0300 && code <= 0x036F)
        || (code >= 0x1AB0 && code <= 0x1AFF)
        || (code >= 0x1DC0 && code <= 0x1DFF)
        || (code >= 0x20D0 && code <= 0x20FF)
        || (code >= 0xFE20 && code <= 0xFE2F)
        || is_hebrew_arabic_mark(code)
        || is_indic_mark(code)
        || is_sea_mark(code)
        || is_extra_combining_mark(code)
}

function is_unicode_format(code: int) -> bool {
    code == 0x00AD
        || (code >= 0x200B && code <= 0x200F)
        || (code >= 0x202A && code <= 0x202E)
        || (code >= 0x2060 && code <= 0x206F)
        || code == 0xFEFF
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
    let chars = s.chars();
    let i = 0;
    while (i < chars.length()) {
        let c = chars.at(i) ?? "";
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

test "skip_space_tab_chars walks a materialized array" {
    let chars = "  \tfoo".chars();
    assert.equal(skip_space_tab_chars(chars, 0), 3);
    assert.equal(skip_space_tab_index("  \tfoo", 0), 3)
}
