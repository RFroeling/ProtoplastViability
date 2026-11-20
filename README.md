# ProtoplastViability

## Overview

This workflow calculates protoplast viability using an FDA (Fluorescein Diacetate) assay. It consists of a FIJI macro ([segmentation.ijm](segmentation.ijm)) that segments microscopy images and counts cells, and a Python script ([analysis.py](analysis.py)) that calculates viability from the FIJI results.

**Viability** is calculated as the ratio of viable cells (FDA-stained) to total cells (brightfield) in protoplast samples, useful for assessing cell viability across multiple replicates and experimental conditions.

*Note on directory selection:* Both scripts use a selection window to specify the working directory.

## Input files

The FIJI segmentation macro reads files from `00_raw/`. It opens supported image formats through the Bio-Formats Windowless Importer.

If the source images are Leica `.lif` files, convert them before running [segmentation.ijm](segmentation.ijm):

1. Open [utils/lif2tiff.ijm](utils/lif2tiff.ijm) in FIJI and run it.
2. Select the `.lif` file.
3. Select the output folder.
4. The macro exports every LIF series as a TIFF named `Series<index>_<series name>.tif`.
5. Copy or move those TIFF files into the working directory's `00_raw/` folder.

Only the exported TIFF files in `00_raw/` are processed by `segmentation.ijm`. The original `.lif` file should not be placed in `00_raw/` when TIFF conversion has been used.

## Installation

Installation is only required for the Python-portion of this workflow. If your goal is to only segment images and manually process the resulting data, no installation is required. Simply download the [macro](segmentation.ijm) and execute in FIJI.

```bash
git clone https://github.com/RFroeling/ProtoplastViability.git
cd ProtoplastViability
```

This project uses [uv](https://github.com/astral-sh/uv) for fast dependency management. If you don't have uv installed, install it first, then clone the repository and install dependencies using:

```bash
uv sync
```

### Alternative: Using pip

A requirements.txt file is provided for compatibility with pip. It is recommended to install the Python requirements in a virtual environment (something [uv](https://github.com/astral-sh/uv) does automatically):

```bash
python -m venv .venv
.venv\Scripts\activate

pip install -r requirements.txt
```

## segmentation.ijm

This FIJI macro opens all images in a user-specified working directory, segments the BF and the FDA channels, and counts the amount of cells in the respective channels. This data can be used to calculate viability of large batches of images. The easiest way to execute the code:

- File > Open > *segmentation.ijm* > Run

### Working directory

Upon execution, the macro prompts the user to select a working directory. This working directory should contain:

- A directory called `00_raw`, containing the raw TIFF or otherwise supported microscopy image files to be analysed. For `.lif` inputs, use [utils/lif2tiff.ijm](utils/lif2tiff.ijm) first as described above.

### Setting selection

After selecting the working directory, enter the segmentation settings. Provide the minimum and maximum particle size, minimum and maximum circularity, the BF and FDA channel indices, and the thresholding algorithms. Channel indices use ImageJ channel names (for example, `1` or `2`). The macro's default BF channel is `C2` and its default FDA channel is `C1`.

Z-stacks are automatically flattened using a maximum intensity projection.

### Output structure

Once finished, the folder '01_analysis' will be added to the working directory. Here, you'll find the following outputs:

- 01_analysis/control: TIFF exports and JPG control/composite images for checking segmentation and cell counting.
- 01_analysis/results: separate CSV result files for the BF and FDA channels of each image.
- 01_analysis/summary.csv: a summary file with the count for each image channel. This is used as input for *analysis.py*.

## analysis.py

This Python script reads `01_analysis/summary.csv`, pairs the BF and FDA counts for each image, and calculates viability. It also groups replicates by condition and calculates the mean viability, replicate count, and standard deviation. The script saves a box plot of the viability for each condition.

$$\text{Viability} = \frac{\text{FDA cell count}}{\text{BF cell count}} \times 100\%$$

### Dealing with replication

Replicate names must end in a suffix such as `_001`, `_002`, and `_003`. The text before this final suffix is used as the condition name. For example, `TreatmentA_001` and `TreatmentA_002` are grouped as `TreatmentA`.

### Execution

Run the script with:

```bash
uv run analysis.py
```

The script prompts the user to select the working directory. This should be the same directory used for the FIJI macro and contain `01_analysis/summary.csv`. It generates:

- `01_analysis/viability.csv`: calculated viability for all replicates
- `01_analysis/viability_statistics.csv`: mean, count, and standard deviation for each condition
- `01_analysis/viability_plot.png`: a box plot of viability by condition

Both these outputs can be used for further analysis/data visualisation.

## Requirements

### System Requirements

- **FIJI**: For running the segmentation and LIF conversion macros. The macros require the FIJI Bio-Formats plugins.
- **Python**: 3.13 or higher

### Python Dependencies

The following Python packages are required (see [requirements.txt](requirements.txt) for full list and versions):

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
  affiliation={Wageningen University \& Research}
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

- Ensure replicates are properly named with a numeric suffix such as `_001` or `_002`
- Verify that `01_analysis/summary.csv` exists
- Check that the CSV format matches the expected output from the FIJI macro

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests to improve this workflow.
