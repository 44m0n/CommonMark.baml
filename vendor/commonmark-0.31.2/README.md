# CommonMark 0.31.2 fixtures

`spec.txt` is the CommonMark specification, vendored from
<https://github.com/commonmark/commonmark-spec/blob/0.31.2/spec.txt>.

License: [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

`spec-tests.json` is the 652 embedded examples extracted from that file
(tabs in the spec are the `→` character, stored here as real tabs).

`spec_tests.py` and `normalize.py` come from the same tag. `cmark.py` is a
local stdin/stdout adapter so we can run:

```bash
python3 vendor/commonmark-0.31.2/spec_tests.py \
  --spec vendor/commonmark-0.31.2/spec.txt \
  --program ./bamark
```
