import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {
    "asr/index.html": "ASR theory dashboards",
    "call-ai/index.html": "Call-AI",
    "skud/index.html": "BST SKUD + T&A",
}
OPTIONAL = {
    "client-skud/index.html": "SKUD Client Execution Board",
}
EXPECTED = REQUIRED | OPTIONAL
ALLOWED_ROOT_HTML = {"index.html", *EXPECTED}
HTML_SUFFIXES = {".htm", ".html"}


class TitleParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.inside_title = False
        self.title_parts = []

    def handle_starttag(self, tag, attrs):
        if tag == "title":
            self.inside_title = True

    def handle_endtag(self, tag):
        if tag == "title":
            self.inside_title = False

    def handle_data(self, data):
        if self.inside_title:
            self.title_parts.append(data)


def find_public_html(repository_root):
    return {
        path.relative_to(repository_root).as_posix()
        for path in repository_root.rglob("*")
        if path.is_file() and path.suffix.casefold() in HTML_SUFFIXES
    }


def extract_title(html):
    parser = TitleParser()
    parser.feed(html)
    parser.close()
    return "".join(parser.title_parts)


class PublicTreeTests(unittest.TestCase):
    def assert_only_allowlisted_html_files(self, repository_root):
        public_html = find_public_html(repository_root)
        self.assertTrue({"index.html", *REQUIRED}.issubset(public_html))
        self.assertTrue(
            public_html.issubset(ALLOWED_ROOT_HTML),
            public_html - ALLOWED_ROOT_HTML,
        )

    def assert_expected_title(self, html, expected_title):
        self.assertIn(expected_title, extract_title(html))

    def assert_disallowed_html_file_fails_allowlist(self, extra_name):
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository_root = Path(temporary_directory)
            for relative_path in ALLOWED_ROOT_HTML:
                board_path = repository_root / relative_path
                board_path.parent.mkdir(parents=True, exist_ok=True)
                board_path.write_text(
                    "<!doctype html><html><head><title>Board</title></head>"
                    "<body>ok</body></html>",
                    encoding="utf-8",
                )

            (repository_root / extra_name).write_text(
                "<!doctype html><html><head><title>Extra</title></head>"
                "<body>extra</body></html>",
                encoding="utf-8",
            )

            with self.assertRaises(AssertionError) as rejection:
                self.assert_only_allowlisted_html_files(repository_root)

            self.assertIn(extra_name, str(rejection.exception))

    def test_only_allowlisted_html_files_are_public(self):
        self.assert_only_allowlisted_html_files(REPOSITORY_ROOT)

    def test_extra_htm_file_fails_allowlist(self):
        self.assert_disallowed_html_file_fails_allowlist("extra.htm")

    def test_uppercase_html_file_fails_allowlist(self):
        self.assert_disallowed_html_file_fails_allowlist("extra.HTML")

    def test_marker_in_body_does_not_satisfy_title_check(self):
        html = (
            "<!doctype html><html><head><title>Different board</title></head>"
            "<body>Call-AI</body></html>"
        )

        with self.assertRaises(AssertionError):
            self.assert_expected_title(html, "Call-AI")

    def test_each_board_contains_its_expected_title(self):
        for relative_path, expected_title in EXPECTED.items():
            with self.subTest(relative_path=relative_path):
                board_path = REPOSITORY_ROOT / relative_path
                if not board_path.is_file():
                    self.assertNotIn(relative_path, REQUIRED)
                    continue
                html = board_path.read_text(encoding="utf-8")

                self.assert_expected_title(html, expected_title)


if __name__ == "__main__":
    unittest.main()
