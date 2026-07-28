# Inspect specific lines as UTF-8.
import sys
p = r'e:\calanderwala\calanderwala\web\index.html'
with open(p, 'rb') as f:
    raw = f.read()
text = raw.decode('utf-8', errors='replace')
lines = text.split('\n')
wanted = [7, 1307, 1381, 1391, 1431, 1526, 1532, 1560, 1727, 1728, 1830, 1831, 1886]
for n in wanted:
    if n-1 < len(lines):
        line = lines[n-1]
        # Print line and char codes of the non-ASCII chars
        non_ascii = [(i, c, ord(c)) for i, c in enumerate(line) if ord(c) > 127]
        print(f'L{n}: {line.strip()[:120]}')
        print(f'  non-ascii: {non_ascii[:8]}')
print(f'Total lines: {len(lines)}')