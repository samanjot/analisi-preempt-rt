# Analisi cyclictest (Preempt-RT vs No Preempt-RT)

Questa cartella contiene i risultati di `cyclictest` in formato JSON per sei scenari:

- `cyclic_baseline_nopreempt_rt.json`
- `cyclic_baseline_preempt_rt.json`
- `cyclic_stress_100k_nopreempt_rt.json`
- `cyclic_stress_100k_preempt_rt.json`
- `cyclic_stress_1M_nopreempt_rt.json`
- `cyclic_stress_1M_preempt_rt.json`

Ogni file include l’istogramma delle latenze per thread; i nomi scenario vengono normalizzati nel notebook.

## Notebook principale

`analisys_def.ipynb` produce:
- jitter massimo per scenario (bar plot con etichette),
- boxplot latenze separati per No Preempt-RT e Preempt-RT,
- distribuzioni delle latenze per scenario,
- riepilogo (media, std, max, min) per scenario,
- jitter per thread per ogni scenario (bar plot con etichette).

### Come eseguire
1. Installare le dipendenze (Python 3.10+):
   ```bash
   pip install -r requirements.txt
   ```
2. Avviare Jupyter:
   ```bash
   jupyter notebook analisys_def.ipynb
   ```
3. Eseguire tutte le celle: i file `cyclic_*.json` vengono individuati automaticamente.

## Come sono stati raccolti i dati

Run baseline (esempio):
```bash
sudo cyclictest -S -p 99 -m -i 1000 -v -D30 --json=cyclic_baseline_nopreempt_rt.json
```

Run sotto carico (esempio 100k timer):
```bash
sudo stress-ng --timer 0 --timer-freq 100000 --timer-slack 0 --timeout 30 --metrics-brief --times &
sudo cyclictest -S -p 99 -m -i 1000 -v -D30 --json=cyclic_stress_100k_nopreempt_rt.json
```

Sostituire i suffissi `_nopreempt_rt` / `_preempt_rt` e i carichi (`100k`, `1M`) in base allo scenario.
