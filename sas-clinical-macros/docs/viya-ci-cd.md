### SAS Viya CI/CD Workflow for SAS Clinical Macros

This document describes a practical, auditable CI/CD workflow to validate and release SAS macros on SAS Viya using GitHub Actions. It assumes:
- Source macros live in `sas-clinical-macros/macros/`
- Tests live in `sas-clinical-macros/tests/`
- Logs and reports saved under `sas-clinical-macros/logs/` and `sas-clinical-macros/output/`

### Goals
- **Automated validation** of SAS macros on Viya (no SAS install on runner)
- **Deterministic test results**: fail builds on test failures or `ERROR:` in logs
- **Release artifacts** with validation evidence (logs, HTML reports)

### Prerequisites
- A working SAS Viya environment with Compute enabled
- A non‑interactive client for OAuth2 (client credentials or password flow)
- GitHub Actions repository secrets configured:
  - `VIYA_BASE_URL` (e.g., `https://viya.example.com`)
  - `VIYA_CLIENT_ID`
  - `VIYA_CLIENT_SECRET`
  - `VIYA_USER` (optional if using client credentials only)
  - `VIYA_PASS` (optional if using client credentials only)

### Test Execution Strategy
- Use a simple GitHub runner with Node.js and `@sasjs/cli` to execute SAS code remotely on Viya.
- Keep tests as `tests/test_*.sas` that set `status` and `message` macro vars and write to a consolidated log.
- Ensure `tests/test_runner.sas`:
  - Sets `sasautos` to include `macros/`
  - Discovers existing `tests/test_*.sas` or lists them explicitly
  - Writes `logs/test_report.html` and `logs/test_results.csv`
  - Aborts with non‑zero code when failures occur

### GitHub Actions (CI) — Viya
Create `.github/workflows/viya-ci.yml`:

```yaml
name: CI - SAS Macros on Viya

on:
  pull_request:
    paths: ['sas-clinical-macros/**']
  push:
    branches: [ main ]
    paths: ['sas-clinical-macros/**']

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm i -g @sasjs/cli@latest
      - name: Lint SAS macros
        run: sasjs lint sas-clinical-macros/macros --failOnWarnings=false

  test-viya:
    runs-on: ubuntu-latest
    needs: [lint]
    env:
      VIYA_BASE_URL: ${{ secrets.VIYA_BASE_URL }}
      VIYA_CLIENT_ID: ${{ secrets.VIYA_CLIENT_ID }}
      VIYA_CLIENT_SECRET: ${{ secrets.VIYA_CLIENT_SECRET }}
      VIYA_USER: ${{ secrets.VIYA_USER }}
      VIYA_PASS: ${{ secrets.VIYA_PASS }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm i -g @sasjs/cli@latest

      - name: Create .sasjsrc (Viya target)
        run: |
          cat > .sasjsrc <<'JSON'
          {
            "targets": [{
              "name": "viya",
              "serverType": "viya",
              "serverUrl": "${VIYA_BASE_URL}",
              "appLoc": "/Public/ci-sas-macros",
              "contextName": "Default Compute Context"
            }],
            "defaultTarget": "viya"
          }
          JSON

      - name: Authenticate to Viya
        run: |
          if [ -n "${VIYA_USER}" ] && [ -n "${VIYA_PASS}" ]; then
            sasjs auth -t viya -u "${VIYA_USER}" -p "${VIYA_PASS}" -c "${VIYA_CLIENT_ID}" -s "${VIYA_CLIENT_SECRET}";
          else
            sasjs auth -t viya -c "${VIYA_CLIENT_ID}" -s "${VIYA_CLIENT_SECRET}";
          fi

      - name: Ensure output directories
        run: |
          mkdir -p sas-clinical-macros/logs
          mkdir -p sas-clinical-macros/output

      - name: Run SAS tests on Viya
        run: |
          sasjs run -t viya \
            -f sas-clinical-macros/tests/test_runner.sas \
            --logFile sas-clinical-macros/logs/ci_viya.log

      - name: Fail on SAS errors or unit test failures
        run: |
          if grep -E '^(ERROR:|UNITTEST:\s*FAIL)' sas-clinical-macros/logs/ci_viya.log; then
            echo "Detected SAS ERROR or UNITTEST FAIL in log"; exit 1;
          fi

      - uses: actions/upload-artifact@v4
        with:
          name: viya-logs
          path: |
            sas-clinical-macros/logs/**
            sas-clinical-macros/output/**
```

### GitHub Actions (Release) — Package and Publish
Create `.github/workflows/viya-release.yml`:

```yaml
name: Release - SAS Macros (Viya)

on:
  push:
    tags: ['v*.*.*']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Package macros and docs
        run: |
          mkdir -p dist
          zip -r dist/sas-clinical-macros-${{ github.ref_name }}.zip \
            sas-clinical-macros/macros \
            sas-clinical-macros/docs

      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: dist/*.zip
          generate_release_notes: true
```

### Runner‑side test expectations
- `tests/test_runner.sas` should:
  - Use `options mautosource sasautos=("&test_root/macros" %sysfunc(getoption(sasautos)));`
  - Only execute tests that exist (e.g., iterate over `test_*.sas` using a control dataset or explicit list)
  - Write: `logs/test_report.html`, `logs/test_results.csv`, and return a non‑zero code on failures

### Security and Compliance
- Store all credentials in GitHub Secrets
- Use synthetic/non‑PHI data in CI tests
- Attach validation evidence (logs, reports) to GitHub Releases
- Require code review and passing checks before merge

### Troubleshooting
- Auth failures: verify `VIYA_*` secrets and client configuration
- Missing logs: ensure `logs/` exists and that `sasjs run` writes `--logFile`
- Intermittent failures: check Viya compute context availability and throttling policies
