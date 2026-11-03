# Pocket Almanac website

**Live status verified November 3, 2026:** `https://apps.droessmj.com/` serves all five pages over valid HTTPS, and the nine public files match the generated output by SHA-256. The repository is now public; the latest observed website-only workflow succeeded. HTTP still served content without redirecting at the review snapshot, so Enforce HTTPS remains to be verified. See [the release checklist](../RELEASE_CHECKLIST.md). Earlier statements below about preparation describe the original local-only work, not the current deployment state.

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

1. Review [the release checklist](../RELEASE_CHECKLIST.md) and privately kept security notes and resolve or explicitly accept the identity/history and personal schedule disclosures before making the repository public. Review policies against the shipping builds and run the readiness check above.
2. Review the exact files to be committed, commit the intended source/site changes, and push when ready. Keep ignored build outputs, provisioning profiles, diagnostics, and personal app data out of Git. Do not force-add ignored files or upload the whole workspace through the GitHub website.
3. Make the repository public only after completing the review. Confirm its Issues tab is reachable by other users and the support email receives mail.
4. In **Settings → Pages → Build and deployment**, choose **GitHub Actions**. In the `github-pages` environment, restrict deployment branches to `main`; add a required reviewer if desired.
5. In **Actions → Publish support website → Run workflow**, choose `main`. The prepared `.github/workflows/pages.yml` runs only when manually requested, verifies the static output, uploads **only `website/dist/`**, and deploys that artifact. It never publishes the repository root. A normal push or pull request does not trigger deployment.
6. Configure the custom domain and HTTPS as described below. After GitHub reports deployment success, verify all five pages without being signed in and test issue/email links. The intended address is `https://apps.droessmj.com/`; this is not a claim that it is live.

The workflow pins official GitHub actions to verified commit SHAs, disables persisted checkout credentials, gives the build read-only repository access, and grants Pages/OIDC writes only to the deploy job. It has not run remotely. GitHub Free supports Pages for public repositories; private-repository availability depends on the account plan.

Alternatively, for a separate website-only repository, copy the **contents of `website/dist/`**, including `.nojekyll`, to its root and use **Deploy from a branch → main → /(root)**. That route does not need the workflow. Keep `site.json` pointing to the app repository for support, regardless of which repo hosts the site.

For a project site, the address is usually `https://OWNER.github.io/REPOSITORY/`; an account site uses `https://OWNER.github.io/`. Keep the same paths if you later change the domain.

GitHub references: [creating a Pages site](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site), [choosing a publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site), [custom Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
## Custom domain: apps.droessmj.com

The publishing workflow uses GitHub Actions, so the domain is configured in the repository's **Settings → Pages**, not in the generated site. GitHub ignores artifact `CNAME` files for this publishing source; none is needed. Internal links and assets are relative, so the site works at the custom domain root without changing the builder.

1. Recommended: in your personal GitHub **Settings → Pages → Add a domain**, verify `droessmj.com`. Add the exact TXT record name and value GitHub supplies to the Route 53 **public hosted zone** for `droessmj.com`, then complete verification in GitHub. Keep that TXT record afterward. Verifying the parent domain also protects its immediate subdomains, including `apps.droessmj.com`, from other GitHub users claiming them.
2. In `droessmj/pocket-almanac` **Settings → Pages**, keep **Source: GitHub Actions**. Set **Custom domain** to `apps.droessmj.com` and save **before** creating the routing record below. This reserves the hostname for the repository before DNS points to GitHub.
3. In Route 53, open the public hosted zone for `droessmj.com` and create this record. The domain's authoritative nameservers must already delegate to this hosted zone.

   | Setting | Value |
   | --- | --- |
   | Record name | `apps` (full name: `apps.droessmj.com`) |
   | Record type | `CNAME` |
   | Value | `droessmj.github.io` |
   | Alias | Off |
   | TTL | `300` seconds |
   | Routing policy | Simple |

   Do not include `https://`, `/pocket-almanac/`, or a trailing path in the value. A CNAME cannot coexist with other record types at the same name; review any existing `apps` records before replacing them. Do not change the apex domain's website or mail records, and do not create a wildcard record.
4. Publish using **Actions → Publish support website → Run workflow → main** when ready, following the publication/security checks above.
5. Wait for the repository's Pages DNS check to pass. GitHub automatically obtains and renews the TLS certificate through Let's Encrypt. Then enable **Enforce HTTPS** in the repository's Pages settings. DNS propagation and availability of this checkbox can take up to 24 hours.

Route 53 provides DNS only; it does not terminate HTTPS. No AWS Certificate Manager certificate, certificate upload, CloudFront distribution, or load balancer is needed for direct GitHub Pages hosting. If you already restrict certificate issuers with CAA records, ensure the effective policy allows `letsencrypt.org`; otherwise no CAA change is needed.

After provisioning, check DNS, TLS, and the HTTP-to-HTTPS redirect:

```sh
dig apps.droessmj.com CNAME +short
# Expected: droessmj.github.io.
curl -I https://apps.droessmj.com/
# Expected: a successful response with normal certificate validation.
curl -I http://apps.droessmj.com/
# Expected: a redirect to https://apps.droessmj.com/.
```

Also open the home page and all four app pages in a browser. The custom domain uses `/`, not `/pocket-almanac/`. If you later disable Pages, remove its DNS routing record to avoid leaving a dangling hostname.

References: [GitHub custom domains](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site), [domain verification](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages), [GitHub HTTPS](https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https), [Route 53 record values](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-shared.html).


## URLs for the apps and App Store Connect

Use these exact App Store Connect URLs after verifying the domain and public HTTPS access:

| App | Support URL | Privacy policy URL |
| --- | --- | --- |
| Day in Ink | `https://apps.droessmj.com/day-in-ink/support.html` | `https://apps.droessmj.com/day-in-ink/privacy.html` |
| Blotter | `https://apps.droessmj.com/blotter/support.html` | `https://apps.droessmj.com/blotter/privacy.html` |

Use `https://apps.droessmj.com/` as the Marketing URL for both apps. Use the listing URL table above; entering these URLs in App Store Connect and adding accessible links inside the apps remain separate release tasks. No App Store download links have been added to the site.

Apple requires working [support and privacy links](https://developer.apple.com/app-store/review/), including an easily accessible privacy-policy link [within each app](https://developer.apple.com/app-store/review/guidelines/#privacy). These pages provide the relevant content; approval still depends on the final app and submission.

## Privacy and design

All five pages use the same Google Analytics Google tag as `https://droessmj.com/`, measurement ID `G-4WHKJVZCYY`, through the shared `src/layout.html`. This shares the existing Analytics property rather than creating a new one; filter reports by hostname to distinguish the support site. The iPhone apps are unchanged and do not include Analytics. Both generated privacy policies disclose website analytics, cookies, Google processing, and the separation from app data.

The meta Content Security Policy allows the Google tag, its hash-authorized inline initialization, and Google's documented non-Ads Analytics endpoints. It still blocks other scripts, object embedding, form submission, and base-URL changes; no `unsafe-inline` or `unsafe-eval` is enabled. If the inline initialization changes, update its SHA-256 hash in the CSP. The no-referrer policy remains, but does not prevent Analytics from explicitly sending page information. No external fonts, embedded media, or forms are included. HTTP-only controls such as `frame-ancestors` cannot be enforced through a meta policy and are not claimed.

This matches the parent site's direct tag setup: it does not add a consent banner or consent-gating. Before deploying where prior consent is required, configure an appropriate consent flow; a privacy notice alone is not consent. Review the shared property's retention, enhanced measurement, and advertising settings, and verify the `apps.droessmj.com` hostname in Analytics Realtime after publication. References: [Google Analytics CSP guidance](https://developers.google.com/tag-platform/security/guides/csp), [Google consent setup](https://developers.google.com/tag-platform/security/guides/consent).

Navigation, headings, skip links, focus styles, semantic FAQ disclosures, reduced-motion support, and responsive layouts are included. Day in Ink uses its ivory/navy paper theme and handwriting face with fallbacks. Blotter uses its indigo/teal icon and native-style type. Each app page uses its real icon as the favicon. Long email addresses wrap on small screens. The website makes no claim that the apps are already listed on the App Store.

Verified locally in headless Chrome on November 3, 2026: all five pages at 1440, 390, and 320 CSS pixels, working styles, real icon loading, project-prefix links, no horizontal overflow, GitHub support links, FAQ expansion, removal of the full name and earlier care branding, CSP presence, and keyboard access to the skip link. Checks used a local `/pocket-almanac/` path to simulate the renamed GitHub Pages project site. Browser verification log: `build/app-support-browser-checks.log` in the app repository (not included in public files). Mailbox delivery, public issue access, and live HTTPS checks remain for publication.
