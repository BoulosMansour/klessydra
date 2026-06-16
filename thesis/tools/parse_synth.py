#!/usr/bin/env python3
"""
parse_synth.py -- Extract area / power / timing metrics from the Design Compiler
report tree produced for the Klessydra DSP fault-tolerance study and emit a
single tidy CSV (plus a couple of convenience CSVs) for plotting.

The report tree lives in:
    DSP_BreakDown/do/synthesis_runs/tech_<node>/replicate_<bool>/<config>/Report_*.txt

Power reporting units differ per node (mW/pW, uW/nW, mW/pW); they are read from
the report headers and everything is normalised to milliwatts (mW).

Author: thesis build tooling
"""

import os
import re
import csv

# ---------------------------------------------------------------------------
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SYNTH_ROOT = os.path.join(REPO, "DSP_BreakDown", "do", "synthesis_runs")
OUT_DIR = os.path.join(HERE, "..", "data")
os.makedirs(OUT_DIR, exist_ok=True)

NODES = ["130nm", "45nm", "15nm"]

# Canonical config-name mapping for the do/synthesis_runs tree, which is laid out
# as  tech_<node>/replicate_<bool>/<config>/Report_*.txt .
# Key = (replicate_dir, config_dir) -> (clean key, label, scenario, FU).
#   scenario "A" : single-core, per-FU / full-accelerator wrappers
#   scenario "B" : replication-based redundancy in the mapping unit
CONFIG_MAP = {
    # scenario A (replicate_false, single core)
    ("replicate_false", "none"):                    ("baseline",  "Baseline",       "A", "none"),
    ("replicate_false", "single_ADDERS_DMR_EN"):     ("add_dmr",   "Adder DMR",      "A", "adder"),
    ("replicate_false", "single_ADDERS_TMR_EN"):     ("add_tmr",   "Adder TMR",      "A", "adder"),
    ("replicate_false", "single_MULTIPLIERS_DMR_EN"):("mult_dmr",  "Multiplier DMR", "A", "mult"),
    ("replicate_false", "single_MULTIPLIERS_TMR_EN"):("mult_tmr",  "Multiplier TMR", "A", "mult"),
    ("replicate_false", "single_SHIFTERS_DMR_EN"):   ("shift_dmr", "Shifter DMR",    "A", "shift"),
    ("replicate_false", "single_SHIFTERS_TMR_EN"):   ("shift_tmr", "Shifter TMR",    "A", "shift"),
    ("replicate_false", "single_COMPARATORS_DMR_EN"):("comp_dmr",  "Comparator DMR", "A", "comp"),
    ("replicate_false", "single_COMPARATORS_TMR_EN"):("comp_tmr",  "Comparator TMR", "A", "comp"),
    ("replicate_false", "all_DMR"):                  ("full_dmr",  "Full DMR",       "A", "full"),
    ("replicate_false", "all_TMR"):                  ("full_tmr",  "Full TMR",       "A", "full"),
    # scenario B (replicate_true, voting in the mapping unit)
    ("replicate_true", "mapping_none"): ("repl_baseline", "Replicated baseline", "B", "none"),
    ("replicate_true", "mapping_DMR"):  ("repl_dmr",      "Replicated DMR",      "B", "full"),
    ("replicate_true", "mapping_TMR"):  ("repl_tmr",      "Replicated TMR",      "B", "full"),
}

# Order used by plotting / tables
B_ORDER = ["baseline", "add_dmr", "add_tmr", "mult_dmr", "mult_tmr",
           "shift_dmr", "shift_tmr", "comp_dmr", "comp_tmr", "full_dmr", "full_tmr"]
A_ORDER = ["repl_baseline", "repl_dmr", "repl_tmr"]


def _num(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def parse_area(path):
    out = {}
    pats = {
        "ports":        r"Number of ports:\s+([\d.]+)",
        "nets":         r"Number of nets:\s+([\d.]+)",
        "cells":        r"Number of cells:\s+([\d.]+)",
        "comb_cells":   r"Number of combinational cells:\s+([\d.]+)",
        "seq_cells":    r"Number of sequential cells:\s+([\d.]+)",
        "buf_inv":      r"Number of buf/inv:\s+([\d.]+)",
        "comb_area":    r"Combinational area:\s+([\d.]+)",
        "bufinv_area":  r"Buf/Inv area:\s+([\d.]+)",
        "noncomb_area": r"Noncombinational area:\s+([\d.]+)",
        "net_area":     r"Net Interconnect area:\s+([\d.]+)",
        "cell_area":    r"Total cell area:\s+([\d.]+)",
        "total_area":   r"Total area:\s+([\d.]+)",
    }
    with open(path, "r", errors="ignore") as f:
        txt = f.read()
    for k, p in pats.items():
        m = re.search(p, txt)
        out[k] = _num(m.group(1)) if m else None
    return out


def parse_power(path):
    """Return dynamic switch/internal/leakage/total power, normalised to mW."""
    with open(path, "r", errors="ignore") as f:
        lines = f.readlines()
    dyn_scale = 1.0   # to mW
    leak_scale = 1.0  # to mW
    for ln in lines:
        m = re.search(r"Dynamic Power Units = 1(\w?)W", ln)
        if m:
            u = m.group(1)
            dyn_scale = {"m": 1.0, "u": 1e-3, "n": 1e-6, "p": 1e-9, "": 1e3}.get(u, 1.0)
        m = re.search(r"Leakage Power Units = 1(\w?)W", ln)
        if m:
            u = m.group(1)
            leak_scale = {"m": 1.0, "u": 1e-3, "n": 1e-6, "p": 1e-9, "": 1e3}.get(u, 1.0)
    # find the hierarchy header then the first data row (top design = 100.0 %)
    top = None
    hdr = False
    for ln in lines:
        if re.search(r"Switch\s+Int\s+Leak\s+Total", ln):
            hdr = True
            continue
        if hdr:
            if set(ln.strip()) <= set("- "):
                continue
            toks = ln.split()
            nums = [t for t in toks if re.match(r"^[\d.]+(e[+\-]?\d+)?$", t)]
            if len(nums) >= 5:
                top = nums[-5:]  # switch int leak total pct
                break
    if not top:
        return {"p_switch": None, "p_int": None, "p_leak": None, "p_total": None}
    sw, it, lk, tot, _pct = [_num(x) for x in top]
    return {
        "p_switch": sw * dyn_scale if sw is not None else None,
        "p_int":    it * dyn_scale if it is not None else None,
        "p_leak":   lk * leak_scale if lk is not None else None,
        "p_total":  tot * dyn_scale if tot is not None else None,
    }


def parse_timing(path):
    """Critical-path (data arrival) delay in the library's time unit (ns for
    130/45 nm; the 15 nm FreePDK reports in its own scaled unit)."""
    if not os.path.exists(path):
        return {"delay": None}
    with open(path, "r", errors="ignore") as f:
        txt = f.read()
    m = re.search(r"data arrival time\s+([\d.]+)", txt)
    return {"delay": _num(m.group(1)) if m else None}


def collect():
    rows = []
    for node in NODES:
        ndir = os.path.join(SYNTH_ROOT, "tech_" + node)
        if not os.path.isdir(ndir):
            continue
        for repl in ("replicate_false", "replicate_true"):
            rdir = os.path.join(ndir, repl)
            if not os.path.isdir(rdir):
                continue
            for cfg in sorted(os.listdir(rdir)):
                cpath = os.path.join(rdir, cfg)
                if os.path.isdir(cpath):
                    _add_row(rows, node, (repl, cfg), cpath)
    return rows


def _add_row(rows, node, key, path):
    if key not in CONFIG_MAP:
        print("  ! unmapped config:", node, key)
        return
    cfg, label, scen, fu = CONFIG_MAP[key]
    area_f = os.path.join(path, "Report_Area.txt")
    pow_f = os.path.join(path, "Report_Power.txt")
    tim_f = os.path.join(path, "Report_time_delay_max.txt")
    if not os.path.exists(area_f):
        print("  ! missing area report:", path)
        return
    row = {"node": node, "config": cfg, "label": label,
           "scenario": scen, "fu": fu}
    row.update(parse_area(area_f))
    row.update(parse_power(pow_f) if os.path.exists(pow_f)
               else {"p_switch": None, "p_int": None, "p_leak": None, "p_total": None})
    row.update(parse_timing(tim_f))
    rows.append(row)


def main():
    rows = collect()
    cols = ["node", "scenario", "config", "label", "fu",
            "cell_area", "total_area", "comb_area", "noncomb_area",
            "bufinv_area", "net_area",
            "cells", "comb_cells", "seq_cells", "buf_inv", "ports", "nets",
            "p_switch", "p_int", "p_leak", "p_total", "delay"]
    out_csv = os.path.join(OUT_DIR, "synth_data.csv")
    with open(out_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c) for c in cols})
    print(f"Wrote {len(rows)} rows -> {out_csv}")

    # also dump per-node normalised-to-baseline overhead table (scenario B)
    norm_csv = os.path.join(OUT_DIR, "overhead_scenarioB.csv")
    by = {}
    for r in rows:
        by[(r["node"], r["config"])] = r
    with open(norm_csv, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "config", "label",
                    "area_x", "power_x", "delay_x",
                    "cell_area", "p_total", "delay"])
        for node in NODES:
            base = by.get((node, "baseline"))
            if not base:
                continue
            for cfg in B_ORDER:
                r = by.get((node, cfg))
                if not r:
                    continue
                ax = (r["cell_area"] / base["cell_area"]) if base["cell_area"] else None
                px = (r["p_total"] / base["p_total"]) if base["p_total"] else None
                dx = (r["delay"] / base["delay"]) if base["delay"] else None
                w.writerow([node, cfg, r["label"],
                            f"{ax:.4f}" if ax else "",
                            f"{px:.4f}" if px else "",
                            f"{dx:.4f}" if dx else "",
                            r["cell_area"], r["p_total"], r["delay"]])
    print(f"Wrote overhead table -> {norm_csv}")


if __name__ == "__main__":
    main()
