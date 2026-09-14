# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Git tags are the project versions (`0.8`, not `0.8.0`). `bamark -V` prints
`bamark 0.31.2`: that is the [CommonMark](https://spec.commonmark.org/0.31.2/)
spec this engine targets, not a semver of this repository.

The supported v1 surface is `parse`, `render_html`, and `to_html`, plus the AST
types in `ns_ast` and `ParseOptions` / `BlockStart` / `InlineParseRule` for
dialects. Other `ns_*` functions are unsupported internals and may change
without a major version.

## [Unreleased]

### Added

- Documented that `parse`, `render_html`, `to_html`, and `bamark` have no
  timeout, max input size, or nest-depth cap. Callers that accept untrusted
  Markdown must bound bytes and wall time themselves.
- Python and TypeScript client generators in `baml.toml`
  (`baml generate` writes `generated/python` and `generated/typescript`).

### Changed

- Migrated the tested BAML toolchain and CI pin to `0.19.0`. JSON error types in the spec runner now use the renamed `baml.json.ParseError` and `baml.json.DecodeError` types.
- Rewrote the root README as a project overview: what the repository contains,
  how to consume it, versions vs the spec string, API, coverage, engine,
  tests, and layout.
- Clarified `safe` mode: it only changes emitted HTML (omit raw HTML; empty
  `javascript:`, `vbscript:`, `data:`, and `file:` URLs). It is not a general
  sanitizer and does not cap parse or render cost.

## [0.8] - 2026-09-05

First tagged release. CommonMark 0.31.2 only; this tree does not implement GFM.

### Added

- `parse` → typed `Document`; `render_html` / `to_html` → HTML. Default
  `ParseOptions` is `commonmark_options()`. Defaulted parameters must be passed
  by name.
- Rule-table dialects via `ParseOptions.block_starts` and
  `ParseOptions.inline_rules` (`BlockStart`, `InlineParseRule`).
- Packed CLI `bamark` (file or stdin → raw HTML) with `--safe`, `-h` / `--help`,
  `-V` / `--version`, and `--`. Input must be UTF-8. `-` or an omitted file
  reads `/dev/stdin` (Unix, Git Bash, WSL).
- Full CommonMark 0.31.2 coverage: 652/652 examples (`baml test` on toolchain
  0.18.0). Vendored spec fixtures and `spec_tests.py`.
- GitHub Actions: `baml check` and `baml test` on toolchain 0.18.0.
- Apache License 2.0. Vendored spec fixtures are CC-BY-SA 4.0. HTML named
  character references are from WHATWG (see NOTICE).

### Security

- Optional `safe` mode (`to_html(..., safe = true)` / `bamark --safe`): omit
  raw HTML as `<!-- raw HTML omitted -->`; empty `href` / `src` whose scheme is
  `javascript:`, `vbscript:`, `data:`, or `file:` (case-insensitive, after
  leading C0 controls, spaces, and tabs — code points `<= 0x20`).
- `http:` / `https:` / relative URLs still pass; attributes are not rewritten.
  `safe` does not cap parse or render cost.

[Unreleased]: https://github.com/44m0n/CommonMark.baml/compare/0.8...HEAD
[0.8]: https://github.com/44m0n/CommonMark.baml/releases/tag/0.8
