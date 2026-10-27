# BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
# Scope: Analysis and plotting implementation.
# This implementation was written/revised with OpenAI generative AI assistance.
# Author-declared contributions: Zhengkang Qian supplied the experimental
# concept, intended methodological direction, and specific revision requests.
# For MATLAB algorithms, the author reports line-by-line review and trial
# runs followed by iterative requests to address implementation/design mismatches.
# AI translated these instructions and method ideas into executable code.
# Existing third-party algorithms, source portions and licenses retain their
# original attribution; AI assistance does not imply authorship of DynIn.
# Review and testing do not certify mathematical or numerical correctness.
# See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
# END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
#
"""Independent dense mathematical audit; does not execute MATLAB or DynIn."""
import csv
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / ".thesis_abc_plot_dependencies"))
sys.path.insert(0, str(ROOT.parent / "experiment_B_multi_alpha"))
import numpy as np
from verify_reference_math import p_double, radius, bisect


def branch_vector(x, a):
    x = np.asarray(x)
    k = 2*a
    p = (-4*a**3*x**3 + 6*a*a*x*x + (4*a**3-6*a)*x
         -(3-2*a*a)*np.expm1(-2*a*x))/(4*a**4)
    use = abs(k*x) < 2
    z = x[use]
    total, term = np.zeros_like(z), np.ones_like(z)
    for n in range(71):
        total += term*(2*z*z/(n+2)-2*z**4/(n+4))
        term *= k*z/(n+1)
    p[use] = np.exp(-k*z)*total
    return p


def corrected(a, n):
    p = lambda x: p_double(x, a, True)
    g = lambda x: 2*(x+1)+2*x-2*x**3-2*a*p(x)
    left, turn, width, residual = -2., False, np.nan, np.nan
    if p(left) < 0:
        lo, hi = -2., -1.
        for _ in range(100):
            mid = lo+(hi-lo)/2
            if mid == lo or mid == hi:
                break
            if p(mid) < 0:
                lo = mid
            else:
                hi = mid
        left, turn, width, residual = hi, True, hi-lo, abs(p(hi))
        assert p(left) >= 0 and width < 1e-12 and residual < 1e-10
    xs = np.linspace(left, 0, n+1)
    gs = 2*(xs+1)+2*xs-2*xs**3-2*a*branch_vector(xs, a)
    points = [left, 0.]
    for i in np.flatnonzero(gs[:-1] == 0):
        points.append(xs[i])
    for i in np.flatnonzero(gs[:-1]*gs[1:] < 0):
        points.append(bisect(g, float(xs[i]), float(xs[i+1])))
    pv = [p(x) for x in points]
    assert min(pv) >= -1e-10
    if turn:
        pv[0] = 0.
    R = min((x+1)**2+max(0., v) for x, v in zip(points,pv))**.5
    return R, width, residual


def main():
    alphas = np.unique(np.r_[np.linspace(.05,2,391), np.arange(1,41)/20,
                             .6878800931, .805, .82, np.sqrt(1.5)])
    rows = []
    for j, a in enumerate(alphas):
        a = float(a)
        r1, _, _ = corrected(a, 2048)
        r2, width, residual = corrected(a, 4096)
        precise = radius(a, True, True)
        assert abs(r1-r2) < 1e-8 and abs(r2-precise) < 1e-10, (a,r1,r2,precise)
        rows.append(dict(alpha=a, reference_double=r2, reference_60_digit=precise,
                         absolute_difference=abs(r2-precise),
                         turning_bracket_width=width, turning_residual=residual))
        if (j+1) % 50 == 0:
            print(f"Checked {j+1}/{len(alphas)} analytical references", flush=True)
    output = ROOT / "reference_dense_math_audit.csv"
    with output.open("w", newline="", encoding="ascii") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"PASS: {len(rows)} dense checks; max difference "
          f"{max(r['absolute_difference'] for r in rows):.3g}", flush=True)
    print("Python mathematical audit only; not a MATLAB runtime test.", flush=True)


if __name__ == "__main__":
    main()
