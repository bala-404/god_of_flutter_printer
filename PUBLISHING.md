# Full publishing & distribution guide

**God of Flutter Printer** monorepo — how to publish and ship **every folder**.

---

## Overview — all folders

| Folder | Where it ships | How users get it |
|--------|----------------|------------------|
| `god_of_flutter_printer_platform_interface` | **pub.dev** | Auto-installed as dependency |
| `god_of_flutter_printer_windows` | **pub.dev** | Auto-installed as dependency |
| `god_of_flutter_printer` | **pub.dev** | `god_of_flutter_printer: ^0.1.0` |
| `example` | **GitHub repo** | Clone repo → `cd example` → `flutter run` |
| `print_agent` | **GitHub Releases** | Download `PrintWorkerHub-win64.zip` |
| `tools` | **GitHub repo** | Clone repo → `cd tools` → run scripts |

---

## Part 1 — pub.dev (3 packages)

Users only add **one** line to `pubspec.yaml`:

```yaml
dependencies:
  god_of_flutter_printer: ^0.1.0
```

### One-time setup

1. Push code to GitHub
2. Create account at [pub.dev](https://pub.dev)
3. Login: `dart pub login`

### Publish order (must follow this order)

```bash
# 1. Platform interface
cd god_of_flutter_printer_platform_interface
dart pub publish --dry-run && dart pub publish

# 2. Windows plugin
cd ../god_of_flutter_printer_windows
dart pub publish --dry-run && dart pub publish

# 3. Main package
cd ../god_of_flutter_printer
dart pub publish --dry-run && dart pub publish
```

Live at: **https://pub.dev/packages/god_of_flutter_printer**

---

## Part 2 — example (demo app)

The example is **not on pub.dev** — it lives in the GitHub repo so developers can try all features.

### You (developer) — run locally

```bash
cd example
flutter pub get
flutter run -d windows    # USB / BT / network
flutter run -d chrome       # web + Print Hub
flutter run -d <device>     # Android / iOS
```

### Users / developers — get the demo

1. Clone: `git clone https://github.com/bala-404/god_of_flutter_printer`
2. `cd god_of_flutter_printer/example`
3. `flutter pub get && flutter run`

### Include in GitHub release notes

Add to each release:

> **Try the demo:** Clone the repo and run `cd example && flutter run -d windows`

See [example/README.md](example/README.md)

---

## Part 3 — print_agent (Print Hub .exe zip)

Print Hub is a **Windows desktop app** for web POS printing. Ship it as a **zip on GitHub Releases**.

### Build the zip

**Option A — quick:**
```powershell
cd print_agent
.\scripts\package_release.ps1
```

**Option B — full release (tests + zip):**
```powershell
cd tools
.\release_all.ps1
```

**Output:**
```
print_agent/dist/PrintWorkerHub-win64.zip
```

### Upload to GitHub Releases

1. Create a git tag:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

2. On GitHub → **Releases** → **Draft a new release**
3. Choose tag `v0.1.0`
4. Title: `God of Flutter Printer v0.1.0`
5. **Attach:** `PrintWorkerHub-win64.zip`
6. Add install instructions (from [print_agent/README.md](print_agent/README.md)):
   - Unzip → Run `install_hub.bat` as Administrator
   - Copy LAN URL into web POS `hubUrl`

### Shop install (for your customers)

```
1. Download PrintWorkerHub-win64.zip from GitHub Releases
2. Unzip on counter PC
3. Right-click install_hub.bat → Run as administrator
4. Paste URL into web POS printer settings
```

See [print_agent/README.md](print_agent/README.md)

---

## Part 4 — tools (scripts)

Scripts ship **inside the GitHub repo** — not on pub.dev.

| Script | Command | Purpose |
|--------|---------|---------|
| Download fonts | `tools/download_fonts.ps1` (Win) or `tools/download_fonts.sh` (Mac/Linux) | Tamil/Hindi font assets |
| Full release build | `tools/release_all.ps1` | Tests + Print Hub zip |

See [tools/README.md](tools/README.md)

---

## Complete release checklist (v0.1.0)

Use this every time you ship a new version:

### Step 1 — Bump versions

Update `version:` in:
- [ ] `god_of_flutter_printer_platform_interface/pubspec.yaml`
- [ ] `god_of_flutter_printer_windows/pubspec.yaml`
- [ ] `god_of_flutter_printer/pubspec.yaml`
- [ ] `print_agent/pubspec.yaml` (optional, for tracking)

Update `CHANGELOG.md` in each publishable package.

### Step 2 — Build & test

```powershell
cd tools
.\release_all.ps1
```

This runs tests and builds `PrintWorkerHub-win64.zip`.

### Step 3 — Publish to pub.dev (order matters)

```bash
cd god_of_flutter_printer_platform_interface && dart pub publish
cd ../god_of_flutter_printer_windows && dart pub publish
cd ../god_of_flutter_printer && dart pub publish
```

### Step 4 — GitHub Release

```bash
git add .
git commit -m "Release v0.1.0"
git tag v0.1.0
git push origin main --tags
```

On GitHub Releases, attach:
- [ ] `print_agent/dist/PrintWorkerHub-win64.zip`

Release notes template:

```markdown
## God of Flutter Printer v0.1.0

### Flutter package (pub.dev)
```yaml
dependencies:
  god_of_flutter_printer: ^0.1.0
```

### Print Hub (web POS — Windows counter PC)
Download **PrintWorkerHub-win64.zip** below.
Unzip → Run install_hub.bat as Administrator.

### Demo app
git clone ... && cd example && flutter run -d windows

### Docs
- Full guide: god_of_flutter_printer/doc/index.html
```

### Step 5 — Verify

- [ ] https://pub.dev/packages/god_of_flutter_printer shows new version
- [ ] GitHub Release has zip attached
- [ ] Example runs: `cd example && flutter run -d windows`

---

## What goes where (summary diagram)

```
god_of_flutter_printer/         (monorepo root)
├── god_of_flutter_printer*     → pub.dev (3 packages)
├── example/                    → GitHub repo (demo app)
├── print_agent/                → GitHub Releases (.zip)
└── tools/                      → GitHub repo (scripts)
```

---

## Author

**Balamurugan** · AI Architect · Chennai, India

| | |
|---|---|
| Email | messagetobalamurugan@gmail.com |
| WhatsApp | [+91 75388 86343](https://wa.me/917538886343) |
| UPI | `balamuruganm2102-1@okaxis` |
| Custom solutions | Enterprise POS printing, Print Hub deployment |
