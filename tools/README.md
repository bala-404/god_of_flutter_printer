# Tools — God of Flutter Printer

Helper scripts for building, releasing, and maintaining the monorepo.

---

## Scripts

| Script | Platform | What it does |
|--------|----------|--------------|
| [`download_fonts.ps1`](download_fonts.ps1) | Windows | Download Noto Tamil + Hindi fonts into the package |
| [`download_fonts.sh`](download_fonts.sh) | macOS / Linux | Same as above |
| [`release_all.ps1`](release_all.ps1) | Windows | Build Print Hub zip + prepare GitHub release assets |

---

## Download fonts (optional)

Improves Tamil/Hindi receipt quality. Not required for basic printing.

**Windows:**
```powershell
cd tools
.\download_fonts.ps1
```

**macOS / Linux:**
```bash
cd tools
chmod +x download_fonts.sh
./download_fonts.sh
```

Fonts are saved to `god_of_flutter_printer/assets/fonts/`.

---

## Full release (Windows)

Builds the Print Hub installer zip for shop distribution:

```powershell
cd tools
.\release_all.ps1
```

Output:
- `print_agent/dist/PrintWorkerHub-win64.zip`

Upload this zip to **GitHub Releases** when you tag a new version.

---

## Author

**Balamurugan** · AI Architect · Chennai, India  
Email: messagetobalamurugan@gmail.com · WhatsApp: [+91 75388 86343](https://wa.me/917538886343)
