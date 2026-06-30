# Troubleshooting

Common errors raised by the pipeline and how to resolve them. Each subject's per-subject
report and the master `processing_log.txt` (in `output_dir/EX/Reports/`) record where a
run stopped.

## "No behavioral file found"

```
ERROR: No behavioral file found matching: *E1_5.xlsx
→ Subject skipped, processing continues with the next file.
```

- Confirm the Excel file is in `behavior_dir`.
- Confirm the name is `EX_Y.xlsx` (no spaces, no date), e.g. `E1_1.xlsx`, `E2_8.xlsx`.

## "Required columns not found"

```
ERROR: Required columns not found in behavioral file
```

Open the Excel file and confirm it contains exactly (case-sensitive): `Correct`,
`Correct2`, `preg1ACC`, `preg2ACC`.

## "Bins file not found"

```
ERROR: Bins file not found: bins imagenes.txt
```

Check the `bins_file` path and that the file exists in ERPLAB BDF format.

## "Cannot find EEG data variable"

```
ERROR: Cannot find EEG data variable. Expected: E1_1_20240305_11232
```

Check the variable name inside the `.mat` file. The signal variable is the one ending in
`2` (see `event-recoding.md`).

## Few events after filtering

- Inspect `preg1ACC` and `preg2ACC` in the behavioral file.
- Many `0` values mean many trials are removed as incorrect, which lowers the final epoch
  count. This is expected for low-performance participants.

## ICA runs slowly

- Roughly 10–20 minutes per subject for ~600,000 samples is normal.

## Master log summary

At the end of a batch run, `processing_log.txt` reports per-file `[SUCCESS]`/`[FAILED]`
lines and a final summary with total files, successes, failures, and success rate.
