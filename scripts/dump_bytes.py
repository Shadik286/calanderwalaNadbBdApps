p = r'e:\calanderwala\calanderwala\web\index.html'
with open(p, 'rb') as f:
    raw = f.read()
text = raw.decode('utf-8')
lines = text.split('\n')
for n in [1381, 1391, 1431, 1526, 1532, 1560, 1727, 1728, 1830, 1831, 1886]:
    line = lines[n-1]
    enc = line.encode('utf-8')
    # find the non-ascii region
    print(f'L{n} bytes:', enc.hex())