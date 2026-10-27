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

import csv
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_ALIGN_VERTICAL, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "outputs_six_model_20260926_023259_094"
VALIDATION = ROOT / "outputs_habib_4d_candidate_validation_20260926_022536_699"
OUT = ROOT / "DynIn与自适应角度方法六模型对比实验中文报告.docx"
ASSETS = ROOT / "report_assets_cn"
ASSETS.mkdir(exist_ok=True)


def read_csv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


SUMMARY = read_csv(RESULTS / "summary_by_model_and_method.csv")
PAIRED = read_csv(RESULTS / "paired_contrasts_proposed_vs_dynin.csv")
REFS = read_csv(RESULTS / "benchmark_references.csv")
CONFIGS = read_csv(RESULTS / "dynin_configurations.csv")
RAW = read_csv(RESULTS / "raw_data_all_runs.csv")
VALID = read_csv(VALIDATION / "candidate_coordinates_and_verdicts.csv")


MODEL_CN = {
    "quadratic_cubic": "Quadratic cubic 势系统",
    "bistable_duffing": "双稳态 Duffing 势系统",
    "habib_unforced_duffing": "Habib 无外激励 Duffing 振子",
    "genda_cosine_quadratic_drag": "余弦势二次阻力系统",
    "habib_vdp_tmd_4d": "Habib 四维 Duffing van der Pol 与 NLTVA 模型",
    "separable_qc_bd_4d": "可分离四维 QC 与双稳态 Duffing 模型",
}

METHOD_CN = {
    "dynin_original_ga": "DynIn 原始 GA",
    "proposed_adaptive_angle": "自适应角度径向方法",
}


def fnum(v, digits=3):
    x = float(v)
    return f"{x:.{digits}f}"


def pct(v, digits=2):
    return f"{100 * float(v):.{digits}f}%"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=100, start=110, bottom=100, end=110):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, val in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(val))
        node.set(qn("w:type"), "dxa")


def set_table_borders(table, color="D9D9D9", size="6"):
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.find(qn("w:tblBorders"))
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = qn(f"w:{edge}")
        node = borders.find(tag)
        if node is None:
            node = OxmlElement(f"w:{edge}")
            borders.append(node)
        node.set(qn("w:val"), "single")
        node.set(qn("w:sz"), size)
        node.set(qn("w:space"), "0")
        node.set(qn("w:color"), color)


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def set_repeat_table_header(row):
    trPr = row._tr.get_or_add_trPr()
    tblHeader = OxmlElement("w:tblHeader")
    tblHeader.set(qn("w:val"), "true")
    trPr.append(tblHeader)


def set_col_widths(table, widths_cm):
    for row in table.rows:
        for idx, width in enumerate(widths_cm):
            if idx < len(row.cells):
                row.cells[idx].width = Cm(width)


def style_table(table, widths=None, font_size=9.0):
    table.autofit = False
    table.alignment = 1
    set_table_borders(table)
    set_repeat_table_header(table.rows[0])
    if widths:
        set_col_widths(table, widths)
    for ridx, row in enumerate(table.rows):
        for cidx, cell in enumerate(row.cells):
            set_cell_margins(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            if ridx == 0:
                set_cell_shading(cell, "404040")
            elif ridx % 2 == 0:
                set_cell_shading(cell, "F3F3F3")
            for p in cell.paragraphs:
                p.paragraph_format.space_after = Pt(0)
                p.paragraph_format.line_spacing = 1.08
                if cidx > 0:
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                for run in p.runs:
                    run.font.name = "Arial"
                    run._element.rPr.rFonts.set(qn("w:eastAsia"), "等线")
                    run.font.size = Pt(font_size)
                    if ridx == 0:
                        run.font.color.rgb = RGBColor(255, 255, 255)
                        run.font.bold = True


def add_table(doc, headers, rows, widths=None, font_size=9.0, caption=None):
    if caption:
        p = doc.add_paragraph(style="Caption")
        p.add_run(caption)
    table = doc.add_table(rows=1, cols=len(headers))
    for i, h in enumerate(headers):
        table.rows[0].cells[i].text = str(h)
    for row_data in rows:
        cells = table.add_row().cells
        for i, val in enumerate(row_data):
            cells[i].text = str(val)
    style_table(table, widths, font_size)
    doc.add_paragraph().paragraph_format.space_after = Pt(0)
    return table


def set_run_font(run, east="等线", latin="Arial", size=None, bold=None, color=None):
    run.font.name = latin
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), east)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if color is not None:
        run.font.color.rgb = RGBColor(*color)


def add_body(doc, text, bold_lead=None):
    p = doc.add_paragraph(style="Body Text")
    if bold_lead and text.startswith(bold_lead):
        r = p.add_run(bold_lead)
        r.bold = True
        p.add_run(text[len(bold_lead):])
    else:
        p.add_run(text)
    return p


def add_bullet(doc, text, level=0):
    style = "List Bullet" if level == 0 else "List Bullet 2"
    p = doc.add_paragraph(text, style=style)
    p.paragraph_format.space_after = Pt(3)
    return p


def add_number(doc, text, level=0):
    style = "List Number" if level == 0 else "List Number 2"
    p = doc.add_paragraph(text, style=style)
    p.paragraph_format.space_after = Pt(4)
    return p


def add_code(doc, code):
    for line in code.strip("\n").splitlines():
        p = doc.add_paragraph(style="Code Block")
        p.add_run(line)


def add_page_number(section):
    footer = section.footer
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = " PAGE "
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.append(fld_char1)
    run._r.append(instr_text)
    run._r.append(fld_char2)
    set_run_font(run, size=9, color=(100, 100, 100))


def add_bookmark(paragraph, name, bookmark_id):
    start = OxmlElement("w:bookmarkStart")
    start.set(qn("w:id"), str(bookmark_id))
    start.set(qn("w:name"), name)
    end = OxmlElement("w:bookmarkEnd")
    end.set(qn("w:id"), str(bookmark_id))
    paragraph._p.insert(0, start)
    paragraph._p.append(end)


def add_internal_link(paragraph, text, anchor):
    hyperlink = OxmlElement("w:hyperlink")
    hyperlink.set(qn("w:anchor"), anchor)
    hyperlink.set(qn("w:history"), "1")
    run = OxmlElement("w:r")
    rpr = OxmlElement("w:rPr")
    color = OxmlElement("w:color")
    color.set(qn("w:val"), "000000")
    rpr.append(color)
    run.append(rpr)
    text_node = OxmlElement("w:t")
    text_node.text = text
    run.append(text_node)
    hyperlink.append(run)
    paragraph._p.append(hyperlink)


def add_heading_new_page(doc, text, level=1, bookmark=None, bookmark_id=None):
    if level == 1:
        doc.add_page_break()
    p = doc.add_heading(text, level=level)
    if bookmark:
        add_bookmark(p, bookmark, bookmark_id)
    return p


def make_figures():
    font_path = Path("C:/Windows/Fonts/msyh.ttc")
    bold_path = Path("C:/Windows/Fonts/msyhbd.ttc")
    def font(size, bold=False):
        path = bold_path if bold and bold_path.exists() else font_path
        return ImageFont.truetype(str(path), size=size) if path.exists() else ImageFont.load_default()

    def base_canvas(title):
        im = Image.new("RGB", (1500, 720), "white")
        dr = ImageDraw.Draw(im)
        dr.text((70, 38), title, fill="#111111", font=font(34, True))
        return im, dr

    def draw_axes(dr, left, top, right, bottom, y_ticks, y_map, y_label):
        dr.line((left, top, left, bottom), fill="#333333", width=2)
        dr.line((left, bottom, right, bottom), fill="#333333", width=2)
        for val, label in y_ticks:
            y = y_map(val)
            dr.line((left, y, right, y), fill="#DDDDDD", width=1)
            dr.text((left - 18, y), label, anchor="rm", fill="#333333", font=font(22))
        if y_label:
            dr.text((left, top - 18), y_label, anchor="ls", fill="#333333", font=font(20))

    ordered = [r["model_id"] for r in REFS]
    labels = ["QC", "双稳态 Duffing", "Habib Duffing", "余弦势", "可分离 4D"]
    benchmark_ids = [m for m in ordered if m != "habib_vdp_tmd_4d"]
    dyn = []
    pro = []
    for mid in benchmark_ids:
        dyn.append(100 * float(next(r for r in SUMMARY if r["model_id"] == mid and r["method"] == "dynin_original_ga")["median_relative_error"]))
        pro.append(100 * float(next(r for r in SUMMARY if r["model_id"] == mid and r["method"] == "proposed_adaptive_angle")["median_relative_error"]))
    im, dr = base_canvas("具有解析或明确数值参考的五个模型")
    left, top, right, bottom = 150, 135, 1450, 600
    log_min, log_max = -3.0, 1.2
    y_map = lambda v: bottom - (math.log10(max(v, 10 ** log_min)) - log_min) / (log_max - log_min) * (bottom - top)
    ticks = [(0.001, "0.001"), (0.01, "0.01"), (0.1, "0.1"), (1, "1"), (10, "10")]
    draw_axes(dr, left, top, right, bottom, ticks, y_map, "中位相对误差 %  对数刻度")
    group_w = (right - left) / len(labels)
    bar_w = 44
    for i, label in enumerate(labels):
        cx = left + group_w * (i + 0.5)
        for offset, value, color in [(-28, dyn[i], "#6B7280"), (28, pro[i], "#0F766E")]:
            x0, x1 = cx + offset - bar_w / 2, cx + offset + bar_w / 2
            y = y_map(value)
            dr.rectangle((x0, y, x1, bottom), fill=color)
        dr.text((cx, bottom + 28), label, anchor="ma", fill="#222222", font=font(20))
    dr.rectangle((760, 75, 795, 95), fill="#6B7280")
    dr.text((808, 85), "DynIn 原始 GA", anchor="lm", fill="#222222", font=font(21))
    dr.rectangle((1060, 75, 1095, 95), fill="#0F766E")
    dr.text((1108, 85), "自适应角度径向方法", anchor="lm", fill="#222222", font=font(21))
    im.save(ASSETS / "median_error_comparison.png", dpi=(220, 220))

    all_labels = ["QC", "双稳态", "Habib 2D", "余弦势", "Habib 4D", "可分离 4D"]
    eval_ratio = [float(r["median_evaluation_ratio"]) for r in PAIRED]
    runtime_ratio = [float(r["median_runtime_ratio"]) for r in PAIRED]
    im, dr = base_canvas("Proposed 相对 DynIn 的计算成本")
    panels = [(80, 140, 730, 600, eval_ratio, "轨迹评估次数比值", "#0F766E", 8.0),
              (820, 140, 1470, 600, runtime_ratio, "中位算法时间比值", "#4B5563", 4.2)]
    for left, top, right, bottom, values, title, color, ymax in panels:
        dr.text(((left + right) / 2, 105), title, anchor="mm", fill="#111111", font=font(25, True))
        y_map = lambda v, t=top, b=bottom, m=ymax: b - v / m * (b - t)
        ticks = [(v, f"{v:g}") for v in np_range(0, ymax, 1 if ymax < 5 else 2)]
        draw_axes(dr, left, top, right, bottom, ticks, y_map, "")
        dr.line((left, y_map(1), right, y_map(1)), fill="#111111", width=2)
        gw = (right - left) / 6
        for i, value in enumerate(values):
            cx = left + gw * (i + 0.5)
            dr.rectangle((cx - 25, y_map(value), cx + 25, bottom), fill=color)
            dr.text((cx, bottom + 25), all_labels[i], anchor="ma", fill="#222222", font=font(17))
    im.save(ASSETS / "cost_ratios.png", dpi=(220, 220))

    im, dr = base_canvas("Habib 四维模型的独立轨迹验证")
    left, top, right, bottom = 170, 160, 1430, 575
    xmin, xmax = 0.532, 0.578
    x_map = lambda v: left + (v - xmin) / (xmax - xmin) * (right - left)
    dr.line((left, bottom, right, bottom), fill="#333333", width=2)
    for val in [0.535, 0.545, 0.555, 0.565, 0.575]:
        x = x_map(val)
        dr.line((x, top, x, bottom), fill="#E5E7EB", width=1)
        dr.text((x, bottom + 22), f"{val:.3f}", anchor="ma", fill="#333333", font=font(21))
    dr.text(((left + right) / 2, 650), "加权距离 R", anchor="mm", fill="#333333", font=font(23))
    for i, r in enumerate(VALID):
        y = top + 75 + i * 110
        lo, hi = float(r["bracket_lower"]), float(r["bracket_upper"])
        dr.text((left - 25, y), f"seed {r['seed']}", anchor="rm", fill="#222222", font=font(22))
        dr.line((x_map(lo), y, x_map(hi), y), fill="#0F766E", width=8)
        dr.ellipse((x_map((lo + hi) / 2) - 8, y - 8, x_map((lo + hi) / 2) + 8, y + 8), fill="#0F766E")
    xp = x_map(0.5737)
    for y in range(top, bottom, 16):
        dr.line((xp, y, xp, min(y + 8, bottom)), fill="#B45309", width=3)
    dr.text((xp - 8, top - 20), "论文数值 0.5737", anchor="rs", fill="#B45309", font=font(22, True))
    im.save(ASSETS / "habib4d_validation.png", dpi=(220, 220))


def np_range(start, stop, step):
    values = []
    x = start
    while x <= stop + 1e-9:
        values.append(round(x, 10))
        x += step
    return values


def add_figure(doc, path, caption, width=6.8):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(path), width=Inches(width))
    cp = doc.add_paragraph(style="Caption")
    cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cp.add_run(caption)


def configure_document(doc):
    sec = doc.sections[0]
    sec.page_width = Inches(8.5)
    sec.page_height = Inches(11)
    sec.top_margin = Inches(0.78)
    sec.bottom_margin = Inches(0.72)
    sec.left_margin = Inches(0.82)
    sec.right_margin = Inches(0.82)
    sec.header_distance = Inches(0.32)
    sec.footer_distance = Inches(0.35)
    add_page_number(sec)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Arial"
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "等线")
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = RGBColor(0, 0, 0)
    normal.paragraph_format.line_spacing = 1.35
    normal.paragraph_format.space_after = Pt(5)

    body = styles["Body Text"]
    body.font.name = "Arial"
    body._element.rPr.rFonts.set(qn("w:eastAsia"), "等线")
    body.font.size = Pt(10.5)
    body.font.color.rgb = RGBColor(0, 0, 0)
    body.paragraph_format.line_spacing = 1.35
    body.paragraph_format.space_after = Pt(6)
    body.paragraph_format.first_line_indent = Cm(0.74)

    title = styles["Title"]
    title.font.name = "Arial"
    title._element.rPr.rFonts.set(qn("w:eastAsia"), "等线")
    title.font.size = Pt(24)
    title.font.bold = True
    title.font.color.rgb = RGBColor(0, 0, 0)
    title.paragraph_format.space_after = Pt(14)

    for style_name, size, before, after in [
        ("Heading 1", 16, 0, 12),
        ("Heading 2", 13, 12, 7),
        ("Heading 3", 11.5, 9, 5),
    ]:
        st = styles[style_name]
        st.font.name = "Arial"
        st._element.rPr.rFonts.set(qn("w:eastAsia"), "等线")
        st.font.size = Pt(size)
        st.font.bold = True
        st.font.color.rgb = RGBColor(0, 0, 0)
        st.paragraph_format.space_before = Pt(before)
        st.paragraph_format.space_after = Pt(after)
        st.paragraph_format.keep_with_next = True

    cap = styles["Caption"]
    cap.font.name = "Arial"
    cap._element.rPr.rFonts.set(qn("w:eastAsia"), "等线")
    cap.font.size = Pt(9)
    cap.font.color.rgb = RGBColor(70, 70, 70)
    cap.paragraph_format.space_before = Pt(5)
    cap.paragraph_format.space_after = Pt(6)

    if "Code Block" not in styles:
        code = styles.add_style("Code Block", WD_STYLE_TYPE.PARAGRAPH)
    else:
        code = styles["Code Block"]
    code.font.name = "Consolas"
    code._element.rPr.rFonts.set(qn("w:eastAsia"), "等线")
    code.font.size = Pt(8.5)
    code.paragraph_format.left_indent = Cm(0.55)
    code.paragraph_format.right_indent = Cm(0.35)
    code.paragraph_format.space_after = Pt(0)
    code.paragraph_format.line_spacing = 1.05

    for list_name in ("List Bullet", "List Bullet 2", "List Number", "List Number 2"):
        st = styles[list_name]
        st.font.name = "Arial"
        st._element.rPr.rFonts.set(qn("w:eastAsia"), "等线")
        st.font.size = Pt(10.5)
        st.paragraph_format.line_spacing = 1.25


def summary_row(model_id, method):
    return next(r for r in SUMMARY if r["model_id"] == model_id and r["method"] == method)


def build():
    make_figures()
    doc = Document()
    configure_document(doc)

    # Cover
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(90)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("DynIn 原始 GA 与自适应角度径向方法\n六模型对比实验报告")
    set_run_font(r, size=24, bold=True)
    p.style = doc.styles["Title"]
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("四个二维模型与两个四维模型的准确性 稳定性和计算成本比较")
    set_run_font(r, size=13, color=(60, 60, 60))
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(32)
    add_table(doc, ["项目", "内容"], [
        ["比较方法", "DynIn 原始 GA 选点 与 Proposed 自适应角度径向搜索"],
        ["实验规模", "6 个模型 × 2 种方法 × 30 个配对 seed，共 360 次运行"],
        ["研究重点", "LIM 估计误差、跨 seed 稳定性、轨迹评估成本、四维边界可信度"],
        ["报告版本", "中文结果报告  2026 年 9 月"],
    ], widths=[3.0, 12.5], font_size=10)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(28)
    r = p.add_run("核心结论")
    set_run_font(r, size=12, bold=True)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("在具有解析或明确数值参考的五个模型上，自适应角度径向方法显著提高了 LIM 估计精度。\n在 Habib 四维模型上，该方法发现了约 0.538 的更近边界，且独立长时间积分确认其外侧轨迹收敛到非目标周期吸引子。")
    set_run_font(r, size=11)

    # TOC
    doc.add_page_break()
    doc.add_heading("目录", level=1)
    toc_entries = [
        ("摘要", "bm_abstract"),
        ("1 研究背景与中心问题", "bm_1"),
        ("2 两种方法的核心算法", "bm_2"),
        ("3 实验设计", "bm_3"),
        ("4 实验结果", "bm_4"),
        ("5 讨论", "bm_5"),
        ("6 结论", "bm_6"),
        ("附录 A DynIn 配置摘要", "bm_a"),
        ("附录 B 结果文件与复现信息", "bm_b"),
    ]
    for label, anchor in toc_entries:
        p = doc.add_paragraph(style="Body Text")
        p.paragraph_format.first_line_indent = Cm(0)
        p.paragraph_format.space_after = Pt(7)
        add_internal_link(p, label, anchor)
    add_body(doc, "说明：在 Word 中点击目录条目即可跳转；正文一级章节均从新页开始，便于快速定位。")

    # Abstract
    add_heading_new_page(doc, "摘要", 1, "bm_abstract", 1)
    add_body(doc, "本报告比较 Habib 的 DynIn 原始遗传算法选点方法与本文提出的自适应角度径向搜索方法。中心问题是：在保持模型定义、目标吸引子和距离度量一致的条件下，自适应方向搜索能否在二维和四维动力系统中，以可接受的计算成本，更准确、更稳定地估计局部完整性度量 LIM。")
    add_body(doc, "实验包含四个二维模型和两个四维模型，每个模型对两种方法使用 30 个配对随机种子，共完成 360 次运行。对具有解析解或明确数值参考的五个模型，报告中位相对误差、95 分位误差、1%、2% 和 5% 达标率、轨迹评估次数与中位算法时间。对于 Habib 四维 Duffing van der Pol 与 NLTVA 模型，论文给出的 0.5737 仅是已发表数值估计，因此另用更长积分时间和更严格容差验证 Proposed 找到的候选边界。")
    add_body(doc, "结果表明，Proposed 方法在四个二维模型和可分离四维解析 benchmark 上均显著降低误差，并在这些模型上实现 100% 的 1% 误差达标率。Habib 四维模型中，Proposed 的中位估计为 0.53795；三个独立方向的验证均出现清晰的 target 与 non target periodic 分界，说明 0.5737 不能作为严格真值。四维精度提升伴随更多轨迹评估，并存在少量达到方向上限或墙钟时间上限的运行，因此当前证据支持该方法在测试模型中的有效性，但尚不足以声称其对任意高维系统都占优。")
    p = doc.add_paragraph()
    p.add_run("关键词：").bold = True
    p.add_run("局部完整性度量；DynIn；遗传算法；自适应角度；径向二分；高维动力系统")

    # 1
    add_heading_new_page(doc, "1 研究背景与中心问题", 1, "bm_1", 2)
    doc.add_heading("1.1 研究背景", level=2)
    add_body(doc, "局部完整性度量 LIM 描述目标吸引子到其吸引域边界的最小加权距离。它回答的不是整个吸引域有多大，而是系统从目标状态出发，最小多大的有限扰动可能使轨迹离开目标吸引子。数值算法的关键因此不是均匀重建完整吸引域，而是尽快找到距离目标最近的真实边界。")
    add_body(doc, "DynIn 使用轨迹积分、网格标记和遗传算法选择新的初始条件。Proposed 方法则把边界搜索写成方向与半径两个层次：先在多个方向上寻找径向临界距离，再把新的方向集中到当前最危险的局部区域，同时保留全局覆盖。二维问题中的方向位于圆周，四维问题中的方向位于三维单位球面 S3。")
    doc.add_heading("1.2 中心研究问题", level=2)
    add_body(doc, "在保持原始 DynIn GA 实现和 Proposed 已冻结选点逻辑的前提下，自适应角度径向搜索能否在二维与四维动力系统中，以可接受的计算成本，更准确且更稳定地估计 LIM？", bold_lead="在保持原始 DynIn GA 实现和 Proposed 已冻结选点逻辑的前提下")
    doc.add_heading("1.3 小问题", level=2)
    add_number(doc, "准确性：在有解析或明确参考值的模型上，哪种方法的中位误差和尾部误差更小？")
    add_number(doc, "稳定性：30 个随机种子下，结果是否集中，1%、2% 和 5% 误差达标率是否稳定？")
    add_number(doc, "维度迁移：二维角度径向思想推广到四维方向空间后，是否仍能找到更近边界？")
    add_number(doc, "计算成本：精度提升需要增加多少轨迹评估，实际中位运行时间如何变化？")
    add_number(doc, "参考值可信度：当已发表结果只是数值估计而不是解析真值时，如何判断 Proposed 找到的更小 LIM 是算法错误还是新边界？")
    doc.add_heading("1.4 实验假设", level=2)
    add_table(doc, ["假设", "内容", "最终判断"], [
        ["H1", "在解析 benchmark 上，Proposed 的中位误差和 P95 误差低于 DynIn。", "支持"],
        ["H2", "自适应局部加密与全局补点能降低随机种子敏感性。", "支持"],
        ["H3", "四维精度提升需要更多方向和轨迹评估。", "支持"],
        ["H4", "Habib 四维模型的论文数值可能高于真实最近边界。", "独立验证支持"],
    ], widths=[1.2, 11.6, 2.6], font_size=9.5, caption="表 1 研究假设及验证状态")

    # 2
    add_heading_new_page(doc, "2 两种方法的核心算法", 1, "bm_2", 3)
    doc.add_heading("2.1 共同目标与距离定义", level=2)
    add_body(doc, "两种方法都估计同一个量：从目标吸引子到吸引域边界的最小加权距离。对于状态 z 和目标平衡点 z_e，加权距离写作 d_W(z,z_e) = sqrt((z-z_e)^T W (z-z_e))。算法只决定从哪里发起轨迹积分；轨迹是否返回目标吸引子，仍由模型动力学和分类规则决定。")
    doc.add_heading("2.2 DynIn 原始 GA 的工作机制", level=2)
    add_number(doc, "建立计算域和网格，并把目标平衡点附近单元标记为 target。")
    add_number(doc, "在当前搜索球内生成 GA 种群。每个个体是一组候选初始状态坐标。")
    add_number(doc, "以候选点到已存储点集 Q 的最小加权距离作为适应度。距离越大，表示该候选点位于当前样本之间较大的未探索空隙。")
    add_number(doc, "通过保留优良个体、交叉、新加入随机个体和近似克隆产生下一代，经过 num gen 代后输出最高适应度候选点。")
    add_number(doc, "从该点进行完整轨迹积分，记录访问网格与 target 或 non target 分类，再进入下一轮。")
    add_body(doc, "DynIn 主循环中真正连接 GA 与外层积分的核心调用如下。GA 输出的新点 OutL.x0(i1+1,:) 直接成为下一条完整轨迹的初始条件。")
    add_code(doc, """
[OutL.x0(i1+1,:), OutL.distance(i1+1)] = ...
    find_furthest_point_approximate( ...
        OutL.xe, OutL.R(i1+1), visited_points, dim, weight, ...
        num_gen, num_crossover, selected_opt, ...
        newcomers, num_almost_clones);
""")
    add_body(doc, "因此，DynIn 中 GA 的职责是选择下一条轨迹从哪里出发；网格的职责是保存轨迹已经提供的分类信息，并帮助后续判断与停止。")

    doc.add_heading("2.3 Proposed 二维自适应角度径向搜索", level=2)
    add_number(doc, "初始方向扫描：以目标平衡点为中心，先设置 16 个均匀方向。")
    add_number(doc, "径向括界：沿每个方向由近到远测试，直到得到一个 target 内端点和一个 non target 外端点。")
    add_number(doc, "径向二分：在安全与非安全端点之间反复测试中点，得到该方向的临界距离。")
    add_number(doc, "局部加密：在当前最小临界距离附近插入新方向，以更细角度寻找最危险方向。")
    add_number(doc, "全局补点：在尚未充分覆盖的最大角度空隙中插入方向，防止局部最小值误导搜索。")
    add_number(doc, "停止：最优 LIM 连续多轮变化很小，且局部与全局覆盖条件均满足后结束。")
    add_code(doc, """
for u in initial_directions
    bracket = radial_scan(u);
    R(u) = radial_bisection(bracket);
end
while budget_remains
    u_local  = refine_near_current_minimum();
    u_global = split_largest_uncovered_gap();
    evaluate_and_update(u_local, u_global);
end
""")

    doc.add_heading("2.4 Proposed 四维自适应方向搜索", level=2)
    add_body(doc, "四维状态中没有单一平面角度。算法先在加权坐标中把搜索方向归一化到三维单位球面 S3，再沿每个方向执行同样的径向括界和二分。初始使用 24 个方向；局部加密通过当前优秀方向的切空间候选实现；全局补点选择与已有方向集合最远的 maximin 方向。")
    add_number(doc, "局部停止条件：候选方向与已测试方向的最小角距离低于约 1 度，并且最优半径连续若干轮不再显著改善。")
    add_number(doc, "全局停止条件：完成额外的全局 maximin 验证轮次，确认未覆盖区域没有给出更小边界。")
    add_number(doc, "完整性审计：停止后再测试 16 个额外方向；只有审计没有发现更小值时，audit pass 才为真。")
    add_body(doc, "本次对比使用的是自适应角度版本，不包含路径复用。每一次候选测试都按该方法的分类器独立执行轨迹积分。")

    doc.add_heading("2.5 两种方法的本质区别", level=2)
    add_table(doc, ["比较项", "DynIn 原始 GA", "自适应角度径向方法"], [
        ["搜索对象", "状态空间中的候选初始点", "方向空间加各方向临界半径"],
        ["下一点依据", "远离已存储点集的最大空隙", "局部最危险方向与全局覆盖共同决定"],
        ["边界细化", "通过后续 GA 采样间接逼近", "对 target 与 non target 区间直接径向二分"],
        ["二维几何", "计算域网格与搜索球", "圆周方向与径向距离"],
        ["四维几何", "四维网格访问与 GA 种群", "S3 方向覆盖与径向距离"],
        ["主要成本来源", "GA 迭代和外层完整积分", "方向数量和每方向的括界二分"],
    ], widths=[3.0, 6.1, 6.1], font_size=9.2, caption="表 2 两种选点机制的差异")

    # 3
    add_heading_new_page(doc, "3 实验设计", 1, "bm_3", 4)
    doc.add_heading("3.1 Benchmark 与参考值", level=2)
    ref_rows = []
    for r in REFS:
        kind = {
            "analytical_branch_evaluated_numerically": "解析分支数值求值",
            "published_approximate_numerical": "论文近似数值",
            "exact_analytical_product_basin": "严格解析乘积吸引域",
        }.get(r["reference_kind"], r["reference_kind"])
        ref_rows.append([
            MODEL_CN[r["model_id"]],
            r["dimension"] + "D",
            f"{r['parameter_name']}={r['parameter_value']}",
            fnum(r["R_reference"], 6),
            kind,
        ])
    add_table(doc, ["模型", "维度", "测试参数", "参考 LIM", "参考性质"], ref_rows,
              widths=[5.2, 1.3, 2.5, 2.4, 4.0], font_size=8.8, caption="表 3 六个 benchmark 及参考值性质")
    add_body(doc, "参考值只用于运行结束后的评分，不传入任何选点算法。尤其需要注意：Habib 四维模型的 0.5737 是论文中的数值估计，不是解析真值；因此对该模型不能把与 0.5737 的差直接解释为真实误差。")

    doc.add_heading("3.2 配对与随机化", level=2)
    add_bullet(doc, "每个模型使用 30 个配对 seed，两种方法在相同 seed 编号下比较。")
    add_bullet(doc, "二维直接运行按随机顺序执行，减少机器负载顺序对计时的系统偏差。")
    add_bullet(doc, "总规模为 6 个模型 × 2 种方法 × 30 个 seed，即 360 条结果；全部运行成功写入。")
    add_bullet(doc, "相同 seed 用于组织可复现的配对比较，但不同方法消耗随机数的方式不同，因此不代表两种算法测试了完全相同的初始点。")

    doc.add_heading("3.3 公平性原则", level=2)
    add_body(doc, "本实验比较的是两种完整方法，而不是只替换选点器的消融实验。对同一模型，两种方法使用相同动力学方程、目标吸引子、加权距离、模型参数和评价参考。DynIn 保留原始 GA 与网格分类逻辑；Proposed 保留自身的径向扫描、二分、方向加密和停止条件。")
    add_body(doc, "因此，轨迹预算并未强行设为完全相同。这样的设计能回答完整方法在实际配置下的精度和成本，但不能把时间差全部归因于选点公式。报告同时给出轨迹评估次数和运行时间，使读者能够区分搜索成本与当前代码实现效率。")

    doc.add_heading("3.4 评价指标", level=2)
    add_bullet(doc, "相对绝对误差：e rel = |R hat − R ref| / R ref。")
    add_bullet(doc, "中位误差衡量典型运行；P95 和最大误差衡量不稳定尾部。")
    add_bullet(doc, "1%、2% 和 5% 达标率表示不同精度门槛下的成功比例。")
    add_bullet(doc, "轨迹评估次数是主要计算成本；中位算法运行时间是次要成本指标。")
    add_bullet(doc, "四维 Proposed 另外记录停止状态和 audit pass，确认停止后额外方向未发现更小边界。")

    doc.add_heading("3.5 Habib 四维模型的独立验证", level=2)
    add_body(doc, "Proposed 得到约 0.538，而论文报告约 0.5737。为避免把更小结果直接当作改进，本实验保存候选方向和 target non target 径向区间，再用更严格的独立积分验证：积分时长提高到 2000、4000 和 8000，使用更紧的误差容限，并检测长期轨迹是否进入非目标周期吸引子。只有区间内侧返回目标、外侧进入稳定非目标周期运动时，才把该方向判断为清晰边界。")

    # 4
    add_heading_new_page(doc, "4 实验结果", 1, "bm_4", 5)
    doc.add_heading("4.1 完整性检查", level=2)
    add_body(doc, "360 次主实验全部成功完成。两个四维模型中，Proposed 的 60 次运行全部通过停止后方向审计。二维和 DynIn 行的 audit pass 记为 0 表示该字段不适用，不代表失败。")

    doc.add_heading("4.2 四个二维模型", level=2)
    rows = []
    for mid in ["quadratic_cubic", "bistable_duffing", "habib_unforced_duffing", "genda_cosine_quadratic_drag"]:
        for method in ["dynin_original_ga", "proposed_adaptive_angle"]:
            r = summary_row(mid, method)
            rows.append([
                MODEL_CN[mid], METHOD_CN[method], pct(r["median_relative_error"], 3), pct(r["p95_relative_error"], 3),
                pct(r["within_1_percent_fraction"], 1), fnum(r["median_trajectory_evaluations"], 1), fnum(r["median_algorithm_runtime_s"], 3)
            ])
    add_table(doc, ["模型", "方法", "中位误差", "P95 误差", "1% 达标率", "轨迹次数", "中位时间 s"], rows,
              widths=[4.1, 3.2, 1.9, 1.9, 1.8, 1.7, 1.9], font_size=8.2, caption="表 4 二维模型 30 seed 结果")
    add_body(doc, "四个二维模型的结论一致。Proposed 的 1% 达标率均为 100%，而 DynIn 分别为 60.0%、53.3%、43.3% 和 83.3%。在三个解析参考模型上，Proposed 的中位误差约为 0.002% 至 0.003%；在 Habib 无外激励 Duffing 模型上，以论文近似值 0.7683 评分时，中位差异为 0.109%。")
    add_body(doc, "配对结果显示，Proposed 在 quadratic cubic、双稳态 Duffing 和余弦势模型的 30 个 seed 中全部误差更小；在 Habib 无外激励 Duffing 中为 27 个 seed 更小。结果并非只改善平均值，而是同时压低了 P95 与最大误差，说明随机种子造成的尾部波动也显著减弱。")
    add_figure(doc, ASSETS / "median_error_comparison.png", "图 1 五个具有解析或明确数值参考的模型中位相对误差  Habib 四维模型因参考值并非严格真值而不纳入此图")

    doc.add_heading("4.3 可分离四维解析 benchmark", level=2)
    d = summary_row("separable_qc_bd_4d", "dynin_original_ga")
    p = summary_row("separable_qc_bd_4d", "proposed_adaptive_angle")
    add_body(doc, f"该模型的严格解析 LIM 为 0.647480。DynIn 的中位估计为 {float(d['median_R_hat']):.6f}，中位相对误差为 {pct(d['median_relative_error'],3)}，P95 为 {pct(d['p95_relative_error'],3)}，1% 达标率为 0%。Proposed 的中位估计为 {float(p['median_R_hat']):.6f}，中位误差为 {pct(p['median_relative_error'],3)}，P95 为 {pct(p['p95_relative_error'],3)}，30 个 seed 全部满足 1% 误差阈值。")
    add_body(doc, "这一结果是四维扩展最强的定量证据，因为参考值来自可分离系统乘积吸引域的严格解析关系，而不是另一个数值算法。配对比较中 Proposed 在 30 个 seed 上全部更准确，并在 29 个 seed 上运行更快。")

    doc.add_heading("4.4 Habib 四维模型", level=2)
    d = summary_row("habib_vdp_tmd_4d", "dynin_original_ga")
    p = summary_row("habib_vdp_tmd_4d", "proposed_adaptive_angle")
    add_body(doc, f"DynIn 的中位估计为 {float(d['median_R_hat']):.6f}，接近论文的 0.5737。Proposed 的中位估计为 {float(p['median_R_hat']):.6f}，30 个 seed 的结果集中在约 0.537 至 0.544。若机械地把 0.5737 当作真值，Proposed 会得到 {pct(p['median_relative_error'],2)} 的差异；但这一差异不能称为误差，因为 0.5737 本身只是已发表数值估计。")
    val_rows = []
    for r in VALID:
        val_rows.append([
            r["seed"], fnum(r["bracket_lower"], 6), fnum(r["bracket_upper"], 6),
            "返回目标", "非目标周期吸引子", "清晰边界已验证"
        ])
    add_table(doc, ["seed", "内侧半径", "外侧半径", "内侧标签", "外侧标签", "判断"], val_rows,
              widths=[1.2, 2.4, 2.4, 2.6, 3.4, 3.4], font_size=9.0, caption="表 5 Habib 四维候选边界的独立验证")
    add_body(doc, "三个验证方向均得到同一结构：区间内侧返回目标吸引子，区间外侧以及同方向的论文半径点均进入稳定的非目标周期吸引子。因此可以严格说，论文数值 0.5737 不是该系统在当前距离定义下的最近已知边界。已验证的最小外侧端点为 0.537497，这给出 LIM ≤ 0.537497 的数值证据。Proposed 的 30 seed 中位值 0.537950 与该验证边界非常接近。")
    add_figure(doc, ASSETS / "habib4d_validation.png", "图 2 Habib 四维模型中三个独立验证区间与论文数值的关系  区间虽很窄但均位于 0.5737 左侧")

    doc.add_heading("4.5 计算成本与停止状态", level=2)
    cost_rows = []
    for r in PAIRED:
        cost_rows.append([
            MODEL_CN[r["model_id"]],
            fnum(r["median_evaluation_ratio"], 3) + "×",
            fnum(r["median_runtime_ratio"], 3) + "×",
            pct(r["proposed_better_error_fraction"], 1),
            pct(r["proposed_faster_fraction"], 1),
        ])
    add_table(doc, ["模型", "轨迹次数比", "中位时间比", "Proposed 更准", "Proposed 更快"], cost_rows,
              widths=[5.2, 2.5, 2.5, 2.7, 2.7], font_size=8.8, caption="表 6 Proposed 相对 DynIn 的配对成本与胜率")
    add_body(doc, "二维 Proposed 通常多使用 1.135 至 1.75 倍轨迹评估，但当前实现的中位时间明显更短。可分离四维模型中轨迹次数增至 3.315 倍，仍在 29 个 seed 上更快。Habib 四维模型中轨迹次数为 7.525 倍，中位时间为 3.814 倍，因此该模型明确展示了精度与成本的交换。")
    add_body(doc, "运行时间不是纯算法复杂度指标，因为两种方法的数据结构、分类器和代码路径不同。论文中应把轨迹评估次数作为主要成本，把中位时间作为当前实现上的辅助结果。四维 Proposed 存在少量 direction limit 或 wall time exhausted 状态，但这些运行仍通过额外方向审计；应在后续工作中同时报告中位数、P95 和停止状态，而不能只给平均时间。")
    add_figure(doc, ASSETS / "cost_ratios.png", "图 3 Proposed 相对 DynIn 的轨迹评估次数与中位算法时间比值  虚线 1 表示两种方法相同")

    # 5
    add_heading_new_page(doc, "5 讨论", 1, "bm_5", 6)
    doc.add_heading("5.1 对中心问题的回答", level=2)
    add_body(doc, "在本实验覆盖的二维和四维模型中，自适应角度径向搜索能够更稳定地定位最近边界。对三个二维解析模型和可分离四维解析模型，误差改善是直接可验证的；对两个只有论文近似结果的 Habib 模型，二维结果与论文值更接近，四维结果则通过独立轨迹验证揭示了论文值之外的更近周期边界。")
    doc.add_heading("5.2 为什么 Proposed 更准确", level=2)
    add_body(doc, "DynIn GA 的适应度鼓励候选点远离已存储点，这有利于填补状态空间空隙，但它不直接优化各方向的临界半径。Proposed 把问题拆成方向选择和径向边界定位：二分直接提高每个已选方向的边界精度，局部加密集中寻找当前最小值，全局补点抑制遗漏其他危险方向。结果中的低 P95 和高达标率与这一机制一致。")
    doc.add_heading("5.3 精度与成本的边界", level=2)
    add_body(doc, "二维中，额外轨迹数较少且方向几何简单，因此 Proposed 同时获得更高精度和更短中位时间。四维中，覆盖 S3 需要显著更多方向，局部切空间加密和全局 maximin 验证都会增加查询数。可分离四维模型仍表现良好，但 Habib 四维模型说明复杂边界可能触发长时间积分和方向扩展。Proposed 的优势应表述为更可靠的边界定位，而不是无条件更快。")
    doc.add_heading("5.4 研究限制", level=2)
    add_bullet(doc, "仅测试了两个四维模型，不能据此推广到任意维度和任意吸引域拓扑。")
    add_bullet(doc, "Habib 四维模型尚无解析 LIM；独立验证证明了更近边界存在，但尚未证明 30 seed 中最小值就是全局 LIM。")
    add_bullet(doc, "完整方法比较保留了各自分类器和停止条件，因此不能单独量化选点器本身的因果贡献。")
    add_bullet(doc, "运行时间受到 MATLAB 实现细节和极端慢轨迹影响，应以配对中位数、P95 和轨迹次数共同解释。")
    add_bullet(doc, "Proposed 的四维方向参数目前是经验冻结值，仍需更多模型验证停止条件和全局覆盖充分性。")

    # 6
    add_heading_new_page(doc, "6 结论", 1, "bm_6", 7)
    add_body(doc, "本实验的主要结论不是 Proposed 在所有情况下都比 DynIn 快，而是它在已测试模型上更直接地把计算资源用于最近边界。四个二维模型中 Proposed 的 1% 达标率均为 100%，并显著降低中位误差和 P95 误差。可分离四维解析模型中，Proposed 把中位误差从 7.278% 降到 0.072%，证明二维自适应方向思想可以推广到四维方向空间。")
    add_body(doc, "Habib 四维模型的结论需要更谨慎：Proposed 与论文数值 0.5737 的差异不是失败证据。独立验证显示约 0.5375 处确实存在从目标吸引子到非目标周期吸引子的清晰边界，因此 Proposed 提供了比原论文估计更紧的 LIM 上界。与此同时，该模型的中位轨迹数和运行时间均高于 DynIn，说明高维可靠搜索需要支付额外覆盖成本。")
    add_body(doc, "因此，当前证据支持继续使用自适应角度径向方法作为 proposed method，并把四维版本的研究重点放在减少方向数量、复用单次积分中的路径信息、改进慢轨迹分类，以及用更多具有解析或可独立验证边界的高维模型检验停止条件。")

    # Appendix A
    add_heading_new_page(doc, "附录 A DynIn 配置摘要", 1, "bm_a", 8)
    config_rows = []
    for r in CONFIGS:
        config_rows.append([
            MODEL_CN.get(r.get("model_id", ""), r.get("model_id", "")),
            r.get("discr", ""), r.get("target_cells", ""),
            r.get("tfinal", ""), r.get("Ts", ""), r.get("number_of_steps", ""),
        ])
    add_table(doc, ["模型", "discr", "目标邻域格数", "tfinal", "Ts", "轨迹预算"], config_rows,
              widths=[6.0, 1.7, 2.4, 1.8, 1.5, 2.0], font_size=8.8, caption="表 A1 DynIn 模型级配置")
    add_body(doc, "共同 GA 参数为 divR = 40、num gen = 5、交叉候选数 = 9、selected opt = 3、newcomers = 8、num almost clones = 2。Habib 四维模型的 DynIn 轨迹预算为 40，其余模型为 100。")

    # Appendix B
    add_heading_new_page(doc, "附录 B 结果文件与复现信息", 1, "bm_b", 9)
    add_body(doc, "主实验结果由以下文件构成。报告中只列文件名，不绑定某一台电脑的绝对目录。")
    add_bullet(doc, "raw data all runs csv：360 次逐运行结果。")
    add_bullet(doc, "summary by model and method csv：按模型和方法汇总的误差、达标率与成本。")
    add_bullet(doc, "paired contrasts proposed vs dynin csv：按配对 seed 计算的误差和成本比值。")
    add_bullet(doc, "benchmark references csv：模型参数、参考 LIM、参考性质和来源。")
    add_bullet(doc, "dynin configurations csv：各模型 DynIn 配置。")
    add_bullet(doc, "candidate coordinates and verdicts csv：Habib 四维候选坐标、验证区间和最终判断。")
    add_body(doc, "复现时应保留随机执行日程、原始逐运行数据和停止状态。对 Habib 四维模型，任何把 0.5737 作为 ground truth 的图或表都应改称与论文数值的相对差异，并同时引用独立验证结果。")

    doc.save(OUT)
    print(OUT)


if __name__ == "__main__":
    build()
