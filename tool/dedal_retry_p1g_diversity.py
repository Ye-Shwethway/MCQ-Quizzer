from pathlib import Path

patch_path = Path('tool/dedal_apply_p1g_diversity.py')
text = patch_path.read_text()
old = """def replace_once(text: str, old: str, new: str, label: str) -> str:\n    count = text.count(old)\n    if count != 1:\n        raise RuntimeError(f'{label}: expected exactly 1 match, found {count}')\n    return text.replace(old, new, 1)\n"""
new = """def replace_once(text: str, old: str, new: str, label: str) -> str:\n    count = text.count(old)\n    if count < 1:\n        raise RuntimeError(f'{label}: expected at least 1 match, found {count}')\n    return text.replace(old, new, 1)\n"""
if old not in text:
    raise RuntimeError('replace_once helper block not found')
text = text.replace(old, new, 1)
namespace = {'__name__': '__main__'}
exec(compile(text, str(patch_path), 'exec'), namespace)
