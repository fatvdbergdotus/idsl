package org.idsl.language.generator

import org.idsl.language.idsl.Config
import org.eclipse.xtext.generator.IFileSystemAccess
import java.io.FileWriter
import java.io.BufferedWriter
import java.io.PrintWriter
import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.resource.Resource
import org.idsl.language.idsl.impl.IdslFactoryImpl
import java.io.File
import java.util.Map
import java.util.HashMap

// Debug mode syntax:
// if (IdslConfiguration.Lookup_value("negative_exponential_distribution_arrivals_use_math")=="true"){
//		...
// }
// (IdslConfiguration.Lookup_value("energy_aware_resources_switched_off_at_start"))
	
class IdslConfiguration {
	private static String global_granularity = "1000" // = "1000" for decent accuracy
	var static IFileSystemAccess file_system
	public static Config DSL_configuration // IdslGenerator puts the configuration here
	var static private List<String> alreadyWarned = new ArrayList<String> // stores given warnings, so that warning are only displayed once in function "warning_and_"
	var static private String current_dsi_path = "" // holds the path of the current dsi so that timestamps can be added to it
	var static Map<String,String> configuration = new HashMap<String,String> // for storing all config entries to be retrieved
	var static boolean first_access = true

	def public static set_filesystem(IFileSystemAccess fsa) { file_system=fsa }

	def addKeyValue (Resource res, String key, String value){ // adds a key and value to the config in a iDSL model
		var config     = res.allContents.toIterable.filter(typeof(Config)).head
		var keyvalue   = IdslFactoryImpl::init.createConfigKeyValue
		keyvalue.key   = key
		keyvalue.value = value
		config.kv.add(keyvalue)
	}
	 
	def static String Lookup_value_in_DSL(String key){
		if (DSL_configuration==null) 
			 return null
		
		for (keyvalue:DSL_configuration.kv){
			// DEBUG ONLY: System.out.println(keyvalue.key+" xx "+keyvalue.value)
			if(keyvalue.key==key) 
				 return keyvalue.value	
		}
		return null // key not found, value in this file will be used
	}
	 
	def static String warning_and_ (String key, String value){ // prints a warning for the given setting, if not warned yet, and s it
		if(!alreadyWarned.contains(key)){
			System.out.println("Warning: "+key+" has value "+value)
			alreadyWarned.add(key)
		}
		return value
	}
	
	def public static void writeTimeToTimestampFile_change_DSI_path (String dsi_path){  // Changes the path to where timestamps are written additionally
		current_dsi_path=dsi_path
	}
	
	def public static void writeTimeStamp_aggregation_script_and_batch (String dsi_path, IFileSystemAccess fsa){ // a script to aggregate timestamp values
		fsa.generateFile(dsi_path+"/timestamps.awk", IdslGeneratorGAWK.pta_model_checking2_timestamp_aggregation)
		fsa.generateFile(dsi_path+"/timestamps_aggregate.bat","gawk.exe -f timestamps.awk timestamps >> timestamps_aggregated")
	}
	
	def public static long writeTimeToTimestampFile (String description){  // writes a timestamp to the log
		var filename 			 = IdslConfiguration.Lookup_value("timestamp_file") 
		var time_unit_power 	 = IdslConfiguration.Lookup_value("timestamp_file_time_unit")
		var time_unit_multiplier = Math.pow(10, new Integer(time_unit_power))
		
		var PrintWriter out = new PrintWriter(new BufferedWriter(new FileWriter(filename, true))) 
		var time = (System.nanoTime * time_unit_multiplier) as long
		
		out.println( time +"  "+description)  // time, event description
		out.close
		
		if(current_dsi_path!=""){ // a DSI path is known, write the timestamp in this folder as well.
			// make a folder first
			var	File file = new File(current_dsi_path)
			if (!file.exists) 
				 file.mkdir
			
			var filename_dsi = current_dsi_path+"/timestamps"
			var PrintWriter out_to_dsi = new PrintWriter(new BufferedWriter(new FileWriter(filename_dsi, true))) 
			out_to_dsi.println( time +"  "+description)  // time, event description
			out_to_dsi.close		
		}
		
		System.out.println("Writing timestamp: "+description)
		return  time
	} 
	
	def static String Lookup_value(String key)
	{
		// Load the configuration if this is the first run
		if(first_access){
			load_configuration
			first_access=false
		}

		// Lookup the config value in the DSL
		val String inDSL_value=Lookup_value_in_DSL(key);
		if(inDSL_value!=null) 
			 return inDSL_value
	
		// Lookup the confing value in the configuration 
		var config_value = configuration.get(key)
		if(config_value!=null)
			 return config_value
		else
			throw new Throwable("key "+key+" not found in Configuration")
	}
	
	def static String load_configuration(){	
		configuration.put("PTA_model_checking2_output_directory",								"y:/pta2_output/") // where is the output of PTA2 model checking stored additionally?
		configuration.put("Create_performance_independent_artefacts_per_service_request",		"false")
		configuration.put("retrieve_number_of_states_before_model_checking",					"false")
		configuration.put("print_aexp_use_int_in_recursion",// print "(int)" in the recursion (via exprexpr) of AExps
			 "false") // only print (int) at the highest level
			//  "true" // print (int) everywhere, e.g., (int)((int)((int)700 / (int)1) + (int)((int)1 / (int)2))
		configuration.put("utilization_sampling_time", // How long to measure to determine the utilization // TO ADD or to use CSV instead of properties
			 "1000000") //warning: if too high, the simulation might take long!!
		configuration.put("postfix_target_directory", // a postfix to be added after Y:/biplane-paper-.idsl_%POSTFIX_HERE%/
			 "") //no postfix
			// "abc" // postfix = _abc
		configuration.put("shuffle_measurements_randomly", // how is the shuffling of measurements done to obtain a random subset?
			//  "true" // differently every time
			 "false") // based on a fixed seed
		configuration.put("gnuplot_printing_method", // staircase, interpolation
			 "staircase")
			// "interpolation"
		configuration.put("gnuplot_title_font", // the font of the (possible) title in GNUplots
			 "font 'Arial,10'")
		configuration.put("default_ecdf_sampling_method", // the way inverse eCDFS are sampled p -> value
			// "0" // staircase: retrieve_value_in_eCDF(ecdf2,index) as double
			 "1") // interpolation: ( ((1-modulus) * retrieve_value_in_eCDF(ecdf2,index_prime)) + ((modulus) * retrieve_value_in_eCDF(ecdf2,index_prime+1)) ) 
			// "2" // arithmicmean_of_ecdf(ecdf)
		    // "3" //  draw_sample_eCDF(ecdf,0.5) // draw median value	
		configuration.put("kolmogorov_interpolation", // use interpolation to determine the Kolmogorov distance
			 "true")
			// "false" // warning: can be tricky with the denominator having the same value
		configuration.put("gnuplot_every", // GNUplot: Every how many datapoints to draw a figure?
			 "400")
		configuration.put("gnuplot_plot_symbols", // GNUplot: draw a figure?
			 "false")
			//  "true"
		configuration.put("evaluate_performanceGraphs", // Creates perrformance graphs using Graphviz
			 "false")
			//  "true" 
		configuration.put("evaluate_createNonPerformanceGraphs", // Creates non-perrformance graphs using Graphviz
			 "false")
			//  "true"
		configuration.put("evaluate_lower_level_latencies", // Removes properties when only top-level latencies are needed
			 "false") // only top-level latencies are computed
			//  "true"			
		configuration.put("execution_retry_runs", // If the console fails (empty/no file or error on first line), then how many times to retry
			 "10")
		configuration.put("enable_dsi_sampling_method", // add non-deterministic sampling to the design space
			 "false")
		configuration.put("enable_model_time_unit", // add model time unit to the design space
			 "false")
		configuration.put("double_multiplier", // number to multiply doubles to reduce precision loss. Warning: A too high number may cause overflows.
			 "100")			
		configuration.put("cdf_ratios_filename", // the name of the file in which ratio CDFS are stored 					
			 "P:\\cdfs_biplane\\ratio")
		configuration.put("cdf_file_path", // the location at which CDF from file files with no path (e.g., aaa vs. C:\aaa) can be found.
			 "P:\\cdfs_biplane\\")
		configuration.put("cdf_graph_path", // the location at with calibration validation graphs are written to
			 "P:\\cdfs_biplane\\graphs\\")
		configuration.put("temporary_working_directory", // the location at which temporary iDSL files are stored
			 "c:\\temp\\idsl\\")
		configuration.put("multiply_eCDFs_multiplier", // an exponent of multiplier of multiply_eCDFs. Can be used to change the unit.
			 "0")  // eg., 0 -> 10^0 !!!
		configuration.put("ecdf_quotient_multiplier", // factor to multiply a eCDF with when a quotient of two eCDFs is taken (to circumvent the usage of doubles)
			 "1000000") // low values lead to inaccuracy, high values may cause an integer overflow
		configuration.put("execution_distance_grannularity", // The number of steps taken in two eCDFs to compute the Execution distances 
			 "1000")
		configuration.put("kolmogorov_grannularity", // The number of steps taken in two eCDFs to compute the Kolmogorov distances (only values that are between both minima and maxima are considered for a start)
			 "10000")
		configuration.put("ecdf_grannularity", // The number of horizonal slices made to take samples of an eCDF
			 global_granularity)
		configuration.put("ecdf_quotient_grannularity",
			 global_granularity) // The number of horizonal slices made to take samples of both eCDFs to be divided
		configuration.put("ecdf_product_grannularity",
			 global_granularity) // The number of horizonal slices made to take samples of both eCDFs to be multiplied
		configuration.put("execute_this",// determine whether to execute the given DSL instance (create graphs, transformations etc.)
			 "true")
		configuration.put("modes_path", // the location at which modes.exe is located
			// "F:\\inpath\\"
			// "F:\\inpath\\Modest-Toolset-20150208\\Modest\\"
			 "F:\\inpath\\Modest-20150730b\\Modest\\")
		configuration.put("modes2_path", // the location at which modes.exe is located
			 "F:\\inpath\\Modest-Release-20160113\\")			 
		configuration.put("modes2_parameters" /* used for simulation with load balancing, --max-run-length 0 means infinity run */,
			"-I Modest -R Uniform -S ASAP --runs 1 --max-run-length 0")
		configuration.put("modes2_parameters_100_runs" /* used for simulation with load balancing, --max-run-length 0 means infinity run */,
			"-I Modest -R Uniform -S ASAP --runs 100 --max-run-length 0")
		configuration.put("modes2_parameters_num_runs",
			"200")
		configuration.put("modes_parameters",
			// OLD:  "-Nql 1 -Nqn 1 -R Uniform -S ASAP --max-run-length 1800000 --batch-size 1" // parameters applied when modes is dispatched
			// "-Nql 1 -Nqn 1 -R Uniform -S ASAP --max-run-length 3800000 --batch-size 1"
			 "-N 1 -R Uniform -S ASAP --max-run-length 3800000 --batch-size 1 --input Modest")
		configuration.put("modes_parameters_alap",
			 "-N 1 -R Uniform -S ALAP --max-run-length 3800000 --batch-size 1 --input Modest")
		configuration.put("MCTAU_analysis_mode", // Note: Works for MC as well
			 "binary_search") // call MCTAU iteratively and halves the search range size on each go
			//  "brute_force_search" // call MCTAU once and have all search comparisons in a single Modest file
		configuration.put("Append_DSL_instance_to_Modest_code",
			// "true" // Appends the base DSL instance in comment below Modest code
			 "false") // Appends nothing
		configuration.put("Debug_mode",
			// "true" // display System.out.println for debugging
			 "false") // hide debug messages
		configuration.put("Graph_titles",
			// "true" // display titles above all graphs
			 "false") // omit titles above all graphs 			
		configuration.put("Output_format_graphics",
			 "pdf")
			// "png"
			// "gif"		
		configuration.put("dot_path",
			 "F:\\inpath\\")
		configuration.put("gnuplot_path",
			 "F:\\inpath\\")
		configuration.put("gawk_path", // where is GAWK located
			 "F:\\inpath\\")
		configuration.put("number_of_UPPAAL_properties", // Nb. the product of the interval and number of UPPAAL properties equals the maximum value checked
			 "15")
		configuration.put("interval_of_UPPAAL_properties",
			 "20")
		configuration.put("check_for_double_names",
			// "true"
			 "false")
		configuration.put("PTA_model_checking2_brute_force_method", // after the absolute bounds are known, how are all values between them computed?
			//  "max_v"
			 "max_p")
		configuration.put("PTA_model_checking2_noprob", // use noprob to find absolute bounds
			// "true"
			 "false") 
		configuration.put("pause_in_batch_file",
			 "") // no pause
			// "\npause" // pause	
		configuration.put("always_non_deterministich_when_integers_used", // to reduce complexity in model checking
			 "true")
			// "false"	
		configuration.put("always_no_priorities_when_integers_used", // to reduce complexity in model checking	
			 "true")
			// "false"	
		configuration.put("always_no_timeslice_when_integers_used", // to reduce complexity in model checking
			 "true")
			// "false"
		configuration.put("small_multiplier_when_reals_used", // to implement an ALT with priorities. alt { ,, op1 ,, delay(1) op2 ,, delay(2) op3 }
			 "0.01")
		configuration.put("mctau_or_mc", // Which tool is used for model checking?
			// "mctau"
			 "mc")
		configuration.put("model_checking_interval_size",
			 "600")
		configuration.put("logfile_name", // name of logfile to write execution information to
			 "logfile.dat")
		configuration.put("write_DSL_instances_to_disk", // write the intermediately generated DSL instances to disk? (i.e., syntactic sugar, measurements)
			 "true")
			// "false"
		configuration.put("gnuplot_legend_position", // 
			// "center bottom"
			 "right bottom")
			// "left top"
		configuration.put("number_of_remaning_CDF_entries_after_operations", 
			 "0") // the number of entries remains constant
		configuration.put("timestamp_file", // file in which timestamps are stored to enable performance evaluation evaluation.
			 "P:\\cdfs_biplane\\timestamps")
		configuration.put("timestamp_file_time_unit", // determines the 10-power of the time unit in the timestamp file
			// "0"  // nanoseconds
			// "-3" // microseconds
			// "-6" // milliseconds
			 "-9")	// seconds
		configuration.put("writa_pta_model_to_external_folder",
			 "") // do not write the pta model to an external folder CURRENTLY NOT IN USE DUE TO BATCH SCRIPT
			// "x:\\bruteforce_pta\\" // write additional files to folder "x:\\bruteforce_pta\\"
		configuration.put("number_of_threads_to_use_for_pta_model_checking", // ideal number depends on the number of CPU cores and memory usaged (memory is shared).
			// "1" // the safe option but relatively slow option
			 "4")
		configuration.put("PTA_model_checking_tool",
			// "mc" // MC
			// "F:\\inpath\\Modest-Release-20150123\\Modest\\mcsta.exe"
			//F:\inpath\Modest-Toolset-20150208\Modest\mcsta.exe
			// "F:\\inpath\\Modest-Toolset-20150208\\Modest\\mcsta.exe"
			 "F:\\inpath\\Modest-20150730b\\Modest\\mcsta.exe")
		configuration.put("PTA_select_image", // rate of 1/a, at which an image is selected
			 "10")
		configuration.put("PTA_compute_range", // the range of values [0..25] that is computed during PTA model checking. Needed for efficient PTA model checking with binary search
			 "25")
		configuration.put("PTA_granularity",
			 "40") // the number of samples to compute brute forcely between the bounds.	
		configuration.put("PTA_generate_upper_bound_files", // Should upperbound models be generated? Note, for creating CDF lower bound files are sufficient
			 "false")
			// "true"
		configuration.put("PTA_binary_search_upperbound", // how far should the inital search algorithm go?
			 "30000000")
		configuration.put("PTA_binary_search_threshold", // how close to 0 and to 1 should the probability be, e.g., 0,001 -> 0 and 0,999 -> 1
			 "0.001")
		configuration.put("PTA_dynamic_model_complexity_determination_threshold_in_seconds", // how long may one execution of PTA model checking maximally take?.
			 "20")
		configuration.put("PTA_brute_force_model_checking",
			// "true" // computes all CDF values from 0 up to "PTA_compute_range"
			 "false") // use scanning, two binary searches to obtain the bounds of the eCDF
			// "script" // to run the computation on another computer, leading to a cache file
		configuration.put("PTA_location_of_cache", // where are the results of PTA model checking cached on disk?
			 "P:\\cdfs_biplane\\idsl_ptacache")
			// "true" // cache is deleted every time started up
		configuration.put("PTA_clear_cache_on_start", // should the cache file be removed on each start?
			 "false") // cache contents remain
			// "true"
		configuration.put("PTA_model_checking_2_use_noprobs",
			 "true") // replaces all palts with alts in modest model
		configuration.put("number_of_simplified_models_with_nondeterministic_segments", // how many simplified models are created to be used for PTA model checking
			 "10") // abstraction will contain power of 2 elements
		configuration.put("number_of_simplified_models_with_modeltimeunits",
			 "10") // abstraction will contain power of 2 elements
		configuration.put("Design_space_display_constraints_information_only", //  
			// "true" // Do not evaluate designs, but do show information about the effect of the constraints
		     "false") // Ordinary performance evaluation
		configuration.put("Create_gobat_and_goallbat", // Create go.bat and go-all.bat files so that performance evaluation can be manually executed.
			 "false")
		configuration.put("number_iterations_kmeans", // how often is the k-means algorithm iterated. Higher value will take longer, but lead to better results 
		 	 "10")
		configuration.put("max_number_iterations_in_kmeans", // how often are the clusters modified when no converguence occurs
		     "10")
		configuration.put("java_execution_engine", // which Java class is used to execute external commands
			// "process"
		     "processbuilder")
		configuration.put("PTA_model_checking2_selectOptimumModelAbstraction",
			// "euclid")    // MIN sqrt ( x^2+y^2)
			"lowest_max")   // MIN max (x,y)
			// "manhattan"  // MIN x+y
			// modelunit"
			//"segment"
		configuration.put("dynamically_selecting_model_timeout",
			 "10") // interrupts model checking after N seconds during dynamic model checking
		configuration.put("time_parameter_for_testing_performance", // mcsta model.xxx -E (val=T) to see how model.xxx performs
			 "100000")
		configuration.put("multiply_results_dsm_comparison_method",
			//  "whole_dsm" // the dsm of the multiplier needs to match the whole DSM in order for the multiplier to be applied  
		     "one_variable") // only one variable of the multiplier needs to match
		configuration.put("pta_model_checking2_simulation_length",
			 "50")
		configuration.put("pta_model_checking2_simulation_runs",
			 "4")
		configuration.put("pta_model_checking2_plot_intermediate_graphs",
			 "true")
		configuration.put("pta_model_checking2_ignore_bestcase_worstcase_simulations", // if true: bestcase, worstcase and simulation results are neglected in "absolute bounds"
			 "false") 
		
		// to skip the model simplification step with pta model checking2
		configuration.put("pta_model_checking2_skip_model_simplification","false")	//true
			
				// overrides the benchmarking process: 
				configuration.put("pta_model_checking2_skip_model_simplification_ecdf","ecdf4")
				configuration.put("pta_model_checking2_skip_model_simplification_mtu","256")
			 
		configuration.put("bestcase_filename",
			"modes_bc_latency.dat")
		// TO IMPLEMENT
		configuration.put("emfit_filename",
			 "emfit_noverbose")
		configuration.put("load_balancer_policy_random_number_of_options", // variable N for the Uniform(1,N) when selecting a random number.
			"10000")
		configuration.put("emfit_settings", // Usage, em_fit <filename> <n|d|e|s|w> numberOfPhases     
			 "n 10")
				//configuration.put('e': EM with dynamic strata and hyper-erlangs. WARNING: requires sorted data!!! Data is dynamically divided into strata with low c2
				//configuration.put('d': EM with dynamic strata. WARNING: requires sorted data!!! Data is dynamically divided into strata with low c2
				//configuration.put('s': EM with sampling. Data is uniformly sampled. Then, plain EM is applied to the samples.
				//configuration.put('w': Weighted EM. Each value is treated by the EM algorithm with a specific weight. Requires the file to contain all values followed by all weight. Weights are normalized automatically.
				//configuration.put('n': Runs a plain EM on the data.	
		configuration.put("show_inbetween_results_in_loss_of_precision_and_information_files",
			 "true")
			// "false"
		configuration.put("negative_exponential_distribution_arrivals_use_math","yes") 
			// print the neg. exponential of arrivals als math, (or as an palt) 	 
		configuration.put("negative_exponential_distribution_multiplier", "100000")	
			// the accuracy of the neg. exponential distribution	
		configuration.put("buffersize_resources","2000") // the queue- or buffersize of resources
		
		configuration.put("palt_may_have_one_alternative","no")		// yes / no
		configuration.put("alt_may_have_one_alternative","no")		// yes / no
		configuration.put("lbalt_may_have_one_alternative","yes")	// yes / no
		configuration.put("path_begin", "Y:/") 						// the top-level path to which all iDSL output
		configuration.put("how_many_energy_aware_resources_switched_off_at_start","0") // "yes"
		configuration.put("count_timeouts","no") // sometimes the timeout variable is not initalized; make this variable "no" then.
	}
	 
	def static void main(String[] args) {
		writeTimeToTimestampFile("Test. Freek")
		writeTimeToTimestampFile("Test. Piet")
	}
}


