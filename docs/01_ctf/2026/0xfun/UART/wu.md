# UART

- [🗞️ INFO](#️-info)
- [📝 Wording](#-wording)
- [🛠️ Tools](#️-tools)
- [🧠 Write Up](#-write-up)
  - [1. Extraction du fichier Sigrok](#1-extraction-du-fichier-sigrok)
  - [2. Analyse du signal](#2-analyse-du-signal)
  - [3. Décodage UART 8N1](#3-décodage-uart-8n1)
  - [Flag](#flag)

## 🗞️ INFO

**Platform**: 0xFun

**Category**: misc

**Difficulty**: easy

**Link**: <https://ctf.0xfun.org/challenges>

## 📝 Wording

> A strange transmission has been recorded. Something valuable lies within.

Fichier fourni : `uart.sr`

## 🛠️ Tools

/

## 🧠 Write Up

### 1. Extraction du fichier Sigrok

Le fichier `.sr` est une archive ZIP contenant une capture d'analyseur logique :

```bash
$ unzip uart.sr -d uart_extracted/
  extracting: version
  inflating: metadata
  inflating: logic-1-1
```

Le fichier `metadata` révèle les paramètres :

```txt
samplerate=1 MHz
total probes=1
probe1=uart.ch1
unitsize=1
```

Un seul canal UART, échantillonné à 1 MHz. Chaque octet du fichier `logic-1-1` représente un sample, et le bit 0 porte la valeur du signal.

### 2. Analyse du signal

```python
data = open('logic-1-1', 'rb').read()
samples = [b & 1 for b in data]  # 2400 samples
```

Le signal commence par des `1` (idle UART), puis le premier start bit (0) apparaît à l'index 86. L'analyse des intervalles entre transitions donne un **bit period de ~8 samples**, soit un baudrate de **1 000 000 / 8 = 125 000 baud**.

### 3. Décodage UART 8N1

Le protocole UART transmet chaque octet ainsi : 1 start bit (0), 8 bits de données LSB first, 1 stop bit (1). On échantillonne au milieu de chaque bit :

```python
data = open('logic-1-1', 'rb').read()
samples = [b & 1 for b in data]

def decode_uart(samples, bit_period=8):
    result = []
    i = 0
    while i < len(samples) - 1:
        if samples[i] == 1 and samples[i+1] == 0:
            start = i + 1
            byte_val = 0
            for bit in range(8):
                pos = int(start + bit_period * (bit + 1.5))
                byte_val |= (samples[pos] << bit)
            result.append(chr(byte_val) if 32 <= byte_val < 127 else f'[0x{byte_val:02x}]')
            i = int(start + bit_period * 9.5)
        else:
            i += 1
    return ''.join(result)

print(decode_uart(samples))
```

Output :

```txt
0xfun{UART_82_M2_B392n9dn2}
```

### Flag

```txt
0xfun{UART_82_M2_B392n9dn2}
```
