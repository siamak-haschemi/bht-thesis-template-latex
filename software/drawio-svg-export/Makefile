# Simple Makefile to export SVGs from figures.drawio into ../../figures.

PY      := python3
SCRIPT  := ./export-drawio-svg.py
DRAWIO  := figures.drawio

# Export changed pages to SVG. Staging/committing the result is up to you.
svg:
	$(PY) $(SCRIPT) $(DRAWIO)
