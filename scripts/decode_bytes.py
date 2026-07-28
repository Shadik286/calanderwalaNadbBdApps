p = r'e:\calanderwala\calanderwala\web\index.html'
with open(p, 'rb') as f:
    raw = f.read()
text = raw.decode('utf-8')
lines = text.split('\n')
# extract the unusual region of line 1381
line = lines[1380]
i = line.find('more ')
j = line.find('each')
region = line[i:j]
print('Region text:', repr(region))
print('Region bytes:', region.encode('utf-8').hex())
# Decode that byte sequence as cp1252
try:
    print('Region as cp1252:', region.encode('utf-8').decode('cp1252'))
except Exception as e:
    print('cp1252 error:', e)
print()
# Same for line 1431 (the taka)
line = lines[1430]
i = line.find('class="price">')
j = line.find('</div>')
region = line[i:j]
print('Region text:', repr(region))
print('Region bytes:', region.encode('utf-8').hex())
try:
    print('Region as cp1252:', region.encode('utf-8').decode('cp1252'))
except Exception as e:
    print('cp1252 error:', e)