# BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
# Scope: Proposed-method implementation, comparison, or supporting model code.
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
from __future__ import annotations

import math
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor

import build_comparison_report_cn as common


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "DynIn_vs_Adaptive_Angular_Radial_Six_Model_Comparison_Report_EN.docx"
ASSETS = ROOT / "report_assets_en"
ASSETS.mkdir(exist_ok=True)

SUMMARY = common.SUMMARY
PAIRED = common.PAIRED
REFS = common.REFS
CONFIGS = common.CONFIGS
VALID = common.VALID

MODEL = {
    "quadratic_cubic": "Quadratic-cubic potential",
    "bistable_duffing": "Bistable Duffing potential",
    "habib_unforced_duffing": "Habib unforced Duffing oscillator",
    "genda_cosine_quadratic_drag": "Cosine potential with quadratic drag",
    "habib_vdp_tmd_4d": "Habib 4D Duffing-van der Pol system with NLTVA",
    "separable_qc_bd_4d": "Separable 4D quadratic-cubic and bistable Duffing system",
}

METHOD = {
    "dynin_original_ga": "DynIn original GA",
    "proposed_adaptive_angle": "Proposed adaptive angular-radial method",
}


def pct(v, digits=2):
    return f"{100 * float(v):.{digits}f}%"


def num(v, digits=3):
    return f"{float(v):.{digits}f}"


def summary_row(model_id, method):
    return next(r for r in SUMMARY if r["model_id"] == model_id and r["method"] == method)


def np_range(start, stop, step):
    values = []
    value = start
    while value <= stop + 1e-9:
        values.append(round(value, 10))
        value += step
    return values


def make_figures():
    regular = Path("C:/Windows/Fonts/times.ttf")
    bold = Path("C:/Windows/Fonts/timesbd.ttf")

    def font(size, is_bold=False):
        path = bold if is_bold and bold.exists() else regular
        return ImageFont.truetype(str(path), size=size) if path.exists() else ImageFont.load_default()

    def canvas(title):
        image = Image.new("RGB", (1500, 720), "white")
        draw = ImageDraw.Draw(image)
        draw.text((70, 38), title, fill="#111111", font=font(34, True))
        return image, draw

    def axes(draw, left, top, right, bottom, ticks, y_map, label=""):
        draw.line((left, top, left, bottom), fill="#333333", width=2)
        draw.line((left, bottom, right, bottom), fill="#333333", width=2)
        for value, text in ticks:
            y = y_map(value)
            draw.line((left, y, right, y), fill="#DDDDDD", width=1)
            draw.text((left - 18, y), text, anchor="rm", fill="#333333", font=font(22))
        if label:
            draw.text((left, top - 18), label, anchor="ls", fill="#333333", font=font(20))

    # Figure 1: accuracy, excluding Habib 4D because 0.5737 is not ground truth.
    benchmark_ids = [r["model_id"] for r in REFS if r["model_id"] != "habib_vdp_tmd_4d"]
    labels = ["QC", "Bistable Duffing", "Habib Duffing", "Cosine", "Separable 4D"]
    dyn = [100 * float(summary_row(mid, "dynin_original_ga")["median_relative_error"]) for mid in benchmark_ids]
    pro = [100 * float(summary_row(mid, "proposed_adaptive_angle")["median_relative_error"]) for mid in benchmark_ids]
    image, draw = canvas("Median Relative Error Across Five Reference Models")
    left, top, right, bottom = 150, 135, 1450, 600
    log_min, log_max = -3.0, 1.2
    y_map = lambda v: bottom - (math.log10(max(v, 10 ** log_min)) - log_min) / (log_max - log_min) * (bottom - top)
    axes(draw, left, top, right, bottom,
         [(0.001, "0.001"), (0.01, "0.01"), (0.1, "0.1"), (1, "1"), (10, "10")],
         y_map, "Median relative error (%) on a logarithmic scale")
    group_w = (right - left) / len(labels)
    bar_w = 44
    for i, label in enumerate(labels):
        center = left + group_w * (i + 0.5)
        for offset, value, color in [(-28, dyn[i], "#6B7280"), (28, pro[i], "#0F766E")]:
            x0, x1 = center + offset - bar_w / 2, center + offset + bar_w / 2
            draw.rectangle((x0, y_map(value), x1, bottom), fill=color)
        draw.text((center, bottom + 28), label, anchor="ma", fill="#222222", font=font(20))
    draw.rectangle((800, 75, 835, 95), fill="#6B7280")
    draw.text((848, 85), "DynIn original GA", anchor="lm", fill="#222222", font=font(21))
    draw.rectangle((1115, 75, 1150, 95), fill="#0F766E")
    draw.text((1163, 85), "Proposed", anchor="lm", fill="#222222", font=font(21))
    image.save(ASSETS / "median_error_comparison_en.png", dpi=(220, 220))

    # Figure 2: paired cost ratios.
    labels = ["QC", "Bistable", "Habib 2D", "Cosine", "Habib 4D", "Separable 4D"]
    eval_ratio = [float(r["median_evaluation_ratio"]) for r in PAIRED]
    runtime_ratio = [float(r["median_runtime_ratio"]) for r in PAIRED]
    image, draw = canvas("Computational Cost of the Proposed Method Relative to DynIn")
    panels = [
        (80, 140, 730, 600, eval_ratio, "Trajectory-evaluation ratio", "#0F766E", 8.0),
        (820, 140, 1470, 600, runtime_ratio, "Median runtime ratio", "#4B5563", 4.2),
    ]
    for left, top, right, bottom, values, title, color, ymax in panels:
        draw.text(((left + right) / 2, 105), title, anchor="mm", fill="#111111", font=font(25, True))
        y_map = lambda value, t=top, b=bottom, maximum=ymax: b - value / maximum * (b - t)
        axes(draw, left, top, right, bottom,
             [(v, f"{v:g}") for v in np_range(0, ymax, 1 if ymax < 5 else 2)], y_map)
        draw.line((left, y_map(1), right, y_map(1)), fill="#111111", width=2)
        group_w = (right - left) / 6
        for i, value in enumerate(values):
            center = left + group_w * (i + 0.5)
            draw.rectangle((center - 25, y_map(value), center + 25, bottom), fill=color)
            draw.text((center, bottom + 25), labels[i], anchor="ma", fill="#222222", font=font(17))
    draw.text((750, 680), "Ratio = Proposed / DynIn; the horizontal line denotes equal cost.",
              anchor="mm", fill="#333333", font=font(19))
    image.save(ASSETS / "cost_ratios_en.png", dpi=(220, 220))

    # Figure 3: independent validation of the Habib 4D boundary.
    image, draw = canvas("Independent Trajectory Validation for the Habib 4D Model")
    left, top, right, bottom = 170, 160, 1430, 575
    xmin, xmax = 0.532, 0.578
    x_map = lambda value: left + (value - xmin) / (xmax - xmin) * (right - left)
    draw.line((left, bottom, right, bottom), fill="#333333", width=2)
    for value in [0.535, 0.545, 0.555, 0.565, 0.575]:
        x = x_map(value)
        draw.line((x, top, x, bottom), fill="#E5E7EB", width=1)
        draw.text((x, bottom + 22), f"{value:.3f}", anchor="ma", fill="#333333", font=font(21))
    draw.text(((left + right) / 2, 650), "Weighted distance R", anchor="mm", fill="#333333", font=font(23))
    for i, row in enumerate(VALID):
        y = top + 75 + i * 110
        lower, upper = float(row["bracket_lower"]), float(row["bracket_upper"])
        draw.text((left - 25, y), f"Seed {row['seed']}", anchor="rm", fill="#222222", font=font(22))
        draw.line((x_map(lower), y, x_map(upper), y), fill="#0F766E", width=8)
        center = x_map((lower + upper) / 2)
        draw.ellipse((center - 8, y - 8, center + 8, y + 8), fill="#0F766E")
    paper_x = x_map(0.5737)
    for y in range(top, bottom, 16):
        draw.line((paper_x, y, paper_x, min(y + 8, bottom)), fill="#B45309", width=3)
    draw.text((paper_x - 8, top - 20), "Published value 0.5737", anchor="rs", fill="#B45309", font=font(22, True))
    image.save(ASSETS / "habib4d_validation_en.png", dpi=(220, 220))


def configure_document(doc):
    section = doc.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(0.78)
    section.bottom_margin = Inches(0.72)
    section.left_margin = Inches(0.82)
    section.right_margin = Inches(0.82)
    section.header_distance = Inches(0.32)
    section.footer_distance = Inches(0.35)
    common.add_page_number(section)

    styles = doc.styles
    for style_name in ["Normal", "Body Text", "List Bullet", "List Bullet 2", "List Number", "List Number 2", "Caption"]:
        style = styles[style_name]
        style.font.name = "Times New Roman"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
        style.font.color.rgb = RGBColor(0, 0, 0)
    styles["Normal"].font.size = Pt(11)
    styles["Normal"].paragraph_format.line_spacing = 1.25
    styles["Normal"].paragraph_format.space_after = Pt(5)
    styles["Body Text"].font.size = Pt(11)
    styles["Body Text"].paragraph_format.line_spacing = 1.25
    styles["Body Text"].paragraph_format.space_after = Pt(6)
    styles["Body Text"].paragraph_format.first_line_indent = Cm(0.74)
    styles["Caption"].font.size = Pt(9)
    styles["Caption"].font.italic = True
    styles["Caption"].font.color.rgb = RGBColor(65, 65, 65)
    styles["Caption"].paragraph_format.space_before = Pt(5)
    styles["Caption"].paragraph_format.space_after = Pt(6)

    title = styles["Title"]
    title.font.name = "Times New Roman"
    title._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
    title.font.size = Pt(24)
    title.font.bold = True
    title.font.color.rgb = RGBColor(0, 0, 0)

    for name, size, before, after in [
        ("Heading 1", 16, 0, 12),
        ("Heading 2", 13, 12, 7),
        ("Heading 3", 11.5, 9, 5),
    ]:
        style = styles[name]
        style.font.name = "Times New Roman"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = RGBColor(0, 0, 0)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True


def restyle_table_times(table, size=9.0):
    for row in table.rows:
        for cell in row.cells:
            for paragraph in cell.paragraphs:
                for run in paragraph.runs:
                    run.font.name = "Times New Roman"
                    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), "Times New Roman")
                    run.font.size = Pt(size)


def add_table(doc, headers, rows, widths, size=9.0, caption=None):
    table = common.add_table(doc, headers, rows, widths=widths, font_size=size, caption=caption)
    restyle_table_times(table, size)
    return table


def add_body(doc, text, bold_lead=None):
    paragraph = common.add_body(doc, text, bold_lead=bold_lead)
    for run in paragraph.runs:
        run.font.name = "Times New Roman"
        run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), "Times New Roman")
        run.font.size = Pt(11)
    return paragraph


def add_figure(doc, path, caption, width=6.8):
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.add_run().add_picture(str(path), width=Inches(width))
    cap = doc.add_paragraph(style="Caption")
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.add_run(caption)


def add_heading(doc, text, bookmark, bookmark_id):
    return common.add_heading_new_page(doc, text, 1, bookmark, bookmark_id)


def force_times_new_roman(path):
    temp = path.with_suffix(".fontfix.docx")
    replacements = [
        (b"Arial", b"Times New Roman"),
        (b"Calibri", b"Times New Roman"),
        (b"Cambria", b"Times New Roman"),
        (b"Courier New", b"Times New Roman"),
        (b"Courier", b"Times New Roman"),
        ("等线".encode("utf-8"), b"Times New Roman"),
    ]
    with zipfile.ZipFile(path, "r") as source, zipfile.ZipFile(temp, "w", zipfile.ZIP_DEFLATED) as target:
        for item in source.infolist():
            data = source.read(item.filename)
            if item.filename.endswith(".xml"):
                for old, new in replacements:
                    data = data.replace(old, new)
            target.writestr(item, data)
    temp.replace(path)


def build():
    make_figures()
    doc = Document()
    configure_document(doc)

    # Cover
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_before = Pt(90)
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run("Comparison of the Original DynIn GA and an Adaptive Angular-Radial Method")
    run.font.name = "Times New Roman"
    run.font.size = Pt(24)
    run.font.bold = True
    paragraph.style = doc.styles["Title"]
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run("Four Two-Dimensional Models and Two Four-Dimensional Models")
    run.font.name = "Times New Roman"
    run.font.size = Pt(14)
    paragraph.paragraph_format.space_before = Pt(8)
    paragraph.paragraph_format.space_after = Pt(30)
    add_table(doc, ["Item", "Description"], [
        ["Methods", "Habib's original DynIn GA and the proposed adaptive angular-radial method"],
        ["Experiment size", "6 models × 2 methods × 30 paired seeds = 360 runs"],
        ["Primary outcomes", "LIM accuracy, seed-to-seed stability, trajectory cost, and four-dimensional boundary validity"],
        ["Report version", "English results report, September 2026"],
    ], [3.0, 12.5], 10)
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_before = Pt(25)
    run = paragraph.add_run("Main finding")
    run.font.name = "Times New Roman"
    run.font.size = Pt(12)
    run.font.bold = True
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run(
        "The proposed method substantially reduced LIM error on all models with an analytical or explicit numerical reference. "
        "For the Habib four-dimensional model, it found a closer boundary near 0.538, which was independently confirmed as a transition from the target attractor to a non-target periodic attractor."
    )
    run.font.name = "Times New Roman"
    run.font.size = Pt(11)

    # Contents
    doc.add_page_break()
    doc.add_heading("Contents", level=1)
    toc = [
        ("1 Research Questions", "bm_1"),
        ("2 Method Configuration for the Comparison", "bm_2"),
        ("3 Experimental Design", "bm_3"),
        ("4 Experimental Results", "bm_4"),
        ("5 Discussion", "bm_5"),
        ("6 Conclusions", "bm_6"),
        ("Appendix A DynIn Configuration Summary", "bm_a"),
        ("Appendix B Reproducibility Files", "bm_b"),
    ]
    for label, anchor in toc:
        paragraph = doc.add_paragraph(style="Body Text")
        paragraph.paragraph_format.first_line_indent = Cm(0)
        paragraph.paragraph_format.space_after = Pt(8)
        common.add_internal_link(paragraph, label, anchor)
        for run in paragraph.runs:
            run.font.name = "Times New Roman"
    add_body(doc, "The entries are clickable in Microsoft Word. Each primary section begins on a new page.")

    # 1 Research questions. No abstract and no background section.
    add_heading(doc, "1 Research Questions", "bm_1", 1)
    doc.add_heading("1.1 Central Research Question", level=2)
    add_body(doc, "When the original DynIn GA implementation and the frozen proposed method are applied to the same dynamical models, can adaptive angular-radial search estimate the local integrity measure more accurately and more consistently in both two and four dimensions, while retaining an acceptable computational cost?")
    doc.add_heading("1.2 Subquestions", level=2)
    for text in [
        "Accuracy: Which method produces lower median and tail error on models with analytical or explicit numerical references?",
        "Stability: How sensitive are the estimates to the random seed, and how often does each method satisfy 1%, 2%, and 5% error thresholds?",
        "Dimensional transfer: Does the adaptive directional concept remain effective when the direction space changes from the circle to the unit hypersphere S3?",
        "Computational cost: How many additional trajectory evaluations are required, and how does the median implementation runtime change?",
        "Reference validity: When a published result is numerical rather than analytical, can an independently validated closer boundary explain disagreement with the published value?",
    ]:
        common.add_number(doc, text)
    doc.add_heading("1.3 Hypotheses", level=2)
    add_table(doc, ["Hypothesis", "Statement", "Outcome"], [
        ["H1", "The proposed method has lower median and P95 error on analytical benchmarks.", "Supported"],
        ["H2", "Local directional refinement plus global coverage reduces seed sensitivity.", "Supported"],
        ["H3", "Four-dimensional accuracy requires more directions and trajectory evaluations.", "Supported"],
        ["H4", "The published Habib 4D estimate may lie above a closer valid boundary.", "Supported by independent validation"],
    ], [1.6, 10.9, 3.0], 9.3, "Table 1. Research hypotheses and outcomes")

    # 2 Concise configuration only, not a complete algorithm chapter.
    add_heading(doc, "2 Method Configuration for the Comparison", "bm_2", 2)
    doc.add_heading("2.1 DynIn Baseline", level=2)
    add_body(doc, "The DynIn baseline strictly uses Habib's original DynIn v1.1.0 implementation. The source functions compute_LIM_FP and find_furthest_point_approximate were not rewritten for this comparison. The setting type_x0 = 1 activates the genetic-algorithm initial-condition selector. Therefore, each next initial condition is returned by the original GA branch and is then passed to the outer trajectory integration and grid-based classification procedure. Model-specific domains, targets, weights, and numerical controls are listed in Appendix A.")
    add_body(doc, "This statement concerns the algorithmic implementation: the DynIn branch is Habib's original GA branch. It does not imply that every model-specific numerical parameter was reported in Habib's paper; parameters required for models not present in the original study were defined explicitly and held fixed before the 30-seed comparison.")

    doc.add_heading("2.2 Proposed Method in Four Dimensions", level=2)
    add_body(doc, "The four-dimensional extension preserves the two-level logic of the two-dimensional method: select a direction first, then locate the target/non-target transition along that direction. Let z_e be the target equilibrium and W the LIM weighting matrix. The algorithm transforms the state displacement to weighted coordinates y = W^(1/2)(z - z_e). In these coordinates, the LIM distance equals the Euclidean radius, d_W(z,z_e) = ||y||_2.")
    add_body(doc, "Every non-zero four-dimensional perturbation can therefore be represented as y = r u, where r is the weighted distance and u belongs to S3, the three-dimensional unit hypersphere embedded in R4. Returning to the physical state gives z(r,u) = z_e + W^(-1/2) r u. Consequently, radii obtained in different directions are directly comparable under the same LIM metric.")
    add_body(doc, "The implementation begins with 24 directions on S3. For each direction, it scans outward to obtain a target inner endpoint and a non-target outer endpoint, and then applies radial bisection. Local candidates are generated in the tangent space around the currently most promising directions. Global candidates are selected by a maximin rule, which chooses a direction that is farthest from the existing direction set. The run stops only after local improvement has plateaued, the minimum angular separation is sufficiently small, and two global validation passes have failed to find a smaller boundary. Sixteen additional audit directions are then evaluated. The version used in this report does not reuse trajectory paths.")
    add_table(doc, ["Element", "Two-dimensional interpretation", "Four-dimensional implementation"], [
        ["Direction space", "Unit circle S1", "Unit hypersphere S3"],
        ["Radial coordinate", "Weighted distance from the target", "Weighted distance from the target"],
        ["Local refinement", "Insert angles near the current minimum", "Generate tangent-space directions near the current minimum"],
        ["Global coverage", "Split the largest angular gap", "Select a maximin direction on S3"],
        ["Termination check", "Plateau plus angular coverage", "Plateau, local angular resolution, global passes, and post-audit"],
    ], [3.0, 5.8, 6.4], 9.0, "Table 2. Geometric extension of the proposed method to four dimensions")

    # 3 Experimental design
    add_heading(doc, "3 Experimental Design", "bm_3", 3)
    doc.add_heading("3.1 Benchmark Models and Reference Values", level=2)
    reference_rows = []
    for row in REFS:
        reference_type = {
            "analytical_branch_evaluated_numerically": "Analytical branch evaluated numerically",
            "published_approximate_numerical": "Published approximate numerical value",
            "exact_analytical_product_basin": "Exact analytical product-basin result",
        }.get(row["reference_kind"], row["reference_kind"])
        reference_rows.append([
            MODEL[row["model_id"]], row["dimension"] + "D",
            f"{row['parameter_name']} = {row['parameter_value']}",
            num(row["R_reference"], 6), reference_type,
        ])
    add_table(doc, ["Model", "Dimension", "Test parameter", "Reference LIM", "Reference type"], reference_rows,
              [5.2, 1.3, 2.5, 2.4, 4.0], 8.7, "Table 3. Benchmark models and reference values")
    add_body(doc, "Reference values were used only for scoring after each run and were not passed to either selection algorithm. The value 0.5737 for the Habib four-dimensional model is a published numerical estimate rather than analytical ground truth; disagreement with it is therefore reported as a difference from the published value, not automatically as numerical error.")

    doc.add_heading("3.2 Paired and Randomized Protocol", level=2)
    for text in [
        "Each model was evaluated with 30 paired seed identifiers for both methods.",
        "The complete experiment contains 6 models × 2 methods × 30 seeds = 360 runs.",
        "The direct two-dimensional runs were executed in randomized order to reduce timing bias caused by execution sequence.",
        "The same seed identifier supports reproducible paired analysis, but it does not imply that different algorithms test identical initial conditions because they consume random numbers differently.",
    ]:
        common.add_bullet(doc, text)

    doc.add_heading("3.3 Fairness of the Comparison", level=2)
    add_body(doc, "For each model, both methods used the same governing equations, target attractor, weighting matrix, model parameters, and evaluation reference. DynIn retained its original GA and grid-classification workflow, while the proposed method retained its radial bracketing, bisection, adaptive directional refinement, and native stopping rules. This is therefore a comparison of complete methods, not a selector-only ablation.")
    add_body(doc, "Trajectory counts were not forced to be identical. Accuracy and computational cost are reported separately. Trajectory evaluations are treated as the primary cost metric, whereas median algorithm runtime is interpreted as a secondary implementation-dependent metric.")

    doc.add_heading("3.4 Evaluation Measures", level=2)
    for text in [
        "Relative absolute error: e_rel = |R_hat - R_ref| / R_ref.",
        "Median error characterizes a typical run; P95 and maximum error characterize unstable tails.",
        "Fractions within 1%, 2%, and 5% quantify reliability at different accuracy thresholds.",
        "Trajectory evaluations are the primary cost measure; median algorithm runtime is secondary.",
        "For four-dimensional proposed runs, the stopping status and post-search audit outcome are also recorded.",
    ]:
        common.add_bullet(doc, text)

    doc.add_heading("3.5 Independent Validation of the Habib 4D Candidate Boundary", level=2)
    add_body(doc, "Because the proposed estimate near 0.538 was lower than the published value 0.5737, candidate directions and target/non-target radial brackets were saved and tested independently. The validation used longer integrations with horizons of 2000, 4000, and 8000, tighter solver tolerances, an expanded domain, and detection of convergence to a non-target periodic attractor. A candidate was accepted only if the inner point returned to the target and the outer point converged to persistent non-target periodic motion.")

    # 4 Results
    add_heading(doc, "4 Experimental Results", "bm_4", 4)
    doc.add_heading("4.1 Integrity Checks", level=2)
    add_body(doc, "All 360 main runs completed successfully. All 60 proposed runs on the two four-dimensional models passed the post-search directional audit. An audit value of zero for two-dimensional and DynIn rows denotes that this field is not applicable, not that the run failed.")

    doc.add_heading("4.2 Two-Dimensional Models", level=2)
    result_rows = []
    for model_id in ["quadratic_cubic", "bistable_duffing", "habib_unforced_duffing", "genda_cosine_quadratic_drag"]:
        for method in ["dynin_original_ga", "proposed_adaptive_angle"]:
            row = summary_row(model_id, method)
            result_rows.append([
                MODEL[model_id], METHOD[method], pct(row["median_relative_error"], 3),
                pct(row["p95_relative_error"], 3), pct(row["within_1_percent_fraction"], 1),
                num(row["median_trajectory_evaluations"], 1), num(row["median_algorithm_runtime_s"], 3),
            ])
    add_table(doc, ["Model", "Method", "Median error", "P95 error", "Within 1%", "Trajectories", "Median time s"],
              result_rows, [4.0, 3.1, 1.9, 1.8, 1.7, 1.7, 1.9], 8.1,
              "Table 4. Results for the four two-dimensional models")
    add_body(doc, "The proposed method achieved a 100% within-1% rate on all four two-dimensional models. The corresponding DynIn rates were 60.0%, 53.3%, 43.3%, and 83.3%. For the three analytical-reference models, the proposed median errors were approximately 0.002% to 0.003%. For the Habib unforced Duffing oscillator, the median difference from the published approximate value 0.7683 was 0.109%.")
    add_body(doc, "In paired comparisons, the proposed method had lower error for all 30 seeds in the quadratic-cubic, bistable Duffing, and cosine models, and for 27 of 30 seeds in the Habib unforced Duffing model. The improvement therefore affected both the median and the error tail rather than only the average result.")
    add_figure(doc, ASSETS / "median_error_comparison_en.png",
               "Figure 1. Median relative error for five models with analytical or explicit numerical references. The Habib 4D model is excluded because its published value is not ground truth.")

    doc.add_heading("4.3 Separable Four-Dimensional Analytical Benchmark", level=2)
    dyn = summary_row("separable_qc_bd_4d", "dynin_original_ga")
    pro = summary_row("separable_qc_bd_4d", "proposed_adaptive_angle")
    add_body(doc, f"The exact analytical LIM is 0.647480. DynIn produced a median estimate of {float(dyn['median_R_hat']):.6f}, a median relative error of {pct(dyn['median_relative_error'],3)}, a P95 error of {pct(dyn['p95_relative_error'],3)}, and a 0% within-1% rate. The proposed method produced a median estimate of {float(pro['median_R_hat']):.6f}, a median error of {pct(pro['median_relative_error'],3)}, a P95 error of {pct(pro['p95_relative_error'],3)}, and a 100% within-1% rate.")
    add_body(doc, "This model provides the strongest quantitative evidence for the four-dimensional extension because the reference follows from an exact product-basin relation rather than from another numerical algorithm. The proposed method was more accurate for all 30 paired seeds and faster for 29 of 30 seeds in the present implementation.")

    doc.add_heading("4.4 Habib Four-Dimensional Model", level=2)
    dyn = summary_row("habib_vdp_tmd_4d", "dynin_original_ga")
    pro = summary_row("habib_vdp_tmd_4d", "proposed_adaptive_angle")
    add_body(doc, f"DynIn produced a median estimate of {float(dyn['median_R_hat']):.6f}, close to the published numerical value 0.5737. The proposed method produced a median estimate of {float(pro['median_R_hat']):.6f}, with the 30 estimates concentrated between approximately 0.537 and 0.544. If 0.5737 were treated mechanically as ground truth, the proposed median difference would be {pct(pro['median_relative_error'],2)}; however, this quantity is not a valid accuracy error because the reference is not analytical.")
    validation_rows = []
    for row in VALID:
        validation_rows.append([
            row["seed"], num(row["bracket_lower"], 6), num(row["bracket_upper"], 6),
            "Target", "Non-target periodic", "Validated sharp boundary",
        ])
    add_table(doc, ["Seed", "Inner radius", "Outer radius", "Inner label", "Outer label", "Verdict"],
              validation_rows, [1.2, 2.3, 2.3, 2.4, 3.5, 3.5], 9.0,
              "Table 5. Independent validation of the Habib 4D candidate boundaries")
    add_body(doc, "All three validation directions showed the same transition: the inner point returned to the target attractor, whereas the outer point and the point at the published radius converged to a stable non-target periodic attractor. The smallest independently validated outer endpoint was 0.537497, which supports the bound LIM ≤ 0.537497 under the present distance definition. The proposed 30-seed median of 0.537950 lies close to this verified boundary.")
    add_figure(doc, ASSETS / "habib4d_validation_en.png",
               "Figure 2. Independently validated radial boundary intervals for the Habib 4D model and the published numerical value 0.5737.")

    doc.add_heading("4.5 Computational Cost and Termination", level=2)
    cost_rows = []
    for row in PAIRED:
        cost_rows.append([
            MODEL[row["model_id"]], num(row["median_evaluation_ratio"], 3) + "×",
            num(row["median_runtime_ratio"], 3) + "×", pct(row["proposed_better_error_fraction"], 1),
            pct(row["proposed_faster_fraction"], 1),
        ])
    add_table(doc, ["Model", "Trajectory ratio", "Median time ratio", "Proposed more accurate", "Proposed faster"],
              cost_rows, [5.1, 2.5, 2.6, 2.8, 2.6], 8.6,
              "Table 6. Paired cost ratios and win fractions for Proposed relative to DynIn")
    add_body(doc, "In two dimensions, the proposed method used approximately 1.135 to 1.75 times as many trajectory evaluations but was substantially faster in the current implementation. In the separable 4D benchmark, the trajectory ratio was 3.315, while the proposed method remained faster for 29 of 30 seeds. In the Habib 4D model, the trajectory ratio was 7.525 and the median runtime ratio was 3.814, demonstrating a clear accuracy-cost trade-off.")
    add_body(doc, "Runtime is not a pure measure of algorithmic complexity because the methods use different data structures, classifiers, and code paths. Trajectory evaluations should therefore be the primary cost measure. A small number of four-dimensional proposed runs reached a direction or wall-time limit, although all of them still passed the post-search audit. Median, tail runtime, and termination status should be reported together.")
    add_figure(doc, ASSETS / "cost_ratios_en.png",
               "Figure 3. Trajectory-evaluation and median-runtime ratios of the proposed method relative to DynIn. A value above one indicates higher cost.")

    # 5 Discussion
    add_heading(doc, "5 Discussion", "bm_5", 5)
    doc.add_heading("5.1 Answer to the Central Question", level=2)
    add_body(doc, "Within the tested two- and four-dimensional systems, adaptive angular-radial search located the nearest known boundary more accurately and with lower seed-to-seed variation. The improvement is directly verifiable for the analytical two-dimensional models and the separable four-dimensional benchmark. For the Habib 4D model, independent trajectory validation shows that the lower result is a real target-to-periodic-attractor boundary rather than a numerical classification artefact.")
    doc.add_heading("5.2 Interpretation of the Accuracy Gain", level=2)
    add_body(doc, "The proposed method explicitly compares critical radii across directions. Radial bisection improves the boundary estimate in every evaluated direction, local directional refinement concentrates effort near the current minimum, and global maximin insertions reduce the risk of missing a remote dangerous direction. The consistently lower P95 errors and higher threshold-success rates are compatible with this mechanism.")
    doc.add_heading("5.3 Accuracy-Cost Trade-off", level=2)
    add_body(doc, "The direction geometry is inexpensive to cover in two dimensions but substantially more demanding on S3. The four-dimensional method must spend queries on both local tangent-space refinement and global coverage verification. The separable benchmark shows that the additional cost can still be efficient, whereas the Habib 4D model shows that slow trajectories and a more complex boundary can make the proposed search more expensive than DynIn.")
    doc.add_heading("5.4 Limitations", level=2)
    for text in [
        "Only two four-dimensional models were tested; the results do not establish dimension-independent superiority.",
        "The Habib 4D model has no analytical LIM. Independent validation proves the existence of a closer boundary but does not prove that the smallest value among all 30 runs is the global LIM.",
        "The comparison preserves method-native classification and stopping rules, so it does not isolate the causal contribution of the point-selection rule alone.",
        "Runtime is affected by MATLAB implementation details and rare slow trajectories; trajectory counts and paired runtime distributions must be interpreted together.",
        "The four-dimensional directional and stopping parameters remain empirically frozen and require validation on additional high-dimensional models.",
    ]:
        common.add_bullet(doc, text)

    # 6 Conclusions
    add_heading(doc, "6 Conclusions", "bm_6", 6)
    add_body(doc, "The principal result is not that the proposed method is universally faster, but that it directs computational effort more explicitly toward the nearest basin boundary. Across the four two-dimensional models, its within-1% rate was 100% and its median and P95 differences from the references were substantially lower than those of the original DynIn GA. In the separable 4D analytical benchmark, it reduced the median relative error from 7.278% to 0.072%, demonstrating that the adaptive directional concept can be transferred from S1 to S3.")
    add_body(doc, "The Habib 4D result requires a different interpretation. The proposed estimate does not fail merely because it differs from 0.5737. Independent validation confirmed a sharp target-to-non-target-periodic boundary near 0.5375, which gives a tighter numerical upper bound on the LIM than the published estimate. This improved boundary discovery required substantially more trajectory evaluations and longer runtime.")
    add_body(doc, "The present evidence supports retaining the adaptive angular-radial method as the proposed method. Future work should reduce the number of required directions, reuse information collected along each trajectory, improve classification of slowly converging trajectories, and evaluate the stopping rule on additional high-dimensional systems with analytical or independently verifiable boundaries.")

    # Appendix A
    add_heading(doc, "Appendix A DynIn Configuration Summary", "bm_a", 7)
    config_rows = []
    for row in CONFIGS:
        config_rows.append([
            MODEL.get(row["model_id"], row["model_id"]), row["discr"], row["target_cells"],
            row["tfinal"], row["Ts"], row["number_of_steps"],
        ])
    add_table(doc, ["Model", "Grid N", "Target cells", "tfinal", "Ts", "Trajectory budget"],
              config_rows, [6.0, 1.6, 2.1, 1.8, 1.5, 2.3], 8.6,
              "Table A1. Model-specific DynIn settings")
    add_body(doc, "All DynIn runs used type_x0 = 1. The common GA parameters were divR = 40, num_gen = 5, num_crossover = 9, selected_opt = 3, newcomers = 8, and num_almost_clones = 2. The Habib 4D model used a trajectory budget of 40; all other models used 100.")

    # Appendix B
    add_heading(doc, "Appendix B Reproducibility Files", "bm_b", 8)
    add_body(doc, "The experiment package contains the following files. Only filenames are listed so that the report is not tied to one computer's absolute directory structure.")
    for text in [
        "raw_data_all_runs.csv: all 360 individual runs.",
        "summary_by_model_and_method.csv: aggregated error, success-rate, and cost measures.",
        "paired_contrasts_proposed_vs_dynin.csv: paired seed-level accuracy and cost ratios.",
        "benchmark_references.csv: model parameters, reference LIM values, reference types, and sources.",
        "dynin_configurations.csv: model-specific DynIn settings.",
        "candidate_coordinates_and_verdicts.csv: Habib 4D candidate coordinates, validation brackets, and verdicts.",
    ]:
        common.add_bullet(doc, text)
    add_body(doc, "Any figure or table involving the Habib 4D value 0.5737 should describe the quantity as a difference from the published numerical estimate rather than as ground-truth error, and should be interpreted together with the independent validation results.")

    doc.save(OUT)
    force_times_new_roman(OUT)
    print(OUT)


if __name__ == "__main__":
    build()
