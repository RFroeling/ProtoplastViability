// ================== Function definition ==================

// Function to indicate in which of the stack slices the BF and FDA images are located
function getSlice() {
	// Prompt user to indicate the slice index in which the BF and FDA images are located
	BF_index = getNumber("Indicate the slice containing the BF image", 0);
	FDA_index = getNumber("Indicate the slice containing the FDA image", 0);
	
	// Convert FDA slice integer to string with preceding zeroes
	BF_slice = d2s(BF_index, 0); // Convert integer to string
	BF_slice = "000" + BF_slice; // Add preceding zeroes to string
	
	// Convert FDA slice integer to string with preceding zeroes
	FDA_slice = d2s(FDA_index, 0); // Convert integer to string
	FDA_slice = "000" + FDA_slice; // Add preceding zeroes to string
	
	// Return the slices array for later use
	return newArray(BF_slice, FDA_slice);
}


// Function to check whether a window with a specific title exists
function isOpen(title) {
    list = getList("window.titles"); // Obtain a list of all the titles of open windows
    for (i = 0; i < list.length; i++) { // Iterate over each item of the list
        if (list[i] == title) { // Check whether the requested title occurs in the list of open windows
            return true; // Return true if requested window is open
        }
    }
    return false; // Return false if requested window is not open
}


// Function to set up the working directory to contain the correct subdirectories for storing the results
function DirectorySetup() {
   working_dir = getDirectory("Select working directory"); // Open selection window to specify working directory
    
	// Define input directory, raise error if it doesn't exist
	input_dir = working_dir + "raw/";
	
	if (!File.exists(input_dir)) {
		print("Error: Input directory ('../raw/') does not exist! \n");
		exit();  // Exit the macro
	}
    
	// Define output directories
	output_dir = working_dir + "analysis/";
	control_dir = output_dir + "control/";
	results_dir = output_dir + "results/";

	// Raise error if output directory already exists
	if (File.exists(output_dir)) {
		print("Error: Output directory already exists, stopping macro to prevent overwriting data! \n");
		exit();  // Exit the macro
	}
	
	// Create output directories if they don't exist
	else {
		File.makeDirectory(output_dir);
		File.makeDirectory(control_dir);
		File.makeDirectory(results_dir);
		
		print("Directories created:\n" + substring(output_dir, lengthOf(output_dir) - 9) + 
		"\n" + substring(control_dir, lengthOf(control_dir) - 17) + 
		"\n" + substring(results_dir, lengthOf(results_dir) - 17) + "\n");
	}
	
    // Return the directories array for later use
    return newArray(input_dir, control_dir, output_dir, results_dir);
}


// Function for image (pre-)processing, segmentation, and counting of cell viability
function Viability(input, control_output, filename) {
	run("Bio-Formats Windowless Importer", "open=[" + input + filename + "]"); // Open image stack
	
	// Obtain the filename without extension for later handling
	pure_filename = File.nameWithoutExtension;
	
	// Statement to show progress 
	print("Analyzing " + pure_filename + "...");

	// Image pre-processing
	setOption("ScaleConversions", true);
	run("8-bit"); // Convert all images to 8-bit
	run("Stack to Images"); // Separate stack into different channels
	
	// Select, save, and duplicate BF and FDA channel
	//BF
	selectImage("raw/" + pure_filename + "-" + slices[0]); // Select BF image
	run("Grays"); // Apply LUT
	saveAs("Tiff", control_output + pure_filename + "_BF"); // Save the original image for later reference
	rename(pure_filename + "_BF_control"); // Rename the image for later handling
	run("Duplicate...", "title=" + pure_filename + "_BF"); // Duplicate the image for later handling
	
	//FDA
	selectImage("raw/" + pure_filename + "-" + slices[1]); // Select the FDA image
	run("Green"); // Apply LUT
	saveAs("Tiff", control_output + pure_filename + "_FDA"); // Save the original image for later reference
	rename(pure_filename + "_FDA_control"); // Rename the image for later handling
	run("Duplicate...", "title=" + pure_filename + "_FDA"); // Duplicate the image for later handling
	
	
	// ---------- Processing, segmentation and analysis of BF image > ADJUST PARAMETERS HERE FOR BF IMAGE ----------
	
	// Select BF image
	selectImage(pure_filename + "_BF");
	
	// Image processing - ADJUSTABLE
	run("Gaussian Blur...", "sigma=2"); // Blur
	run("Subtract Background...", "rolling=20 light sliding"); // Remove background noise
	
	// Segmentation - ADJUSTABLE
	setAutoThreshold("MaxEntropy no-reset"); // Make image binary according to specified protocol
	setOption("BlackBackground", true); // Background is black, foreground is white
	run("Convert to Mask");
	run("Dilate"); // Widen the segmentation size
	run("Fill Holes"); // Fill holes in segmented cells
	run("Watershed"); // Single pixel black line to separate neighbouring cells
	
	// Save segmented image for later reference
	saveAs("Jpeg", control_output + pure_filename + "_BF_segmented"); // Save segmented image for later reference
	
	// Analysis - ADJUSTABLE 
	run("Analyze Particles...", "size=100-Infinity circularity=0.75-1.00 show=Ellipses display exclude clear include summarize");
	
	// -------------------------------------------------------------------------------------------------------------
	
	// Check if the "Results" window is open
	if (isOpen("Results")) {
    	// Save results as .csv
    	selectWindow("Results"); // Select 'Results' window
    	saveAs("Results", directories[3] + pure_filename + "_BF_results.csv"); // Save as .csv
    	close("Results"); // Close results window
	} 
	// No results window? Skip saving and continue
	else {
   		print("No 'Results' window open. Skipping save operation. \n");
	}
	
	// Overlay of fitted ellipses on the original BF image
	selectWindow("Drawing of " + pure_filename + "_BF");
	run("Magenta"); // Apply 'Magenta' LUT - Magenta background, black ellipses
	run("Invert LUT"); // Invert LUT - Black background - magenta ellipses
	run("Dilate"); // Increase width of ellipse stroke
	run("Merge Channels...", "c4=" + pure_filename + "_BF_control c6=[Drawing of " + pure_filename + "_BF] create keep"); // Overlay ellipse fit onto original FDA image
	saveAs("Jpeg", control_output + pure_filename + "_BF_composite"); // Save overlay for later referencing
	
	// Convert ellipse fit of BF image to mask
	selectImage("Drawing of " + pure_filename + "_BF"); // Select ellipse fit of BF image
	rename("FDA_mask"); // Rename the image for later handling
	run("Fill Holes"); // Solid fill of fitted ellipses
	run("Dilate"); // Increase size of mask
	run("Dilate"); // Increase size of mask
	run("Apply LUT"); // Fix the applied LUT	
	
	// ---------- Processing, segmentation and analysis of FDA image > ADJUST PARAMETERS HERE FOR FDA IMAGE ----------
	
	// Select FDA image
	selectImage(pure_filename + "_FDA");
	
	// Image processing - ADJUSTABLE
	run("Gaussian Blur...", "sigma=2"); // Blur
//	run("Subtract Background...", "rolling=50");  // Remove background noise
	
	// Segmentation - ADJUSTABLE
	setAutoThreshold("Triangle dark no-reset"); // Make image binary according to specified protocol
	setOption("BlackBackground", true); // Background is black, foreground is white
	run("Convert to Mask");
	run("Dilate"); // Widen the segmentation size
	run("Fill Holes"); // Fill holes in segmented cells
	run("Watershed"); // Single pixel black line to separate neighbouring cells
	rename(pure_filename + "_FDA_segmented"); // Rename for later handling
	
	// Apply BF mask
	imageCalculator("AND create", pure_filename + "_FDA_segmented","FDA_mask"); // Overlay BF fit mask on segmented FDA image
	
	// Save segmented and masked image for later reference
	saveAs("Jpeg", control_output + pure_filename + "_FDA_segmented");
	rename(pure_filename + "_FDA"); // Rename for later handling
	
	// Analysis - ADJUSTABLE 
	run("Analyze Particles...", "size=100-Infinity circularity=0.75-1.00 show=Ellipses display exclude clear include summarize");
	
	// -------------------------------------------------------------------------------------------------------------
	
	// Check if the "Results" window is open
	if (isOpen("Results")) {
    	// Save results as .csv
    	selectWindow("Results"); // Select 'Results' window
    	saveAs("Results", directories[3] + pure_filename + "_FDA_results.csv"); // Save as .csv
    	close("Results"); // Close results window
	} 
	// No results window? Skip saving and continue
	else {
   		print("No 'Results' window open. Skipping save operation. \n");
	}
	
	// Overlay of fitted ellipses on the original FDA image
	selectWindow("Drawing of " + pure_filename + "_FDA"); // Select window containing ellipse fit
	run("Magenta"); // Apply 'Magenta' LUT - Magenta background, black ellipses
	run("Invert LUT"); // Invert LUT - Black background - magenta ellipses
	run("Dilate"); // Increase width of ellipse stroke
	run("Merge Channels...", "c2=" + pure_filename + "_FDA_control c6=[Drawing of " + pure_filename + "_FDA] create keep"); // Overlay ellipse fit onto original FDA image
	saveAs("Jpeg", control_output + pure_filename + "_FDA_composite"); // Save overlay for later referencing
	
	// Close all images before continuing with the next image
	run("Close All");
}


// ================== Execution ==================

// Close all open images to prevent incorrect image selection
run("Close All");

// Setup the directory structure
directories = DirectorySetup(); // Run DirectorySetup function

// Define which slice contains the BF and FDA image (slices[0] = BF, slices[1] = FDA)  
slices = getSlice(); // Run getSlice function
print("Selected slices:\nBF slice: " + slices[0] + "\nFDA slice: " + slices[1] + "\n"); // Print output of getSlice()

// Batch mode: don't display windows during processing
setBatchMode(true);

// Iterate over all files in the input directory and count cells for each image
list = getFileList(directories[0]); // Obtain a list of all filenames in the 'raw' directory
for (i = 0; i < list.length; i++) { // Iterate over each item of the list
	Viability(directories[0], directories[1], list[i]); // Apply viability function for each image in the 'raw' directory
}

// Save the output as .scv
selectWindow("Summary"); // Select summary window
saveAs("Results", directories[2] + "summary.csv"); // Save as .csv
close("summary.csv"); // Close summary window

// Print finished statement
print("Finished! Results can be found in " + directories[2] + "\n");

// Turn off batch mode
setBatchMode(false);

