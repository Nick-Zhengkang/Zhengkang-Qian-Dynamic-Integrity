"""Plot measured cross-model transfer data, never substitute synthetic solver runs."""
import argparse
import csv
import json
from pathlib import Path
import sys

deps = Path(__file__).resolve().parents[1] / ".thesis_abc_plot_dependencies"
if deps.is_dir():
    sys.path.insert(0, str(deps))
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def read_csv(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def summarize(raw):
    groups = {}
    seen = set()
    for row in raw:
        a, seed, role = float(row["alpha"]), int(row["seed"]), row["role"]
        if role not in ("baseline", "candidate"):
            raise ValueError(f"Unexpected role: {role}")
        key = (a, seed, role)
        if key in seen:
            raise ValueError(f"Duplicate run: {key}")
        seen.add(key)
        groups.setdefault((a, role), []).append(row)
    alphas = sorted({key[0] for key in groups})
    if not alphas:
        raise ValueError("Empty experiment")
    summaries = []
    for a in alphas:
        left = groups.get((a, "baseline"), [])
        right = groups.get((a, "candidate"), [])
        if not left or {r["seed"] for r in left} != {r["seed"] for r in right}:
            raise ValueError(f"Missing paired records at alpha={a}")
        for role in ("baseline", "candidate"):
            rows = groups[(a, role)]
            ref = np.array([float(r["reference_LIM"]) for r in rows])
            if not np.isfinite(ref).all() or (ref <= 0).any() or np.ptp(ref) > 1e-12:
                raise ValueError("Invalid or inconsistent analytical reference")
            valid = [r for r in rows if r["success"].lower() in ("1", "true")]
            values = np.array([float(r["R_hat"]) for r in valid])
            if not np.isfinite(values).all() or (values < 0).any():
                raise ValueError("Invalid successful estimate")
            errors = abs(values - ref[0])
            for row, error in zip(valid, errors):
                if not np.isclose(error, float(row["absolute_error"]), atol=1e-12, rtol=1e-10):
                    raise ValueError("Saved error disagrees with LIM/reference")
            complete = len(valid) == len(rows)
            q = np.quantile(values, [.25, .5, .75], method="hazen") if complete else [np.nan]*3
            summaries.append(dict(alpha=a, role=role, n=len(rows), failures=len(rows)-len(valid),
                                  reference_LIM=ref[0], q1_R=q[0], median_R=q[1], q3_R=q[2],
                                  median_absolute_error=np.median(errors) if complete else np.nan,
                                  median_relative_error_percent=100*np.median(errors)/ref[0] if complete else np.nan))
    return summaries, groups


def plot(folder, test_only=False):
    folder = Path(folder)
    raw = read_csv(folder / "transfer_raw.csv")
    summaries, groups = summarize(raw)
    recorded = read_csv(folder / "summary_by_alpha_and_profile.csv")
    lookup = {(float(r["alpha"]), r["role"]): r for r in recorded}
    for row in summaries:
        saved = lookup[(row["alpha"], row["role"])]
        for field in ("median_R", "median_absolute_error"):
            if not np.isclose(row[field], float(saved[field]), equal_nan=True, atol=1e-12, rtol=1e-9):
                raise ValueError(f"MATLAB/Python summary mismatch: {field}")
    with (folder / "curve_summary_python.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(summaries[0]))
        writer.writeheader()
        writer.writerows(summaries)
    curve = read_csv(folder / "analytical_curve.csv")
    ca = np.array([float(r["alpha"]) for r in curve])
    cr = np.array([float(r["reference_LIM"]) for r in curve])
    if not (np.diff(ca) > 0).all() or not np.isfinite(cr).all():
        raise ValueError("Analytical curve must be finite and ordered")
    for row in summaries:
        j = np.argmin(abs(ca-row["alpha"]))
        if abs(ca[j]-row["alpha"]) > 1e-10 or abs(cr[j]-row["reference_LIM"]) > 1e-10:
            raise ValueError("Curve/reference mismatch")
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "pdf.fonttype": 42, "ps.fonttype": 42, "svg.fonttype": "none",
                         "axes.spines.top": False, "axes.spines.right": False,
                         "axes.linewidth": .8})
    fig, axes = plt.subplots(2, 1, figsize=(8.2, 7.2), sharex=True,
                             gridspec_kw={"height_ratios": [2.1, 1], "hspace": .15})
    top, bottom = axes
    top.plot(ca, cr, "k--", lw=1.8, label="Analytical LIF envelope (Fig. 9)", zorder=5)
    styles = [("baseline", "#8b6046", "s", "Habib-based transfer"),
              ("candidate", "#087f86", "o", "QC-trained BO transfer")]
    counts = sorted({r["n"] for r in summaries})
    for role, color, marker, label in styles:
        rs = [r for r in summaries if r["role"] == role]
        a = np.array([r["alpha"] for r in rs])
        med = np.array([r["median_R"] for r in rs])
        lo = np.array([r["q1_R"] for r in rs])
        hi = np.array([r["q3_R"] for r in rs])
        top.fill_between(a, lo, hi, color=color, alpha=.17, linewidth=0)
        top.plot(a, med, color=color, marker=marker, ms=3.2, lw=1.2, label=label, zorder=4)
        for row in rs:
            good = [float(r["R_hat"]) for r in groups[(row["alpha"],role)]
                    if r["success"].lower() in ("1","true")]
            top.scatter([row["alpha"]]*len(good), good, s=5, color=color,
                        alpha=.18, linewidths=0, rasterized=True)
        bottom.plot(a, [r["median_relative_error_percent"] for r in rs],
                    color=color, marker=marker, ms=3.2, lw=1.2)
    for ax in axes:
        ax.grid(axis="y", color="#dddddd", lw=.6)
        ax.set_axisbelow(True)
        ax.axvline(.6878800931, color="#777777", ls=":", lw=.8)
    top.set_ylabel("Estimated LIM")
    top.set_ylim(bottom=0)
    top.set_title("(a) Bistable Duffing: frozen cross-model transfer", loc="left", fontsize=12, pad=12)
    top.legend(loc="best", frameon=False, fontsize=9)
    bottom.set_title("(b) Error against the analytical envelope", loc="left", fontsize=10)
    bottom.set_ylabel("Median relative error (%)")
    bottom.set_yscale("symlog", linthresh=.1, linscale=.5)
    bottom.set_ylim(bottom=0)
    bottom.set_xlabel(r"Quadratic damping coefficient $\alpha$")
    bottom.set_xlim(.035, 2.02)
    bottom.set_xticks([.05, .25, .5, .75, 1, 1.25, 1.5, 1.75, 2])
    failed = sum(r["failures"] for r in summaries)
    note = (f"{'/'.join(map(str,counts))} seeds per alpha and profile; lines: medians; bands: Q1-Q3; dots: individual runs.\n"
            f"Dotted vertical: analytical branch switch, alpha = 0.68788. Error axis linear below 0.1%, logarithmic above.\n"
            f"Failed runs: {failed}; incomplete groups have no median/band. No retuning on this model.")
    fig.text(.11, .02, note, ha="left", va="bottom", fontsize=8, linespacing=1.5)
    fig.subplots_adjust(left=.11, right=.98, bottom=.17, top=.92 if test_only else .94)
    if test_only:
        fig.suptitle("SYNTHETIC TEST DATA - NOT EXPERIMENT RESULTS", fontsize=10, y=.99)
    for ext in ("png", "pdf", "svg"):
        fig.savefig(folder / f"duffing_transfer.{ext}", dpi=300, facecolor="white")
    plt.close(fig)
    metadata = {"raw_rows": len(raw), "alpha_count": len(groups)//2, "failed_runs": failed,
                "quantiles": "Hazen; middle 50% of seeds, not a confidence interval",
                "reference": "V2 bistable Duffing Fig.9 analytical lower envelope",
                "retuned": False, "summary_crosscheck": "MATLAB/Python passed"}
    (folder / "plot_audit.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"Python figures saved: {folder / 'duffing_transfer.png'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_directory", type=Path)
    plot(parser.parse_args().output_directory)
