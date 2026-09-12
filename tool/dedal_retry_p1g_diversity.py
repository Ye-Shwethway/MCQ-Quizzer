from pathlib import Path

service_path = Path('lib/services/ai_generation_service.dart')
text = service_path.read_text()
old = """          final dup = result.any(\n            (existing) =>\n                _combinedSimilarity(existing.questionText, q.questionText) >=\n                _dedupeSimilarityThreshold,\n          );\n"""
new = """          final dup = result.any(\n            (existing) => _questionsNearDuplicate(existing, q),\n          );\n"""
count = text.count(old)
if count != 2:
    raise RuntimeError(f'expected 2 remaining refill dedupe gates, found {count}')
text = text.replace(old, new)
service_path.write_text(text)
print('Updated serial refill paths to use the domain-agnostic semantic dedupe gate')
