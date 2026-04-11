# BHT Thesis Template

LaTeX template for bachelor's and master's theses supervised by **Prof. Dr. Siamak Haschemi** at the **Berliner Hochschule für Technik (BHT)**. Provides a BHT-branded cover page (German and English), a sane preamble (`biblatex`/`biber`, `babel`, `hyperref`, `tikz`, `svg`), and example chapters that double as a writing guide.

The committed [`template.pdf`](template.pdf) shows the rendered output.

## Getting started (workflow for students)

1. **Plan your timeline.** Draft a schedule with a few milestones and send it to Siamak via Discord before you start writing.
2. **Read the FAQ chapter** in `chapters/03- common-questions.tex` — please read it before asking questions, so we don't repeat ourselves.
3. **Create your own repository from this template.** This repo is configured as a GitHub *template repository*, so on its GitHub page click **Use this template → Create a new repository**. Do **not** fork — a template gives you a clean history to start from.
4. **Invite Siamak as a collaborator** on your new repository (GitHub → Settings → Collaborators → Add people → `siamakhaschemi`).
5. **Siamak imports the GitHub repo into Overleaf** and adds you to the Overleaf project. This gives you access to all paid Overleaf features (Git integration, history, real-time collaboration, etc.) for the duration of your thesis. From then on you can edit either locally and push to GitHub, or directly in Overleaf — both stay in sync via the Git integration.
6. **Delete the example chapters** (`chapters/01-introduction.tex` … `chapters/05-student-messages.tex`) and start writing your own.

The example chapters that ship with this template are not just placeholders — they contain advice on common mistakes, thesis structure, the FAQ, and tips & tricks. Read them once before deleting.

## Contributing back

The template improves whenever a student contributes back. If you find a bug, a typo, or have a workflow improvement, please open a pull request against [`siamak-haschemi/bht-thesis-template-latex`](https://github.com/siamak-haschemi/bht-thesis-template-latex) so future students benefit. And give the repo a star.

## Prerequisites

Most students write in Overleaf and need none of this. Install these only if you want to build the PDF locally or regenerate the example SVG diagrams from `.drawio` sources.

- **Docker** — required by `build.sh`. On macOS, [OrbStack](https://orbstack.dev) is a lightweight drop-in for Docker Desktop and works out of the box; on Linux any Docker engine is fine. You do **not** need a local TeX install — TeX Live and Inkscape live inside the image `build.sh` builds.
- **draw.io desktop** — only needed if you edit `software/drawio-svg-export/figures.drawio` and want to re-export the SVGs via `software/drawio-svg-export/export-drawio-svg.py`. The export script shells out to the `drawio` CLI that ships with the desktop app:

  ```bash
  brew install --cask drawio       # macOS
  ```

  The `drawio` binary must be on your `PATH` for the script to find it.

## Building locally

`build.sh` runs everything inside Docker — see [Prerequisites](#prerequisites):

```bash
./build.sh        # → out/main.pdf
./cleanup.sh      # remove build artifacts
```

`build.sh` builds a small image on top of `texlive/texlive:latest` that adds Inkscape (required by the `svg` package for `\includesvg`), then runs `latexmk -shell-escape -pdf main.tex`. The image is cached, so only the first build is slow.

In day-to-day work most students use Overleaf and never need to build locally — but it's useful for CI, offline work, or debugging package issues.

## Switching language

The template ships in German. To switch to English, change **both** of these — they are independent:

```latex
\selectlanguage{english}     % preamble: babel + biblatex strings
\coverPageLanguage{en}       % cover page text block
```

## Directory structure

- `main.tex` — entry point; sets cover-page metadata and includes chapters
- `preamble.tex` — package imports and global config
- `macros.tex` — custom commands (e.g. the BHT TOC squares overlay)
- `bht-cover-page.sty` — BHT cover page renderer (redefines `\maketitle`)
- `layout.sty` — page geometry
- `chapters/` — thesis chapters (`\include`d from `main.tex`)
- `bib/sources.bib` — bibliography entries (biblatex/biber)
- `figures/` — images and SVG diagrams
- `cover/` — BHT logo PDFs used by the cover page
- `software/` — optional helpers: `drawio-svg-export/` (Python script that exports `.drawio` pages to SVG) and `matplotlib/` (BHT-styled matplotlib config matched to the document's text width)
- `Dockerfile`, `build.sh`, `cleanup.sh` — local build pipeline
- `template.pdf` — committed reference output
