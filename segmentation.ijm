// ================== Function definition ==================

function modality_to_channel(modality) {
	/*
	Function to convert an integer channel index to a string with preceding zeroes.

	Args: index (integer) - channel index as integer

	Returns: channel (string) - channel index as string with preceding zeroes
	*/
	index = getNumber("Indicate the channel containing the " + modality + " image", 0); // Prompt user for channel index
	channel = d2s(index, 0);
	channel = "C" + channel;
	
	return channel;
}


function get_channels() {
	/*
	Function to indicate in which of the stack channels the BF and FDA images are located.

	Returns: channels (array) - array containing the BF and FDA channel strings
	*/
	BF_channel = modality_to_channel("BF");
	FDA_channel = modality_to_channel("FDA");
	
	return newArray(BF_channel, FDA_channel);
}


function is_open(title) {
	/*
	Function to check whether a window with a specific title exists.

	Args: title (string) - title of the window to check

	Returns: (boolean) - true if window is open, false if not
	*/
    list = getList("window.titles");
    for (i = 0; i < list.length; i++) {
        if (list[i] == title) {
            return true;
        }
    }
    return false;
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
	
	return newArray(input_dir, output_dir, control_dir, results_dir);
}


function set_up_working_dir() {
	/*
	Function to set up the working directory structure.

	Returns: directories (array) - array containing the paths of the input and output directories
	*/
	working_dir = get_working_directory();
	directories = define_relative_directories(working_dir);
	
	for (i = 1; i < directories.length; i++) { // Check/create all output directories (start from i=1 to skip input directory)
		check_directory(directories[i]);
	}
	
	if (!File.exists(directories[0])) { // Check whether input directory exists (directories[0] = input directory)
		print("Error: Input directory ('../00_raw/') does not exist! \n");
		exit();
	}

    return directories;
}


function open_image(path, filename) {
	/*
	Function to open an image using Bio-Formats.

	Args: path (string) - path of the directory containing the image
		  filename (string) - name of the image file

	Returns: pure_filename (string) - filename without extension
	*/
	run("Bio-Formats Windowless Importer", "open=[" + path + filename + "]"); // Open image stack
	pure_filename = File.nameWithoutExtension;
	print("Opened " + pure_filename);

	return pure_filename;
}


function z_project_if_stack() {
	/*
	Function to perform a Z-projection if the image is a stack.
	*/
	if (nSlices > 1) {
		run("Z Project...", "projection=[Max Intensity]");
	}
}


function preprocess_and_duplicate_channels(channel, LUT, modality) {
	/* 
	Function to preprocces and dupliacte channels for later reference.

	Args: channel (string) - channel to process
		  LUT (string) - LUT to apply
		  modality (string) - modality name for saving
	*/

	selectImage(channel + "-00_raw/" + filename);
	z_project_if_stack();
	run(LUT);
	saveAs("Tiff", control_path + pure_filename + "_" + modality);
	rename(pure_filename + "_" + modality + "_control");
	run("Duplicate...", "title=" + pure_filename + "_" + modality);
}


// Function for image (pre-)processing, segmentation, and counting of cell viability
function Viability(input_path, control_path, filename) {
	pure_filename = open_image(input_path, filename);

	// Image pre-processing
	setOption("ScaleConversions", true);
	run("8-bit"); // Convert all images to 8-bit
	run("Split Channels"); // Separate stack into different channels

	preprocess_and_duplicate_channels(channels[0], "Grays", "BF");
	preprocess_and_duplicate_channels(channels[1], "Green", "FDA");
	
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
	saveAs("Jpeg", control_path + pure_filename + "_BF_segmented"); // Save segmented image for later reference
	
	// Analysis - ADJUSTABLE 
	run("Analyze Particles...", "size=100-Infinity circularity=0.75-1.00 show=Ellipses display exclude clear include summarize");
	
	// -------------------------------------------------------------------------------------------------------------
	
	// Check if the "Results" window is open
	if (is_open("Results")) {
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
	saveAs("Jpeg", control_path + pure_filename + "_BF_composite"); // Save overlay for later referencing
	
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
	saveAs("Jpeg", control_path + pure_filename + "_FDA_segmented");
	rename(pure_filename + "_FDA"); // Rename for later handling
	
	// Analysis - ADJUSTABLE 
	run("Analyze Particles...", "size=100-Infinity circularity=0.75-1.00 show=Ellipses display exclude clear include summarize");
	
	// -------------------------------------------------------------------------------------------------------------
	
	// Check if the "Results" window is open
	if (is_open("Results")) {
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
	saveAs("Jpeg", control_path + pure_filename + "_FDA_composite"); // Save overlay for later referencing
	
	// Close all images before continuing with the next image
	run("Close All");
}


// ================== Execution ==================

// Close all open images to prevent incorrect image selection
run("Close All");

// Setup the directory structure
directories = set_up_working_dir(); // Run DirectorySetup function

// Define which channel contains the BF and FDA image (channels[0] = BF, channels[1] = FDA)  
channels = get_channels(); // Run getChannel function
print("Selected channels:\nBF channel: " + channels[0] + "\nFDA channel: " + channels[1] + "\n"); // Print output of getChannel()

// Batch mode: don't display windows during processing
setBatchMode(true);

// Iterate over all files in the input directory and count cells for each image
list = getFileList(directories[0]); // Obtain a list of all filenames in the 'raw' directory
for (i = 0; i < list.length; i++) { // Iterate over each item of the list
	Viability(directories[0], directories[2], list[i]); // Apply viability function for each image in the 'raw' directory
}

// Save the output as .scv
selectWindow("Summary"); // Select summary window
saveAs("Results", directories[1] + "summary.csv"); // Save as .csv
close("summary.csv"); // Close summary window

// Print finished statement
print("Finished! Results can be found in " + directories[1] + "\n");

// Turn off batch mode
setBatchMode(false);

// setBatchMode(true);
// main();
// setBatchMode(false);