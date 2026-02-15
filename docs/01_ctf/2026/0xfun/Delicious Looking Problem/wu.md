# Delicious Looking Problem

- [🗞️ INFO](#️-info)
- [📝 Wording](#-wording)
- [🛠️ Tools](#️-tools)
- [🧠 Write Up](#-write-up)

## 🗞️ INFO

**Platform**: 0xFun

**Category**: crypto

**Difficulty**: warmup

**Link**: <https://ctf.0xfun.org/challenges>

## 📝 Wording

> A delicious looking problem for starters. Always remember that the answer to life, universe and everything is 42.

## 🛠️ Tools

- Python3
- sympy (discrete_log)
- pycryptodome (AES)

## 🧠 Write Up

On a deux fichiers: `chall.py` et `output.txt`.

En lisant le code, on comprend le schéma:

1. Une `key` aléatoire de la même taille que le flag
2. 8 samples où on calcule `h = g^key mod p` avec des safe primes `p` de **42 bits** (le hint du titre!)
3. Le flag est chiffré en AES-ECB avec `SHA256(key)`

Le jeu de mots "Delicious Looking Problem" = **DLP** = Discrete Logarithm Problem. Des primes de 42 bits c'est ridiculement petit, on peut résoudre le DLP trivialement.

Pour chaque sample on résout `g^x ≡ h (mod p)` ce qui nous donne `key ≡ x_i (mod p_i - 1)`:

```python
from sympy.ntheory import discrete_log

samples = [
    (227293414901,  1559214942312, 3513364021163),
    (2108076514529, 1231299005176, 2627609083643),
    (1752240335858, 1138499826278, 2917520243087),
    (1564551923739, 283918762399,  2602533803279),
    (1809320390770, 700655135118,  2431482961679),
    (1662077312271, 354214090383,  2820691962743),
    (474213905602,  1149389382916, 3525049671887),
    (2013522313912, 2559608094485, 2679851241659),
]

residues, moduli = [], []
for g, h, p in samples:
    x = discrete_log(p, h, g)
    residues.append(x)
    moduli.append(p - 1)
```

Ensuite on combine les 8 congruences avec le **CRT** (Théorème des Restes Chinois). Attention les moduli partagent tous le facteur 2 (safe primes → p-1 = 2q), donc il faut un CRT qui gère les moduli non copremiers:

```python
from math import gcd

def extended_gcd(a, b):
    if a == 0:
        return b, 0, 1
    g, x, y = extended_gcd(b % a, a)
    return g, y - (b // a) * x, x

def crt_pair(r1, m1, r2, m2):
    g = gcd(m1, m2)
    assert (r1 - r2) % g == 0
    lcm = m1 * m2 // g
    _, x, _ = extended_gcd(m1 // g, m2 // g)
    r = (r1 + m1 * ((r2 - r1) // g) * x) % lcm
    return r, lcm

r, m = residues[0], moduli[0]
for i in range(1, len(residues)):
    r, m = crt_pair(r, m, residues[i], moduli[i])
```

Le CRT nous donne `key mod M` avec M ≈ 2^325. Mais la key fait 43 octets = 344 bits, donc il reste un gap. La vraie key c'est `key = r + k × M` pour un certain `k`. Comme k_max ≈ 1 000 000, c'est brute-forçable:

```python
from Crypto.Util.number import long_to_bytes
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad
import hashlib

ct = bytes.fromhex(
    '175a6f682303e313e7cae01f4579702a'
    'e6885644d46c15747c39b85e5a1fab66'
    '7d2be070d383268d23a6387a4b3ec791'
)

key_len = 43
k_max = (2 ** (8 * key_len) - 1 - r) // m

for k in range(k_max + 1):
    key_int = r + k * m
    key_bytes = key_int.to_bytes(key_len, 'big')
    aes_key = hashlib.sha256(key_bytes).digest()
    cipher = AES.new(aes_key, AES.MODE_ECB)
    raw = cipher.decrypt(ct)
    pad_byte = raw[-1]
    if 1 <= pad_byte <= 16 and raw[-pad_byte:] == bytes([pad_byte]) * pad_byte:
        pt = raw[:-pad_byte]
        try:
            text = pt.decode('utf-8', errors='strict')
            if text.isprintable():
                print(f"FLAG: {text}")
                break
        except:
            pass
```

À k = 975590 on obtient le flag.

**Flag**: *0xfun{pls_d0nt_hur7_my_b4by(DLP)_AI_kun!:3}*
