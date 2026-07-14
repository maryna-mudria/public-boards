import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = REPOSITORY_ROOT / "scripts" / "validate-board.py"
ALLOWED = (
    "asr/index.html",
    "call-ai/index.html",
    "skud/index.html",
    "client-skud/index.html",
)
SAFE_HTML = (
    "<!doctype html><html><head><title>Board</title></head>"
    "<body>ok</body></html>"
)


class ValidateBoardTests(unittest.TestCase):
    def run_validator(self, html, target, *, write_source=True):
        with tempfile.TemporaryDirectory() as temporary_directory:
            source = Path(temporary_directory) / "board.html"
            if write_source:
                if isinstance(html, bytes):
                    source.write_bytes(html)
                else:
                    source.write_text(html, encoding="utf-8")

            return subprocess.run(
                [sys.executable, str(VALIDATOR), str(source), target],
                cwd=temporary_directory,
                text=True,
                capture_output=True,
            )

    def assert_rejected(self, html, target, diagnostic, *, write_source=True):
        result = self.run_validator(
            html,
            target,
            write_source=write_source,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(diagnostic, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_each_allowlisted_target_accepts_safe_html(self):
        for target in ALLOWED:
            with self.subTest(target=target):
                result = self.run_validator(SAFE_HTML, target)

                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, f"validated: {target}\n")
                self.assertEqual(result.stderr, "")

    def test_rejects_targets_outside_the_allowlist_before_reading_source(self):
        for target in ("../index.html", "other/index.html"):
            with self.subTest(target=target):
                self.assert_rejected(
                    SAFE_HTML,
                    target,
                    "target path is not allowlisted",
                    write_source=False,
                )

    def test_rejects_missing_html_element(self):
        html = (
            "<!doctype html><head><title>Board</title></head>"
            "<body>ok</body>"
        )

        self.assert_rejected(
            html,
            ALLOWED[0],
            "missing <html> element",
        )

    def test_rejects_missing_title_element(self):
        html = "<!doctype html><html><head></head><body>ok</body></html>"

        self.assert_rejected(
            html,
            ALLOWED[0],
            "missing <title> element",
        )

    def test_rejects_required_tags_only_in_html_comment(self):
        html = (
            "<!doctype html><!-- "
            "<html><head><title>Board</title></head><body>ok</body></html>"
            " -->"
        )

        self.assert_rejected(
            html,
            ALLOWED[0],
            "missing <html> element",
        )

    def test_rejects_required_tags_only_in_script_text(self):
        html = (
            '<!doctype html><script>const markup = "'
            "<html><title>Board</title></html>"
            '";</script>'
        )

        self.assert_rejected(
            html,
            ALLOWED[0],
            "missing <html> element",
        )

    def test_rejects_unclosed_html_element(self):
        html = (
            "<!doctype html><html><head><title>Board</title></head>"
            "<body>ok</body>"
        )

        self.assert_rejected(
            html,
            ALLOWED[0],
            "unclosed <html> element",
        )

    def test_rejects_unclosed_title_element(self):
        html = (
            "<!doctype html><html><head><title>Board</head>"
            "<body>ok</body></html>"
        )

        self.assert_rejected(
            html,
            ALLOWED[0],
            "unclosed <title> element",
        )

    def test_rejects_github_token(self):
        token = "ghp_" + "A" * 36

        self.assert_rejected(
            SAFE_HTML.replace("ok", token),
            ALLOWED[0],
            "detected GitHub token",
        )

    def test_rejects_private_key(self):
        self.assert_rejected(
            SAFE_HTML.replace("ok", "-----BEGIN PRIVATE KEY-----"),
            ALLOWED[0],
            "detected private key",
        )

    def test_rejects_password_assignment(self):
        self.assert_rejected(
            SAFE_HTML.replace("ok", "password = hunter2"),
            ALLOWED[0],
            "detected password assignment",
        )

    def test_rejects_localhost_urls(self):
        for url in ("http://localhost:3000", "http://127.0.0.1"):
            with self.subTest(url=url):
                self.assert_rejected(
                    SAFE_HTML.replace("ok", url),
                    ALLOWED[0],
                    "detected localhost URL",
                )

    def test_rejects_private_network_urls(self):
        for url in (
            "http://10.1.2.3",
            "http://192.168.1.2",
            "http://172.16.0.1",
        ):
            with self.subTest(url=url):
                self.assert_rejected(
                    SAFE_HTML.replace("ok", url),
                    ALLOWED[0],
                    "detected private network URL",
                )

    def test_rejects_missing_source(self):
        self.assert_rejected(
            SAFE_HTML,
            ALLOWED[0],
            "unable to read source as UTF-8",
            write_source=False,
        )

    def test_rejects_non_utf8_source(self):
        self.assert_rejected(
            b"\xff\xfe\xfd",
            ALLOWED[0],
            "unable to read source as UTF-8",
        )


if __name__ == "__main__":
    unittest.main()
