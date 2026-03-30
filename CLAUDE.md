# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick start

This is a MATLAB evaluation toolkit. There is no dedicated build or lint system; work is done by editing `Src/*.m`, adjusting `Src/config.m`, and running the relevant entry script.

```powershell
matlab -batch "run('Src/main_calculateATE.m')"
matlab -batch "run('Src/main_plotAPE.m')"
matlab -batch "run('Src/main_plotBoxViolin.m')"
matlab -batch "run('Src/main_evaluateCBEE.m')"
matlab -batch "run('Src/main_errorTimeSeries.m')"
matlab -batch "run('Src/main_plotLoopClosures.m')"
```

Single-test example:

```powershell
matlab -batch "addpath(genpath('Src')); addpath('Test'); test_computeRmsConsistencyError"
```

## Repository map

- `Src/config.m`: shared configuration center for paths, visualization, export, and per-module parameters.
- `Src/main_*.m`: workflow entry scripts. They load config, validate inputs, call helper functions, and export results.
- `Src/*.m`: implementation functions for parsing trajectories, alignment, plotting, CBEE computation, submap loading, and loop visualization.
- `Test/`: mixed validation directory. Some files are callable MATLAB test functions; others are manual workflow scripts tied to local datasets.
- `Data/`: source trajectories and submaps.
- `Results/`: generated outputs, usually timestamped.
- `Docs/`: human-facing module documentation.

## Workflow notes

- Start with `Src/config.m` when changing dataset paths, labels, figure sizes, export formats, or algorithm parameters.
- Start with the matching `main_*.m` file when changing workflow behavior.
- Treat `main_*.m` as orchestration scripts, not reusable APIs.
- Prefer the current code in `Src/` over documentation if they disagree.

## Module-specific hints

- ATE has two separate flows:
  1. **Single-dataset ATE** (`main_calculateATE.m`): configured via `cfg.ate`. Reads one `input_folder`, computes ATE for corrupted/optimized trajectories, saves per-run CSV + figures to `Results/ATE/ATE_data`.
  2. **Multi-dataset violin comparison** (`main_plotBoxViolin.m`): configured via `cfg.ateViolin`. Reads a `datasets` struct array (each with `id`/`displayName`/`gtPath`/`slamPath`), computes ATE on the fly from raw trajectories (no pre-computed CSV needed), then calls `plotATEDistributions`. Adding a new dataset only requires a config change. Dataset order in the array determines the x-axis order of the violin plot. `plotATEDistributions.m` accepts either `'files'` (CSV paths) or `'data'` (cell array of error vectors).
- APE: `main_plotAPE.m` sits on top of `plotAPEComparison.m`.
- CBEE: `main_evaluateCBEE.m` is the heaviest workflow. Read it together with `loadAllSubmaps.m`, `generateOptimizedSubmaps.m`, `buildCbeeErrorGrid.m`, `computeRmsConsistencyError.m`, and `visualizeSubmaps.m` before editing.
- Error time series: supports 1 reference dataset + multiple benchmark datasets + 1 configurable INS curve. Configured via referenceDataset, benchmarkDatasets (struct array), and ins.sourceDatasetId in config.m. Adding a new benchmark only requires config changes, no code edits. errorTimeSeries.m loops over all datasets; main_errorTimeSeries.m handles dynamic path validation and plotting driven by vis.metricOrder + vis.curves list. vis.curves is a struct array (not struct fields). NOTE: errorTimeSeries and APE share the same error logic (XY positional error, slam vs original), but differ in calculation method (submap-level expanded to ping-level vs per-pose) and x-axis (pseudo time via pingDt vs pose index). APE calculation is currently not needed and should not be added.
- Loop closures: `main_plotLoopClosures.m` loads one pose file and one `loop_closures.txt`; `plotLoopClosures.m` converts loop records to graph edges and renders odometry edges plus loop edges in XY.

## Testing notes

There is no single unified test runner. Validate changes by running the relevant `main_*.m` workflow and then the closest matching script/function in `Test/`. Some older tests appear to target earlier config layouts, so verify assumptions before treating them as authoritative.
