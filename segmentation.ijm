// ================== Function definition ==================

// Function to indicate in which of the stack channels the BF and FDA images are located
function getChannel() {
	// Prompt user to indicate the channel index in which the BF and FDA images are located
	BF_index = getNumber("Indicate the channel containing the BF image", 0);
	FDA_index = getNumber("Indicate the channel containing the FDA image", 0);
	
	// Convert FDA channel integer to string with preceding zeroes
	BF_channel = d2s(BF_index, 0); // Convert integer to string
	BF_channel = "C" + BF_channel; // Add preceding zeroes to string
	
	// Convert FDA channel integer to string with preceding zeroes
	FDA_channel = d2s(FDA_index, 0); // Convert integer to string
	FDA_channel = "C" + FDA_channel; // Add preceding zeroes to string
	
	// Return the channels array for later use
	return newArray(BF_channel, FDA_channel);
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


function check_directory(directory) {
	/* 	
	Function to check whether a directory exists, and create it if it doesn't.

	Args: directory (string) - path of the directory to check/create
	*/
	if (!File.exists(directory)) {
		File.makeDirectory(directory);
		print("Checked/created directory:\n" + directory + "\n");
	}
}


function get_working_directory() {
	/*
	Function to promt the user to select the working directory.

	Returns: working_dir (string) - path of the selected working directory
	*/
	working_dir = getDirectory("Select working directory");
	return working_dir;
}


function define_relative_directories(working_dir) {
	/*
	Function to define the relative paths of the input and output directories.

	Args: working_dir (string) - path of the working directory

	Returns: directories (array) - array containing the paths of the input and output directories
	*/
	input_dir = working_dir + "00_raw/";
	output_dir = working_dir + "01_analysis/";
	control_dir = output_dir + "control/";
	results_dir = output_dir + "results/";
	
	return newArray(input_dir, control_dir, output_dir, results_dir);
}

// Function to set up the working directory to contain the correct subdirectories for storing the results
function DirectorySetup() {
	working_dir = get_working_directory();

	directories = define_relative_directories(working_dir);
	
	for (i = 1; i < directories.length; i++) { // Check/create all output directories (start from i=1 to skip input directory)
		check_directory(directories[i]);
	}

	// Define input directory, raise error if it doesn't exist
	input_dir = working_dir + "00_raw/";
	
	if (!File.exists(input_dir)) {
		print("Error: Input directory ('../raw/') does not exist! \n");
		exit();  // Exit the macro
	}
    
	// // Define output directories
	// output_dir = working_dir + "01_analysis/";
	// check_directory(output_dir);

	// control_dir = output_dir + "control/";
	// check_directory(control_dir);

	// results_dir = output_dir + "results/";
	// check_directory(results_dir);
	
	// // Print confirmation
	// print("Checked/created directories:\n" + output_dir + "\n" + control_dir + "\n" + results_dir + "\n");
	
    // Return the directories array for later use
    return directories;
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
	run("Split Channels"); // Separate stack into different channels
	
	// Select, save, and duplicate BF and FDA channel
	//BF
	selectImage(channels[0] + "-00_raw/" + filename); // Select BF image
	if (nSlices > 1) {
		run("Z Project...", "projection=[Max Intensity]");
	}
	run("Grays"); // Apply LUT
	saveAs("Tiff", control_output + pure_filename + "_BF"); // Save the original image for later reference
	rename(pure_filename + "_BF_control"); // Rename the image for later handling
	run("Duplicate...", "title=" + pure_filename + "_BF"); // Duplicate the image for later handling
	
	//FDA
	selectImage(channels[1] + "-00_raw/" + filename); // Select the FDA image
	if (nSlices > 1) {
		run("Z Project...", "projection=[Max Intensity]");
	}
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

// Define which channel contains the BF and FDA image (channels[0] = BF, channels[1] = FDA)  
channels = getChannel(); // Run getChannel function
print("Selected channels:\nBF channel: " + channels[0] + "\nFDA channel: " + channels[1] + "\n"); // Print output of getChannel()

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

