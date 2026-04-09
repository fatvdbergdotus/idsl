package org.idsl.language.generator

import java.util.List
import java.util.ArrayList
import java.util.Scanner
import java.util.concurrent.TimeUnit
import java.io.File
import java.nio.file.Files
import java.nio.charset.Charset
import java.util.Comparator
import java.util.Collections
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.DesignSpaceModel

class IdslGeneratorPerformExperimentPTAModelCheck2 {

	def static String determine_model_filename_for_model_abstraction(String modes_theo_bounds, Pair<String,String> ecdf_mtu_pair){
		var String modes_theo_bounds_copy=modes_theo_bounds
		var samplingmethod     = ecdf_mtu_pair.key
		var modeltimeunit      = ecdf_mtu_pair.value
		modes_theo_bounds_copy = modes_theo_bounds_copy.replace("samplingmethod_ecdf1", "samplingmethod_"+samplingmethod)
		modes_theo_bounds_copy = modes_theo_bounds_copy.replace("modeltimeunit_1", "modeltimeunit_"+modeltimeunit)	
		return modes_theo_bounds_copy
	}
	
	// List of all the services and belonging modest models in the model
	//public static var List<Pair<String,String>>    modes_theo_bounds_and_activitymodels = new ArrayList<Pair<String,String>>

	def static void PTAModelcheck (String modes_theo_bounds, String DSI_and_SPACE_and_service_String){ //before: DSI_and_SPACE_and_service_String
		var String pta2_output = IdslConfiguration.Lookup_value("PTA_model_checking2_output_directory")
		var boolean apply_model_simplification = !IdslConfiguration.Lookup_value("pta_model_checking2_skip_model_simplification").equals("true")
		var String  default_ecdf               = IdslConfiguration.Lookup_value("pta_model_checking2_skip_model_simplification_ecdf")
		var String  default_mtu                = IdslConfiguration.Lookup_value("pta_model_checking2_skip_model_simplification_mtu")

		IdslConfiguration.writeTimeToTimestampFile("START PTAModelcheck: "+modes_theo_bounds+" "+DSI_and_SPACE_and_service_String)
		var List<List<String>> results        
		
		if(apply_model_simplification) // skip determine_model_abstraction_dynamically
		   results = IdslGeneratorPerformExperimentPTAModelCheck2SelectModelAbstraction.
							determine_model_abstraction_dynamically(modes_theo_bounds) // benchmarks the possible model abstractions
		IdslGeneratorSyntacticSugarECDF.listToFile(modes_theo_bounds+"_dynamic_mc.html", IdslGeneratorHTML.createTable(results,true,true))
		IdslGeneratorSyntacticSugarECDF.listToFile(modes_theo_bounds+"_dynamic_mc.csv", IdslGeneratorHTML.createCSV(results,true,true))
        IdslGeneratorSyntacticSugarECDF.listToFile(pta2_output+repl_backsl_sl_by_uscore(modes_theo_bounds.replace("Y:/","/"))+"_dynamic_mc.html", IdslGeneratorHTML.createTable(results,true,true))					
		IdslGeneratorSyntacticSugarECDF.listToFile(pta2_output+repl_backsl_sl_by_uscore(modes_theo_bounds.replace("Y:/","/"))+"_dynamic_mc.csv", IdslGeneratorHTML.createCSV(results,true,true))
		
		var Pair<String,String> ecdf_mtu_pair
		if(apply_model_simplification) // selects the model abstraction that is below the threshold
			ecdf_mtu_pair = IdslGeneratorPerformExperimentPTAModelCheck2SelectModelAbstraction.
					selectOptimumModelAbstraction(results, modes_theo_bounds) 
	    else // select a fixed model simplification, as defined in the configuration file (DEBUG ONLY)
	    	ecdf_mtu_pair = default_ecdf  -> default_mtu // e.g., "ecdf1024" -> "1"
		System.out.println(ecdf_mtu_pair.key+"-->"+ecdf_mtu_pair.value)

		// let selected_modes_theo_bounds be the model selected via benchmarking
		var String selected_modes_theo_bounds = determine_model_filename_for_model_abstraction(modes_theo_bounds,ecdf_mtu_pair)
		System.out.println(selected_modes_theo_bounds)
		var int multiplier = new Integer(ecdf_mtu_pair.value) // is needed for multiplying the outcomes again
		
		// STEP1: BEST CASE and SIMULATION
		IdslConfiguration.writeTimeToTimestampFile("START PTAModelcheck (step1): "+modes_theo_bounds+" "+DSI_and_SPACE_and_service_String)
		var Integer bc_bound	   				     = BestCase(selected_modes_theo_bounds, DSI_and_SPACE_and_service_String, "best")
		var Integer wc_bound	   				     = BestCase(selected_modes_theo_bounds, DSI_and_SPACE_and_service_String, "worst") // todo: find a purpose for this value
		System.out.println("best case:"  + bc_bound + " " + "worst case:" + wc_bound) // DEBUG ONLY!
		var Pair<Integer,Integer> sim_bounds         = InitialSimulation(selected_modes_theo_bounds) // get some rough bounds quickly using simulation
		System.out.println("sim bounds:" + sim_bounds.key + " " + sim_bounds.value) // DEBUG ONLY!
		IdslConfiguration.writeTimeToTimestampFile("STOP PTAModelcheck (step1 ): "+modes_theo_bounds+" "+DSI_and_SPACE_and_service_String)
		
		// STEP2: MODEL CHECKING: finding bounds
		IdslConfiguration.writeTimeToTimestampFile("START PTAModelcheck (step2): "+modes_theo_bounds+" "+DSI_and_SPACE_and_service_String)
		var Integer lower_bound_pmax
		var Integer upper_bound_pmin
		var Integer upper_bound_pmax
		var Integer lower_bound_pmin 

		if(IdslConfiguration.Lookup_value("pta_model_checking2_ignore_bestcase_worstcase_simulations")=="false"){
			var boolean noprob = IdslConfiguration.Lookup_value("PTA_model_checking2_noprob")=="true"
			lower_bound_pmax    			 = CheckAbsoluteBounds(selected_modes_theo_bounds, bc_bound -> sim_bounds.key, "pmax", "lb", noprob /* noprobs */)
			upper_bound_pmin    			 = CheckAbsoluteBounds(selected_modes_theo_bounds, Math.max(sim_bounds.value,wc_bound) /* -> infinity */, "pmin", "ub", noprob /* noprobs */)
			upper_bound_pmax    			 = CheckAbsoluteBounds(selected_modes_theo_bounds, lower_bound_pmax -> upper_bound_pmin, "pmax", "ub", false /* noprobs */)
			lower_bound_pmin    			 = CheckAbsoluteBounds(selected_modes_theo_bounds, lower_bound_pmax -> upper_bound_pmin, "pmin", "lb", false /* noprobs */) 
		}
		else { // alternative path in which the bestcase and simulation result are neglected!!
			upper_bound_pmin    			 = CheckAbsoluteBounds(selected_modes_theo_bounds, 1 /* -> infinity */, "pmin", "ub", false /* noprobs */)
			lower_bound_pmin    			 = CheckAbsoluteBounds(selected_modes_theo_bounds, 1 -> upper_bound_pmin, "pmin", "lb", false /* noprobs */) 
			upper_bound_pmax    			 = CheckAbsoluteBounds(selected_modes_theo_bounds, 1, "pmax", "ub", false /* noprobs */)
			lower_bound_pmax    			 = CheckAbsoluteBounds(selected_modes_theo_bounds, 1 -> upper_bound_pmax, "pmax", "lb", false /* noprobs */)
		}
		IdslConfiguration.writeTimeToTimestampFile("STOP PTAModelcheck (step2): "+modes_theo_bounds+" "+DSI_and_SPACE_and_service_String)

		// OUTPUT the intermediate results to a file
		output_intermediate_values_of_measures(modes_theo_bounds, DSI_and_SPACE_and_service_String, 
											   bc_bound, wc_bound, sim_bounds.key, sim_bounds.value,
											   lower_bound_pmax, upper_bound_pmin, upper_bound_pmax, lower_bound_pmin)

		// STEP3: PROBABLISTIC MODEL CHECKING: compute the whole CDF
		IdslConfiguration.writeTimeToTimestampFile("START PTAModelcheck (step3): "+modes_theo_bounds+" "+DSI_and_SPACE_and_service_String)
		var List<Pair<Integer,Double>> cdf_pmin      = ComputeWholeCDF(selected_modes_theo_bounds, lower_bound_pmin -> upper_bound_pmin, "pmin", multiplier)
		var List<Pair<Integer,Double>> cdf_pmax      = ComputeWholeCDF(selected_modes_theo_bounds, lower_bound_pmax -> upper_bound_pmax, "pmax", multiplier)
		IdslConfiguration.writeTimeToTimestampFile("STOP PTAModelcheck (step3): "+modes_theo_bounds+" "+DSI_and_SPACE_and_service_String)
	
		IdslConfiguration.writeTimeToTimestampFile("STOP PTAModelcheck: "+modes_theo_bounds+" "+DSI_and_SPACE_and_service_String)
		// OUTPUT the results to the DSL, graphs and files
		output_CDFs_to_DSL_graphs_and_files(selected_modes_theo_bounds, DSI_and_SPACE_and_service_String, 
											convert_cdf(cdf_pmin, multiplier), convert_cdf(cdf_pmax, multiplier))
	}
	
	def static hardcopy_list_list_string (List<List<String>> _results){
		var results = new ArrayList<List<String>>
		for(List<String> dim1:_results){
			var row = new ArrayList<String>
			row.addAll(dim1)
			results.add(row)
		}
		return results
	}
	
	def static List<List<String>> augment_results_with_lop_and_loi (List<List<String>> _results, 
								List<Pair<Pair<ExtendedProcessModel,DesignSpaceModel>,String>> epms_dsi_to_lop, 
						        List<Pair<Pair<ExtendedProcessModel,DesignSpaceModel>,String>> epms_dsi_to_loi){
		var results = hardcopy_list_list_string(_results) 
		var num_segments  = new Integer(IdslConfiguration.Lookup_value("number_of_simplified_models_with_nondeterministic_segments"))
		var num_timeunits = new Integer(IdslConfiguration.Lookup_value("number_of_simplified_models_with_modeltimeunits"))
		
		for(row:0..num_segments){ // paste in front
			// DEBUG: results.get(row).add(0, "loi "+(num_segments-row))
			results.get(row).add(0, retrieve_loss_of_information(epms_dsi_to_loi,Math.pow(2,num_segments-row) as int))
		}
		results.get(num_segments+1).add(0, "<b>loi</b>")
		
		var new_row=new ArrayList<String>
		for(column:0..num_timeunits){ // paste in a new row in front
			// DEBUG: new_row.add("lop "+(num_segments-column))
			new_row.add(retrieve_loss_of_precision(epms_dsi_to_lop,Math.pow(2,num_segments-column) as int))
		}
		new_row.add("<b>lop</b>")
		results.add(0, new_row)
		
		return results
	}
	
	def static String retrieve_loss_of_precision (List<Pair<Pair<ExtendedProcessModel,DesignSpaceModel>,String>> epms_dsi_to_lop, int modeltimeunit){
		for(lop_entry:epms_dsi_to_lop){
			var dsi=lop_entry.key.value
			var value = lop_entry.value
			if(IdslGeneratorDesignSpace.DSMparamToValue(dsi, "modeltimeunit").equals(modeltimeunit.toString) &&
			   IdslGeneratorDesignSpace.DSMparamToValue(dsi, "samplingmethod").equals("ecdf1024"))
				  return value
		}
		throw new Throwable ("retrieve_loss_of_precision: modeltimeunit "+modeltimeunit+" not found.")
	} 
	
	def static String retrieve_loss_of_information (List<Pair<Pair<ExtendedProcessModel,DesignSpaceModel>,String>> epms_dsi_to_loi, int numsegments){
		for(loi_entry:epms_dsi_to_loi){
			var dsi=loi_entry.key.value
			var value = loi_entry.value
			if(IdslGeneratorDesignSpace.DSMparamToValue(dsi, "modeltimeunit").equals("1") &&
			   IdslGeneratorDesignSpace.DSMparamToValue(dsi, "samplingmethod").equals("ecdf"+numsegments.toString))
				  return value			
		}
		throw new Throwable ("retrieve_loss_of_information: numsegments "+numsegments+" not found.")
	} 
		
	def static Pair<List<Integer>,List<Double>> convert_cdf(List<Pair<Integer,Double>> _cdf){ // overloading for no multiplier
		return convert_cdf(_cdf, 1)
	}
	
	def static Pair<List<Integer>,List<Double>> convert_cdf(List<Pair<Integer,Double>> _cdf, int multiplier){
		var List<Pair<Integer,Double>> cdf = new ArrayList<Pair<Integer,Double>> 
		cdf.addAll(_cdf) // clone
		Collections.sort(cdf, new MyComparator_Sort_CDF_points) // sort
		
		var List<Integer> vals = new ArrayList<Integer>
		var List<Double> probs = new ArrayList<Double>
		for(cdf_line:cdf){
		 	vals.add(cdf_line.key * multiplier)
		 	probs.add(cdf_line.value)
		}
		return vals -> probs
	}
	
	def static output_intermediate_values_of_measures(  String modes_theo_bounds, String DSI_and_SPACE_and_service_String,
														int bc_bound, int wc_bound, int sim_bounds_key, int sim_bounds_value,
											   		    int lower_bound_pmax, int upper_bound_pmin, int upper_bound_pmax, int lower_bound_pmin){
		IdslGeneratorSyntacticSugarECDF.listToFile(modes_theo_bounds+"_intermediate.dat",
												   "bc_bound "+bc_bound+" wc_bound "+wc_bound+" sim_bounds_key "+sim_bounds_key+
												   " sim_bounds_value "+sim_bounds_value+" lower_bound_pmax "+lower_bound_pmax+
											   	   " upper_bound_pmin "+upper_bound_pmin+" upper_bound_pmax "+upper_bound_pmax+
											   	   " lower_bound_pmin "+lower_bound_pmin)
	}
	
	def static output_CDFs_to_DSL_graphs_and_files (String selected_modes_theo_bounds, String DSI_and_SPACE_and_service_String, 
													Pair<List<Integer>, List<Double>> p_min, Pair<List<Integer>, List<Double>> p_max ){
		var String pta2_output = 						IdslConfiguration.Lookup_value("PTA_model_checking2_output_directory")
		val String DSI = 		    					DSI_and_SPACE_and_service_String.split(" ").get(0)
		val String service = 							DSI_and_SPACE_and_service_String.split(" ").get(1)
		var modes_theo_bounds_filename_lb_pmin_cdf = 	selected_modes_theo_bounds+"-lb-pmin-cdf.out"
		var modes_theo_bounds_filename_lb_pmax_cdf =	selected_modes_theo_bounds+"-lb-pmax-cdf.out"
		var modes_theo_bounds_filename_lb_pmin_result =	selected_modes_theo_bounds+"-lb-pmin-results.dat"
		var modes_theo_bounds_filename_lb_pmax_result =	selected_modes_theo_bounds+"-lb-pmax-results.dat"
		var modes_theo_bounds_graph =					selected_modes_theo_bounds+"-graph"

		IdslGeneratorDesignSpaceMeasurements.writePTAProbabilitiesToDSL (DSI, service, "pmax", p_max)
		IdslGeneratorDesignSpaceMeasurements.writePTAProbabilitiesToDSL (DSI, service, "pmin", p_min)
		
		//write values to CDF file
		var List<String> p_max_cdf = IdslGeneratorDesignSpaceMeasurements.convertPTAProbabilitiesToListOfCDFValues("pmax", p_max)
		var List<String> p_min_cdf = IdslGeneratorDesignSpaceMeasurements.convertPTAProbabilitiesToListOfCDFValues("pmin", p_min)
		var fsa2 = new fsa2
		fsa2.generateFile(modes_theo_bounds_filename_lb_pmax_cdf, IdslGeneratorPerformExperimentPTAModelCheck.list_to_String(p_max_cdf))
		fsa2.generateFile(modes_theo_bounds_filename_lb_pmin_cdf, IdslGeneratorPerformExperimentPTAModelCheck.list_to_String(p_min_cdf))
		
		// write the obtained value/probabilities to files
		IdslGeneratorPerformExperimentPTAModelCheck.values_list_and_probs_list_to_file(
											#[modes_theo_bounds_filename_lb_pmin_result, modes_theo_bounds_filename_lb_pmax_result],
										    #[p_min.key, p_max.key], #[p_min.value, p_max.value])	
										   										 
		// write the obtained values to a graph (interpolated)
		//var p_max_sc = IdslGeneratorPerformExperimentPTAModelCheck.intermediate_points (p_max, "pmax") // add intermediate points to create a staircase graph
		//var p_min_sc = IdslGeneratorPerformExperimentPTAModelCheck.intermediate_points (p_min, "pmin")
		write_valueprobs_GNUplot_graph_to_file_double(modes_theo_bounds_graph, 
			pta2_output+repl_backsl_sl_by_uscore(selected_modes_theo_bounds.replace("Y:/","/")), p_min, p_max) 
	}
	
	def static repl_backsl_sl_by_uscore (String str){
		var ret = str.replace("\\","_").replace("/","_")
		return ret 
	}
	
	def static  write_valueprobs_GNUplot_graph_to_file_double(String modes_theo_bounds_graph1, String modes_theo_bounds_graph2, Pair<List<Integer>,List<Double>> _p_min, Pair<List<Integer>,List<Double>> _p_max){
		// writes two similar graphs with a single command
		write_valueprobs_GNUplot_graph_to_file_double(modes_theo_bounds_graph1, _p_min, _p_max)
		write_valueprobs_GNUplot_graph_to_file_double(modes_theo_bounds_graph2, _p_min, _p_max)
	}
	
	def static write_valueprobs_GNUplot_graph_to_file_double(String modes_theo_bounds_graph, Pair<List<Integer>,List<Double>> _p_min, Pair<List<Integer>,List<Double>> _p_max){
		var Pair<List<Integer>,List<Double>> p_max = new ArrayList<Integer> -> new ArrayList<Double> // copy
		p_max.key.addAll(_p_max.key)
		p_max.value.addAll(_p_max.value)
		
		var Pair<List<Integer>,List<Double>> p_min = new ArrayList<Integer> -> new ArrayList<Double> // copy
		p_min.key.addAll(_p_min.key)
		p_min.value.addAll(_p_min.value)

		var p_max_sc = IdslGeneratorPerformExperimentPTAModelCheck.intermediate_points (p_max, "pmax") // add intermediate points to create a staircase graph
		var p_min_sc = IdslGeneratorPerformExperimentPTAModelCheck.intermediate_points (p_min, "pmin")
		
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file_double(
			"" /* graph title */, modes_theo_bounds_graph, 
			#[p_min_sc.key,p_max_sc.key], #[p_min_sc.value,p_max_sc.value], 
			#[IdslGeneratorPerformExperimentPTAModelCheck.list_integer_double(p_min.key), IdslGeneratorPerformExperimentPTAModelCheck.list_integer_double(p_max.key)],
			#[p_min.value, p_max.value])				
	}
	
	def static Integer BestCase(String selected_modes_theo_bounds, String DSI_and_SPACE_and_service_String, String best_or_worst){
		var bestcase_file   = selected_modes_theo_bounds.substring(0,selected_modes_theo_bounds.lastIndexOf("/")+1)+
							  IdslConfiguration.Lookup_value("bestcase_filename") // determines the filename of the bestcase results
		val String service  = DSI_and_SPACE_and_service_String.split(" ").get(1)
		return return_bestcase_from_file_for_given_service(bestcase_file, service, best_or_worst)
	}
	
	def static Integer return_bestcase_from_file_for_given_service (String bestcase_file, String _service, String best_or_worst){
		var contents = file_to_list(bestcase_file) // example line: worst pmax s1 p1 1 sum ([sum ([1 / 1 + 1 / 2])])
		for(content:contents){
			var String best_worst = content.split(" ").get(0)
			var String pmin_pmax  = content.split(" ").get(1)
			var String service    = content.split(" ").get(2)
			var String time       = content.split(" ").get(4)
			if(best_worst.equals(best_or_worst) && pmin_pmax.equals("pmin") && service.equals(_service)) // currently only pmin is supported for the bestcase
				return new Integer(time)
		}
		throw new Throwable("return_bestcase_from_file_for_given_service: service "+_service+" not found file "+bestcase_file)
	} 
	
	def static List<String> file_to_list (String filename) {
		return Files.readAllLines(new File(filename).toPath, Charset.defaultCharset )
	}
	
	def static Pair<Integer,Integer> InitialSimulation(String selected_modes_theo_bounds){
		var modes_theo_bounds_filename_sim = selected_modes_theo_bounds+"-sim.modest"
		val String modes_path              = IdslConfiguration.Lookup_value("modes_path")
		val String modes_params_asap       = IdslConfiguration.Lookup_value("modes_parameters")
		val String modes_params_alap       = IdslConfiguration.Lookup_value("modes_parameters_alap")
		val String sim_runs			       = IdslConfiguration.Lookup_value("pta_model_checking2_simulation_runs")
		
		var int min=999999
		var int max=0
		
		for(cnt:1..new Integer(sim_runs)){
			// as soon as possible (asap) simulation run: min and max value are updates after each run.
			IdslGeneratorConsole.execute(modes_path+"modes.exe "+modes_params_asap+" "+modes_theo_bounds_filename_sim,
									 	selected_modes_theo_bounds+"-sim_asap.out")
			var asap_minmax = read_simulation_output (selected_modes_theo_bounds+"-sim_asap.out", min, max)
			min = asap_minmax.key
			max = asap_minmax.value
			// as late as possible (alap) simulation run: min and max value are updates after each run.
			IdslGeneratorConsole.execute(modes_path+"modes.exe "+modes_params_alap+" "+modes_theo_bounds_filename_sim,
									 	selected_modes_theo_bounds+"-sim_alap.out")
			var alap_minmax = read_simulation_output (selected_modes_theo_bounds+"-sim_alap.out", min, max)
			min = alap_minmax.key
			max = alap_minmax.value
		}
		return min -> max
	}
	
	def static Pair<Integer,Integer> read_simulation_output (String filename, int _min, int _max){
		var min=_min
		var max=_max
		for(content:file_to_list(filename)){
			if(content.contains("Mean:")){
				val int value = new Integer(content.split(" ").get(3))
				if (value<min) // update min
					min=value
				if (value>max) // update max
					max=value
			}	
		}
		return min -> max // the strict range of the simulation results
	}
	
	def static String model_filename (String selected_modes_theo_bounds, String pmin_or_pmax, boolean noprob, String lb_or_ub) 
		'''«selected_modes_theo_bounds»-«lb_or_ub»-«pmin_or_pmax»«IF noprob»-noprob«ENDIF».modest'''
	
	
	def static Integer CheckAbsoluteBounds(String selected_modes_theo_bounds, int lb_to_infinity, String pmin_pmax, String lb_or_ub, boolean noprobs){
		// compute an upper bound first, then perform a binary search
		val double threshold = new Double(IdslConfiguration.Lookup_value("PTA_binary_search_threshold"))
		var model_name = 	   model_filename(selected_modes_theo_bounds,pmin_pmax,noprobs,"lb") //TODO: use a alt model and --p0 and --p1 here.
		var int ultra_ub = 	   lb_to_infinity
		var double result =    0
		
		while(result+threshold < 1){
			ultra_ub=ultra_ub*2
			result=IdslGeneratorPerformExperimentPTAModelCheck.PTAmodelcheck (model_name, ultra_ub).value
		}
		
		return CheckAbsoluteBounds(selected_modes_theo_bounds, lb_to_infinity -> ultra_ub, pmin_pmax, lb_or_ub, noprobs)												 	
	}
	
	def static Integer CheckAbsoluteBounds(String selected_modes_theo_bounds, 
														 Pair<Integer,Integer> lb_to_ub, String pmin_pmax, String lb_or_ub, boolean noprobs){
		// binary search
		val double threshold = new Double(IdslConfiguration.Lookup_value("PTA_binary_search_threshold"))
		var model_name = 	   model_filename(selected_modes_theo_bounds,pmin_pmax,noprobs,lb_or_ub) //TODO: use a alt model and --p0 and --p1 here.
		var range_min =		   lb_to_ub.key
		var range_max =		   lb_to_ub.value

		//IdslGeneratorPerformExperiment.PTAModelCheckPTAmodelcheck (model_name, i_value, retries, true /*pre_comp_p0p1*/)
		
		if(Math.abs(range_min-range_max)<=1) // the range is small enough, return the value
			return range_min
		
		val int range_middle=(range_min+range_max)/2
		
		val Pair<Integer,Double> val_prob = IdslGeneratorPerformExperimentPTAModelCheck.PTAmodelcheck (model_name, range_middle)
		
		if(lb_or_ub.equals("lb")){
			if (val_prob.value < threshold) // prob=0: continue with higher half of range
				return CheckAbsoluteBounds(selected_modes_theo_bounds,range_middle -> range_max, pmin_pmax, lb_or_ub, noprobs)
			else
				return CheckAbsoluteBounds(selected_modes_theo_bounds,range_min -> range_middle, pmin_pmax, lb_or_ub, noprobs)
		}
		if(lb_or_ub.equals("ub")){
			if (val_prob.value < threshold) // prob=0: continue with lower half of range
				return CheckAbsoluteBounds(selected_modes_theo_bounds,range_min -> range_middle, pmin_pmax, lb_or_ub, noprobs)
			else
				return CheckAbsoluteBounds(selected_modes_theo_bounds,range_middle -> range_max, pmin_pmax, lb_or_ub, noprobs)
		}
	}
	
	def static List<Pair<Integer,Double>> ComputeWholeCDF(String selected_modes_theo_bounds, Pair<Integer,Integer> abs_bounds, String pmin_pmax, int multiplier){
		var modes_theo_bounds_graph_dir 	   = selected_modes_theo_bounds+"-graph-"+pmin_pmax+""
		var intermediate_graphs 			   = IdslConfiguration.Lookup_value("pta_model_checking2_plot_intermediate_graphs")=="true"
		var graphcounter 					   = 1000 // to avoid having to add leading zeros
		var model_name 						   = model_filename(selected_modes_theo_bounds,pmin_pmax,false,"lb")
		var List<Pair<Integer,Double>> ret     = new ArrayList<Pair<Integer,Double>>
		ret.add(abs_bounds.key -> 0.0)
		ret.add(abs_bounds.value -> 1.0) 
		
		var int segment_val = -2 
		while(segment_val!=-1){ // stop criterion (no segment left)
			ret = include_zero_delta_p_times(ret) // interpolate
			
			if ((IdslConfiguration.Lookup_value("PTA_model_checking2_brute_force_method")=="max_p"))
				segment_val = ComputeWholeCDF_select_next_segment_greatest_delta_prob(ret) // next value to compute (max_p method)
			else //((IdslConfiguration.Lookup_value("PTA_model_checking2_brute_force_method")=="max_v"))
				segment_val =ComputeWholeCDF_select_next_segment_greatest_delta_val(ret) // next value to compute (max_v method)
			
			val Pair<Integer,Double> val_prob = IdslGeneratorPerformExperimentPTAModelCheck.PTAmodelcheck (model_name, segment_val) // perform computation
			
			if (val_prob.key!=-1) // value is legal
				ret.add(val_prob)
			
			if(intermediate_graphs){ // create an intermediate graph
				write_valueprobs_GNUplot_graph_to_file_double(modes_theo_bounds_graph_dir+"filegraph-"+graphcounter.toString, convert_cdf(ret,multiplier), convert_cdf(ret,multiplier))
				graphcounter = graphcounter + 1
			}
		}
		return ret
	}
	
	def static List<Pair<Integer,Double>> include_zero_delta_p_times (List<Pair<Integer,Double>> _comp_vals){
		val double threshold = new Double(IdslConfiguration.Lookup_value("PTA_binary_search_threshold"))
		
		Collections.sort(_comp_vals, new MyComparator_Sort_CDF_points)
		var List<Pair<Integer,Double>> comp_vals = new ArrayList<Pair<Integer,Double>>
		comp_vals.addAll(_comp_vals) // copy

		var int counter=0

		for(cnt:0.._comp_vals.length-2){ // number of segments
			var double seg_start_p = _comp_vals.get(cnt).value
			var double seg_end_p   = _comp_vals.get(cnt+1).value
			var int    seg_start   = _comp_vals.get(cnt).key
			var int    seg_end     = _comp_vals.get(cnt+1).key
			
			var double delta_p = Math.abs(seg_end_p - seg_start_p)
			if (delta_p < threshold && seg_end-seg_start > 1) // when p values are similar (enough) and the range between them has elements
				for(value:seg_start+1..seg_end-1){
						comp_vals.add(value -> comp_vals.get(cnt).value) // interpolate all p values between them
						counter=counter+1
				}
		}
		if(counter>0)
			System.out.println("Interpolation: "+counter+" values.")
		
		Collections.sort(comp_vals, new MyComparator_Sort_CDF_points)
		return comp_vals
	}
	
	def static Integer ComputeWholeCDF_select_next_segment_greatest_delta_val(List<Pair<Integer,Double>> comp_vals){ // effectively binary steps
		// looks for the greates delta values
		Collections.sort(comp_vals, new MyComparator_Sort_CDF_points)
		var Pair<Integer,Integer> segment
		var int max_delta_val = -1 		
		
		for(cnt:0..comp_vals.length-2){ // number of segments
			var delta_v = Math.abs(comp_vals.get(cnt+1).key - comp_vals.get(cnt).key)
			if(delta_v>max_delta_val && (comp_vals.get(cnt+1).key- comp_vals.get(cnt).key)>1){ // found a better segment and of sufficient size
				max_delta_val=delta_v
				segment= comp_vals.get(cnt).key -> comp_vals.get(cnt+1).key
			}
		}
		if(max_delta_val==-1) // no new segments found
			return -1
		else
			return (segment.key+segment.value) / 2 // middle of the segment
	}
	
	def static Integer ComputeWholeCDF_select_next_segment_greatest_delta_prob(List<Pair<Integer,Double>> comp_vals){ // A.r.j.a.n method
		// looks for the greatest delta probabilities
		Collections.sort(comp_vals, new MyComparator_Sort_CDF_points)
		var Pair<Integer,Integer> segment
		var double max_delta_p = -1 

		for(cnt:0..comp_vals.length-2){ // number of segments
			var delta_p = Math.abs(comp_vals.get(cnt+1).value - comp_vals.get(cnt).value)
			if(delta_p>max_delta_p && (comp_vals.get(cnt+1).key- comp_vals.get(cnt).key)>1){ // found a better segment and of sufficient size
				max_delta_p=delta_p
				segment= comp_vals.get(cnt).key -> comp_vals.get(cnt+1).key
			}
		}
		if(max_delta_p==-1) // no new segments found
			return -1
		else
			return (segment.key+segment.value) / 2 // middle of the segment
	}
	

	 
	def static void main(String[] args) {
		//var modes="Y:/add_to_design_space.idsl/_SCN_scen_DSE_x_1_samplingmethod_ecdf64_modeltimeunit_2_/ExpPTAModelChecking2/modes_theo_bounds_pm"
		//InitialSimulation(modes,"")
		
		/*var Runtime r=Runtime.runtime
		var command ="F:/inpath/Modest-Toolset-20150208/Modest/mcsta.exe Y:/add_to_design_space.idsl/_SCN_scen_DSE_x_1_samplingmethod_ecdf1_modeltimeunit_1_/ExpPTAModelChecking2/modes_theo_bounds_pm-lb-pmax.modest -E \"VAL=10000\""   
		var Process p=r.exec ("C:\\Windows\\System32\\cmd.exe /c "+command)

		if(!p.waitFor(2, TimeUnit.SECONDS)) {
   			 System.out.println("timeout")
   			 //timeout - kill the process. 
  			 p.destroy(); // consider using destroyForcibly instead
		}*/
		System.out.println
	}
}

public class MyComparator_Sort_CDF_points implements Comparator<Pair<Integer,Double>> {
	override int compare(Pair<Integer,Double> p1, Pair<Integer,Double> p2) {
			var int val1 = p1.key
			var int val2 = p2.key
			var int dif = val1-val2
			return dif
	}
}