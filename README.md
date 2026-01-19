## Cyclic Latency Test Tool

Questo script (`run_cyclic_tests.sh`) automatizza l’esecuzione di **cyclictest** (e benchmark di memoria) in vari scenari di carico. Unifica test di latenza CPU (con carico timer) e test di interferenza di memoria.

**NOTA: Di default lo script NON esegue alcun test. Devi specificare quali test vuoi eseguire usando i flag.**

### Uso e Opzioni

```bash
sudo ./run_cyclic_tests.sh [options] [test-flags]
```

---

### Opzioni Test (Selezionane almeno uno)

#### 1. Test Standard (CPU Timer)
Scenari standard per valutare la latenza scheduler con carico timer:

| Flag              | Descrizione                                      |
| ----------------- | ------------------------------------------------ |
| `--baseline`      | Esegue test baseline (senza carico)              |
| `--stress-min`    | Esegue test con stress leggero (default 100k)    |
| `--stress-max`    | Esegue test con stress pesante (default 1M)      |
| `--smin <freq>`   | Imposta la frequenza per stress-min (def: 100k)  |
| `--smax <freq>`   | Imposta la frequenza per stress-max (def: 1M)    |
| `-t, --timeout`   | Durata in secondi per ogni test (def: 30)        |


#### 2. Test Interferenza Memoria
Scenari che valutano l'impatto del carico di memoria sulla latenza (richiede `membench`/`meminterf`):

| Flag                     | Descrizione                                      |
| ------------------------ | ------------------------------------------------ |
| `--mem-baseline`         | Esegue `membench` (linear/random)                |
| `--mem-interf`           | Scan interferenza (cyclictest + meminterf)       |
| `--mem-interf-100k`      | Scan interferenza + stress timer (100k)          |
| `--mem-interf-1M`        | Scan interferenza + stress timer (1M)            |
| `--interf-cores <N>`     | Numero max core interferenti (default: nproc-1)  |
| `--membench-cmd <path>`  | Percorso eseguibile `membench`                   |
| `--meminterf-cmd <path>` | Percorso eseguibile `meminterf`                  |

---

### Opzioni Generali

| Opzione               | Descrizione                             |
| --------------------- | --------------------------------------- |
| `-n, --name <suffix>` | Suffisso scenario nei nomi file (def: default) |
| `--outdir <dir>`      | Directory di output (def: .)            |
| `--hist <max_us>`     | Istogramma fino a `<max_us>` µs         |
| `--nohist`            | Disabilita istogramma                   |
| `-h, --help`          | Mostra aiuto                            |

---

### Esempi

**Solo baseline:**
```bash
sudo ./run_cyclic_tests.sh --baseline
```

**Test Standard Completo (Baseline + Stress Min + Stress Max):**
```bash
sudo ./run_cyclic_tests.sh --baseline --stress-min --stress-max --outdir results/standard
```

**Solo Test Interferenza Memoria (Scan fino a 3 core):**
```bash
sudo ./run_cyclic_tests.sh \
  --mem-interf --mem-interf-100k \
  --interf-cores 3 \
  --outdir results/memory
```

**Esecuzione Mista:**
```bash
sudo ./run_cyclic_tests.sh --baseline --mem-interf --outdir results/mixed
```

### Requisiti

* Esecuzione come **root**
* Pacchetti installati: `cyclictest` (rt-tests), `stress-ng`
* Tool addizionali opzionali: `membench`, `meminterf` (per i test di memoria)[https://git.hipert.unimore.it/mem-prof/hesoc-mark/-/tree/master?ref_type=heads]