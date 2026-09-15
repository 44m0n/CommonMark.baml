# CommonMark.baml documentation

CommonMark.baml is a CommonMark 0.31.2 parser written in [BAML](https://docs.boundaryml.com). It turns Markdown into a typed AST (`Document` and the types in `ns_ast`) and renders that tree as HTML. This tree does not implement GFM.

The supported v1 surface is `parse`, `render_html`, and `to_html`, plus the AST types and the dialect types `ParseOptions`, `BlockStart`, `BlockStartContext`, `InlineParseRule`, and `InlineParseContext`. BAML cannot hide namespaces, so `Parser`, `Open`, scanners, spec helpers, and other `ns_*` functions are visible but unsupported: they may change without a major version. The project is pinned and tested on BAML nightly 0.19.1-nightly.20260911.a and passes 652/652 CommonMark examples.

These pages describe usage (including resource limits), spec coverage, the AST, extensions, architecture, HTML rendering (including `safe` mode), and tests. The [root README](../README.md) is the project overview: what this repository contains, versions, API, coverage, and how to run it. Copyright 2026 Ramon C Horomnea; Apache License 2.0. Keep [NOTICE](../NOTICE) with the code. Vendored spec fixtures are CC-BY-SA 4.0; HTML named character references are from WHATWG (see NOTICE).

## Contents

- [Changelog](../CHANGELOG.md) — tagged releases (`0.8` and later). Project version is the git tag; `bamark -V` prints the CommonMark spec (`0.31.2`).
- [Usage](usage.md) — `parse`, `render_html`, `to_html`, the `bamark` CLI, and [limits](usage.md#limits).
- [Spec coverage](coverage.md) — CommonMark 0.31.2 conformance (652/652) and what is out of scope.
- [AST](ast.md) — `Document`, `Block`, `Inline`, and post-`parse()` field conventions.
- [Extensions](extensions.md) — `ParseOptions`, `BlockStart`, and `InlineParseRule`.
- [Architecture](architecture.md) — two-phase parse and `baml_src/` layout.
- [HTML rendering](html.md) — HTML renderer and `safe` mode.
- [Testing](testing.md) — `baml test` and `vendor/commonmark-0.31.2/spec_tests.py`.

[Root README](../README.md)
