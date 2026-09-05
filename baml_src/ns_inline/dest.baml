class ScanPiece {
    end: int,
    value: string,
}

function max_dest_paren_depth() -> int {
    32
}

function parse_link_label(s: string, i: int) -> int? {
    parse_link_label_chars(s.chars(), i)
}

function parse_link_label_chars(chars: string[], i: int) -> int? {
    if (chars.at(i) != "[") {
        return null;
    }
    let j = i + 1;
    let n = chars.length();
    while (j < n) {
        if (j - i > 1000) {
            return null;
        }
        let c = chars.at(j) ?? "";
        if (c == "\\") {
            j += 1;
            if (j < n) {
                j += 1;
            }
        } else if (c == "[") {
            return null;
        } else if (c == "]") {
            return j + 1;
        } else {
            j += 1;
        }
    }
    null
}

function parse_link_destination(s: string, i: int, table: map<string, string>) -> ScanPiece? {
    parse_link_destination_chars(s, s.chars(), i, table = table)
}

function parse_link_destination_chars(
    s: string,
    chars: string[],
    i: int,
    table: map<string, string>,
) -> ScanPiece? {
    let n = chars.length();
    if (chars.at(i) == "<") {
        let j = i + 1;
        while (j < n) {
            let c = chars.at(j) ?? "";
            if (c == "\n" || c == "<") {
                return null;
            }
            if (c == "\\") {
                j += 1;
                if (j < n) {
                    j += 1;
                }
            } else if (c == ">") {
                return ScanPiece { end: j + 1, value: unescape_markdown(s.slice(i + 1, j), table = table) };
            } else {
                j += 1;
            }
        }
        return null;
    }
    let save = i;
    let open_parens = 0;
    while (i < n) {
        let c = chars.at(i) ?? "";
        if (c == "\\" && root.scan.is_escapable(chars.at(i + 1))) {
            i += 2;
        } else if (c == "(") {
            open_parens += 1;
            if (open_parens > max_dest_paren_depth()) {
                return null;
            }
            i += 1;
        } else if (c == ")") {
            if (open_parens < 1) {
                break;
            }
            open_parens -= 1;
            i += 1;
        } else if (c == " " || c == "\t" || c == "\n") {
            break;
        } else {
            let code = c.code_point_at(0) ?? 0;
            if (code < 32 || code == 127) {
                return null;
            }
            i += 1;
        }
    }
    if (i == save || open_parens != 0) {
        return null;
    }
    ScanPiece { end: i, value: unescape_markdown(s.slice(save, i), table = table) }
}

function parse_link_title(s: string, i: int, table: map<string, string>) -> ScanPiece? {
    parse_link_title_chars(s, s.chars(), i, table = table)
}

function parse_link_title_chars(
    s: string,
    chars: string[],
    i: int,
    table: map<string, string>,
) -> ScanPiece? {
    let opener = chars.at(i);
    if (opener != "\"" && opener != "'" && opener != "(") {
        return null;
    }
    let closer = if (opener == "(") {
        ")"
    } else {
        opener ?? "\""
    };
    let j = i + 1;
    let n = chars.length();
    while (j < n) {
        let c = chars.at(j) ?? "";
        if (c == "\n" && chars.at(j + 1) == "\n") {
            return null;
        }
        if (c == "\\") {
            j += 1;
            if (j < n) {
                j += 1;
            }
        } else if (opener == "(" && c == "(") {
            return null;
        } else if (c == closer) {
            return ScanPiece { end: j + 1, value: unescape_markdown(s.slice(i + 1, j), table = table) };
        } else {
            j += 1;
        }
    }
    null
}

function normalize_reference(raw_label: string) -> string {
    let inner = raw_label.slice(1, raw_label.length() - 1);
    let parts: string[] = [];
    let chars = inner.chars();
    let i = 0;
    let last_space = false;
    let started = false;
    let n = chars.length();
    while (i < n) {
        let c = chars.at(i) ?? "";
        if (c == " " || c == "\t" || c == "\n") {
            if (started) {
                last_space = true;
            }
            i += 1;
        } else {
            if (last_space) {
                parts.push(" ");
                last_space = false;
            }
            let start = i;
            i += 1;
            while (i < n) {
                let nxt = chars.at(i) ?? "";
                if (nxt == " " || nxt == "\t" || nxt == "\n") {
                    break;
                }
                i += 1;
            }
            parts.push(inner.slice(start, i));
            started = true;
        }
    }
    root.scan.unicode_case_fold(parts.join(""))
}
