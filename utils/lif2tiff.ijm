lifPath = File.openDialog("Select LIF file");
// lifDir = getDirectory(pathFile); Might use later to auto-select the output directory

// Output folder
outputDir = getDirectory("Choose output folder");

function sanitize_filename(unsafe) {
	/*
	Pure function that converts an arbitrary string into a safe filename.

	Args: unsafe (string) - the original, possibly unsafe string

	Returns: safe (string) - a version that is safe to use as a filename
	*/
	illegal = newArray("/", "\\", ":", "*", "?", "\"", "<", ">", "|");
	safe = unsafe;

	// Replace illegal characters (and control characters) with underscores
	for (i = 0; i < illegal.length; i++)
		safe = replace(safe, "\\" + illegal[i], "_");

	// Collapse any other whitespace control characters
	safe = replace(safe, "[\\r\\n\\t]+", "_");

	// Windows disallows trailing dots and spaces
	safe = replace(safe, "[. ]+$", "");

	// Fall back to a placeholder if nothing is left
	if (lengthOf(safe) == 0)
		safe = "unnamed";

	// Keep length within common filesystem limits (255 bytes)
	if (lengthOf(safe) > 200)
		safe = substring(safe, 0, 200);

	return safe;
}

setBatchMode(true);

// Get the number of series in the LIF
run("Bio-Formats Macro Extensions");
Ext.setId(lifPath);
Ext.getSeriesCount(seriesCount);
print("Found " + seriesCount + " series in file.");

// Loop through each series
for (i = 0; i < seriesCount; i++) {

    // Set current series
    Ext.setSeries(i);

    // Get series title
    Ext.getSeriesName(seriesName);
    
    // Sanitize series title
    saveName = sanitize_filename(seriesName);
	
	// Open the series
	run("Bio-Formats Importer", "open=[" + lifPath + "] autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_" + i);

 	// Save the series as TIFF
	savePath = outputDir + "Series" + i + "_" + saveName + ".tif";
	saveAs("Tiff", savePath);
	print("Saved to: " + savePath);
	
	// Close the image to free memory
	close("*");
}

setBatchMode(false);

// Close Bio-Formats
Ext.close();
print("All series processed.");