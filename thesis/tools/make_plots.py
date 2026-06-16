#!/usr/bin/env python3
"""
make_plots.py -- generate every comparison figure for the thesis Results chapter
from thesis/data/synth_data.csv (produced by parse_synth.py).

All figures are written as vector PDF into thesis/img/plots/ so they drop
straight into the LaTeX build (Overleaf-friendly).

Grouping philosophy: only *comparable* configurations share a figure.
  - Per-FU DMR/TMR overhead is normalised to the per-node baseline.
  - Full-accelerator and replication families get their own figures.
  - Absolute values are shown per node (units differ across nodes).
"""

import os
import csv
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data", "synth_data.csv")
IMG = os.path.join(HERE, "..", "img", "plots")
os.makedirs(IMG, exist_ok=True)

plt.rcParams.update({
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "axes.grid": True,
    "grid.alpha": 0.3,
    "grid.linestyle": "--",
    "figure.autolayout": True,
    "axes.axisbelow": True,
})

NODES = ["130nm", "45nm", "15nm"]
NODE_LABEL = {"130nm": "IHP 130 nm", "45nm": "NanGate 45 nm", "15nm": "NanGate 15 nm"}
# colour-blind-friendly palette
C = {
    "dmr": "#0072B2", "tmr": "#D55E00", "base": "#999999",
    "comb": "#56B4E9", "noncomb": "#E69F00", "bufinv": "#009E73",
    "net": "#CC79A7", "switch": "#56B4E9", "int": "#E69F00", "leak": "#CC79A7",
}
NODE_COLOR = {"130nm": "#0072B2", "45nm": "#009E73", "15nm": "#D55E00"}

FU_LABEL = {"add": "Adder", "mult": "Multiplier", "shift": "Shifter", "comp": "Comparator"}
FU_KEYS = ["add", "mult", "shift", "comp"]


def load():
    rows = list(csv.DictReader(open(DATA)))
    for r in rows:
        for k, v in r.items():
            if k not in ("node", "scenario", "config", "label", "fu"):
                r[k] = float(v) if v not in ("", None) else 0.0
    return rows


def index(rows):
    return {(r["node"], r["config"]): r for r in rows}


def save(fig, name):
    p = os.path.join(IMG, name)
    fig.savefig(p + ".pdf", bbox_inches="tight")
    fig.savefig(p + ".png", dpi=130, bbox_inches="tight")
    plt.close(fig)
    print("  wrote", name)


# ---------------------------------------------------------------------------
# 1. Per-FU normalised AREA overhead, grouped by node (DMR vs TMR)
# ---------------------------------------------------------------------------
def fig_fu_area_overhead(idx):
    for metric, fname, ylab, title in [
        ("cell_area", "fu_area_overhead", "Cell-area overhead (x baseline)",
         "Per-functional-unit cell-area overhead"),
        ("p_total", "fu_power_overhead", "Total-power overhead (x baseline)",
         "Per-functional-unit total-power overhead"),
    ]:
        fig, axes = plt.subplots(1, 3, figsize=(13, 4.2), sharey=True)
        for ax, node in zip(axes, NODES):
            base = idx[(node, "baseline")][metric]
            x = np.arange(len(FU_KEYS))
            w = 0.38
            dmr = [idx[(node, f"{fu_short(fu)}_dmr")][metric] / base for fu in FU_KEYS]
            tmr = [idx[(node, f"{fu_short(fu)}_tmr")][metric] / base for fu in FU_KEYS]
            ax.bar(x - w/2, dmr, w, label="DMR", color=C["dmr"])
            ax.bar(x + w/2, tmr, w, label="TMR", color=C["tmr"])
            ax.axhline(1.0, color="k", lw=0.8, ls=":")
            ax.set_xticks(x)
            ax.set_xticklabels([FU_LABEL[f] for f in FU_KEYS], rotation=20, ha="right")
            ax.set_title(NODE_LABEL[node])
            for xi, (d, t) in enumerate(zip(dmr, tmr)):
                ax.text(xi - w/2, d + 0.02, f"{d:.2f}", ha="center", va="bottom", fontsize=7)
                ax.text(xi + w/2, t + 0.02, f"{t:.2f}", ha="center", va="bottom", fontsize=7)
        axes[0].set_ylabel(ylab)
        axes[0].legend(loc="upper left")
        fig.suptitle(title, y=1.02, fontsize=13)
        save(fig, fname)


def fu_short(fu):
    return {"add": "add", "mult": "mult", "shift": "shift", "comp": "comp"}[fu]


# ---------------------------------------------------------------------------
# 2. Full-accelerator DMR/TMR overhead across nodes (area, power, delay)
# ---------------------------------------------------------------------------
def fig_full_overhead(idx):
    fig, axes = plt.subplots(1, 3, figsize=(13, 4.2))
    metrics = [("cell_area", "Cell area"), ("p_total", "Total power"), ("delay", "Critical-path delay")]
    for ax, (m, mlab) in zip(axes, metrics):
        x = np.arange(len(NODES))
        w = 0.38
        dmr = [idx[(n, "full_dmr")][m] / idx[(n, "baseline")][m] for n in NODES]
        tmr = [idx[(n, "full_tmr")][m] / idx[(n, "baseline")][m] for n in NODES]
        ax.bar(x - w/2, dmr, w, label="Full DMR", color=C["dmr"])
        ax.bar(x + w/2, tmr, w, label="Full TMR", color=C["tmr"])
        ax.axhline(1.0, color="k", lw=0.8, ls=":")
        ax.set_xticks(x); ax.set_xticklabels([NODE_LABEL[n] for n in NODES], rotation=15, ha="right")
        ax.set_title(mlab)
        ax.set_ylabel("Overhead (x baseline)")
        for xi, (d, t) in enumerate(zip(dmr, tmr)):
            ax.text(xi - w/2, d + 0.01, f"{d:.2f}", ha="center", va="bottom", fontsize=8)
            ax.text(xi + w/2, t + 0.01, f"{t:.2f}", ha="center", va="bottom", fontsize=8)
    axes[0].legend(loc="upper left")
    fig.suptitle("Full-accelerator DMR / TMR overhead across technology nodes", y=1.02, fontsize=13)
    save(fig, "full_overhead")


# ---------------------------------------------------------------------------
# 3. Area composition (stacked) per node, all scenario-B configs
# ---------------------------------------------------------------------------
B_ORDER = ["baseline", "add_dmr", "add_tmr", "mult_dmr", "mult_tmr",
           "shift_dmr", "shift_tmr", "comp_dmr", "comp_tmr", "full_dmr", "full_tmr"]
B_SHORT = {"baseline": "Base", "add_dmr": "ADD\nDMR", "add_tmr": "ADD\nTMR",
           "mult_dmr": "MUL\nDMR", "mult_tmr": "MUL\nTMR", "shift_dmr": "SHF\nDMR",
           "shift_tmr": "SHF\nTMR", "comp_dmr": "CMP\nDMR", "comp_tmr": "CMP\nTMR",
           "full_dmr": "FULL\nDMR", "full_tmr": "FULL\nTMR"}


def fig_area_composition(idx):
    for node in NODES:
        fig, ax = plt.subplots(figsize=(11, 4.6))
        x = np.arange(len(B_ORDER))
        comb = np.array([idx[(node, c)]["comb_area"] for c in B_ORDER])
        noncomb = np.array([idx[(node, c)]["noncomb_area"] for c in B_ORDER])
        bufinv = np.array([idx[(node, c)]["bufinv_area"] for c in B_ORDER])
        net = np.array([idx[(node, c)]["net_area"] for c in B_ORDER])
        # comb already includes buf/inv in DC reports; show comb-minus-bufinv + bufinv separately
        comb_only = np.clip(comb - bufinv, 0, None)
        ax.bar(x, comb_only, label="Combinational (excl. buf/inv)", color=C["comb"])
        ax.bar(x, bufinv, bottom=comb_only, label="Buffer / inverter", color=C["bufinv"])
        ax.bar(x, noncomb, bottom=comb_only + bufinv, label="Sequential", color=C["noncomb"])
        ax.bar(x, net, bottom=comb_only + bufinv + noncomb, label="Net interconnect", color=C["net"])
        ax.set_xticks(x); ax.set_xticklabels([B_SHORT[c] for c in B_ORDER], fontsize=8)
        ax.set_ylabel("Area (library units)")
        ax.set_title(f"Area composition by configuration -- {NODE_LABEL[node]}")
        ax.legend(ncol=2, fontsize=9)
        save(fig, f"area_composition_{node}")


# ---------------------------------------------------------------------------
# 4. Power composition (stacked switch/internal/leakage) per node
# ---------------------------------------------------------------------------
def fig_power_composition(idx):
    for node in NODES:
        fig, ax = plt.subplots(figsize=(11, 4.6))
        x = np.arange(len(B_ORDER))
        sw = np.array([idx[(node, c)]["p_switch"] for c in B_ORDER])
        it = np.array([idx[(node, c)]["p_int"] for c in B_ORDER])
        lk = np.array([idx[(node, c)]["p_leak"] for c in B_ORDER])
        ax.bar(x, sw, label="Switching", color=C["switch"])
        ax.bar(x, it, bottom=sw, label="Internal", color=C["int"])
        ax.bar(x, lk, bottom=sw + it, label="Leakage", color=C["leak"])
        ax.set_xticks(x); ax.set_xticklabels([B_SHORT[c] for c in B_ORDER], fontsize=8)
        ax.set_ylabel("Power (mW)")
        ax.set_title(f"Power composition by configuration -- {NODE_LABEL[node]}")
        ax.legend()
        save(fig, f"power_composition_{node}")


# ---------------------------------------------------------------------------
# 5. Cell counts: combinational vs sequential, per node
# ---------------------------------------------------------------------------
def fig_cell_counts(idx):
    for node in NODES:
        fig, ax = plt.subplots(figsize=(11, 4.4))
        x = np.arange(len(B_ORDER))
        comb = np.array([idx[(node, c)]["comb_cells"] for c in B_ORDER])
        seq = np.array([idx[(node, c)]["seq_cells"] for c in B_ORDER])
        w = 0.42
        ax.bar(x - w/2, comb, w, label="Combinational cells", color=C["comb"])
        ax.bar(x + w/2, seq, w, label="Sequential cells", color=C["noncomb"])
        ax.set_xticks(x); ax.set_xticklabels([B_SHORT[c] for c in B_ORDER], fontsize=8)
        ax.set_ylabel("Cell count")
        ax.set_title(f"Combinational vs. sequential cell count -- {NODE_LABEL[node]}")
        ax.legend()
        save(fig, f"cell_counts_{node}")


# ---------------------------------------------------------------------------
# 6. Area-vs-power trade-off scatter (per node, scenario B)
# ---------------------------------------------------------------------------
def fig_tradeoff(idx):
    for node in NODES:
        fig, ax = plt.subplots(figsize=(7.2, 5.2))
        base_a = idx[(node, "baseline")]["cell_area"]
        base_p = idx[(node, "baseline")]["p_total"]
        for c in B_ORDER:
            r = idx[(node, c)]
            ax_ = r["cell_area"] / base_a
            px = r["p_total"] / base_p
            color = C["base"] if c == "baseline" else (C["tmr"] if c.endswith("tmr") else C["dmr"])
            marker = "o" if c == "baseline" else ("^" if c.endswith("tmr") else "s")
            ax.scatter(ax_, px, s=70, color=color, marker=marker, zorder=3, edgecolor="k", lw=0.4)
            ax.annotate(r["label"].replace(" ", "\n"), (ax_, px), fontsize=7,
                        textcoords="offset points", xytext=(6, 4))
        ax.set_xlabel("Cell-area overhead (x baseline)")
        ax.set_ylabel("Total-power overhead (x baseline)")
        ax.set_title(f"Area vs. power trade-off -- {NODE_LABEL[node]}")
        from matplotlib.lines import Line2D
        leg = [Line2D([0], [0], marker="o", color="w", markerfacecolor=C["base"], markeredgecolor="k", label="Baseline"),
               Line2D([0], [0], marker="s", color="w", markerfacecolor=C["dmr"], markeredgecolor="k", label="DMR"),
               Line2D([0], [0], marker="^", color="w", markerfacecolor=C["tmr"], markeredgecolor="k", label="TMR")]
        ax.legend(handles=leg, loc="upper left")
        save(fig, f"tradeoff_{node}")


# ---------------------------------------------------------------------------
# 7. Absolute cell area per node (full family) - separate axes
# ---------------------------------------------------------------------------
def fig_absolute_area(idx):
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.6))
    for ax, node in zip(axes, NODES):
        x = np.arange(len(B_ORDER))
        vals = [idx[(node, c)]["cell_area"] for c in B_ORDER]
        colors = [C["base"] if c == "baseline" else (C["tmr"] if c.endswith("tmr") else C["dmr"]) for c in B_ORDER]
        ax.bar(x, vals, color=colors)
        ax.set_xticks(x); ax.set_xticklabels([B_SHORT[c] for c in B_ORDER], fontsize=7)
        ax.set_title(NODE_LABEL[node])
        ax.set_ylabel("Total cell area (library units)")
    fig.suptitle("Absolute cell area by configuration (per node)", y=1.02, fontsize=13)
    save(fig, "absolute_area")


# ---------------------------------------------------------------------------
# 8. Scenario A: replication + voting (130 & 45 nm where runs differ)
# ---------------------------------------------------------------------------
def fig_replication(idx):
    nodes = ["130nm", "45nm"]
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.4))
    for ax, node in zip(axes, nodes):
        cfgs = ["repl_baseline", "repl_dmr", "repl_tmr"]
        labs = ["Replicated\nbaseline", "Replicated\n+DMR vote", "Replicated\n+TMR vote"]
        base = idx[(node, "baseline")]["cell_area"]
        vals = [idx[(node, c)]["cell_area"] / base for c in cfgs]
        ax.bar(np.arange(3), vals, color=[C["base"], C["dmr"], C["tmr"]])
        ax.set_xticks(np.arange(3)); ax.set_xticklabels(labs, fontsize=9)
        ax.axhline(1.0, color="k", lw=0.8, ls=":")
        ax.set_title(NODE_LABEL[node])
        ax.set_ylabel("Cell area (x single-core baseline)")
        for xi, v in enumerate(vals):
            ax.text(xi, v + 0.03, f"{v:.2f}", ha="center", va="bottom", fontsize=9)
    fig.suptitle("Replication-based redundancy: cost relative to single-core baseline", y=1.02, fontsize=13)
    save(fig, "replication_area")


# ---------------------------------------------------------------------------
# 9. Cross-node normalised summary (DMR & TMR full) line/marker
# ---------------------------------------------------------------------------
def fig_node_summary(idx):
    fig, ax = plt.subplots(figsize=(8, 5))
    metrics = ["cell_area", "p_total"]
    mlab = {"cell_area": "Area", "p_total": "Power"}
    xpos = np.arange(len(NODES))
    for m, ls in zip(metrics, ["-", "--"]):
        dmr = [idx[(n, "full_dmr")][m] / idx[(n, "baseline")][m] for n in NODES]
        tmr = [idx[(n, "full_tmr")][m] / idx[(n, "baseline")][m] for n in NODES]
        ax.plot(xpos, dmr, ls, marker="s", color=C["dmr"], label=f"DMR {mlab[m]}")
        ax.plot(xpos, tmr, ls, marker="^", color=C["tmr"], label=f"TMR {mlab[m]}")
    ax.set_xticks(xpos); ax.set_xticklabels([NODE_LABEL[n] for n in NODES])
    ax.set_ylabel("Overhead (x baseline)")
    ax.set_title("Full-accelerator overhead stability across nodes")
    ax.legend()
    save(fig, "node_summary")


def fig_ijtag(_idx):
    """IJTAG sensor-instrumentation cost from ijtag_data.csv."""
    path = os.path.join(HERE, "..", "data", "ijtag_data.csv")
    if not os.path.exists(path):
        print("  (no ijtag_data.csv, skipping IJTAG figure)")
        return
    rows = list(csv.DictReader(open(path)))
    for r in rows:
        r["n_sensors"] = int(r["n_sensors"])
        r["cell_area"] = float(r["cell_area"]) if r["cell_area"] else 0.0
    by = {(r["n_sensors"], r["node"], r["mode"]): r for r in rows}

    # Panel A: counted vs blackbox absolute area at 130 nm (effect visible);
    # Panel B: instrument area (counted - blackbox) per node, per sensor count.
    fig, (axA, axB) = plt.subplots(1, 2, figsize=(12, 4.4))
    ns = [1, 2, 3]
    node = "130nm"
    cnt = [by[(n, node, "counted")]["cell_area"] for n in ns]
    blk = [by[(n, node, "blackbox")]["cell_area"] for n in ns]
    x = np.arange(len(ns)); w = 0.38
    axA.bar(x - w/2, blk, w, label="Sensors as black box", color=C["base"])
    axA.bar(x + w/2, cnt, w, label="Sensors counted", color=C["dmr"])
    axA.set_xticks(x); axA.set_xticklabels([f"{n} sensor(s)" for n in ns])
    axA.set_ylabel("Total cell area (library units)")
    axA.set_title(f"Instrumented top-level area -- {NODE_LABEL[node]}")
    axA.set_ylim(min(blk) * 0.985, max(cnt) * 1.005)
    axA.legend(fontsize=9)

    for node in NODES:
        inst = [by[(n, node, "counted")]["cell_area"] - by[(n, node, "blackbox")]["cell_area"] for n in ns]
        pct = [100.0 * i / by[(n, node, "blackbox")]["cell_area"] for n, i in zip(ns, inst)]
        axB.plot(ns, pct, marker="o", color=NODE_COLOR[node], label=NODE_LABEL[node])
    axB.axhline(0, color="k", lw=0.8, ls=":")
    axB.set_xticks(ns)
    axB.set_xlabel("Number of inserted sensors")
    axB.set_ylabel("Instrument area (% of design)")
    axB.set_title("IJTAG sensor + network area cost")
    axB.legend(fontsize=9)
    save(fig, "ijtag_cost")


def main():
    rows = load()
    idx = index(rows)
    print("Generating figures ->", IMG)
    fig_fu_area_overhead(idx)
    fig_full_overhead(idx)
    fig_area_composition(idx)
    fig_power_composition(idx)
    fig_cell_counts(idx)
    fig_tradeoff(idx)
    fig_absolute_area(idx)
    fig_replication(idx)
    fig_node_summary(idx)
    fig_ijtag(idx)
    print("done.")


if __name__ == "__main__":
    main()
