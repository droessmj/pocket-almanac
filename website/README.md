# Pocket Almanac website

A static website for **Day in Ink: Habit Tracker** and **Blotter: Message Filter**. The branding describes personal tools shared with others, with no promised response time or roadmap. Includes a shared home page and separate support/privacy pages for each app. It is prepared locally and has not been published.

## Edit and build

Issues and support link to **https://github.com/droessmj/pocket-almanac/issues**, derived from the repository URL in `site.json`. Email **app-support@droessmj.com** remains available for private or privacy-related questions and visitors without repo access. The site uses the handle `droessmj`; the developer’s full name does not appear in the website source or generated pages. This does not remove identity information from the rest of the repository or its Git history.

The repository is currently private. Its issue links become generally accessible only after the repository is made public. Verify issue access and email delivery before submitting these support URLs to Apple. Update `repository_url` if you rename the GitHub repo again; update the policy revision date when changing a policy.

Edit page content in `src/`, shared markup in `src/layout.html`, and styles in `src/assets/styles.css`. Shared privacy paragraphs live in `build.py`. Build with Python 3 (standard library only):

```sh
python3 website/build.py
python3 website/build.py --check --ready
```

`dist/` contains only public HTML, CSS, the favicon, the two actual app icons, and `.nojekyll`. The builder copies icons directly from the app asset catalogs. It needs no server-side code, JavaScript, or package installation. Generated files are included for direct preview and upload. Rebuild after editing sources. The check verifies output freshness, local links/fragments, assets, page headings, language, viewport metadata, support contact configuration, an exact public file list, and absence of symbolic links. It does not verify mailbox delivery, live repository visibility, or App Review acceptance.

To preview from the repository root:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory website/dist
```

Open `http://127.0.0.1:8000/`. Stop the server with Control-C. You can also open `dist/index.html` directly; all internal links and assets use relative paths. The site supports GitHub Pages project paths such as `/pocket-almanac/` and custom domains without rebuilding.

## Publish later, when ready

The existing repository has been renamed by its owner to `droessmj/pocket-almanac`; the local origin URL and site links now use that name. No commit, push, visibility change, Pages setting, or deployment has been performed by this work. Renaming the local `sift` folder is optional and does not affect the site or the app bundle IDs.

1. Read [the security review](../docs/security/PUBLIC_RELEASE_REVIEW.md) and resolve or explicitly accept the identity/history and personal schedule disclosures before making the repository public. Review policies against the shipping builds and run the readiness check above.
2. Review the exact files to be committed, commit the intended source/site changes, and push when ready. Keep ignored build outputs, provisioning profiles, diagnostics, and personal app data out of Git. Do not force-add ignored files or upload the whole workspace through the GitHub website.
3. Make the repository public only after completing the review. Confirm its Issues tab is reachable by other users and the support email receives mail.
4. In **Settings → Pages → Build and deployment**, choose **GitHub Actions**. In the `github-pages` environment, restrict deployment branches to `main`; add a required reviewer if desired.
5. In **Actions → Publish support website → Run workflow**, choose `main`. The prepared `.github/workflows/pages.yml` runs only when manually requested, verifies the static output, uploads **only `website/dist/`**, and deploys that artifact. It never publishes the repository root. A normal push or pull request does not trigger deployment.
6. After GitHub reports success, use the HTTPS address shown in Pages settings. Verify all five pages without being signed in, test issue/email links, and enable **Enforce HTTPS** if offered. The expected address for this repo name is `https://droessmj.github.io/pocket-almanac/`; this is not a claim that it is live.

The workflow pins official GitHub actions to verified commit SHAs, disables persisted checkout credentials, gives the build read-only repository access, and grants Pages/OIDC writes only to the deploy job. It has not run remotely. GitHub Free supports Pages for public repositories; private-repository availability depends on the account plan.

Alternatively, for a separate website-only repository, copy the **contents of `website/dist/`**, including `.nojekyll`, to its root and use **Deploy from a branch → main → /(root)**. That route does not need the workflow. Keep `site.json` pointing to the app repository for support, regardless of which repo hosts the site.

For a project site, the address is usually `https://OWNER.github.io/REPOSITORY/`; an account site uses `https://OWNER.github.io/`. Keep the same paths if you later change the domain.

GitHub references: [creating a Pages site](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site), [choosing a publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site), [custom Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## URLs for the apps and App Store Connect

Append these paths to your published site’s base URL:

| App | Support URL | Privacy policy URL |
| --- | --- | --- |
| Day in Ink | `day-in-ink/support.html` | `day-in-ink/privacy.html` |
| Blotter | `blotter/support.html` | `blotter/privacy.html` |

Once the site is live, add the real URLs to the App Store listings and accessible links inside the apps. Those changes remain a separate release task. No speculative live URLs or App Store download links have been added to the site.

Apple requires working [support and privacy links](https://developer.apple.com/app-store/review/), including an easily accessible privacy-policy link [within each app](https://developer.apple.com/app-store/review/guidelines/#privacy). These pages provide the relevant content; approval still depends on the final app and submission.

## Privacy and design

No external fonts, scripts, analytics, tracking pixels, forms, or browser storage. A restrictive meta Content Security Policy blocks scripts, external resource loading, object embedding, form submission, and base-URL changes; a no-referrer policy avoids sending page addresses to linked services. GitHub links navigate to the repository; email links use the visitor’s mail app. Both policies describe public issue contents and GitHub Pages IP logging. The site does not claim the host collects no data. HTTP-only controls such as frame-ancestors cannot be enforced through this meta policy and are not claimed.

Navigation, headings, skip links, focus styles, semantic FAQ disclosures, reduced-motion support, and responsive layouts are included. Day in Ink uses its ivory/navy paper theme and handwriting face with fallbacks. Blotter uses its indigo/teal icon and native-style type. Each app page uses its real icon as the favicon. Long email addresses wrap on small screens. The website makes no claim that the apps are already listed on the App Store.

Verified locally in headless Chrome on November 3, 2026: all five pages at 1440, 390, and 320 CSS pixels, working styles, real icon loading, project-prefix links, no horizontal overflow, GitHub support links, FAQ expansion, removal of the full name and earlier care branding, CSP presence, and keyboard access to the skip link. Checks used a local `/pocket-almanac/` path to simulate the renamed GitHub Pages project site. Browser verification log: `build/app-support-browser-checks.log` in the app repository (not included in public files). Mailbox delivery, public issue access, and live HTTPS checks remain for publication.
