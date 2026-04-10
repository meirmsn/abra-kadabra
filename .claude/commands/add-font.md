# Add Font

Add a new font to the iOS app from Google Fonts.

## 1. Verify it's official and open source

Scrape the Google Fonts specimen page for the source repo, then confirm SIL OFL license:

```bash
curl -sL "https://fonts.google.com/specimen/Font+Name" | grep -o 'github\.com/[^"&]*' | sort -u
curl -sL "https://raw.githubusercontent.com/{owner}/{repo}/master/OFL.txt" | head -3
```

Must be SIL OFL. Stop if it isn't.

## 2. Download from the GitHub release

The Google Fonts download page is JS-rendered and unusable with curl. Use the GitHub release directly:

```bash
curl -s "https://api.github.com/repos/{owner}/{repo}/releases/latest" \
  | python3 -c "import sys,json; r=json.load(sys.stdin); [print(a['browser_download_url']) for a in r['assets']]"

curl -sL {url} -o /tmp/font.zip && unzip -o /tmp/font.zip -d /tmp/font
find /tmp/font -name "*.ttf" | grep -v Variable | sort
```

## 3. Pick the right TTF and check its PostScript name

For display sizes (56px+) use the largest optical size variant (e.g. `Fraunces144pt-Regular`). The PostScript name is what SwiftUI's `.custom(...)` needs:

```bash
python3 -c "
import struct
def names(path):
    data=open(path,'rb').read(); offset=12; tables={}
    n=struct.unpack('>H',data[4:6])[0]
    for i in range(n):
        tag=data[offset:offset+4].decode('ascii')
        _,o,l=struct.unpack('>III',data[offset+4:offset+16]); tables[tag]=(o,l); offset+=16
    nd=data[tables['name'][0]:]; cnt=struct.unpack('>H',nd[2:4])[0]; st=struct.unpack('>H',nd[4:6])[0]
    r={}
    for i in range(cnt):
        b=6+i*12; pid,_,_,nid,ln,so=struct.unpack('>HHHHHH',nd[b:b+12])
        s=nd[st+so:st+so+ln]
        try: r[nid]=(s.decode('utf-16-be') if pid==3 else s.decode('latin-1'))
        except: pass
    return r.get(1,'?'),r.get(6,'?')  # family, postscript
print(names('YOURFILE.ttf'))
"
```

## 4. Copy to project and wire up

```bash
cp /tmp/font/Whatever-Regular.ttf ios/Sources/Resources/Fonts/
```

Then in `ios/Sources/Design/AppFonts.swift`:

1. Add the filename (without `.ttf`) to `FontLoader.registerFonts()`
2. Add a `static func` in the `Font` extension using `.custom("PostScriptName", size: N, relativeTo: .x)`
