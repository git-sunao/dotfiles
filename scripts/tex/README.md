# TeX and bibliography

- `packtex OUTDIR --source main.tex`: collect submission files; optional `--tar`, `--compile`.
- `extract-authors < main.tex`: extract author names.
- `fixgpt FILE.ipynb --diff`: preview Markdown math-delimiter changes; omit `--diff` to write.
- `solvebib.py FILE`, `deleteBibKey.py FILE`, `shortenAuthor.py FILE`: repair selected entries, remove fields, shorten author lists. `-o` overwrites.
- `processbib FILE`: currently runs only `solvebib`; other processing steps are commented out.
- `copy-proc-bib.sh`: copy `~/Desktop/refs.bib` here and run the three bibliography tools in place.

BibTeX tools require `bibtexparser`. Use `--help` for available options.
