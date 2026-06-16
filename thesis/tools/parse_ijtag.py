#!/usr/bin/env python3
"""
parse_ijtag.py -- extract area from the IJTAG sensor-instrumented synthesis runs
produced by the sensor-insertion tool. For each {1,2,3}-sensor configuration,
each technology node, and each accounting mode (blackbox = sensor instruments
treated as empty black boxes; counted = sensor instruments fully synthesised and
counted), the total cell area and cell counts are recorded.

The difference (counted - blackbox) is the synthesised cost of the inserted
sensor instruments plus the IJTAG access network glue.

Output: thesis/data/ijtag_data.csv
"""
import os, re, csv

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUTROOT = os.path.join(REPO, "DSP_BreakDown", "modules", "out")
OUT = os.path.join(HERE, "..", "data")
os.makedirs(OUT, exist_ok=True)

NODES = ["130nm", "45nm", "15nm"]
SENSORS = ["1sensor", "2sensor", "3sensor"]
MODES = ["counted", "blackbox"]


def parse_area(path):
    out = {}
    pats = {
        "cells":      r"Number of cells:\s+([\d.]+)",
        "comb_cells": r"Number of combinational cells:\s+([\d.]+)",
        "seq_cells":  r"Number of sequential cells:\s+([\d.]+)",
        "cell_area":  r"Total cell area:\s+([\d.]+)",
        "total_area": r"Total area:\s+([\d.]+)",
    }
    txt = open(path, errors="ignore").read()
    for k, p in pats.items():
        m = re.search(p, txt)
        out[k] = float(m.group(1)) if m else None
    return out


def main():
    rows = []
    for s in SENSORS:
        n_sensors = int(s[0])
        for node in NODES:
            for mode in MODES:
                d = os.path.join(OUTROOT, s,
                                 f"synthesis_reports_{s}_{node}_{mode}",
                                 "report_area.txt")
                if not os.path.exists(d):
                    print("  ! missing", d)
                    continue
                r = {"n_sensors": n_sensors, "node": node, "mode": mode}
                r.update(parse_area(d))
                rows.append(r)
    cols = ["n_sensors", "node", "mode", "cell_area", "total_area",
            "cells", "comb_cells", "seq_cells"]
    with open(os.path.join(OUT, "ijtag_data.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c) for c in cols})
    print(f"Wrote {len(rows)} rows -> ijtag_data.csv")

    # sensor-instrument cost = counted - blackbox, per node & sensor count
    by = {(r["n_sensors"], r["node"], r["mode"]): r for r in rows}
    with open(os.path.join(OUT, "ijtag_cost.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "n_sensors", "counted_area", "blackbox_area",
                    "instrument_area", "instrument_pct"])
        for node in NODES:
            for n in (1, 2, 3):
                c = by.get((n, node, "counted"))
                b = by.get((n, node, "blackbox"))
                if not c or not b:
                    continue
                inst = c["cell_area"] - b["cell_area"]
                pct = 100.0 * inst / b["cell_area"] if b["cell_area"] else 0
                w.writerow([node, n, f"{c['cell_area']:.1f}", f"{b['cell_area']:.1f}",
                            f"{inst:.1f}", f"{pct:.3f}"])
    print("Wrote ijtag_cost.csv")


if __name__ == "__main__":
    main()
