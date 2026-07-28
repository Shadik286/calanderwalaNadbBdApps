# Fix the double-mojibake patterns remaining in index.html.
# The file is UTF-8 but contains literal sequences where a UTF-8 char was
# mis-decoded as cp1252 and re-saved as UTF-8. Detect and fix those.

p = r'e:\calanderwala\calanderwala\web\index.html'
with open(p, 'rb') as f:
    raw = f.read()

# Each entry: (bad_literal_bytes_as_in_file, correct_utf8_bytes, label)
mappings = [
    # double-mojibake ৳ -> ৳
    # original UTF-8: E0 A7 B3 -> cp1252 decoded "à§³" -> re-saved as UTF-8:
    # C3 A0 C2 A7 C2 B3
    (b'\xc3\xa0\xc2\xa7\xc2\xb3', b'\xe0\xa7\xb3', 'taka'),
    # double-mojibake — (em dash):
    # original UTF-8: E2 80 94 -> cp1252 decoded "â€\"" (3 chars)
    # -> re-saved as UTF-8: C3 A2 C5 92 E2 80 9D (C3=A2, 20AC, 201D)
    # Actually the cp1252 decoding of E2 80 94 is U+00E2 U+20AC U+201D.
    # Re-encoded as UTF-8 those become: C3 A2 E2 82 AC E2 80 9D (6 bytes).
    (b'\xc3\xa2\xe2\x82\xac\xe2\x80\x9d', b'\xe2\x80\x94', 'em-dash'),
    # double-mojibake … (ellipsis):
    # original UTF-8: E2 80 A6 -> cp1252 decoded "â€¦" -> UTF-8: C3 A2 E2 82 AC C2 A6
    (b'\xc3\xa2\xe2\x82\xac\xc2\xa6', b'\xe2\x80\xa6', 'ellipsis'),
    # double-mojibake ✓ (check):
    # original UTF-8: E2 9C 93 -> cp1252 decoded "âœ\"" -> UTF-8:
    # C3 A2 C5 93 E2 80 9C
    (b'\xc3\xa2\xc5\x93\xe2\x80\x9c', b'\xe2\x9c\x93', 'check'),
    # double-mojibake © (copyright):
    # original UTF-8: C2 A9 -> cp1252 decoded "Â©" -> UTF-8: C3 82 C2 A9
    (b'\xc3\x82\xc2\xa9', b'\xc2\xa9', 'copyright'),
    # double-mojibake · (middot):
    # original UTF-8: C2 B7 -> cp1252 decoded "Â·" -> UTF-8: C3 82 C2 B7
    (b'\xc3\x82\xc2\xb7', b'\xc2\xb7', 'middot'),
]

total = 0
for bad, good, label in mappings:
    hits = raw.count(bad)
    if hits:
        raw = raw.replace(bad, good)
        print(f'  {label}: {hits} replacement(s)')
        total += hits

# Also handle single-mojibake ৳ if any:
taka_simple = b'\xe0\xa7\xb3'
# (already correct bytes, but if absent leave as-is)

with open(p, 'wb') as f:
    f.write(raw)

print(f'Done. Total replacements: {total}')
print(f'File now: {len(raw)} bytes')