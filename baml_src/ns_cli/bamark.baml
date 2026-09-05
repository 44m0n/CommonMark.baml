class BamarkArgs {
    safe: bool,
    help: bool,
    version: bool,
    error: string?,
}

function bamark_usage() -> string {
    [
        "Usage: bamark [options]",
        "Read Markdown from stdin and write HTML to stdout.",
        "",
        "  --safe         Omit raw HTML and empty javascript:, vbscript:, data:, and file: URLs",
        "  -h, --help     Show this help",
        "  -V, --version  Print bamark 0.31.2 (CommonMark spec version)",
        "",
        "Default matches CommonMark: raw HTML and javascript: URLs pass through.",
        "",
    ]
        .join("\n")
}

function parse_bamark_args(args: string[]) -> BamarkArgs {
    let parsed = BamarkArgs { safe: false, help: false, version: false, error: null };
    let i = 0;
    if (args.length() > 0 && !args[0].starts_with("-")) {
        i = 1;
    }
    while (i < args.length()) {
        let a = args[i];
        i += 1;
        if (a == "--help" || a == "-h") {
            parsed.help = true;
        } else if (a == "--version" || a == "-V") {
            parsed.version = true;
        } else if (a == "--safe") {
            parsed.safe = true;
        } else if (a.starts_with("-")) {
            parsed.error = `unknown option: ${a}`;
            return parsed;
        }
    }
    parsed
}

function read_stdin() -> string throws baml.errors.Io | baml.errors.ParseError {
    baml.fs.read("/dev/stdin")
}

function bamark() -> void {
    let args = parse_bamark_args(baml.sys.argv());
    //# Handle --help, --version, and unknown flags
    if let err: string = args.error {
        baml.io.eprintln(err);
        baml.sys.exit(2);
    }
    if (args.help) {
        baml.io.print(bamark_usage());
        baml.sys.exit(0);
    }
    if (args.version) {
        baml.io.println("bamark 0.31.2");
        baml.sys.exit(0);
    }
    let md = read_stdin() catch_all (e) {
        _ => {
            baml.io.eprintln(e.to_string());
            baml.sys.exit(1);
            ""
        }
    };
    //# Render stdin Markdown as HTML
    baml.io.print(root.to_html(md, safe = args.safe))
}

test "parse_bamark_args help and version flags" {
    let help_long = parse_bamark_args(["--help"]);
    assert.is_true(help_long.help);
    assert.equal(help_long.error, null);
    let help_short = parse_bamark_args(["-h"]);
    assert.is_true(help_short.help);
    let ver_long = parse_bamark_args(["--version"]);
    assert.is_true(ver_long.version);
    let ver_short = parse_bamark_args(["-V"]);
    assert.is_true(ver_short.version)
}

test "parse_bamark_args skips program name and sets safe" {
    let parsed = parse_bamark_args(["bamark", "--safe"]);
    assert.is_true(parsed.safe);
    assert.equal(parsed.help, false);
    assert.equal(parsed.version, false);
    assert.equal(parsed.error, null)
}

test "parse_bamark_args unknown flag is an error" {
    let parsed = parse_bamark_args(["./bamark", "--bogus"]);
    assert.equal(parsed.error, "unknown option: --bogus")
}

test "bamark usage mentions stdin safe and commonmark default" {
    let u = bamark_usage();
    assert.is_true(u.includes("stdin"));
    assert.is_true(u.includes("--safe"));
    assert.is_true(u.includes("javascript:"))
}
