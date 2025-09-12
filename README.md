# ProtoplastViability

Workflow to calculate the viability of protoplasts based on a FDA assay. The workflow consits of a ImageJ/Fiji macro (01_ViabilitySegmentation.ijm) to deal with images, and a python script (02_CalculateViability.py) to calculate the viability based on the Fiji macro output.
Both scripts use some type of selection window to specify the working directory. This allows for greater flexibility, but also slows the excecution. If this becomes a problem, it is suggested to replace the code for opening a selection window with an absolute/relavive path for your working directory.

## 01_ViabilitySegmentation.ijm

This ImageJ/Fiji macro opens all images in a user-specified working directory, segments the BF and the FDA channels, and counts the amount of cells in the respective channels. This data can be used to calculate viability of large batches of images. There are three options to execute the macro:
- Plugins > Macros > Run > select the file *'01_ViabilitySegmentation.ijm'* (For single execution of the unedited script)
- Plugins > Macros > Run > select the file *'01_ViabilitySegmentation.ijm'* (For repeated execution of the unedited script)
- File > Open > select the file *'01_ViabilitySegmentation.ijm'* > edit the script in the Fiji macro editor > Run (For single execution of the edited script)

### Working directory

Upon excecution, the macro prompts the user to select a working directory. This working directory should contain:
- A directory called '00_raw', where the raw image files to be analysed are located

### Channel selection

The macro assumes that the BF and FDA images are presented as different channels. You are asked to provide the number of the channel of the BF and FDA image ('1' for the first slice, '2' for the second, etc.).

### Output structure

Once finished, the folder '01_analysis' will be added to the working directory. Here, you'll find the following outputs:
- 01_analysis/control: .tif exports of the BF and FDA channels for each image, as well as .jpg images that indicate which cells are counted, and .jpg images of the segmentation. Use these outputs to check the quality of the segmentation/troubleshoot any problems.
- 01_analysis/results: .csv files for each image channel (seperate files for BF and FDA), with the results from the analysis.
- 01_analysis/summary.csv: a summary file with the count for each image channel. This is used as input for *'02_CalculateViability.py'*.

## 02_CalculateViability.py

This Python script reads the *summary.csv* output from the ImageJ/Fiji macro, and calculates viability based on the amount of cells counted in the BF and FDA slice of each replicate. It then groups the replicates by condition, and calculates the mean viability, amount of replicates (Count), and standard deviation of that condition. It also produces a box/violin plot of the viability for each condition.

*Viability = (FDA cell count / BF cell count) x 100%*

(!) Make sure that replicates of a single condition are indicated by the suffix (_00x), where x indicates the index of that replicate (so _001, _002, etc.). 
Images taken using Nikon's NIS software contain such a suffix by default.

### Execution

Upon excecution, the script prompts the user to select a working directory. This should be the same working directory as used for the ImageJ/Fiji macro (or at least, the selected directory should contain *analysis/summary.csv*). The Python script will generate two .csv files:
- 'viability.csv', which contains the calculated viability for all replicates
- 'viability_statistics.csv', which contains the mean, count, and standard deviation of the viability for each condition.

Both these outputs can be used for further analysis/data visualisation.

