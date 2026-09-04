"""stdin Markdown → stdout HTML adapter for spec_tests.py --program."""

from subprocess import PIPE, Popen


def pipe_through_prog(prog, text):
    proc = Popen(prog.split(), stdout=PIPE, stdin=PIPE, stderr=PIPE)
    result, err = proc.communicate(input=text.encode("utf-8"))
    return [proc.returncode, result, err]


class CMark:
    def __init__(self, prog=None, library_dir=None):
        if not prog:
            raise SystemExit("pass --program (for example ./bamark)")
        self.to_html = lambda markdown: pipe_through_prog(prog, markdown)
