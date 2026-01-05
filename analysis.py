import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from tkinter import filedialog


def select_working_directory():
    """Opens selection window to select the working directory. Should be the same path as used in the FIJI macro.

    Working directory should contain "01_analysis/viability.csv".

    Returns:
        string: Path to working directory.
    """
    return filedialog.askdirectory(title="Select Working Directory")


def calculate_viability(bf_row: pd.Series, fda_row: pd.Series) -> float:
    """Calculates viability of a single BF/FDA pair.

    *Viability = (FDA cell count / BF cell count) x 100%*

    Args:
        bf_row (pd.Series): Brightfield row extracted from DataFrame containing summary data.
        fda_row (pd.Series): Corresponding FDA row.

    Returns:
        float: Viability
    """
    bf_count = bf_row['Count']
    fda_count = fda_row['Count'].values[0]

    return (fda_count / bf_count) * 100


def viability_per_sample(df):
    """Calculates viability of all sample-entries in the summary DataFrame.

    Assumes replicates are indicated by the suffix (_00x), where x indicates the index of that replicate (so _001, _002, etc.). 

    Args:
        df (pd.DataFrame): DataFrame containing the summary output from the FIJI macro.

    Returns:
        pd.DataFrame: DataFrame containing the calculated viability for each image (BF/FDA pair).
    """
    results = [] # Initialize list to hold viability data
    
    bf_rows = df[df['Slice'].str.endswith('_BF')]
    fda_rows = df[df['Slice'].str.endswith('_FDA')]
    
    for _, bf_row in bf_rows.iterrows():
        slice_prefix = bf_row['Slice'].replace('_BF', '')      
        fda_row = fda_rows[fda_rows['Slice'].str.startswith(slice_prefix)] # Find the corresponding FDA row
        
        if not fda_row.empty:
            viability = calculate_viability(bf_row, fda_row)
            condition = slice_prefix.rsplit("_", 1)[0] # Extract condition (everything before "_00x")
            results.append({
                'Slice Prefix': slice_prefix,
                'Condition': condition,
                'Viability': viability
            })

    return pd.DataFrame(results)


def calculate_statistics(df: pd.DataFrame):
    """Groups viability data by condition and calculates mean, sample size and standard deviation.

    Args:
        df (pd.DataFrame): DataFrame containing viability data per image

    Returns:
        pd.DataFrame: DataFrame containing calculated statistics per condition.
    """
    stats = df.groupby('Condition')['Viability'].agg(
        Mean='mean',
        Count='count',
        StdDev='std'
    ).reset_index()
    
    return stats


def boxplot(df: pd.DataFrame):
    pass


def violin_plot(df: pd.DataFrame):
    pass


def plot_viability(df, plot_type="violin"):
    # Ensure valid input
    if plot_type not in ["violin", "box"]:
        raise ValueError("plot_type must be 'violin' or 'box'")
    
    grouped = df.groupby("Condition")["Viability"].apply(list)
    conditions = grouped.index
    data = grouped.values

    fig, ax = plt.subplots(figsize=(5, 8))
    
    # Choose plot type
    if plot_type == "violin":
        parts = ax.violinplot(data, showmeans=True, showextrema=False)
        parts['cmeans'].set_color('black')  # Set mean line color
        for pc in parts['bodies']:
            pc.set_facecolor('#548235')
            pc.set_edgecolor('black')
            pc.set_alpha(0.6)
    else:  # boxplot
        bp = ax.boxplot(data, patch_artist=True, widths=0.6)
        for patch in bp['boxes']:
            patch.set_facecolor("#548235")
            patch.set_alpha(0.6)
    
    # Add individual points
    for i, vals in enumerate(data, start=1):
        x = np.random.normal(i, 0.04, size=len(vals))  # jitter
        ax.scatter(x, vals, color='black', alpha=0.7, s=20, zorder=3)

    # Annotate mean ± std
    for i, vals in enumerate(data, start=1):
        mean_val = np.mean(vals)
        std_val = np.std(vals)
        ax.text(i, mean_val + std_val + 2, f"{mean_val:.1f} ± {std_val:.1f}",
                ha='center', va='bottom', fontsize=9, fontweight='bold')
        
    # Extend y-axis so annotations fit
    max_val = max([max(vals) for vals in data])
    ax.set_ylim(top=max_val * 1.025)  # 2.5% higher than max datapoint

    # Formatting
    ax.set_xticks(range(1, len(conditions) + 1))
    ax.set_xticklabels(conditions, rotation=45, ha="right")
    ax.set_ylabel("Viability (%)")

    plt.tight_layout()
    plt.savefig(plot_output_path, dpi=300)
    plt.show()

# ========== Excecution ==========

# Prompt user for the working directory
working_dir = select_working_directory()
if not working_dir:
    print("No directory selected. Exiting...")

# Load the summary CSV file
file_path = os.path.join(working_dir, '01_analysis', 'summary.csv')
if not os.path.exists(file_path):
    print(f"File not found: {file_path}")
    
df = pd.read_csv(file_path)
print(df)

# Calculate viability
viability_df = viability_per_sample(df)
print(viability_df)

# Calculate statistics for each condition
stats_df = calculate_statistics(viability_df)

# Save the results
viability_output_path = os.path.join(working_dir, '01_analysis/viability.csv')
stats_output_path = os.path.join(working_dir, '01_analysis/viability_statistics.csv')
plot_output_path = os.path.join(working_dir, '01_analysis/viability_plot.png')

viability_df.to_csv(viability_output_path, index=False)
stats_df.to_csv(stats_output_path, index=False)

# Plot the statistics
plot_viability(viability_df, plot_type='violin')
print(f"Viability results saved to: {viability_output_path}")
print(f"Statistics saved to: {stats_output_path}")
print(f"Plot saved to: {plot_output_path}")