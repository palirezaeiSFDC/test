# My Notes App

A lightweight, browser-based notes app with:

- Multiple lists
- Rich text notes (bold, italic, underline, bullets)
- Checklist items (checkboxes)
- Per-list note management
- Local persistence via browser `localStorage`

## Run Locally

No build step is required.

1. Clone this repository.
2. Open `index.html` (or `notes.html`) in your browser.

## Create Your Own Instance

Each user automatically gets their own instance because data is stored in that user's browser `localStorage`.

- If two people open the same deployed URL, each sees their own saved data on their own browser/device.
- Data does not sync between users unless a backend is added.

## Deploy on GitHub Pages

This repository includes a workflow at `.github/workflows/pages.yml` to deploy automatically.

1. Push your branch to GitHub.
2. In GitHub, open **Settings > Pages**.
3. Under **Build and deployment**, set **Source** to **GitHub Actions**.
4. Push to `main` (or trigger workflow manually).
5. Open the Pages URL shown in the GitHub Pages settings.

## File Overview

- `notes.html` - main app UI and logic
- `index.html` - root entry point that redirects to `notes.html`
- `.github/workflows/pages.yml` - GitHub Pages deployment workflow
