function is_uri_scheme_cont(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        c.is_ascii_alphanumeric() || c == "+" || c == "." || c == "-"
    }
}

function scan_uri_autolink(line: string, start: int) -> int? {
    if (line.at(start) != "<") {
        return null;
    }
    let i = start + 1;
    let first = line.at(i);
    if (first == null) {
        return null;
    }
    if (!first.is_ascii_alphabetic()) {
        return null;
    }
    i += 1;
    let extra = 0;
    while (extra < 31 && is_uri_scheme_cont(line.at(i))) {
        i += 1;
        extra += 1;
    }
    if (extra < 1 || line.at(i) != ":") {
        return null;
    }
    i += 1;
    while (i < line.length()) {
        let c = line.at(i) ?? "";
        if (c == ">") {
            return i + 1;
        }
        let code = c.code_point_at(0) ?? 0;
        if (c == " " || c == "<" || code < 32 || code == 127) {
            return null;
        }
        i += 1;
    }
    null
}

function is_email_local_char(c: string?) -> bool {
    if (c == null) {
        false
    } else {
        c.is_ascii_alphanumeric() || ".!#$%&'*+/=?^_`{|}~-".includes(c)
    }
}

function scan_email_label(line: string, i: int) -> int? {
    let c0 = line.at(i);
    if (c0 == null) {
        return null;
    }
    if (!c0.is_ascii_alphanumeric()) {
        return null;
    }
    let j = i + 1;
    while (j - i < 63) {
        let c = line.at(j);
        if (c == null) {
            break;
        }
        if (c.is_ascii_alphanumeric() || c == "-") {
            j += 1;
        } else {
            break;
        }
    }
    if (j - i > 1 && line.at(j - 1) == "-") {
        return null;
    }
    j
}

function scan_email_autolink(line: string, start: int) -> int? {
    if (line.at(start) != "<") {
        return null;
    }
    let i = start + 1;
    let local_start = i;
    while (is_email_local_char(line.at(i))) {
        i += 1;
    }
    if (i == local_start || line.at(i) != "@") {
        return null;
    }
    i += 1;
    let label = scan_email_label(line, i);
    if (label == null) {
        return null;
    }
    i = label;
    while (line.at(i) == ".") {
        let next = scan_email_label(line, i + 1);
        if (next == null) {
            return null;
        }
        i = next;
    }
    if (line.at(i) != ">") {
        return null;
    }
    i + 1
}

class AutolinkRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "autolink"
        }

        function parse(self, s: Subject) -> bool throws never {
            if (peek(s) != "<") {
                return false;
            }
            let line = s.scan.line;
            let start = s.scan.pos;
            let uri_end = scan_uri_autolink(line, start);
            if (uri_end != null) {
                let dest = line.slice(start + 1, uri_end - 1);
                advance_to(s, uri_end);
                push_node(s, root.ast.Autolink { destination: dest, email: false });
                return true;
            }
            let email_end = scan_email_autolink(line, start);
            if (email_end != null) {
                let dest = line.slice(start + 1, email_end - 1);
                advance_to(s, email_end);
                push_node(s, root.ast.Autolink { destination: dest, email: true });
                return true;
            }
            false
        }
    }
}
