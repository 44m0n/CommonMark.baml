class EntityScan {
    end: int,
    value: string,
}

class NamedEntityCache {
    table: map<string, string>?,
}

// BAML has no module-level let; a client binding is a process-wide singleton.
client NAMED_ENTITY_CACHE = NamedEntityCache { table: null };

function named_entity_cache() -> NamedEntityCache {
    if let cache: NamedEntityCache = NAMED_ENTITY_CACHE {
        cache
    } else {
        baml.sys.panic("named entity cache is not an instance")
    }
}

function load_named_entities() -> map<string, string> {
    let cache = named_entity_cache();
    if let t: map<string, string> = cache.table {
        t
    } else {
        let parsed = baml.json.from_string<map<string, string>>(named_entities_json()) catch_all (e) {
            _ => {
                baml.sys.panic("named entity table is corrupt")
            }
        };
        cache.table = parsed;
        parsed
    }
}

function hex_val(c: string) -> int? {
    let code = c.code_point_at(0) ?? 0;
    if (code >= 48 && code <= 57) {
        code - 48
    } else if (code >= 65 && code <= 70) {
        code - 55
    } else if (code >= 97 && code <= 102) {
        code - 87
    } else {
        null
    }
}

function replacement_char() -> string {
    string.from_code_points([65533]) catch (e) {
        baml.errors.InvalidArgument => "?"
    }
}

function code_point_string(n: int) -> string {
    if (n <= 0 || n > 1114111 || (n >= 55296 && n <= 57343)) {
        replacement_char()
    } else {
        string.from_code_points([n]) catch (e) {
            baml.errors.InvalidArgument => replacement_char()
        }
    }
}

function scan_named_entity(
    line: string,
    chars: string[],
    i: int,
    table: map<string, string>,
) -> EntityScan? {
    if (chars.at(i) != "&") {
        return null;
    }
    let j = i + 1;
    while (j < chars.length()) {
        let c = chars.at(j) ?? "";
        if (c.is_ascii_alphanumeric()) {
            j += 1;
        } else {
            break;
        }
    }
    if (j == i + 1 || chars.at(j) != ";") {
        return null;
    }
    let name = line.slice(i + 1, j);
    let value = table.get(name);
    if (value == null) {
        null
    } else {
        EntityScan { end: j + 1, value: value }
    }
}

function scan_decimal_entity(chars: string[], i: int) -> EntityScan? {
    if (chars.at(i) != "&" || chars.at(i + 1) != "#") {
        return null;
    }
    let j = i + 2;
    let digits = 0;
    let n = 0;
    while (digits < 7) {
        let c = chars.at(j);
        if (c == null) {
            break;
        }
        if (!c.is_ascii_numeric()) {
            break;
        }
        n = n * 10 + ((c.code_point_at(0) ?? 48) - 48);
        j += 1;
        digits += 1;
    }
    if (digits < 1 || chars.at(j) != ";") {
        return null;
    }
    EntityScan { end: j + 1, value: code_point_string(n) }
}

function scan_hex_entity(chars: string[], i: int) -> EntityScan? {
    if (chars.at(i) != "&" || chars.at(i + 1) != "#") {
        return null;
    }
    let x = chars.at(i + 2);
    if (x != "x" && x != "X") {
        return null;
    }
    let j = i + 3;
    let digits = 0;
    let n = 0;
    while (digits < 6) {
        let c = chars.at(j);
        if (c == null) {
            break;
        }
        let d = hex_val(c);
        if (d == null) {
            break;
        }
        n = n * 16 + d;
        j += 1;
        digits += 1;
    }
    if (digits < 1 || chars.at(j) != ";") {
        return null;
    }
    EntityScan { end: j + 1, value: code_point_string(n) }
}

function scan_entity(line: string, i: int, table: map<string, string>) -> EntityScan? {
    scan_entity_chars(line, line.chars(), i, table)
}

function scan_entity_chars(
    line: string,
    chars: string[],
    i: int,
    table: map<string, string>,
) -> EntityScan? {
    let named = scan_named_entity(line, chars, i, table);
    if (named != null) {
        return named;
    }
    let hex = scan_hex_entity(chars, i);
    if (hex != null) {
        return hex;
    }
    scan_decimal_entity(chars, i)
}

function unescape_markdown(s: string, table: map<string, string>) -> string {
    if (s.index_of("\\") == null && s.index_of("&") == null) {
        return s;
    }
    let parts: string[] = [];
    let chars = s.chars();
    let i = 0;
    while (i < chars.length()) {
        let c = chars.at(i) ?? "";
        if (c == "\\" && root.block.is_escapable(chars.at(i + 1))) {
            parts.push(chars.at(i + 1) ?? "");
            i += 2;
        } else if (c == "&") {
            let ent = scan_entity_chars(s, chars, i, table);
            if let e: EntityScan = ent {
                parts.push(e.value);
                i = e.end;
            } else {
                parts.push(c);
                i += 1;
            }
        } else {
            let start = i;
            i += 1;
            while (i < chars.length()) {
                let n = chars.at(i) ?? "";
                if (n == "\\" || n == "&") {
                    break;
                }
                i += 1;
            }
            parts.push(s.slice(start, i));
        }
    }
    parts.join("")
}

class EntityRule {
    implements InlineParseRule {
        function name(self) -> string throws never {
            "entity"
        }

        function parse(self, s: Subject) -> bool throws never {
            if (peek(s) != "&") {
                return false;
            }
            let ent = scan_entity_chars(s.scan.line, s.scan.chars, s.scan.pos, s.entities);
            if let e: EntityScan = ent {
                advance_to(s, e.end);
                push_text(s, e.value);
                return true;
            }
            false
        }
    }
}

test "named entity table includes copy" {
    assert.equal(load_named_entities().get("copy"), "©")
}

test "load_named_entities returns the same copy entity twice" {
    let first = load_named_entities();
    let second = load_named_entities();
    assert.equal(first.get("copy"), "©");
    assert.equal(second.get("copy"), first.get("copy"));
    assert.equal(named_entity_cache().table?.get("copy"), "©")
}

test "named copy entity renders as copyright sign" {
    assert.equal(root.to_html("&copy;"), "<p>©</p>\n")
}
