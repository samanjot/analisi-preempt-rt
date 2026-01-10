## Cyclic Latency Test Tool

Questo script (`run_cyclic_tests.sh`) automatizza l’esecuzione di **cyclictest** in tre scenari:

1. **Baseline** (senza carico)
2. **Con stress leggero** (`stress-ng` a frequenza `smin`)
3. **Con stress pesante** (`stress-ng` a frequenza `smax`)

Per ogni scenario vengono prodotti:

* un file **JSON** con i risultati completi di `cyclictest`
* opzionalmente un file **HIST** con l’istogramma delle latenze (distribuzione statistica)

È pensato per confrontare il comportamento real-time del kernel (PREEMPT / PREEMPT_RT, tuning IRQ, governor CPU, isolcpus, ecc.).

---

### Requisiti

* Esecuzione come **root**
* Pacchetti installati:

  * `cyclictest`
  * `stress-ng`

---

### Uso base

```bash
sudo ./run_cyclic_tests.sh
```

Esegue:

* baseline (30 s)
* stress a 100 kHz
* stress a 1 MHz

---

### Opzioni principali

| Opzione               | Descrizione                             |                                     |
| --------------------- | --------------------------------------- | ----------------------------------- |
| `-b, --baseline true  | false`                                  | Abilita/disabilita il test baseline |
| `-t, --timeout <sec>` | Durata di ogni run di cyclictest        |                                     |
| `--smin <freq>`       | Frequenza timer stress “leggero”        |                                     |
| `--smax <freq>`       | Frequenza timer stress “pesante”        |                                     |
| `-n, --name <suffix>` | Suffisso scenario nei nomi file         |                                     |
| `--outdir <dir>`      | Directory di output                     |                                     |
| `--hist <max_us>`     | Abilita istogramma fino a `<max_us>` µs |                                     |
| `--nohist`            | Disabilita generazione istogrammi       |                                     |

---

### Esempi

```bash
sudo ./run_cyclic_tests.sh -n kernelA --outdir results/kernelA
sudo ./run_cyclic_tests.sh -n kernelB --outdir results/kernelB
```

```bash
sudo ./run_cyclic_tests.sh --hist 20000
```

```bash
sudo ./run_cyclic_tests.sh -b false --smin 1000000 --smax 5000000
```

---

### Note

* I file `.hist` permettono di analizzare la **distribuzione** delle latenze (non solo il massimo), utile per individuare jitter, code lunghe e comportamento anomalo sotto carico.
* I file `.json` sono ideali per parsing automatico (es. Python, pandas, Grafana, ecc.).
