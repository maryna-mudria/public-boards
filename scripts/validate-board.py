#!/usr/bin/env python3

import re
import sys
from html.parser import HTMLParser
from pathlib import Path


ALLOWED_TARGETS = {
    "asr/index.html",
    "call-ai/index.html",
    "skud/index.html",
    "client-skud/index.html",
}

REQUIRED_ELEMENTS = ("html", "title")

PATTERNS = {
    "GitHub token": r"\b(?:ghp|github_pat)_[A-Za-z0-9_]{20,}\b",
    "private key": r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
    "password assignment": r"(?i)\bpassword\s*[:=]\s*['\"]?[^\s<'\"]{6,}",
    "localhost URL": r"https?://(?:localhost|127\.0\.0\.1)(?::\d+)?",
    "private network URL": r"https?://(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})(?::\d+)?",
}
COMPILED_PATTERNS = {
    name: re.compile(pattern, re.IGNORECASE)
    for name, pattern in PATTERNS.items()
}


class BoardStructureParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.seen = set()
        self.open_elements = []
        self.error = None

    def handle_starttag(self, tag, attrs):
        if self.error is not None or tag not in REQUIRED_ELEMENTS:
            return
        if tag in self.seen:
            self.error = f"duplicate <{tag}> element"
            return
        if tag == "title" and "html" not in self.open_elements:
            self.error = "<title> element is outside <html>"
            return

        self.seen.add(tag)
        self.open_elements.append(tag)

    def handle_endtag(self, tag):
        if self.error is not None or tag not in REQUIRED_ELEMENTS:
            return
        if not self.open_elements or tag not in self.open_elements:
            self.error = f"unexpected closing </{tag}> tag"
            return
        if self.open_elements[-1] != tag:
            self.error = f"unclosed <{self.open_elements[-1]}> element"
            return

        self.open_elements.pop()

    def diagnostic(self):
        for tag in REQUIRED_ELEMENTS:
            if tag not in self.seen:
                return f"missing <{tag}> element"
        if self.error is not None:
            return self.error
        if self.open_elements:
            return f"unclosed <{self.open_elements[-1]}> element"
        return None


def reject(diagnostic):
    print(f"error: {diagnostic}", file=sys.stderr)
    return 1


def main(argv):
    if len(argv) != 3:
        return reject("usage: validate-board.py SOURCE_PATH TARGET_PATH")

    source_path = argv[1]
    target_path = argv[2]

    if target_path not in ALLOWED_TARGETS:
        return reject("target path is not allowlisted")

    try:
        html = Path(source_path).read_text(encoding="utf-8")
    except (OSError, UnicodeError, ValueError):
        return reject("unable to read source as UTF-8")

    structure = BoardStructureParser()
    structure.feed(html)
    structure.close()
    structure_diagnostic = structure.diagnostic()
    if structure_diagnostic is not None:
        return reject(structure_diagnostic)

    for name, pattern in COMPILED_PATTERNS.items():
        if pattern.search(html):
            return reject(f"detected {name}")

    print(f"validated: {target_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
