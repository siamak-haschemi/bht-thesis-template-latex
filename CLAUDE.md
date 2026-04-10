# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LaTeX thesis template for Berliner Hochschule für Technik (BHT), maintained by Prof. Dr. Siamak Haschemi. Provides a BHT-branded cover page (German/English) and the surrounding scaffolding (preamble, layout, macros, helper scripts) for student bachelor/master theses.

## Build

Builds run inside a Docker image so no local TeX install is required:

```bash
./build.sh                                  # full build → out/main.pdf
```

`build.sh` first does a `docker build` of the local `Dockerfile` (which extends `texlive/texlive:latest` and adds `inkscape`), then runs `latexmk -shell-escape -pdf main.tex` against that image. The image is tagged `bht-thesis-texlive:latest` and is cached, so only the first build is slow. **Inkscape + `-shell-escape` are mandatory**: `chapters/04-tips-and-tricks.tex` uses `\includesvg{...}`, which the `svg` package converts on the fly by shelling out to Inkscape. Removing either will break the build with `Package svg Error: File '..._svg-tex.pdf' is missing.`

`latexmk` handles biber + multi-pass rebuilds. All build artifacts land in `out/`; the committed `template.pdf` at the repo root is the published reference output (not the live build target).

## Architecture

Entry point is `main.tex`, which loads three layers in order:

1. `preamble.tex` — package imports + global config: `babel` (english/ngerman), `biblatex` (biber backend, numeric style, `bib/sources.bib`), `svg`, `tikz`, `hyperref` (`hidelinks`), `cleveref`, paragraph spacing (`\parskip=0.8em`, `\parindent=0pt`).
2. `macros.tex` — defines `\EnableTocSquares` / `\DisableTocSquares`, the four-color BHT square stamp at the top of every page that hyperlinks back to the table of contents (uses `AddToShipoutPictureFG` so it persists across pages).
3. `bht-cover-page.sty` + `layout.sty` — the cover page renderer and the page geometry. `\maketitle` is **redefined** by `bht-cover-page.sty` to call `\bhtTitlePage`, which consumes the metadata commands set in `main.tex` (`\thesisTitle`, `\authorName`, `\department`, `\degreeProgram`, `\degreeType`, `\supervisorField`, `\submissionDate`, `\studentId`, optional `\version`). Cover language is selected with `\coverPageLanguage{de}` or `{en}` independently from `\selectlanguage{...}`.

The BHT corporate colors (`bhtBlue`, `bhtRed`, `bhtYellow`, `bhtCyan`/`bhtTurquoise`, `bhtGray`) are defined in `bht-cover-page.sty` and reused by the TOC squares macro — keep them in sync if branding changes.

`layout.sty` is a verbatim port from S. Tschirley's original BHT template (A4, 150mm text width, 245mm text height). The header comment explicitly notes the magic numbers are not to be touched without reason.

### Content layout

- `chapters/` — each chapter is a separate `.tex` file `\include`d from `main.tex`. Front matter (`00-abstract`) is roman-paginated, main content (`01-introduction` … `05-student-messages`) is arabic-paginated. Note `chapters/03- common-questions.tex` has a literal space in the filename — preserve it when editing the include in `main.tex`.
- `bib/sources.bib` — single BibTeX file consumed by biblatex/biber; `\printbibliography` is added to the TOC manually via `\addcontentsline`.
- `cover/` — BHT logo PDFs (`BHT-Logo-vertikal`, `BHT-Logo-horizontal`, `BHT-Elements`, `BHT-Studiere-vertikal`). `bht-cover-page.sty` sets `\graphicspath{{cover/}}` so these are referenced unqualified.
- `figures/` — images/diagrams referenced by chapters.

### Helper scripts (`software/`)

- `software/drawio-svg-export/export-drawio-svg.py` — exports each page of a `.drawio` file to SVG (per-figure config in `.drawio-export.figures.json`). Invocation example is in the commented line at the top of `build.sh`. Run via the local `Makefile` in that directory.
- `software/matplotlib/` — `bht_colors.py` and `matplotlib_style.py` provide BHT-branded matplotlib styling for plots used in figures; `test_plot.py` is a smoke test.

## Editing conventions

- When adding a new chapter, create `chapters/NN-name.tex` and add `\include{chapters/NN-name}` to `main.tex` in the arabic-numbered block. Don't `\input` chapters — `\include` is required for the `\cleardoublepage` boundaries to work with the layout.
- Switching the thesis language requires changing **both** `\selectlanguage{...}` (affects babel/biblatex strings) and `\coverPageLanguage{...}` (affects only the cover page text block).
- The biblatex `DefineBibliographyStrings` blocks in `preamble.tex` localize the `backref` "cited on page" strings for both languages — extend these if adding more languages.
