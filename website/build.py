#!/usr/bin/env python3
"""Build and check a dependency-free GitHub Pages site. Never publishes."""
import argparse
from datetime import date
from html import escape
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sys
from urllib.parse import quote, unquote, urlsplit

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "src"
OUTPUT = HERE / "dist"
PAGES = {
    "index.html": (
        "Pocket Almanac — Personal iPhone Apps",
        "Personal iPhone apps, shared in case they are useful to you. Help and privacy information for Day in Ink and Blotter.",
    ),
    "day-in-ink/support.html": (
        "Day in Ink — Help & Support",
        "Get help with Day in Ink habits, pass/fail defaults, tracking types, backups, and restoring your progress.",
    ),
    "day-in-ink/privacy.html": (
        "Day in Ink — Privacy Policy",
        "How Day in Ink handles habit data, on-device storage, backups, deletion, and support correspondence.",
    ),
    "blotter/support.html": (
        "Blotter — Help & Support",
        "Set up Blotter message filtering, configure keyword matching, troubleshoot eligible texts, and contact support.",
    ),
    "blotter/privacy.html": (
        "Blotter — Privacy Policy",
        "How Blotter processes eligible texts on your iPhone, stores keyword rules, and handles deletion and support.",
    ),
}

SUPPORT_PRIVACY = """<section><h2>When you contact support</h2>
<p>Issues and feature requests are handled in the app repository on GitHub. GitHub processes your account information and anything you submit under its own privacy policy. In a public repository, issues and comments are public: your username, message, and attachments can be read by others. Do not post private habit records, real texts, verification codes, or phone numbers.</p>
<p>If you email instead, the developer receives your email address and the information you choose to include. This is used to answer your request, troubleshoot issues, and handle follow-up correspondence. Email is processed by the email providers involved in delivery and storage.</p>
<p>Support correspondence is retained as needed to resolve your request and maintain relevant correspondence, or as required by law. You can use the contact below to ask about or request deletion of information you sent to support. Please do not send private habit records, real message contents, verification codes, or phone numbers unless necessary and discussed first.</p></section>"""

WEBSITE_PRIVACY = """<section><h2>This support website</h2>
<p>This website uses Google Analytics to understand visits and how its pages are used. It uses the same Google Analytics measurement ID as droessmj.com. Google receives information such as pages visited, browser and device details, and network information; analytics cookies can recognize returning browsers and may be shared across droessmj.com subdomains. This website analytics is separate from the iPhone apps, which do not include Google Analytics or send habit data, keyword rules, or message contents to it.</p>
<p>Google processes analytics information under its <a href="https://policies.google.com/privacy">Privacy Policy</a>. Analytics retention and related settings are managed in the shared Google Analytics property. You can block analytics with browser controls or use the <a href="https://tools.google.com/dlpage/gaoptout">Google Analytics opt-out browser add-on</a> where supported. For questions or deletion requests about information sent through this website, use the privacy contact below. The site loads no third-party fonts or embedded media. Email links open your chosen mail app; no message is sent until you send it.</p>
<p>The website is hosted on GitHub Pages. GitHub logs visitors’ IP addresses for security purposes. This is separate from data processed by the iPhone app. See <a href="https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages#data-collection">GitHub Pages data collection</a> and the <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement">GitHub Privacy Statement</a>.</p></section>"""


class PageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.links = []
        self.h1_count = 0
        self.errors = []
        self.has_language = False
        self.has_viewport = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "html":
            self.has_language = attrs.get("lang") == "en"
        if tag == "meta" and attrs.get("name") == "viewport":
            self.has_viewport = True
        if tag == "h1":
            self.h1_count += 1
        if "id" in attrs:
            if attrs["id"] in self.ids:
                self.errors.append("duplicate ID: " + attrs["id"])
            self.ids.add(attrs["id"])
        for attr in ("href", "src"):
            if attr in attrs:
                self.links.append(attrs[attr])
        if tag == "img" and "alt" not in attrs:
            self.errors.append("image missing alt attribute")


def render(config):
    email = config["support_email"].strip()
    if email and not re.fullmatch(r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", email):
        raise ValueError("support_email must be a plain email address")
    updated = date.fromisoformat(config["policy_updated"])
    repository = config["repository_url"].rstrip("/")
    if not re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("repository_url must be an HTTPS GitHub repository URL")
    values = {
        "developer": escape(config["developer_handle"]),
        "repository_url": escape(repository, quote=True),
        "issues_url": escape(repository + "/issues", quote=True),
        "year": str(updated.year),
        "policy_date": updated.isoformat(),
        "policy_date_label": updated.strftime("%B") + f" {updated.day}, {updated.year}",
        "support_privacy": SUPPORT_PRIVACY,
        "website_privacy": WEBSITE_PRIVACY,
    }
    for key, app in (("day", "Day in Ink"), ("blotter", "Blotter")):
        issue_url = repository + "/issues/new?title=" + quote("[" + app + "] ", safe="")
        contact = (f'<p class="issue-actions"><a class="button issue-link" href="{escape(issue_url, quote=True)}">'
                   'Open a GitHub issue <span aria-hidden="true">↗</span></a> '
                   f'<a href="{escape(repository + "/issues", quote=True)}">Browse issues</a></p>')
        if email:
            address = quote(email, safe="@")
            subject = quote(app + " support", safe="")
            contact += (
                f'<p class="contact-email">For email or private questions: <a href="mailto:{address}?subject={subject}">'
                + escape(email) + "</a></p>"
            )
        values["contact_" + key] = contact

    def replace_tokens(source, tokens):
        def replace(match):
            key = match.group(1)
            if key not in tokens:
                raise ValueError("Unknown template token: " + key)
            return tokens[key]
        return re.sub(r"\{\{([a-z_]+)\}\}", replace, source)

    files = {".nojekyll": b""}
    layout = (SOURCE / "layout.html").read_text()
    for name, (title, description) in PAGES.items():
        app = name.split("/")[0] if "/" in name else "home"
        app_icon = "assets/" + app + "-icon.png"
        root = "../" if "/" in name else ""
        favicon = app_icon if app != "home" else "assets/favicon.svg"
        content = replace_tokens((SOURCE / name).read_text(), values)
        tokens = dict(values, content=content, title=escape(title),
                      description=escape(description), root=root, theme=app,
                      theme_color="#f4f0e7" if app != "blotter" else "#f2f2f7",
                      favicon=favicon, icon_type="image/svg+xml" if app == "home" else "image/png",
                      app_badge="" if app == "home" else f'<img class="page-app-icon" src="{root + app_icon}" width="72" height="72" alt="">')
        files[name] = replace_tokens(layout, tokens).encode()
    # Keep a fixed public asset list: an accidental file in src/assets must not ship.
    for name in ("favicon.svg", "styles.css"):
        files["assets/" + name] = (SOURCE / "assets" / name).read_bytes()
    for app, icon in {
        "day-in-ink": "apps/DayInInk/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        "blotter": "apps/Sift/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    }.items():
        files["assets/" + app + "-icon.png"] = (HERE.parent / icon).read_bytes()
    return files


def validate(files):
    pages = {}
    errors = []
    for name in PAGES:
        parser = PageParser()
        parser.feed(files[name].decode())
        pages[name] = parser
        if parser.h1_count != 1:
            parser.errors.append("expected one h1")
        if not parser.has_language or not parser.has_viewport:
            parser.errors.append("missing language or mobile viewport")
        errors.extend(name + ": " + error for error in parser.errors)
    for name, parser in pages.items():
        for link in parser.links:
            target = urlsplit(link)
            if target.scheme in ("https", "mailto"):
                continue
            if target.scheme or target.netloc or target.path.startswith("/"):
                errors.append(name + ": unsupported or root-relative link: " + link)
                continue
            path = (OUTPUT / name).parent / unquote(target.path) if target.path else OUTPUT / name
            try:
                local = path.resolve().relative_to(OUTPUT.resolve()).as_posix()
            except ValueError:
                errors.append(name + ": link escapes website: " + link)
                continue
            if local not in files:
                errors.append(name + ": missing local target: " + link)
            elif target.fragment and (local not in pages or unquote(target.fragment) not in pages[local].ids):
                errors.append(name + ": missing fragment: " + link)
    if errors:
        raise ValueError("\n".join(errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check generated files without writing")
    parser.add_argument("--ready", action="store_true", help="Also require a configured public support email")
    args = parser.parse_args()
    config = json.loads((HERE / "site.json").read_text())
    if SOURCE.is_symlink() or OUTPUT.is_symlink() or any(path.is_symlink() for directory in (SOURCE, OUTPUT) for path in directory.rglob("*")):
        raise ValueError("Website source/output must not contain symbolic links")
    if args.ready and not config["support_email"].strip():
        raise ValueError("Set support_email in website/site.json before publication")
    files = render(config)
    validate(files)
    if args.check:
        for name, data in files.items():
            path = OUTPUT / name
            if not path.is_file() or path.read_bytes() != data:
                raise ValueError("Generated output is missing or outdated: " + name + "; run build.py")
        actual = {path.relative_to(OUTPUT).as_posix() for path in OUTPUT.rglob("*") if path.is_file()}
        if actual != set(files):
            raise ValueError("Unexpected files in dist: " + ", ".join(sorted(actual - set(files))))
    else:
        for name, data in files.items():
            path = OUTPUT / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print(f"{'Checked' if args.check else 'Built'} {len(PAGES)} pages and their local links, fragments, and assets.")
    if not config["support_email"].strip():
        print("Draft only: support email is not configured.")
    print("No files have been published.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
