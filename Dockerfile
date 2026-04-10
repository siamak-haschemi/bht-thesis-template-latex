FROM texlive/texlive:latest

# Inkscape is required by the LaTeX `svg` package, which converts SVG figures
# to PDF on the fly via -shell-escape (see chapters/04-tips-and-tricks.tex).
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends inkscape \
 && rm -rf /var/lib/apt/lists/*
