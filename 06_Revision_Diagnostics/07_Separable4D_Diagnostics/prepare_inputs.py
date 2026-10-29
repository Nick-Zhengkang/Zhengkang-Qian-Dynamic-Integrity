"""Copy only required frozen inputs; never edit or execute original files."""
from pathlib import Path
import csv
import hashlib
import shutil
ROOT=Path(__file__).resolve().parent
SOURCE=Path(r'C:\Users\-qian-\Documents\Codex\r13publish\04_Method_Comparison\02_Raw_Data\Six_Models_360_Runs\outputs_sampled_forward_full_20261018_204956_915')
pairs=[(SOURCE/'separable_qc_bd_4d_settings.mat',ROOT/'input/separable_qc_bd_4d_settings.mat')]
pairs += [(p,ROOT/'input/runs'/p.name) for p in (SOURCE/'runs').glob('separable_qc_bd_4d__proposed_sampled_forward__seed_*.mat')]
for name in ['sampled_forward_geometry.m','sampled_forward_step.m','sampled_forward_integrate.m','sampled_forward_classifier.m']:
    pairs.append((SOURCE/'source_snapshot/six_model_sampled_forward_comparison'/name,ROOT/'engine'/name))
for name in ['find_index.m','find_cells_around_a_cell.m']:
    pairs.append((SOURCE/'source_snapshot/work/DynIn/DynIn_v1.1.0/functions'/name,ROOT/'native'/name))
pairs.append((SOURCE/'dynin_models/separable_qc_bd_4d/sistema.m',ROOT/'model/sistema.m'))
license_path=Path(r'C:\Users\-qian-\Documents\Codex\r13publish\00_Shared_MATLAB\work\DynIn\LICENSE')
pairs.append((license_path,ROOT/'native/LICENSE'))
manifest=[]
for src,dst in pairs:
    data=src.read_bytes()
    digest=hashlib.sha256(data).hexdigest()
    dst.parent.mkdir(parents=True,exist_ok=True)
    if dst.exists():
        assert dst.read_bytes()==data, f'Refusing to overwrite changed input: {dst}'
    else:
        shutil.copy2(src,dst)
    assert dst.read_bytes()==data and src.read_bytes()==data
    manifest.append(dict(relative_path=dst.relative_to(ROOT).as_posix(),source_path=str(src),bytes=len(data),sha256=digest))
with (ROOT/'input_manifest.csv').open('w',encoding='utf-8',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(manifest[0]));w.writeheader();w.writerows(manifest)
print(f'Copied and verified {len(manifest)} frozen files. Original files unchanged.')
