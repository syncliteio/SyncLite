# Embed SyncLite Site in Google Sites (Option 2)

This guide uses the hosted GitHub Pages URL and embeds it into Google Sites.

## 1. Publish the site from this repo

1. Push your current branch to GitHub.
2. Open repository settings: `https://github.com/syncliteio/SyncLite/settings/pages`
3. In **Build and deployment**:
   - Source: **Deploy from a branch**
   - Branch: **main**
   - Folder: **/docs**
4. Save and wait for deployment.

Expected public URL:
- `https://syncliteio.github.io/SyncLite/`

Page URLs:
- Landing: `https://syncliteio.github.io/SyncLite/`
- About: `https://syncliteio.github.io/SyncLite/about.html`
- Get Started: `https://syncliteio.github.io/SyncLite/getting-started/`

## 2. Embed in Google Sites

1. Open your Google Site editor.
2. Go to the page where you want SyncLite content.
3. Click **Insert** -> **Embed** -> **By URL**.
4. Paste one of the URLs above.
5. Click **Insert**.
6. Resize the embed frame and publish the Google Site.

## 3. Recommended page structure in Google Sites

- Home page: embed landing URL.
- About page: embed about URL.
- Getting Started page: embed getting-started URL.

This keeps your Google Site simple while all design/content stays maintained in this repo.

## 4. If Google Sites blocks iframe embed

Some hosts may block iframe rendering via security headers in certain setups. If that happens:

1. Keep the same Google Site page.
2. Add a button or text link to open the hosted URL in a new tab.
3. Label examples:
   - "Open SyncLite Landing"
   - "Open About"
   - "Open Getting Started"

## 5. Update flow

After this is set:

1. Edit files in `docs/` in this repo.
2. Push changes.
3. GitHub Pages auto-updates.
4. Google Sites embed reflects updates without re-pasting URLs.
