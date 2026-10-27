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

import base64
import html
import sys
from pathlib import Path

from docx import Document
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parent
DOCX = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "DynIn与自适应角度方法六模型对比实验中文报告.docx"
HTML = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "report_preview.html"


def blocks(doc):
    for child in doc.element.body.iterchildren():
        if child.tag == qn("w:p"):
            yield Paragraph(child, doc)
        elif child.tag == qn("w:tbl"):
            yield Table(child, doc)


def paragraph_text(p):
    return "".join(node.text or "" for node in p._p.iter(qn("w:t")))


def paragraph_images(p):
    result = []
    for blip in p._p.iter(qn("a:blip")):
        rid = blip.get(qn("r:embed"))
        if not rid:
            continue
        part = p.part.related_parts[rid]
        mime = part.content_type
        data = base64.b64encode(part.blob).decode("ascii")
        result.append(f"data:{mime};base64,{data}")
    return result


def has_page_break(p):
    return any(br.get(qn("w:type")) == "page" for br in p._p.iter(qn("w:br")))


def main():
    doc = Document(DOCX)
    out = ["""<!doctype html><html lang='zh-CN'><head><meta charset='utf-8'>
<style>
@page { size: Letter; margin: 0.78in 0.82in 0.72in 0.82in; }
body { font-family: 'Times New Roman', serif; font-size: 11pt; line-height: 1.25; color:#000; margin:0; }
.pagebreak { break-before: page; height:0; }
h1 { font-size:16pt; margin:0 0 12pt 0; break-after:avoid; color:#000; }
h2 { font-size:13pt; margin:12pt 0 7pt 0; break-after:avoid; color:#000; }
h3 { font-size:11.5pt; margin:9pt 0 5pt 0; break-after:avoid; color:#000; }
p { margin:0 0 6pt 0; text-align:justify; }
.body { text-indent:0.74cm; }
.title { font-size:24pt; font-weight:bold; text-align:center; margin-top:1.2in; }
.caption { font-size:9pt; color:#464646; text-align:center; margin:5pt 0 6pt 0; }
.code { font-family:'Times New Roman',serif; font-size:9pt; margin:0 0 0 0.55cm; white-space:pre-wrap; }
.list { margin-left:0.35in; text-indent:-0.18in; }
table { width:100%; border-collapse:collapse; margin:5pt 0 8pt 0; font-size:9pt; break-inside:auto; }
th, td { border:1px solid #d9d9d9; padding:5pt 6pt; vertical-align:middle; }
tr:first-child td { background:#404040; color:#fff; font-weight:bold; text-align:center; }
tr:nth-child(odd) td { background:#f3f3f3; }
img { max-width:100%; height:auto; display:block; margin:4pt auto; }
</style></head><body>"""]
    for block in blocks(doc):
        if isinstance(block, Paragraph):
            if has_page_break(block):
                out.append("<div class='pagebreak'></div>")
            text = html.escape(paragraph_text(block))
            style = block.style.name if block.style else ""
            tag = "p"
            cls = ""
            if style == "Title": cls = "title"
            elif style == "Heading 1": tag = "h1"
            elif style == "Heading 2": tag = "h2"
            elif style == "Heading 3": tag = "h3"
            elif style == "Body Text": cls = "body"
            elif style == "Caption": cls = "caption"
            elif style == "Code Block": cls = "code"
            elif style.startswith("List"):
                cls = "list"
                text = "• " + text
            if text:
                out.append(f"<{tag} class='{cls}'>{text}</{tag}>")
            for src in paragraph_images(block):
                out.append(f"<img src='{src}'>")
        else:
            out.append("<table>")
            for row in block.rows:
                out.append("<tr>")
                for cell in row.cells:
                    value = "<br>".join(html.escape(paragraph_text(p)) for p in cell.paragraphs)
                    out.append(f"<td>{value}</td>")
                out.append("</tr>")
            out.append("</table>")
    out.append("</body></html>")
    HTML.write_text("\n".join(out), encoding="utf-8")
    print(HTML)


if __name__ == "__main__":
    main()
