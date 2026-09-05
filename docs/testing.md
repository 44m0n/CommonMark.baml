# Testing

How this repository checks the parser and HTML renderer against CommonMark 0.31.2. Packing `bamark` for the Python harness is in [usage.md](usage.md). The renderer under test is described in [html.md](html.md).

## Toolchain

```bash
baml toolchain use 0.18.0
```

Tests assume that toolchain.

## Compile

```bash
baml check
```

Type-checks the project without running tests.

## `baml test`

```bash
baml test
```

Runs unit tests and every CommonMark spec section. Section coverage is `spec_failures(section)` from `baml_src/ns_spec/runner.baml`, asserted to return an empty list of failing example numbers. Together those section tests cover all **652** examples in the vendored dump.

`spec_failures` loads the examples for `section`, panics if the name is unknown (`unknown CommonMark spec section: …` when no examples match), then compares `to_html(markdown)` to the expected HTML for each example. Failed example numbers are returned; a passing section is `[]`. Spec comparison uses default `to_html` (`safe = false`).

## Spec runner

`baml_src/ns_spec/runner.baml` reads `vendor/commonmark-0.31.2/spec-tests.json` (`spec_tests_path()`), decodes it as `SpecExample[]`, and filters by `section` or by example number. The dump’s length is asserted to be 652.

## Python harness

The upstream process-per-example harness still works against a packed binary:

```bash
baml pack cli.bamark --output ./bamark
python3 vendor/commonmark-0.31.2/spec_tests.py \
  --spec vendor/commonmark-0.31.2/spec.txt \
  --program ./bamark
```

It needs `./bamark` (see [usage.md](usage.md)). Each example starts a new process. Cold start of the packed binary is about one second, so this path is slow. Prefer `baml test` for day-to-day coverage of the 652 examples.

## Fixtures

Vendored under `vendor/commonmark-0.31.2/`:

- `spec.txt` — CommonMark 0.31.2 specification (CC-BY-SA 4.0).
- `spec-tests.json` — the 652 embedded examples extracted from that file.
- `spec_tests.py` (and `normalize.py`) — BSD-2-Clause.

See `NOTICE` for the full attribution.

## Extension examples

Dialect hooks are exercised with extra rules that are not part of CommonMark. Without those rules, the same input is ordinary text.

- `PercentBreakStart` in `baml_src/ns_block/options.baml` — a `BlockStart` whose `triggers()` is `%`. Appended to `commonmark_options().block_starts`, a line of three or more `%` characters (spaces and tabs allowed between them) renders as `<hr />`. Dispatch is by trigger characters, not by `name()`.
- `PercentSpanRule` in `baml_src/ns_inline/parse.baml` — an `InlineParseRule` whose `triggers()` is `%`. Appended to `ParseOptions.inline_rules`, `%x%` becomes `<span>x</span>` (via `HtmlInline`). Without the extra rule, `%x%` stays text.

How to write your own: [extensions.md](extensions.md).
