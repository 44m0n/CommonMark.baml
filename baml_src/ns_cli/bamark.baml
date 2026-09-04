function read_stdin() -> string throws baml.errors.Io | baml.errors.ParseError {
    baml.fs.read("/dev/stdin")
}

function bamark() -> void {
    let md = read_stdin() catch_all (e) {
        _ => {
            baml.io.eprintln(e.to_string());
            baml.sys.exit(1);
            ""
        }
    };
    baml.io.print(root.to_html(md))
}
