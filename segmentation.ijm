
// ================== Named field indices ==================
IDX_SIZE_MIN   = 0;
IDX_SIZE_MAX   = 1;
IDX_CIRC_MIN   = 2;
IDX_CIRC_MAX   = 3;
IDX_BF_CHANNEL = 4;
IDX_FDA_CHANNEL= 5;

// ================== Function definition ==================
function get_analysis_settings() {
	/*
	Prompts the user to input the analysis settings, and validates the inputs.

	Returns: params (array) - array containing the validated analysis parameters:
		[SIZE_MIN (number) - minimum particle size in pixels,
		SIZE_MAX (number or string) - maximum particle size in pixels,
		CIRC_MIN (number) - minimum particle circularity (0.00 - 1.00),
		CIRC_MAX (number) - maximum particle circularity (0.00 - 1.00),
		BF_CHANNEL (string) - name of the brightfield channel (e.g. "C1"),
		FDA_CHANNEL (string) - name of the FDA channel (e.g. "C2")]
	*/
    valid = false;

    while (!valid) {
        Dialog.create("Analysis Settings");

        Dialog.addMessage("Particle Analysis Parameters");
        Dialog.addNumber("Minimum particle size:", 100);
        Dialog.addString("Maximum particle size (use 'Infinity'):", "Infinity");
        Dialog.addNumber("Minimum circularity (0.00 - 1.00):", 0.80);
        Dialog.addNumber("Maximum circularity (0.00 - 1.00):", 1.00);

        Dialog.addMessage("Channel Selection");
        Dialog.addNumber("BF channel:", 2);
        Dialog.addNumber("FDA channel:", 1);

        Dialog.show();

        // ---- Retrieve inputs ----
        size_min = Dialog.getNumber();
        size_max_str = Dialog.getString();
        circ_min = Dialog.getNumber();
        circ_max = Dialog.getNumber();

        bf_index = Dialog.getNumber();
        fda_index = Dialog.getNumber();

        BF_channel = "C" + d2s(bf_index, 0);
        FDA_channel = "C" + d2s(fda_index, 0);

        // ---- Validation ----
        valid = true;
        error_msg = "";

        if (size_min < 0)
            error_msg += "- Minimum size must be >= 0\n";

        if (size_max_str != "Infinity") {
            size_max = parseFloat(size_max_str);
            if (isNaN(size_max) || size_max < 0)
                error_msg += "- Maximum size must be >= 0 or 'Infinity'\n";
            else if (size_max < size_min)
                error_msg += "- Maximum size must be >= minimum size\n";
        }

        if (circ_min < 0 || circ_min > 1)
            error_msg += "- Minimum circularity must be between 0 and 1\n";

        if (circ_max < 0 || circ_max > 1)
            error_msg += "- Maximum circularity must be between 0 and 1\n";

        if (circ_max < circ_min)
            error_msg += "- Maximum circularity must be >= minimum circularity\n";

        if (bf_index < 1 || fda_index < 1)
            error_msg += "- Channel indices must be > 0\n";

        if (error_msg != "") {
            valid = false;
            showMessage("Invalid Input", error_msg);
        }
    }

    return newArray(size_min, size_max_str, circ_min, circ_max, BF_channel, FDA_channel);
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


function preprocess_file() {
	/*
	Function to perform basic image pre-processing before analysis.
	*/
	setOption("ScaleConversions", true);
	run("8-bit");
	run("Split Channels");
}


function preprocess_and_duplicate_channels(modality) {
	/* 
	Function to preprocces and duplicate channels for later reference.

	Args: channel (string) - channel to process
		  modality (string) - modality name for saving
	*/
	if (modality == "BF") {
		channel_id = params[IDX_BF_CHANNEL];
		LUT = "Grays";	
	}
	else {
		channel_id = params[IDX_FDA_CHANNEL];
		LUT = "Green";	
	}

	selectImage(channel_id + "-00_raw/" + filename);
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


function analyze_particles(params) {
	/*
	Runs particle analysis with specified size and circularity parameters. 

	Args: params (array): [SIZE_MIN (number) - minimum particle size in pixels
,
		  				   SIZE_MAX (number or string) - maximum particle size in pixels
,
		  				   CIRC_MIN (number) - minimum particle circularity (0.00 - 1.00)
,
		  				   CIRC_MAX (number) - maximum particle circularity (0.00 - 1.00)
]
	*/
	run("Analyze Particles...", "size=" + params[0] + "-" + params[1] + "circularity=" + params[2] + "-" + params[3] + " show=Ellipses display exclude clear include summarize");
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


function create_BF_mask(BF_filename) {
	/* 
	Function to create a mask from the brightfield ellipse fit.
	*/	
	selectImage("Drawing of " + BF_filename + "_BF"); // Select ellipse fit of BF image
	rename("FDA_mask");
	run("Fill Holes"); // Fill holes to make mask
	run("Dilate");
	run("Dilate");
	run("Apply LUT");
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


function save_summary() {
	/*
	Function to save the summary results window as .csv.
	*/
	if (is_open("Summary")) {
		selectWindow("Summary");
		saveAs("Results", directories[1] + "summary.csv"); // diretories[1] = output directory
		close("summary.csv");
	} 
	else {
		print("No 'Summary' window open. Skipping save operation. \n");
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
	/* 
	Function to analyze a specific modality.

	Args: modality (string) - modality name for saving
		  algorithm (string) - thresholding algorithm to use	
	*/
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

	analyze_particles(params);
	save_results(modality);
	outline_cells(modality);
}


function analyze_file(input_path, control_path, filename) {
	/*
	Function to analyze a single file.

	Args: input_path (string) - path of the input directory
		  control_path (string) - path of the control directory
		  filename (string) - name of the image file
	*/
	pure_filename = open_image(input_path, filename);
	preprocess_file();	
	analyze_modality("BF", "MaxEntropy");
	create_BF_mask(pure_filename);
	analyze_modality("FDA", "Triangle");
	run("Close All");
}


function main() {
	/*
	Main function to set up working directory and analyze all files.
	*/
	run("Close All"); // To prevent previous windows from interfering
	directories = set_up_working_dir();
	params = get_analysis_settings();

	list = getFileList(directories[0]); // Get list of files in input directory
	for (i = 0; i < list.length; i++) {
		analyze_file(directories[0], directories[2], list[i]); // directories[0] = input directory, directories[2] = control directory
	}

	save_summary();
	print("Finished! Results can be found in " + directories[1] + "\n");
}


// ================== Execution ==================
setBatchMode(true);
main();
setBatchMode(false);