#!/usr/bin/env python3
"""
make_tables.py -- emit LaTeX tables (booktabs) from thesis/data/synth_data.csv.
Output goes to thesis/content/tables/*.tex and is \\input{} by the chapters.
"""
import os, csv

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data", "synth_data.csv")
OUT = os.path.join(HERE, "..", "content", "tables")
os.makedirs(OUT, exist_ok=True)

NODES = ["130nm", "45nm", "15nm"]
NODE_LABEL = {"130nm": "IHP 130\\,nm", "45nm": "NanGate 45\\,nm", "15nm": "NanGate 15\\,nm"}
B_ORDER = ["baseline", "add_dmr", "add_tmr", "mult_dmr", "mult_tmr",
           "shift_dmr", "shift_tmr", "comp_dmr", "comp_tmr", "full_dmr", "full_tmr"]

rows = list(csv.DictReader(open(DATA)))
idx = {(r["node"], r["config"]): r for r in rows}


def f(r, k):
    v = r.get(k)
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def fmt(x, d=0):
    if x is None:
        return "--"
    return f"{x:,.{d}f}"


# ---- Table 1: absolute area/power/delay per node, scenario B -------------
def table_absolute(node):
    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\caption{Synthesis results for the single-core fault-tolerance "
                 f"configurations at {NODE_LABEL[node]}. Area is in library units, "
                 "power in mW, and delay is the critical-path (data-arrival) "
                 "time in the library time unit.}")
    lines.append(f"\\label{{tab:abs_{node}}}")
    lines.append("\\small")
    lines.append("\\begin{tabular}{lrrrrr}")
    lines.append("\\toprule")
    lines.append("Configuration & Cell area & Comb. cells & Seq. cells & "
                 "Power (mW) & Delay \\\\")
    lines.append("\\midrule")
    for c in B_ORDER:
        r = idx[(node, c)]
        lines.append(f"{r['label']} & {fmt(f(r,'cell_area'),0)} & {fmt(f(r,'comb_cells'),0)} & "
                     f"{fmt(f(r,'seq_cells'),0)} & {fmt(f(r,'p_total'),2)} & {fmt(f(r,'delay'),2)} \\\\")
    lines.append("\\bottomrule")
    lines.append("\\end{tabular}")
    lines.append("\\end{table}")
    open(os.path.join(OUT, f"abs_{node}.tex"), "w").write("\n".join(lines) + "\n")


# ---- Table 2: normalised overhead (area & power) across nodes ------------
def table_overhead():
    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\caption{Cell-area and total-power overhead of each single-core "
                 "fault-tolerance configuration, normalised to the per-node baseline "
                 "($\\times$ baseline). Values are remarkably stable across the three "
                 "technology nodes.}")
    lines.append("\\label{tab:overhead}")
    lines.append("\\small")
    lines.append("\\begin{tabular}{l" + "rr" * len(NODES) + "}")
    lines.append("\\toprule")
    lines.append(" & " + " & ".join([f"\\multicolumn{{2}}{{c}}{{{NODE_LABEL[n]}}}" for n in NODES]) + " \\\\")
    cmid = " ".join([f"\\cmidrule(lr){{{2+2*i}-{3+2*i}}}" for i in range(len(NODES))])
    lines.append(cmid)
    lines.append("Configuration & " + " & ".join(["Area & Power"] * len(NODES)) + " \\\\")
    lines.append("\\midrule")
    for c in B_ORDER:
        if c == "baseline":
            continue
        cells = []
        for n in NODES:
            r = idx[(n, c)]
            b = idx[(n, "baseline")]
            ax = f(r, "cell_area") / f(b, "cell_area")
            px = f(r, "p_total") / f(b, "p_total")
            cells.append(f"{ax:.2f} & {px:.2f}")
        lines.append(f"{idx[(NODES[0], c)]['label']} & " + " & ".join(cells) + " \\\\")
    lines.append("\\bottomrule")
    lines.append("\\end{tabular}")
    lines.append("\\end{table}")
    open(os.path.join(OUT, "overhead.tex"), "w").write("\n".join(lines) + "\n")


# ---- Table 3: replication (scenario A) -----------------------------------
def table_replication():
    cfgs = [("repl_baseline", "Replicated baseline (3 lanes)"),
            ("repl_dmr", "Replicated + DMR voting"),
            ("repl_tmr", "Replicated + TMR voting")]
    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\caption{Replication-based redundancy (Scenario~B): three-lane "
                 "accelerator with voting inserted in the mapping unit. Cell area is "
                 "given in library units and also normalised to the single-core baseline. "
                 "Adding voting changes the area only marginally relative to the "
                 "replicated baseline.}")
    lines.append("\\label{tab:replication}")
    lines.append("\\small")
    lines.append("\\begin{tabular}{llrr}")
    lines.append("\\toprule")
    lines.append("Node & Configuration & Cell area & $\\times$ single-core \\\\")
    lines.append("\\midrule")
    for n in ["130nm", "45nm", "15nm"]:
        b = f(idx[(n, "baseline")], "cell_area")
        for cfg, lab in cfgs:
            r = idx.get((n, cfg))
            if not r:
                continue
            a = f(r, "cell_area")
            lines.append(f"{NODE_LABEL[n]} & {lab} & {fmt(a,0)} & {a/b:.2f} \\\\")
        lines.append("\\midrule")
    lines[-1] = "\\bottomrule"
    lines.append("\\end{tabular}")
    lines.append("\\end{table}")
    open(os.path.join(OUT, "replication.tex"), "w").write("\n".join(lines) + "\n")


# ---- Table 4: config matrix ----------------------------------------------
def table_matrix():
    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\caption{Complete configuration matrix explored in this work. Each "
                 "configuration is synthesised at all three technology nodes, for a total "
                 "of 42 synthesis runs.}")
    lines.append("\\label{tab:matrix}")
    lines.append("\\small")
    lines.append("\\begin{tabular}{llp{7.5cm}}")
    lines.append("\\toprule")
    lines.append("Scenario & Configuration & Description \\\\")
    lines.append("\\midrule")
    data = [
        ("A (single core)", "Baseline", "Unhardened reference accelerator"),
        ("", "Adder DMR / TMR", "Redundancy on the adder functional unit only"),
        ("", "Multiplier DMR / TMR", "Redundancy on the multiplier functional unit only"),
        ("", "Shifter DMR / TMR", "Redundancy on the shifter functional unit only"),
        ("", "Comparator DMR / TMR", "Redundancy on the comparator functional unit only"),
        ("", "Full DMR / TMR", "Redundancy applied to all functional units simultaneously"),
        ("B (replicated)", "Replicated baseline", "Three accelerator lanes, no voting"),
        ("", "Replicated + DMR", "Three lanes with duplication-comparison in the mapping unit"),
        ("", "Replicated + TMR", "Three lanes with majority voting in the mapping unit"),
    ]
    for s, c, d in data:
        lines.append(f"{s} & {c} & {d} \\\\")
    lines.append("\\bottomrule")
    lines.append("\\end{tabular}")
    lines.append("\\end{table}")
    open(os.path.join(OUT, "matrix.tex"), "w").write("\n".join(lines) + "\n")


def table_ijtag():
    path = os.path.join(HERE, "..", "data", "ijtag_cost.csv")
    if not os.path.exists(path):
        return
    crows = list(csv.DictReader(open(path)))
    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\caption{Area cost of the IEEE~1687 sensor instrumentation. "
                 "\\emph{Counted} synthesises the sensor instruments fully; "
                 "\\emph{black box} treats them as empty. Their difference is the "
                 "synthesised cost of the sensors plus the IJTAG access network. "
                 "The cost is about 1.7\\% at the mature node and falls within "
                 "synthesis optimisation noise at the finer nodes.}")
    lines.append("\\label{tab:ijtag}")
    lines.append("\\small")
    lines.append("\\begin{tabular}{llrrr}")
    lines.append("\\toprule")
    lines.append("Node & Sensors & Counted area & Black-box area & Instrument cost (\\%) \\\\")
    lines.append("\\midrule")
    nlab = {"130nm": "IHP 130\\,nm", "45nm": "NanGate 45\\,nm", "15nm": "NanGate 15\\,nm"}
    last = None
    for r in crows:
        node = nlab[r["node"]]
        shown = node if r["node"] != last else ""
        last = r["node"]
        ca = float(r["counted_area"]); ba = float(r["blackbox_area"]); p = float(r["instrument_pct"])
        lines.append(f"{shown} & {r['n_sensors']} & {ca:,.0f} & {ba:,.0f} & {p:+.2f} \\\\")
        if r["n_sensors"] == "3":
            lines.append("\\midrule")
    lines[-1] = "\\bottomrule"
    lines.append("\\end{tabular}")
    lines.append("\\end{table}")
    open(os.path.join(OUT, "ijtag.tex"), "w").write("\n".join(lines) + "\n")


for n in NODES:
    table_absolute(n)
table_overhead()
table_replication()
table_matrix()
table_ijtag()
print("tables written to", OUT)
