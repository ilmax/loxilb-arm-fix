# Sync Workflow Setup

The sync workflow checks for new loxilb releases every night and creates matching tags automatically. By default, GitHub Actions won't trigger other workflows when using the standard `GITHUB_TOKEN` (this prevents infinite loops). To make the build workflow run automatically when new tags are created, you need to configure either a GitHub App or a Personal Access Token.

## Authentication Options

### GitHub App (Preferred)

GitHub Apps use short-lived tokens that refresh automatically and can be scoped to specific repositories.

1. Create a GitHub App:
   - Go to Settings → Developer settings → GitHub Apps → New GitHub App
   - Fill in the basics:
     - Name: `loxilb-sync-automation`
     - Homepage URL: `https://github.com/ilmax/loxilb-arm-fix`
     - Webhook: Uncheck "Active"
   - Set repository permissions:
     - Contents: Read and write
     - Workflows: Read and write
   - Where can this GitHub App be installed: "Only on this account"
   - Click "Create GitHub App"

2. Generate and save the private key:
   - Scroll to "Private keys" section
   - Click "Generate a private key"
   - Save the downloaded `.pem` file somewhere secure

3. Note the App ID shown at the top of the page

4. Install the app:
   - Go to "Install App" in the sidebar
   - Click "Install" next to your account
   - Select "Only select repositories"
   - Choose `loxilb-arm-fix`

5. Add to repository:
   - Go to repository Settings → Secrets and variables → Actions
   - Under Variables tab: Add `APP_ID` with the app ID from step 3
   - Under Secrets tab: Add `APP_PRIVATE_KEY` with the full contents of the `.pem` file

### Personal Access Token

If you prefer not to set up a GitHub App, you can use a PAT instead.

Classic PAT:

- Settings → Developer settings → Personal access tokens → Tokens (classic)
- Generate new token with `repo` and `workflow` scopes
- Add to repository secrets as `PAT_TOKEN`

Fine-grained PAT:

- Settings → Developer settings → Personal access tokens → Fine-grained tokens
- Create token with:
  - Repository access: Only select `loxilb-arm-fix`
  - Permissions: Contents (Read and write), Workflows (Read and write)
- Add to repository secrets as `PAT_TOKEN`

## How It Works

The workflow tries these in order:

1. GitHub App token (if `APP_ID` and `APP_PRIVATE_KEY` exist)
2. `PAT_TOKEN` (if set)
3. `GITHUB_TOKEN` (default, but won't trigger builds)

Without a GitHub App or PAT configured, the sync workflow will still create tags and releases, but you'll need to manually trigger the build workflow.

## Common Issues

If the build workflow doesn't trigger automatically:

- Verify `APP_ID` variable and `APP_PRIVATE_KEY` secret are set (for GitHub App)
- Or verify `PAT_TOKEN` secret exists and hasn't expired (for PAT)
- Check that the token has Contents and Workflows write permissions
- For GitHub Apps, make sure it's installed on the repository

If you see "Resource not accessible by integration":

- The GitHub App needs Contents: Write and Workflows: Write permissions
- Try reinstalling the app with the correct permissions
