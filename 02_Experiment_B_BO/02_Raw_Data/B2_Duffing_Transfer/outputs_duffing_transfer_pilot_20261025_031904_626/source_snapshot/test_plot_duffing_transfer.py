"""Synthetic unit fixtures only; not experimental evidence."""
import tempfile
import unittest
from pathlib import Path
import csv
import os
import shutil
import numpy as np
from plot_duffing_transfer import summarize, plot


def fixture():
    rows = []
    for a in [.05, .7, 2.]:
        for role in ["baseline", "candidate"]:
            for seed, value in enumerate([.1, .5, .7, .9]):
                rows.append(dict(alpha=str(a), role=role, seed=str(seed), success="1",
                                 reference_LIM=".7", R_hat=str(value),
                                 absolute_error=str(abs(value-.7))))
    return rows


def write(path, rows):
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


class PlotTests(unittest.TestCase):
    def test_statistics_and_failure(self):
        raw = fixture()
        summary, _ = summarize(raw)
        self.assertAlmostEqual(summary[0]["median_R"], .6)
        self.assertAlmostEqual(summary[0]["median_absolute_error"], .2)
        self.assertAlmostEqual(summary[0]["q1_R"], .3)
        raw[0]["success"] = "0"
        summary, _ = summarize(raw)
        self.assertEqual(summary[0]["failures"], 1)
        self.assertTrue(np.isnan(summary[0]["median_R"]))

    def test_invalid_records(self):
        raw = fixture()
        with self.assertRaises(ValueError):
            summarize(raw + [raw[0]])
        with self.assertRaises(ValueError):
            summarize(raw[1:])
        raw[0]["absolute_error"] = "999"
        with self.assertRaises(ValueError):
            summarize(raw)

    def test_export(self):
        # This folder is temporary and never used as a study output.
        with tempfile.TemporaryDirectory(prefix="synthetic_plot_test_", dir=Path(__file__).parent) as temp:
            folder = Path(temp)
            raw = fixture()
            summary, _ = summarize(raw)
            write(folder / "transfer_raw.csv", raw)
            write(folder / "summary_by_alpha_and_profile.csv", summary)
            write(folder / "analytical_curve.csv", [
                dict(alpha=a, reference_LIM=.7) for a in [.05, .7, 2.]])
            plot(folder, test_only=True)
            for ext in ["png", "pdf", "svg"]:
                self.assertGreater((folder / f"duffing_transfer.{ext}").stat().st_size, 1000)
            if os.environ.get("DUFFING_PLOT_QA"):
                qa = Path(os.environ["DUFFING_PLOT_QA"])
                qa.mkdir(exist_ok=True, parents=True)
                shutil.copyfile(folder / "duffing_transfer.png", qa / "synthetic_layout_only.png")


if __name__ == "__main__":
    unittest.main()
