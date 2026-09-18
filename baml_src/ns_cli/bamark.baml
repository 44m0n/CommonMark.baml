class BamarkArgs {
    safe: bool,
    help: bool,
    version: bool,
    input: string?,
    error: string?,
}

function bamark_usage() -> string {
    [
        "Usage: bamark [options] [file]",
        "Read Markdown from a file or stdin and write HTML to stdout.",
        "",
        "  --safe         Omit raw HTML and empty javascript:, vbscript:, data:, and file: URLs",
        "  -h, --help     Show this help",
        "  -V, --version  Print bamark 0.31.2 (CommonMark spec version)",
        "",
        "If file is omitted or is -, read stdin (Unix, Git Bash, WSL).",
        "On Windows cmd/PowerShell, pass a file path. Input must be UTF-8.",
        "Default matches CommonMark: raw HTML and javascript: URLs pass through.",
        "",
    ]
        .join("\n")
}

function program_base(prog: string) -> string {
    let parts = prog.replace_all("\\", "/").split("/");
    parts.at(parts.length() - 1) ?? prog
}

function is_baml_runner(prog: string) -> bool {
    let base = program_base(prog).to_lower_case();
    base == "baml-cli" || base == "baml-cli.exe"
}

function skip_program_args(args: string[]) -> int {
    if (args.length() == 0 || args[0].starts_with("-")) {
        return 0;
    }
    let i = 1;
    if (i < args.length() && !args[i].starts_with("-") && is_baml_runner(args[0])) {
        i += 1;
    }
    if (
        i == 1
            && i < args.length()
            && !args[i].starts_with("-")
            && program_base(args[0]).to_lower_case() == program_base(args[i]).to_lower_case()
    ) {
        i += 1;
    }
    i
}

function parse_bamark_args(args: string[]) -> BamarkArgs {
    let parsed = BamarkArgs { safe: false, help: false, version: false, input: null, error: null };
    let i = skip_program_args(args);
    let rest_positional = false;
    while (i < args.length()) {
        let a = args[i];
        i += 1;
        if (!rest_positional && (a == "--help" || a == "-h")) {
            parsed.help = true;
        } else if (!rest_positional && (a == "--version" || a == "-V")) {
            parsed.version = true;
        } else if (!rest_positional && a == "--safe") {
            parsed.safe = true;
        } else if (!rest_positional && a == "--") {
            rest_positional = true;
        } else if (!rest_positional && a.starts_with("-") && a != "-") {
            parsed.error = `unknown option: ${a}`;
            return parsed;
        } else {
            if (parsed.input != null) {
                parsed.error = `unexpected argument: ${a}`;
                return parsed;
            }
            parsed.input = a;
        }
    }
    parsed
}

function read_markdown(path: string?) -> string throws baml.errors.Io | baml.errors.ParseError {
    if (path == null || path == "-") {
        baml.fs.read("/dev/stdin")
    } else {
        baml.fs.read(path)
    }
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
    let md = read_markdown(args.input) catch_all (e) {
        _ => {
            baml.io.eprintln(e.to_string());
            baml.sys.exit(1);
            ""
        }
    };
    //# Render Markdown as HTML
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
    assert.equal(parsed.input, null);
    assert.equal(parsed.error, null)
}

test "parse_bamark_args unknown flag is an error" {
    let parsed = parse_bamark_args(["./bamark", "--bogus"]);
    assert.equal(parsed.error, "unknown option: --bogus")
}

test "parse_bamark_args takes a file after the program name" {
    let parsed = parse_bamark_args(["bamark", "README.md"]);
    assert.equal(parsed.input, "README.md");
    assert.equal(parsed.safe, false);
    assert.equal(parsed.error, null)
}

test "parse_bamark_args file can mix with --safe" {
    let after = parse_bamark_args(["bamark", "--safe", "notes.md"]);
    assert.equal(after.input, "notes.md");
    assert.is_true(after.safe);
    let before = parse_bamark_args(["bamark", "notes.md", "--safe"]);
    assert.equal(before.input, "notes.md");
    assert.is_true(before.safe)
}

test "parse_bamark_args dash is stdin and extra files error" {
    let dash = parse_bamark_args(["bamark", "-"]);
    assert.equal(dash.input, "-");
    assert.equal(dash.error, null);
    let extra = parse_bamark_args(["bamark", "a.md", "b.md"]);
    assert.equal(extra.error, "unexpected argument: b.md")
}

test "parse_bamark_args end of options and windows path" {
    let dashed = parse_bamark_args(["bamark", "--", "-weird.md"]);
    assert.equal(dashed.input, "-weird.md");
    assert.equal(dashed.error, null);
    let win = parse_bamark_args(["bamark.exe", "C:\\docs\\hi.md"]);
    assert.equal(win.input, "C:\\docs\\hi.md")
}

test "parse_bamark_args skips baml run runner and target" {
    let parsed = parse_bamark_args(["/home/coder/.baml/toolchains/0.19.0/bin/baml-cli", "cli.bamark", "--safe", "README.md"]);
    assert.equal(parsed.input, "README.md");
    assert.is_true(parsed.safe);
    assert.equal(parsed.error, null);
    let win_cli = parse_bamark_args(["C:\\Users\\me\\.baml\\bin\\baml-cli.exe", "cli.bamark", "notes.md"]);
    assert.equal(win_cli.input, "notes.md")
}

test "parse_bamark_args skips duplicated packed entrypoint before a file" {
    let parsed = parse_bamark_args(["bamark", "bamark", "README.md"]);
    assert.equal(parsed.input, "README.md");
    assert.equal(parsed.error, null);
    let windows = parse_bamark_args(["C:\\Tools\\BAMARK.EXE", "bamark.exe", "notes.md"]);
    assert.equal(windows.input, "notes.md");
    assert.equal(windows.error, null)
}

test "parse_bamark_args skips duplicated packed entrypoint before stdin" {
    let parsed = parse_bamark_args(["bamark", "bamark"]);
    assert.equal(parsed.input, null);
    assert.equal(parsed.error, null)
}

test "bamark usage mentions file stdin safe and windows" {
    let u = bamark_usage();
    assert.is_true(u.includes("[file]"));
    assert.is_true(u.includes("stdin"));
    assert.is_true(u.includes("--safe"));
    assert.is_true(u.includes("javascript:"));
    assert.is_true(u.includes("Windows"))
}
