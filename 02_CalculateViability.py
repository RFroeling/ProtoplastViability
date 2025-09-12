import pandas as pd
import os
from tkinter import Tk, filedialog
import matplotlib.pyplot as plt
import numpy as np

# Prompt user to select a working directory
def select_working_directory():
    Tk().withdraw()  # Hide the root Tkinter window
    return filedialog.askdirectory(title="Select Working Directory")

# Function to calculate viability
def calculate_viability(df):
    results = []
    
    # Filter the data to get only _BF and _FDA rows
    bf_rows = df[df['Slice'].str.endswith('_BF')]
    fda_rows = df[df['Slice'].str.endswith('_FDA')]
    
    # Loop through BF rows and match them with the corresponding FDA rows
    for index, bf_row in bf_rows.iterrows():
        slice_prefix = bf_row['Slice'].replace('_BF', '')
        
        # Find the corresponding FDA row
        fda_row = fda_rows[fda_rows['Slice'].str.startswith(slice_prefix)]
        
        if not fda_row.empty:
            # Calculate viability
            bf_count = bf_row['Count']
            fda_count = fda_row['Count'].values[0]
            viability = (fda_count / bf_count) * 100
            
            # Extract condition (everything before "_00x")
            condition = slice_prefix.rsplit("_", 1)[0]  # Split at the last underscore
            
            # Append the result to the list
            results.append({
                'Slice Prefix': slice_prefix,
                'Condition': condition,
                'Viability': viability
            })

    return pd.DataFrame(results)

# Function to calculate statistics for each condition
def calculate_statistics(viability_df):
    stats = viability_df.groupby('Condition')['Viability'].agg(
        Mean='mean',
        Count='count',
        StdDev='std'
    ).reset_index()
    return stats

# Function to plot statistics
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
viability_df = calculate_viability(df)
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