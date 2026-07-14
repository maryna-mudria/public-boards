import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PAGES_WORKFLOW = REPOSITORY_ROOT / ".github" / "workflows" / "pages.yml"
PUBLIC_INDEX = REPOSITORY_ROOT / "index.html"


class PagesWorkflowTests(unittest.TestCase):
    def test_stages_client_skud_as_a_regular_public_page(self):
        workflow = PAGES_WORKFLOW.read_text(encoding="utf-8")

        self.assertIn(
            "find index.html asr call-ai skud client-skud -type l",
            workflow,
        )
        self.assertIn(
            "client-skud/index.html",
            workflow,
        )
        self.assertIn(
            "mkdir -p _site/asr _site/call-ai _site/skud _site/client-skud",
            workflow,
        )
        self.assertIn(
            "install -m 0644 client-skud/index.html _site/client-skud/index.html",
            workflow,
        )

    def test_public_index_links_to_client_skud(self):
        index = PUBLIC_INDEX.read_text(encoding="utf-8")

        self.assertIn('href="./client-skud/"', index)


if __name__ == "__main__":
    unittest.main()
