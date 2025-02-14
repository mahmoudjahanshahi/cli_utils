#!/usr/bin/env python3

"""
Web Scraper Script Using Playwright

This script reads lines from standard input, where each line contains a unique key and a single URL.
It uses Playwright to visit each URL, waits for the DOM to fully load, and extracts all text content from the page.

Key Features:
- Saves the extracted text to a 'data' directory, with each key corresponding to a file (e.g., key.txt).
- If multiple URLs share the same key, their contents are appended to the same file, separated by the URL.
- Handles timeout errors with a fallback delay.
- Uses the default Playwright browser User-Agent for better compatibility and to reduce detection.

Usage:
  echo "key1 http://example.com" | ./fetch_page_playwright.py
  cat urls.txt | ./fetch_page_playwright.py

Output:
  data/key1.txt (containing all pages fetched under 'key1')

Dependencies:
  - Python 3.x
  - Playwright (install with `pip install playwright`)
  - Install Playwright browsers with `playwright install`
"""

import sys
import os
import time
from playwright.sync_api import sync_playwright, TimeoutError

def fetch_page_text(page, url, user_agent):
    try:
        page.set_user_agent(user_agent)
        page.goto(url, wait_until='domcontentloaded', timeout=10000)
    except TimeoutError:
        time.sleep(5)

    return page.evaluate("document.body.innerText")

def main():
    output_dir = "data"
    os.makedirs(output_dir, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        user_agent = browser.user_agent
        page = browser.new_page()

        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            parts = line.split(None, 1)
            if len(parts) < 2:
                continue
            key, url = parts

            try:
                text_content = fetch_page_text(page, url, user_agent)
                out_path = os.path.join(output_dir, f"{key}.txt")
                with open(out_path, "a", encoding="utf-8") as f:
                    f.write(f"===== URL: {url} =====\n")
                    f.write(text_content)
                    f.write("\n\n")
            except Exception as e:
                print(f"Error fetching {url}: {e}", file=sys.stderr)

        browser.close()

if __name__ == "__main__":
    main()
