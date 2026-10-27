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
"""Independent 60-digit checks of the MATLAB reference's mathematical scheme.

This does not execute MATLAB or validate the DynIn/BO runtime pipeline.
Uses only the Python standard library. No model trajectories are integrated.
"""
import csv
import math
from decimal import Decimal, getcontext
from pathlib import Path

getcontext().prec = 60
D = Decimal


def p_decimal(x, a, duffing):
    if duffing:
        return (-4*a**3*x**3 + 6*a*a*x*x + (4*a**3-6*a)*x
                - (3-2*a*a)*((-2*a*x).exp()-1))/(4*a**4)
    return (2*a*a*x*x-2*a*a*x-2*a*x+2*a
            -(1-a)*((2*a*(1-x)).exp()-1))/(2*a**3)


def p_double(x, a, duffing):
    k = 2*a
    z = x if duffing else x-1
    if abs(k*z) < 2:
        total, term = 0.0, 1.0
        for n in range(71):
            integral = (2*z*z/(n+2)-2*z**4/(n+4) if duffing
                        else 2*z*z/(n+2)+2*z**3/(n+3))
            total += term*integral
            term *= k*z/(n+1)
        return math.exp(-k*z)*total
    if duffing:
        return (-4*a**3*x**3+6*a*a*x*x+(4*a**3-6*a)*x
                -(3-2*a*a)*math.expm1(-2*a*x))/(4*a**4)
    return (2*a*a*x*x-2*a*a*x-2*a*x+2*a
            -(1-a)*math.expm1(2*a*(1-x)))/(2*a**3)


def bisect(fun, lo, hi):
    fl = fun(lo)
    if fl == 0:
        return lo
    if fun(hi) == 0:
        return hi
    assert fl*fun(hi) < 0
    for _ in range(150):
        mid = (lo+hi)/2
        if mid == lo or mid == hi:
            break
        fm = fun(mid)
        if fm == 0:
            return mid
        if fl*fm > 0:
            lo, fl = mid, fm
        else:
            hi = mid
    return (lo+hi)/2


def radius(a, duffing, high_precision):
    scalar = D if high_precision else float
    a = scalar(str(a))
    center = scalar(-1 if duffing else 0)
    saddle = scalar(0 if duffing else 1)
    left = center-1
    pf = p_decimal if high_precision else p_double
    p = lambda x: pf(x, a, duffing)
    force = (lambda x: 2*x-2*x**3) if duffing else (lambda x: -2*x+2*x*x)
    g = lambda x: 2*(x-center)+force(x)-2*a*p(x)
    if p(left) < 0:
        left = bisect(p, left, center)
    points = [left, saddle]
    # Different root-scan resolution from the MATLAB evaluator.
    n = 367
    xs = [left+(saddle-left)*i/n for i in range(n+1)]
    for lo, hi in zip(xs, xs[1:]):
        if g(lo) == 0:
            points.append(lo)
        if g(lo)*g(hi) < 0:
            points.append(bisect(g, lo, hi))
    r2 = min((x-center)**2+max(scalar(0), p(x)) for x in points)
    return float(r2.sqrt()) if high_precision else math.sqrt(r2)


def main():
    rows = []
    grids = [("train", i/10) for i in range(1, 21)]
    grids += [("validation", i/20) for i in range(1, 40, 2)]
    grids += [("regime_check", x) for x in (.27944, .6878800931, math.sqrt(1.5))]
    for model, duffing in [("quadratic_cubic", False), ("bistable_duffing", True)]:
        for split, a in grids:
            high = radius(a, duffing, True)
            low = radius(a, duffing, False)
            difference = abs(high-low)
            assert difference < 1e-10, (model, a, high, low)
            rows.append(dict(model=model, split=split, alpha=a,
                             reference_60_digit=high, reference_double=low,
                             absolute_difference=difference))
    assert abs(radius(1, False, True)-math.sqrt(.5)) < 1e-14
    assert abs(radius(.7, True, True)-.72892785915611505908) < 1e-14
    output = Path(__file__).parent / "reference_math_audit.csv"
    with output.open("w", newline="", encoding="ascii") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"PASS: {len(rows)} reference checks, max double/60-digit difference "
          f"{max(r['absolute_difference'] for r in rows):.3g}")
    print(output)


if __name__ == "__main__":
    main()
