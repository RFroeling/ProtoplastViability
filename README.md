# ProtoplastViability

## Overview

Workflow to calculate the viability of protoplasts using an FDA (Fluorescein Diacetate) assay. The workflow consists of a FIJI macro (segmentation.ijm) to process microscopy images, and a Python script (analysis.py) to calculate viability based on cell counts from the FIJI macro output.

**Viability** is calculated as the ratio of viable cells (FDA-stained) to total cells (brightfield) in protoplast samples, useful for assessing cell viability across multiple replicates and experimental conditions.

*Note on file selection:* Both scripts use a selection window to specify the working directory. This allows for greater flexibility, but also slows execution. If this becomes a problem, consider replacing the selection window code with an absolute/relative path to your working directory.

## Installation

```bash
git clone https://git.wur.nl/froel001/protoplastviability.git
cd protoplastviability

# It is recommended to install the Python requirements in a virtual environment:
python -m venv .venv
venv\Scripts\activate

pip install -r requirements.txt
```

## segmentation.ijm

This FIJI macro opens all images in a user-specified working directory, segments the BF and the FDA channels, and counts the amount of cells in the respective channels. This data can be used to calculate viability of large batches of images. The easiest way to execute the code:

- File > Open > *segmentation.ijm* > Run

### Working directory

Upon excecution, the macro prompts the user to select a working directory. This working directory should contain:

- A directory called '00_raw', where the raw image files to be analysed are located

### Channel selection

The macro assumes that the BF and FDA images are presented as different channels. You are asked to provide the number of the channel of the BF and FDA image ('1' for the first slice, '2' for the second, etc.).

Z-stacks are automatically flattened using a maximum intensity projection.

### Output structure

Once finished, the folder '01_analysis' will be added to the working directory. Here, you'll find the following outputs:

- 01_analysis/control: .tif exports of the BF and FDA channels for each image, as well as .jpg images that indicate which cells are counted, and .jpg images of the segmentation. Use these outputs to check the quality of the segmentation/troubleshoot any problems.
- 01_analysis/results: .csv files for each image channel (seperate files for BF and FDA), with the results from the analysis.
- 01_analysis/summary.csv: a summary file with the count for each image channel. This is used as input for *analysis.py*.

## analysis.py

This Python script reads the *summary.csv* output from the *segmentation.ijm* and calculates viability based on the amount of cells counted in the BF and FDA slice of each replicate. It then groups the replicates by condition, and calculates the mean viability, amount of replicates (Count), and standard deviation of that condition. It also produces a box/violin plot of the viability for each condition.

$$\text{Viability} = \frac{\text{FDA cell count}}{\text{BF cell count}} \times 100\%$$

### Dealing with replication

Make sure that replicates of a single condition are indicated by the suffix (_00x), where x indicates the index of that replicate (so_001, _002, etc.). Images taken using Nikon's NIS software contain such a suffix by default.

### Execution

Upon excecution, the script prompts the user to select a working directory. This should be the same working directory as used for the FIJI macro (or at least, the selected directory should contain *analysis/summary.csv*). The Python script will generate two .csv files:

- 'viability.csv', which contains the calculated viability for all replicates
- 'viability_statistics.csv', which contains the mean, count, and standard deviation of the viability for each condition.

Both these outputs can be used for further analysis/data visualisation.

## Requirements

### System Requirements

- **FIJI/ImageJ**: For running the segmentation macro (segmentation.ijm)
- **Python**: 3.7 or higher

### Python Dependencies

The following Python packages are required (see `requirements.txt` for full list and versions):

- **pandas**: Data manipulation and CSV handling
- **numpy**: Numerical computations
- **matplotlib**: Plotting and visualization

Install all dependencies with:

```bash
pip install -r requirements.txt
```

## Authors

- **Rik Froeling** (Wageningen University & Research) - [ORCID: 0009-0007-3879-1329](https://orcid.org/0009-0007-3879-1329)
- **Joris Sprakel** (Wageningen University & Research) - [ORCID: 0000-0001-6532-4514](https://orcid.org/0000-0001-6532-4514)

## License

This project is licensed under the **Creative Commons Attribution 4.0 International License**. See the [LICENSE](LICENSE) file for details.

## Citation

If you use this software in your research, please cite it using the following metadata:

```bibtex
@software{ProtoplastViability,
  title={ProtoplastViability},
  author={Froeling, Rik and Sprakel, Joris},
  affiliation={Wageningen University \& Research},
  doi={},
  year={2024}
}
```

For the most up-to-date citation information, refer to the [CITATION.cff](CITATION.cff) file.

## Troubleshooting

### Segmentation Issues

If the cell segmentation quality is poor, consider:

- Adjusting the image preprocessing parameters in the macro
- Verifying that images are correctly placed in the `00_raw` directory
- Checking the quality of the channel separation
- Reviewing the control images in `01_analysis/control`

### Python Script Issues

- Ensure replicates are properly named with the suffix `_00x` (e.g., `sample_001`, `sample_002`)
- Verify that `summary.csv` exists in the working directory's `analysis` folder
- Check that the CSV format matches the expected output from the FIJI macro

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests to improve this workflow.
