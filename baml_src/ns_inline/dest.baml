class ScanPiece {
    end: int,
    value: string,
}

function max_dest_paren_depth() -> int {
    32
}

function parse_link_label(s: string, i: int) -> int? {
    if (s.at(i) != "[") {
        return null;
    }
    let j = i + 1;
    while (j < s.length()) {
        if (j - i > 1000) {
            return null;
        }
        let c = s.at(j) ?? "";
        if (c == "\\") {
            j += 1;
            if (j < s.length()) {
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
    if (s.at(i) == "<") {
        let j = i + 1;
        while (j < s.length()) {
            let c = s.at(j) ?? "";
            if (c == "\n" || c == "<") {
                return null;
            }
            if (c == "\\") {
                j += 1;
                if (j < s.length()) {
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
    while (i < s.length()) {
        let c = s.at(i) ?? "";
        if (c == "\\" && root.scan.is_escapable(s.at(i + 1))) {
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
    let opener = s.at(i);
    if (opener != "\"" && opener != "'" && opener != "(") {
        return null;
    }
    let closer = if (opener == "(") {
        ")"
    } else {
        opener ?? "\""
    };
    let j = i + 1;
    while (j < s.length()) {
        let c = s.at(j) ?? "";
        if (c == "\n" && s.at(j + 1) == "\n") {
            return null;
        }
        if (c == "\\") {
            j += 1;
            if (j < s.length()) {
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
    let i = 0;
    let last_space = false;
    let started = false;
    while (i < inner.length()) {
        let c = inner.at(i) ?? "";
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
            while (i < inner.length()) {
                let n = inner.at(i) ?? "";
                if (n == " " || n == "\t" || n == "\n") {
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
