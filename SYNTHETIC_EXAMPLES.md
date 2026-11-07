# Download and test the synthetic examples

Each download includes synthetic inputs, a runnable example, expected outputs,
and an automatic comparison report. **All eight packaged examples passed** on
November 7, 2026, after extraction into a new folder containing spaces.

These ZIPs come from main and include the tested readiness fixes, synthetic
inputs, example runners, and reference outputs.

QuickLab and Spatiotemporal_PCA_Data_Driven are private repositories: their GitHub
downloads require sign-in and repository access. An owner can also download a
ZIP and share that archive with the intended user. The other six repositories
are public. This index is hosted in the private QuickLab repository as well.

| Repository | Run it with | Included check | Download and instructions |
|---|---|---|---|
| QuickLab | EEGLAB plugin | Infinity minus Average: mean 2 microvolts; RMS 2.121320344 | [ZIP](https://github.com/MPG-Git/QuickLab/archive/refs/heads/main.zip) · [Guide](https://github.com/MPG-Git/QuickLab/blob/main/QuickLab_11.12.21_NL/examples/synthetic/README.md) |
| NeuroLode | EEGLAB plugin + Audio Toolbox | 10/15/20 Hz centroids; exact epoch-average export | [ZIP](https://github.com/MPG-Git/NeuroLode/archive/refs/heads/main.zip) · [Guide](https://github.com/MPG-Git/NeuroLode/blob/main/Neurolode1.7/examples/synthetic/README.md) |
| eeg_preprocess_BrainVision | MATLAB + EEGLAB plugins | BrainVision import, ASR/ICA/ICLabel, 9-channel average-reference result | [ZIP](https://github.com/MPG-Git/eeg_preprocess_BrainVision/archive/refs/heads/main.zip) · [Guide](https://github.com/MPG-Git/eeg_preprocess_BrainVision/blob/main/examples/synthetic/README.md) |
| Spatiotemporal_PCA_Data_Driven | MATLAB + EEGLAB + Statistics Toolbox | 2 temporal factors, 1 spatial factor; rotation and loading checks | [ZIP](https://github.com/MPG-Git/Spatiotemporal_PCA_Data_Driven/archive/refs/heads/main.zip) · [Guide](https://github.com/MPG-Git/Spatiotemporal_PCA_Data_Driven/blob/main/examples/synthetic/README.md) |
| roi-mask-builder | MATLAB + full SPM12 | Exact 8-voxel mask on a shifted grid | [ZIP](https://github.com/MPG-Git/roi-mask-builder/archive/refs/heads/main.zip) · [Guide](https://github.com/MPG-Git/roi-mask-builder/blob/main/examples/synthetic/README.md) |
| FSL_Windows_WSL2_TOPUP | Linux/WSL2 + FSL | Two actual TOPUP runs on a zero-distortion phantom | [ZIP](https://github.com/MPG-Git/FSL_Windows_WSL2_TOPUP/archive/refs/heads/main.zip) · [Guide](https://github.com/MPG-Git/FSL_Windows_WSL2_TOPUP/blob/main/examples/synthetic/README.md) |
| Caret_ml_pipeline | R | 18 classifier/sampling combinations; accuracy and AUC comparisons | [ZIP](https://github.com/MPG-Git/Caret_ml_pipeline/archive/refs/heads/main.zip) · [Guide](https://github.com/MPG-Git/Caret_ml_pipeline/blob/main/examples/synthetic/README.md) |
| Neurotoolbox | Python | All three analysis CLIs, reference CSVs and plots | [ZIP](https://github.com/MPG-Git/Neurotoolbox/archive/refs/heads/main.zip) · [Guide](https://github.com/MPG-Git/Neurotoolbox/blob/main/examples/synthetic/README.md) |

Extract the ZIP to a writable folder, install the dependencies in its guide,
and run the example. Success writes `PASS.txt` and a `comparison.csv` report.
The guide describes each output and its comparison tolerance. Default output
folders cannot be reused, so old results cannot masquerade as a fresh run.

The files are generated data, not participant recordings. These examples test
the illustrated workflows; they do not validate scientific use for a study.
Manual Neurolode menu checks remain part of its pre-release checklist.

QuickLab's earlier Infinity/Average comparison repair remains available on main.
Its downloadable example is included in the main-branch ZIP linked above.
