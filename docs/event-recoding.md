# Event Recoding

This document describes how events are imported, filtered, and recoded from behavioral
data during preprocessing.

## Input files

**`.mat` files** — `EX_Y YYYYMMDD HHMM.mat` (with spaces), e.g. `E1_3 20240308 1109.mat`.

- EEG signal: the variable whose name ends in `2`, e.g. `E1_3_20240308_11092`
  (a 65×N matrix: 65 channels × N samples). The variable ending in `1` is ignored.
  The middle digits are a timestamp; always select the one ending in `2`.
- Events: `ECI_TCPIP_55513` (always named this). Row 1 holds event types (cell array),
  row 4 holds latencies/frames (numbers).
- Ignored variables: `Impedances_0`, `samplingRate`.

**Behavioral `.xlsx` files** — `EX_Y.xlsx` (no timestamp, no spaces), e.g. `E1_1.xlsx`.
Required columns (case-sensitive):

| Column     | Meaning                  | Values  |
|------------|--------------------------|---------|
| `Correct`  | Valence                  | 1, 2, 3 |
| `Correct2` | Congruence               | 1, 2    |
| `preg1ACC` | Accuracy, question 1     | 0, 1    |
| `preg2ACC` | Accuracy, question 2     | 0, 1    |

## Event filtering

After import, only `imag` (stimulus) and `TRSP` (response) events are kept. The `TRSP`
events are renamed `TRSP1` and `TRSP2` by sequence order, then matched against the
behavioral Excel file.

## Recoding scheme

**`imag` events (stimuli):** `congruence * 10 + valence`

| Congruence | Valence | Code |
|------------|---------|------|
| 1          | 1       | 11   |
| 1          | 2       | 12   |
| 1          | 3       | 13   |
| 2          | 1       | 21   |
| 2          | 2       | 22   |
| 2          | 3       | 23   |

**`TRSP1` events (response 1):** `valence * 100` → 100, 200, 300.

**`TRSP2` events (response 2):** `congruence * 1000` → 1000, 2000.

## Incorrect-trial removal

Events are removed when the corresponding response was incorrect:

- `TRSP1` with `preg1ACC = 0`
- `TRSP2` with `preg2ACC = 0`

## Bin definitions

Bins are defined in `bins imagenes.txt` (ERPLAB BDF format), shared across E1, E2, E3:

| Bin | Label              | Codes        |
|-----|--------------------|--------------|
| 1   | Congruent          | 11, 12, 13   |
| 2   | Incongruent        | 21, 22, 23   |
| 3   | Positive valence   | 11, 21       |
| 4   | Neutral valence    | 12, 22       |
| 5   | Negative valence   | 13, 23       |
