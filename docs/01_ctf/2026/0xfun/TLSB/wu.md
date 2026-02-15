# TLSB

- [🗞️ INFO](#️-info)
- [📝 Wording](#-wording)
- [🛠️ Tools](#️-tools)
- [🧠 Write Up](#-write-up)
  - [1. Identification du fichier](#1-identification-du-fichier)
  - [2. Extraction du 3ème bit le moins significatif](#2-extraction-du-3ème-bit-le-moins-significatif)
  - [3. Résultat](#3-résultat)
  - [Flag](#flag)

## 🗞️ INFO

**Platform**: 0xFun

**Category**: forensics

**Difficulty**: easy

**Link**: <https://ctf.0xfun.org/challenges>

## 📝 Wording

> You might know about Least Significant Bit (LSB) steganography, but have you ever heard of Third Least Significant Bit (TLSB) steganography? (Probably not, I invented it for this challenge).

Fichier fourni : `TLSB` (sans extension)

## 🛠️ Tools

- Python3
- `file` (identification du format)

## 🧠 Write Up

### 1. Identification du fichier

```bash
$ file TLSB
TLSB: PC bitmap, Windows 3.x format, 16 x 16 x 24, cbSize 822
```

C'est une image BMP de 16×16 pixels en 24 bits (RGB), avec un header de 54 octets et 768 octets de données pixel.

### 2. Extraction du 3ème bit le moins significatif

La stéganographie LSB classique cache des données dans le bit 0 (le moins significatif) de chaque octet. Ici, le challenge indique **TLSB** (Third Least Significant Bit), donc on extrait le **bit 2** (0-indexé) de chaque octet des pixels :

```python
data = open('TLSB', 'rb').read()
pixels = data[54:]  # skip BMP header

# Extraire le bit 2 de chaque octet
bits = [(byte >> 2) & 1 for byte in pixels]

# Regrouper en octets MSB-first
chars = []
for i in range(0, len(bits) - 7, 8):
    val = 0
    for b in bits[i:i+8]:
        val = (val << 1) | b
    chars.append(chr(val) if 32 <= val < 127 else f'[{val:02x}]')

print(''.join(chars))
```

### 3. Résultat

Le message extrait est :

```txt
Hope you had fun :). The Flag is: `MHhmdW57VGg0dDVfbjB0X0wzNDV0X1MxZ24xZjFjNG50X2IxdF81dDNnfQ==`
```

C'est du Base64. On décode :

```bash
$ echo 'MHhmdW57VGg0dDVfbjB0X0wzNDV0X1MxZ24xZjFjNG50X2IxdF81dDNnfQ==' | base64 -d
0xfun{Th4t5_n0t_L345t_S1gn1f1c4nt_b1t_5t3g}
```

### Flag

```txt
0xfun{Th4t5_n0t_L345t_S1gn1f1c4nt_b1t_5t3g}
```
