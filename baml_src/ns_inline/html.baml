function index_from(line: string, needle: string, from: int) -> int? {
    let i = line.slice(from, line.length()).index_of(needle);
    if (i == null) {
        null
    } else {
        from + i
    }
}

function skip_tag_ws(chars: string[], i: int) -> int {
    while (chars.at(i) == " " || chars.at(i) == "\t") {
        i += 1;
    }
    if (chars.at(i) == "\n") {
        i += 1;
        while (chars.at(i) == " " || chars.at(i) == "\t") {
            i += 1;
        }
    }
    i
}

function scan_tag_name(chars: string[], i: int) -> int? {
    if (!root.scan.is_ascii_letter_char(chars.at(i))) {
        return null;
    }
    i += 1;
    while (root.scan.is_tag_name_char(chars.at(i))) {
        i += 1;
    }
    i
}

function scan_unquoted_attr_value(chars: string[], i: int) -> int? {
    let start = i;
    while (i < chars.length()) {
        let c = chars.at(i) ?? "";
        let code = c.code_point_at(0) ?? 0;
        if (
            c == "\""
                || c == "'"
                || c == "="
                || c == "<"
                || c == ">"
                || c == "`"
                || c == " "
                || c == "\t"
                || c == "\n"
                || code < 32
        ) {
            break;
        }
        i += 1;
    }
    if (i == start) {
        null
    } else {
        i
    }
}

function scan_quoted_attr_value(chars: string[], i: int, quote: string) -> int? {
    if (chars.at(i) != quote) {
        return null;
    }
    i += 1;
    while (i < chars.length()) {
        if (chars.at(i) == quote) {
            return i + 1;
        }
        i += 1;
    }
    null
}

function scan_attr_value(chars: string[], i: int) -> int? {
    let q = chars.at(i);
    if (q == "\"" || q == "'") {
        scan_quoted_attr_value(chars, i, q ?? "\"")
    } else {
        scan_unquoted_attr_value(chars, i)
    }
}

function scan_attribute(chars: string[], i: int) -> int? {
    let j = skip_tag_ws(chars, i);
    if (j == i) {
        return null;
    }
    if (!root.scan.is_attr_name_start(chars.at(j))) {
        return null;
    }
    j += 1;
    while (root.scan.is_attr_name_char(chars.at(j))) {
        j += 1;
    }
    let k = skip_tag_ws(chars, j);
    if (chars.at(k) == "=") {
        k = skip_tag_ws(chars, k + 1);
        let v = scan_attr_value(chars, k);
        if (v == null) {
            return null;
        }
        v
    } else {
        j
    }
}

function scan_open_tag(chars: string[], start: int) -> int? {
    if (chars.at(start) != "<") {
        return null;
    }
    let name_end = scan_tag_name(chars, start + 1);
    if (name_end == null) {
        return null;
    }
    let j = name_end;
    while (true) {
        let next = scan_attribute(chars, j);
        if (next == null) {
            break;
        }
        j = next;
    }
    j = skip_tag_ws(chars, j);
    if (chars.at(j) == "/") {
        j += 1;
    }
    if (chars.at(j) == ">") {
        j + 1
    } else {
        null
    }
}

function scan_close_tag(chars: string[], start: int) -> int? {
    if (chars.at(start) != "<" || chars.at(start + 1) != "/") {
        return null;
    }
    let name_end = scan_tag_name(chars, start + 2);
    if (name_end == null) {
        return null;
    }
    let j = skip_tag_ws(chars, name_end);
    if (chars.at(j) == ">") {
        j + 1
    } else {
        null
    }
}

function scan_html_comment(line: string, start: int) -> int? {
    if (line.slice(start, start + 4) != "<!--") {
        return null;
    }
    if (line.slice(start, start + 5) == "<!-->") {
        return start + 5;
    }
    if (line.slice(start, start + 6) == "<!--->") {
        return start + 6;
    }
    let i = index_from(line, "-->", start + 4);
    if (i == null) {
        null
    } else {
        i + 3
    }
}

function scan_processing_instruction(line: string, chars: string[], start: int) -> int? {
    if (chars.at(start) != "<" || chars.at(start + 1) != "?") {
        return null;
    }
    let i = index_from(line, "?>", start + 2);
    if (i == null) {
        null
    } else {
        i + 2
    }
}

function scan_declaration(chars: string[], start: int) -> int? {
    if (chars.at(start) != "<" || chars.at(start + 1) != "!") {
        return null;
    }
    if (!root.scan.is_ascii_letter_char(chars.at(start + 2))) {
        return null;
    }
    let i = start + 3;
    while (i < chars.length()) {
        if (chars.at(i) == ">") {
            return i + 1;
        }
        i += 1;
    }
    null
}

function scan_cdata(line: string, start: int) -> int? {
    if (line.slice(start, start + 9) != "<![CDATA[") {
        return null;
    }
    let i = index_from(line, "]]>", start + 9);
    if (i == null) {
        null
    } else {
        i + 3
    }
}

function scan_html_inline(line: string, chars: string[], start: int) -> int? {
    let end = scan_html_comment(line, start);
    if (end != null) {
        return end;
    }
    end = scan_processing_instruction(line, chars, start);
    if (end != null) {
        return end;
    }
    end = scan_cdata(line, start);
    if (end != null) {
        return end;
    }
    end = scan_declaration(chars, start);
    if (end != null) {
        return end;
    }
    end = scan_open_tag(chars, start);
    if (end != null) {
        return end;
    }
    scan_close_tag(chars, start)
}

class HtmlInlineRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "html_inline"
        }

        function parse(self, context: InlineParseContext) -> bool throws never {
            let s = internal_inline_subject(context);
            if (peek(s) != "<") {
                return false;
            }
            let end = scan_html_inline(s.scan.line, s.scan.chars, s.scan.pos);
            if (end == null) {
                return false;
            }
            let literal = s.scan.line.slice(s.scan.pos, end);
            advance_to(s, end);
            push_node(s, root.ast.HtmlInline { literal: literal });
            true
        }
    }
}
