# Master's Thesis — Fault-Tolerance & IJTAG Monitoring for the Klessydra Vector Accelerator

LaTeX source for the thesis *"Design-Space Exploration of Fault-Tolerance and
In-Field Monitoring Techniques for the Klessydra RISC-V Vector Accelerator."*

## Building

The project compiles with **pdfLaTeX** (no shell-escape needed). On Overleaf,
upload the whole `thesis/` folder (or the provided `thesis_overleaf.zip`) and set
the main document to `main.tex`. Locally:

```
pdflatex main && pdflatex main   # twice, to resolve the ToC / refs
```

There is no external bibliography processor: references live in
`ref/refs.tex` inside a `thebibliography` environment.

## Layout

```
main.tex                 preamble + document skeleton
content/                 title, abstract, acknowledgements, acronyms
content/<chapter>.tex     introduction, background, architecture, framework,
                          ijtag, experiment, results, conclusion
content/tables/*.tex      auto-generated booktabs tables (from data/)
appendix/appendix.tex     tooling + configuration reference
ref/refs.tex              bibliography (\bibitem list)
img/polito.png            logo
img/plots/*.pdf           auto-generated figures (from data/)
data/*.csv                reduced synthesis data
tools/*.py                data-reduction & figure/table generators
```

## Regenerating data, figures, and tables

All numerical content is generated from the raw Design Compiler reports in
`../DSP_BreakDown/`:

```
python tools/parse_synth.py     # -> data/synth_data.csv, overhead_scenarioB.csv
python tools/parse_ijtag.py     # -> data/ijtag_data.csv, ijtag_cost.csv
python tools/make_plots.py      # -> img/plots/*.pdf (+ .png previews)
python tools/make_tables.py     # -> content/tables/*.tex
```

Only `matplotlib` and `numpy` are required.
