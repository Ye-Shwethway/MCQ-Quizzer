from pathlib import Path

path = Path('lib/services/export_service.dart')
text = path.read_text()
old = "'${quizSet.title}_${kind}_${DateTime.now().millisecondsSinceEpoch}.$ext'"
new = "'${quizSet.title}_${kind}.$ext'"
count = text.count(old)
if count != 2:
    raise RuntimeError(f'expected 2 timestamped export filename builders, found {count}')
text = text.replace(old, new)
path.write_text(text)
print('Removed timestamp suffix from normal export filenames')
