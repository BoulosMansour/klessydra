#!/usr/bin/env python3
"""
run_synthesis_sweep.py
======================

Automates Design Compiler synthesis of the Klessydra DSP across every
fault-tolerance configuration AND every synthesis technology (15/45/130 nm),
saving each run's reports into its own clearly-named directory and flagging
any dc_shell errors explicitly.

The full sweep is the cartesian product: technologies x configurations.
Results are grouped under tech_<N>nm/ at the top level.

The sweep is specific to this design and covers two scenarios:

  Scenario A -- ENABLE_REPLICATE = true
      Redundancy lives in DSP_Mapping.vhd. The top-level constants in
      RTL_DSP_TOP_synth.vhd are all forced to false, while DSP_Mapping.vhd
      alternates between:
          * DMR_ENABLED = true,  TMR_ENABLED = false   (mapping_DMR)
          * DMR_ENABLED = false, TMR_ENABLED = true    (mapping_TMR)
          * DMR_ENABLED = false, TMR_ENABLED = false   (mapping_none)

  Scenario B -- ENABLE_REPLICATE = false
      Redundancy lives in the per-FU wrappers. DSP_Mapping.vhd constants are
      both forced to false, while RTL_DSP_TOP_synth.vhd alternates between:
          * each of the 8 *_DMR_EN / *_TMR_EN constants true on its own
          * all four *_DMR_EN constants true            (all_DMR)
          * all four *_TMR_EN constants true            (all_TMR)
          * everything false                            (none)

The two source files are backed up before any edits and restored when the
sweep finishes (even on error / Ctrl-C), so the working tree is left clean.

Usage:
    python run_synthesis_sweep.py [--scenario {a,b,all}] [--ncores N]
                                  [--dc-shell CMD] [--dry-run]
"""

import argparse
import fnmatch
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime

# --------------------------------------------------------------------------- #
# Paths (all resolved relative to this script's location: the do/ directory)  #
# --------------------------------------------------------------------------- #
DO_DIR        = os.path.dirname(os.path.abspath(__file__))
MODULES_DIR   = os.path.normpath(os.path.join(DO_DIR, "..", "modules"))
TOP_FILE      = os.path.join(MODULES_DIR, "RTL_DSP_TOP_synth.vhd")
MAPPING_FILE  = os.path.join(MODULES_DIR, "mapping", "DSP_Mapping.vhd")
TEMPLATE_TCL  = os.path.join(DO_DIR, "synthesis_template.tcl")
RESULTS_ROOT  = os.path.join(DO_DIR, "synthesis_runs")

# Top-level constants in RTL_DSP_TOP_synth.vhd
TOP_DMR_CONSTANTS = [
    "ADDERS_DMR_EN",
    "MULTIPLIERS_DMR_EN",
    "COMPARATORS_DMR_EN",
    "SHIFTERS_DMR_EN",
]
TOP_TMR_CONSTANTS = [
    "ADDERS_TMR_EN",
    "MULTIPLIERS_TMR_EN",
    "COMPARATORS_TMR_EN",
    "SHIFTERS_TMR_EN",
]
TOP_ALL_CONSTANTS = TOP_DMR_CONSTANTS + TOP_TMR_CONSTANTS

# Mapping constants in DSP_Mapping.vhd
MAPPING_CONSTANTS = ["DMR_ENABLED", "TMR_ENABLED"]

# Synthesis technologies to sweep -> clock period for create_clock.
# 15nm uses a ps timeunit (period 2000 = 500 MHz); 45nm and 130nm use ns
# (period 2 = 500 MHz). These mirror the original synthesis.tcl.
TECHNOLOGIES = {
    "15":  "2000",
    "45":  "2",
    "130": "2",
}

# Junk that Design Compiler scatters into the working (do/) directory. Only
# entries matching these patterns AND created during the sweep are removed, so
# pre-existing files (e.g. .synopsys_dc.setup) are never touched.
DC_ARTIFACT_PATTERNS = [
    "command.log", ".command.log", "*.svf",
    "WORK", "alib*", "crte*",
    "*.syn", "*.mr", "*.pvl", "*.db_postlink",
    "*.log~", "filenames.log", "*.svf.bak",
]


def clean_dc_artifacts(pre_existing):
    """Remove DC junk from DO_DIR that was not present before the sweep.

    pre_existing: set of entry names that existed in DO_DIR at startup.
    Returns the list of removed entry names.
    """
    removed = []
    for entry in os.listdir(DO_DIR):
        if entry in pre_existing:
            continue
        if not any(fnmatch.fnmatch(entry, pat) for pat in DC_ARTIFACT_PATTERNS):
            continue
        path = os.path.join(DO_DIR, entry)
        try:
            if os.path.isdir(path) and not os.path.islink(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
            removed.append(entry)
        except OSError as exc:
            print(f"    [warn] could not remove artifact '{entry}': {exc}")
    return removed


# --------------------------------------------------------------------------- #
# VHDL constant editing                                                       #
# --------------------------------------------------------------------------- #
def set_boolean_constant(path, name, value):
    """Set a single `constant <name> : boolean := <value>;` line in a file."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    bool_literal = "true" if value else "false"
    pattern = re.compile(
        r"(constant\s+" + re.escape(name) + r"\s*:\s*boolean\s*:=\s*)(true|false)(\s*;)",
        re.IGNORECASE,
    )
    new_content, n = pattern.subn(lambda m: m.group(1) + bool_literal + m.group(3), content)
    if n == 0:
        raise RuntimeError(f"Constant '{name}' not found in {path}")
    if n > 1:
        raise RuntimeError(f"Constant '{name}' matched {n} times in {path} (expected 1)")

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)


def apply_top_constants(values):
    """values: dict {constant_name: bool}. Missing names are set to False."""
    for name in TOP_ALL_CONSTANTS:
        set_boolean_constant(TOP_FILE, name, values.get(name, False))


def apply_mapping_constants(dmr, tmr):
    set_boolean_constant(MAPPING_FILE, "DMR_ENABLED", dmr)
    set_boolean_constant(MAPPING_FILE, "TMR_ENABLED", tmr)


# --------------------------------------------------------------------------- #
# Iteration plan                                                              #
# --------------------------------------------------------------------------- #
def build_iterations(scenario):
    """
    Return a list of iteration dicts:
        { name, enable_replicate, mapping (dmr,tmr), top {const:bool} }
    """
    iterations = []

    # Scenario A: ENABLE_REPLICATE = true, top all false, toggle mapping.
    if scenario in ("a", "all"):
        iterations.append({
            "name": "replicate_true/mapping_DMR",
            "enable_replicate": True,
            "mapping": (True, False),
            "top": {},
        })
        iterations.append({
            "name": "replicate_true/mapping_TMR",
            "enable_replicate": True,
            "mapping": (False, True),
            "top": {},
        })
        iterations.append({
            "name": "replicate_true/mapping_none",
            "enable_replicate": True,
            "mapping": (False, False),
            "top": {},
        })

    # Scenario B: ENABLE_REPLICATE = false, mapping both false, toggle top.
    if scenario in ("b", "all"):
        # each constant true on its own
        for const in TOP_ALL_CONSTANTS:
            iterations.append({
                "name": f"replicate_false/single_{const}",
                "enable_replicate": False,
                "mapping": (False, False),
                "top": {const: True},
            })
        # all DMR true
        iterations.append({
            "name": "replicate_false/all_DMR",
            "enable_replicate": False,
            "mapping": (False, False),
            "top": {c: True for c in TOP_DMR_CONSTANTS},
        })
        # all TMR true
        iterations.append({
            "name": "replicate_false/all_TMR",
            "enable_replicate": False,
            "mapping": (False, False),
            "top": {c: True for c in TOP_TMR_CONSTANTS},
        })
        # everything false
        iterations.append({
            "name": "replicate_false/none",
            "enable_replicate": False,
            "mapping": (False, False),
            "top": {},
        })

    return iterations


# --------------------------------------------------------------------------- #
# TCL generation + dc_shell invocation                                        #
# --------------------------------------------------------------------------- #
def generate_iteration_tcl(template_text, enable_replicate, technology, clock_period,
                           report_dir, ncores, dst_path):
    text = template_text
    text = text.replace("__ENABLE_REPLICATE__", "true" if enable_replicate else "false")
    text = text.replace("__SYNTHESIS_TECHNOLOGY__", str(technology))
    text = text.replace("__CLOCK_PERIOD__", str(clock_period))
    text = text.replace("__NCORES__", str(ncores))
    # dc_shell wants forward slashes even on Windows-authored paths
    text = text.replace("__REPORT_DIR__", report_dir.replace("\\", "/"))
    with open(dst_path, "w", encoding="utf-8") as f:
        f.write(text)


# dc_shell error lines look like "Error: ..." ; warnings like "Warning: ...".
ERROR_RE = re.compile(r"^\s*Error:", re.MULTILINE)


def run_dc_shell(dc_shell_cmd, tcl_path, log_path):
    """Run dc_shell -f <tcl> from DO_DIR, capture combined output to log_path.
    Returns (returncode, error_lines)."""
    with open(log_path, "w", encoding="utf-8") as log:
        proc = subprocess.run(
            [dc_shell_cmd, "-f", tcl_path],
            cwd=DO_DIR,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )

    with open(log_path, "r", encoding="utf-8", errors="replace") as log:
        log_text = log.read()
    error_lines = [ln.strip() for ln in log_text.splitlines() if ERROR_RE.match(ln)]
    return proc.returncode, error_lines


# --------------------------------------------------------------------------- #
# Main                                                                        #
# --------------------------------------------------------------------------- #
def main():
    parser = argparse.ArgumentParser(description="Sweep DC synthesis over all DMR/TMR configurations.")
    parser.add_argument("--scenario", choices=["a", "b", "all"], default="all",
                        help="a = ENABLE_REPLICATE true (mapping), b = ENABLE_REPLICATE false (top), all = both")
    parser.add_argument("--tech", choices=list(TECHNOLOGIES.keys()) + ["all"], nargs="+",
                        default=["all"],
                        help="synthesis technologies to sweep (15, 45, 130, or all). Default: all")
    parser.add_argument("--ncores", type=int, default=1, help="value for NCORES in the TCL")
    parser.add_argument("--dc-shell", default="dc_shell", help="dc_shell executable name/path")
    parser.add_argument("--dry-run", action="store_true",
                        help="edit files and generate TCLs but do not invoke dc_shell")
    args = parser.parse_args()

    for required in (TOP_FILE, MAPPING_FILE, TEMPLATE_TCL):
        if not os.path.isfile(required):
            print(f"[FATAL] required file missing: {required}")
            return 1

    with open(TEMPLATE_TCL, "r", encoding="utf-8", errors="replace") as f:
        template_text = f.read()

    # Resolve the technology selection (preserve TECHNOLOGIES order).
    if "all" in args.tech:
        technologies = list(TECHNOLOGIES.keys())
    else:
        technologies = [t for t in TECHNOLOGIES if t in args.tech]

    config_iterations = build_iterations(args.scenario)

    # Full sweep = technologies x configurations. Each entry carries the
    # technology and its clock period plus a tech-prefixed result path.
    iterations = []
    for tech in technologies:
        for cfg in config_iterations:
            iterations.append({
                **cfg,
                "technology": tech,
                "clock_period": TECHNOLOGIES[tech],
                "name": f"tech_{tech}nm/{cfg['name']}",
            })

    os.makedirs(RESULTS_ROOT, exist_ok=True)

    # Back up the two source files so we can restore them afterwards.
    top_backup     = TOP_FILE + ".sweep_bak"
    mapping_backup = MAPPING_FILE + ".sweep_bak"
    shutil.copy2(TOP_FILE, top_backup)
    shutil.copy2(MAPPING_FILE, mapping_backup)

    # Snapshot the do/ directory so we only ever delete DC junk we created.
    pre_existing = set(os.listdir(DO_DIR))

    summary = []
    start_ts = datetime.now()
    print(f"=== Synthesis sweep started {start_ts:%Y-%m-%d %H:%M:%S} ===")
    print(f"    scenario={args.scenario}  tech={technologies}  "
          f"iterations={len(iterations)}  dc_shell='{args.dc_shell}'"
          + ("  [DRY-RUN]" if args.dry_run else ""))

    try:
        for idx, it in enumerate(iterations, 1):
            report_dir = os.path.join(RESULTS_ROOT, *it["name"].split("/"))
            os.makedirs(report_dir, exist_ok=True)

            # 1. Apply the VHDL constant configuration for this iteration.
            dmr, tmr = it["mapping"]
            apply_mapping_constants(dmr, tmr)
            apply_top_constants(it["top"])

            # 2. Generate the per-iteration TCL.
            tcl_path = os.path.join(report_dir, "synthesis.tcl")
            generate_iteration_tcl(template_text, it["enable_replicate"],
                                   it["technology"], it["clock_period"],
                                   report_dir, args.ncores, tcl_path)

            print(f"\n[{idx}/{len(iterations)}] {it['name']}")
            print(f"    tech={it['technology']}nm (period={it['clock_period']})  "
                  f"ENABLE_REPLICATE={it['enable_replicate']}  "
                  f"mapping(DMR={dmr},TMR={tmr})  top={it['top'] or 'all false'}")
            print(f"    -> {report_dir}")

            if args.dry_run:
                summary.append((it["name"], "SKIPPED (dry-run)"))
                continue

            # 3. Run dc_shell and check for errors.
            log_path = os.path.join(report_dir, "dc_shell.log")
            rc, error_lines = run_dc_shell(args.dc_shell, tcl_path, log_path)

            if rc != 0 or error_lines:
                status = f"FAILED (rc={rc}, {len(error_lines)} error line(s))"
                print(f"    [ERROR] {status}")
                for ln in error_lines[:10]:
                    print(f"        {ln}")
                if len(error_lines) > 10:
                    print(f"        ... and {len(error_lines) - 10} more (see {log_path})")
            else:
                status = "OK"
                print(f"    [OK] reports written")
            summary.append((it["name"], status))

            # 4. Clean the DC artifacts this run scattered into do/.
            removed = clean_dc_artifacts(pre_existing)
            if removed:
                print(f"    cleaned {len(removed)} synthesis artifact(s): {', '.join(sorted(removed))}")

    finally:
        # Always restore the original source files and sweep up any stragglers.
        shutil.move(top_backup, TOP_FILE)
        shutil.move(mapping_backup, MAPPING_FILE)
        clean_dc_artifacts(pre_existing)
        print("\nRestored RTL_DSP_TOP_synth.vhd and DSP_Mapping.vhd to their original state.")

    # Final summary.
    print("\n=== Sweep summary ===")
    failures = 0
    for name, status in summary:
        marker = "OK " if status == "OK" else "!! "
        if status.startswith("FAILED"):
            failures += 1
        print(f"  {marker} {name:55s} {status}")
    elapsed = datetime.now() - start_ts
    print(f"\nFinished in {elapsed}.  {len(summary)} runs, {failures} failed.")

    # Write a machine-readable summary alongside the results.
    summary_path = os.path.join(RESULTS_ROOT, "sweep_summary.txt")
    with open(summary_path, "w", encoding="utf-8") as f:
        f.write(f"Synthesis sweep {start_ts:%Y-%m-%d %H:%M:%S}\n")
        for name, status in summary:
            f.write(f"{name}\t{status}\n")
    print(f"Summary written to {summary_path}")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
