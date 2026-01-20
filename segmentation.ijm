// ================== Analysis constants ==================

SIZE_MIN = 100; // Minimum particle size in pixels
SIZE_MAX = "Infinity"; // Maximum particle size in pixels (set to "Infinity" for no maximum)
CIRC_MIN = 0.80; // Minimum particle circularity (0.00 - 1.00)
CIRC_MAX = 1.00; // Maximum particle circularity (0.00 - 1.00)

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
	print("Selected channels:\nBF channel: " + BF_channel + "\nFDA channel: " + FDA_channel + "\n");
	
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
	
	if (!File.exists(directories[0])) { // Check whether input directory exists (directories[0] = input directory)
		print("Error: Input directory ('../00_raw/') does not exist! Exiting macro... \n");
		exit();
	}

	for (i = 1; i < directories.length; i++) { // Check/create all output directories (start from i=1 to skip input directory)
		check_directory(directories[i]);
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


function preprocess_and_duplicate_channels(modality) {
	/* 
	Function to preprocces and dupliacte channels for later reference.

	Args: channel (string) - channel to process
		  modality (string) - modality name for saving
	*/
	if (modality == "BF") {
		channel_id = 0;
		LUT = "Grays";	
	}
	else {
		channel_id = 1;
		LUT = "Green";	
	}

	selectImage(channels[channel_id] + "-00_raw/" + filename);
	z_project_if_stack();
	run(LUT);
	save_image("Tiff", modality, "raw");
	rename(pure_filename + "_" + modality + "_control");
	run("Duplicate...", "title=" + pure_filename + "_" + modality);
}


function process_image(modality) {
	/*
	Function to perform basic image processing before segmentation.
	*/
	run("Gaussian Blur...", "sigma=2");
	
	if (modality == "BF") {
		run("Subtract Background...", "rolling=20 light sliding");
		// BF specific processin can be added here
	}
	else {
		// FDA specific processing can be added here
	}
}

function segment_image(modality, algorithm) {
	/* 
	Function to segment an image according to a specified algorithm.

	Args: modality (string) - modality name for saving
		  algorithm (string) - thresholding algorithm to use	
	*/
	if (modality == "BF") {
		mode = "";	
	}
	else {
		mode = "dark";
	}

	setAutoThreshold(algorithm + " " + mode + " no-reset");
	setOption("BlackBackground", true); // Background is black, foreground is white
	run("Convert to Mask");
	run("Dilate"); 
	run("Fill Holes");
	run("Watershed");
}


function analyze_particles(SIZE_MIN, SIZE_MAX, CIRC_MIN, CIRC_MAX) {
	/*
	Runs particle analysis with specified size and circularity parameters. 

	Args: SIZE_MIN (number) - minimum particle size in pixels
		  SIZE_MAX (number or string) - maximum particle size in pixels
		  CIRC_MIN (number) - minimum particle circularity (0.00 - 1.00)
		  CIRC_MAX (number) - maximum particle circularity (0.00 - 1.00)
	*/
	run("Analyze Particles...", "size=" + SIZE_MIN + "-" + SIZE_MAX + "circularity=" + CIRC_MIN + "-" + CIRC_MAX + " show=Ellipses display exclude clear include summarize");
}


function outline_cells(modality) {
	/* 
	Function to outline fitted ellipses on the original image.

	Args: modality (string) - modality name for saving
	*/
	if (modality == "BF") {
		channel_id = 4;	
	}
	else {
		channel_id = 2;	
	}

	selectWindow("Drawing of " + pure_filename + "_" + modality);
	run("Magenta");
	run("Invert LUT");
	run("Dilate");
	run("Merge Channels...", "c" + channel_id + "=" + pure_filename + "_" + modality + "_control c6=[Drawing of " + pure_filename + "_" + modality + "] create keep"); // Overlay ellipse fit onto original FDA image
	save_image("Jpeg", modality, "composite");
}


function save_results(modality) {
	/*
	Function to save the results window as .csv.

	Args: modality (string) - modality name for saving
	*/
	if (is_open("Results")) {
		selectWindow("Results");
		saveAs("Results", directories[3] + pure_filename + "_" + modality + "_results.csv"); // diretories[3] = results directory
		close("Results");
	} 
	else {
		print("No 'Results' window open. Skipping save operation. \n");
		}
}


function save_image(filetype, modality, suffix) {
	/*
	Function to save the current image with a specified filetype and suffix.

	Args: filetype (string) - filetype to save as (e.g. "Jpeg", "Tiff")
		  modality (string) - modality name for saving
		  suffix (string) - suffix to append to filename
	*/
	saveAs(filetype, control_path + pure_filename + "_" + modality + "_" + suffix);
}


function analyze_modality(modality, algorithm) {
	preprocess_and_duplicate_channels(modality);
	selectImage(pure_filename + "_" + modality);
	process_image(modality);
	segment_image(modality, algorithm);

	if (modality == "FDA") {
		rename(pure_filename + "_" + modality + "_segmented"); // Rename for later handling
		imageCalculator("AND create", pure_filename + "_" + modality + "_segmented","" + modality + "_mask"); // Overlay BF fit mask on segmented FDA image
	}

	save_image("Jpeg", modality, "segmented");
	
	if (modality == "FDA") {
		rename(pure_filename + "_" + modality); // Rename for later handling
	}

	analyze_particles(SIZE_MIN, SIZE_MAX, CIRC_MIN, CIRC_MAX);
	save_results(modality);
	outline_cells(modality);
}


function analyze_file(input_path, control_path, filename) {
	pure_filename = open_image(input_path, filename);

	// Image pre-processing
	setOption("ScaleConversions", true);
	run("8-bit"); // Convert all images to 8-bit
	run("Split Channels"); // Separate stack into different channels
	
	analyze_modality("BF", "MaxEntropy");

	// Convert ellipse fit of BF image to mask
	selectImage("Drawing of " + pure_filename + "_BF"); // Select ellipse fit of BF image
	rename("FDA_mask"); // Rename the image for later handling
	run("Fill Holes"); // Solid fill of fitted ellipses
	run("Dilate"); // Increase size of mask
	run("Dilate"); // Increase size of mask
	run("Apply LUT"); // Fix the applied LUT	
	
	analyze_modality("FDA", "Triangle");

	run("Close All");
}


function main() {
	run("Close All"); // To prevent previous windows from interfering
	directories = set_up_working_dir();
	channels = get_channels();

	list = getFileList(directories[0]); // Get list of files in input directory
	for (i = 0; i < list.length; i++) {
		analyze_file(directories[0], directories[2], list[i]); // directories[0] = input directory, directories[2] = control directory
	}

	selectWindow("Summary");
	saveAs("Results", directories[1] + "summary.csv"); // directories[1] = output directory
	close("summary.csv");

	// Print finished statement
	print("Finished! Results can be found in " + directories[1] + "\n");
}


// ================== Execution ==================
setBatchMode(true);
main();
setBatchMode(false);