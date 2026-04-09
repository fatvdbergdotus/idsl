package org.idsl.language.generator

import java.util.List
import java.util.ArrayList
import java.nio.file.Files
import java.nio.file.Path
import java.io.File

class IdslGeneratorPerformExperimentPTAModelCheck2SelectModelAbstraction {	
	def static List<List<String>> determine_model_abstraction_dynamically(String modes_theo_bounds){
		// check different model abstractions and returns a table of execution time results
		val String tool = IdslConfiguration.Lookup_value("PTA_model_checking_tool")
		var int    time_limit = new Integer(IdslConfiguration.Lookup_value("dynamically_selecting_model_timeout"))	
		var modes_theo_bounds_filename_lb_pmax = modes_theo_bounds+"-lb-pmax.modest"	
		
		var List<List<String>> results = new ArrayList<List<String>> // samplingmethod,modeltimeunit,exec_time
		// make the header
		var List<String> result_row = new ArrayList<String>
		result_row.add("")
		result_row.addAll(modeltimeunit_values.map[t | "<b>" + t + "</b>"])
		results.add(result_row.reverse)

		var int skip_row=0 // modeltimeunit to skip
		for(samplingmethod:samplingmethod_values())/*.reverse*/{
			result_row = new ArrayList<String>
			//var skip_row=false // if true, the rest of the for-loop is neglected
			
			for(modeltimeunit:modeltimeunit_values().reverse){
				if(new Integer(modeltimeunit)>skip_row){
				//if(!skip_row){ 
					var String perf_time  = (new Integer(IdslConfiguration.Lookup_value("time_parameter_for_testing_performance")) / new Integer(modeltimeunit)).toString					
					var modes_theo_bounds_copy = IdslGeneratorPerformExperimentPTAModelCheck2.determine_model_filename_for_model_abstraction(
															modes_theo_bounds_filename_lb_pmax, samplingmethod -> modeltimeunit)										
					var long    starttime  = IdslConfiguration.writeTimeToTimestampFile("PTA2 benchmark start "+samplingmethod+" "+modeltimeunit)
					var boolean suc_exec   = IdslGeneratorConsole.execute_with_timeout(tool+" "+modes_theo_bounds_copy+" -E \"VAL="+perf_time+"\"", time_limit)
					var long    endtime    = IdslConfiguration.writeTimeToTimestampFile("PTA2 benchmark stop "+samplingmethod+" "+modeltimeunit)
					System.out.println("Time: "+(endtime-starttime))
	
					if(suc_exec) // store the execution time	
						result_row.add((endtime-starttime).toString)
					else{ // store -1 to indicate execution failed and break the for-loop
						result_row.add(">"+" "+ time_limit)
						//skip_row=true	
						skip_row = Math.max(skip_row,new Integer(modeltimeunit)) //raise the skip_row if needed
					}
				}
				else{
					//result_row.add(">"+samplingmethod+" "+modeltimeunit+" "+ time_limit)
					result_row.add(">"+" "+ time_limit+"s")
				}
			}
			result_row.add("<b>"+samplingmethod+"</b>")
			results.add(result_row)
		}
		return results.reverse
	}
	
	def static Pair<String,String> selectOptimumModelAbstraction (List<List<String>> results, String modes_theo_bounds){
		var distance_measure = IdslConfiguration.Lookup_value("PTA_model_checking2_selectOptimumModelAbstraction")
		if (distance_measure.equals("euclid") || distance_measure.equals("lowest_max") || distance_measure.equals("manhattan") ||
			distance_measure.equals("modelunit") || distance_measure.equals("segment"))	
			return selectOptimumModelAbstraction (results,distance_measure, modes_theo_bounds)
		throw new Throwable("selectOptimumModelAbstraction: illegal distance_measure specified "+distance_measure)
	}
	
	def static Pair<String,String> selectOptimumModelAbstraction(List<List<String>> results, String distance_measure, String modes_theo_bounds){ // TODO: test this function
		// Computes all distance_measures in one go and then selects the right one	
		var Pair<Integer,Integer> best_euclid_so_far_int          = -1 -> -1
		var double                distance_euclid_best_so_far 	  = 10000000.0 // large number
		var Pair<Integer,Integer> best_lowest_max_so_far_int      = -1 -> -1
		var double                distance_lowest_max_best_so_far = 10000000.0 // large number
		var Pair<Integer,Integer> best_manhattan_so_far_int       = -1 -> -1
		var double                distance_manhattan_best_so_far  = 10000000.0 // large number
		var Pair<Integer,Integer> best_modelunit_so_far_int       = -1 -> -1
		var double                distance_modelunit_best_so_far  = 10000000.0 // large number
		var Pair<Integer,Integer> best_segment_so_far_int         = -1 -> -1
		var double                distance_segment_best_so_far    = 10000000.0 // large number
		
		for(samplingmethod_cnt:0..samplingmethod_values().length-1){ // for every table entry
			for(modeltimeunit_cnt:0..modeltimeunit_values().length-1){
				var String result=results.get(samplingmethod_cnt).get(modeltimeunit_cnt)
				if(!result.substring(0,1).equals(">")){  // computation performed within threshold time
					var double delta_sampling      = samplingmethod_cnt
					var double delta_modeltimeunit = modeltimeunit_values().length-1 - modeltimeunit_cnt
					
					var double euclid_distance       = Math.sqrt(Math.pow(delta_sampling,2) + Math.pow(delta_modeltimeunit,2))
					var double lowest_max_distance   = Math.max(delta_sampling,delta_modeltimeunit) 
					var double lowest_max_distance2  = Math.max(delta_sampling+0.001*delta_modeltimeunit,delta_modeltimeunit+0.001*delta_sampling) //TODO implement lowest_max_distance measure
					var double manhattan_distance    = delta_sampling+delta_modeltimeunit
					var double modelunit_distance    = delta_modeltimeunit
					var double segment_distance  	 = delta_sampling
					
					if(euclid_distance<=distance_euclid_best_so_far){ // closer option found
						distance_euclid_best_so_far     = euclid_distance
						best_euclid_so_far_int          = samplingmethod_cnt -> modeltimeunit_cnt
					}
					if(lowest_max_distance<=distance_lowest_max_best_so_far){ // closer option found
						distance_lowest_max_best_so_far = lowest_max_distance
						best_lowest_max_so_far_int      = samplingmethod_cnt -> modeltimeunit_cnt
					}
					if(manhattan_distance<=distance_manhattan_best_so_far){ // closer option found
						distance_manhattan_best_so_far  = manhattan_distance
						best_manhattan_so_far_int       = samplingmethod_cnt -> modeltimeunit_cnt
					}
					if(modelunit_distance<=distance_modelunit_best_so_far){ // closer option found
						distance_modelunit_best_so_far	= modelunit_distance
						best_modelunit_so_far_int       = samplingmethod_cnt -> modeltimeunit_cnt
					}
					if(segment_distance<=distance_segment_best_so_far){ // closer option found
						distance_segment_best_so_far    = segment_distance
						best_segment_so_far_int     	= samplingmethod_cnt -> modeltimeunit_cnt
					}
				}
			}
		}
		
		if(best_euclid_so_far_int.key==-1 || best_lowest_max_so_far_int.key==-1 || best_manhattan_so_far_int.key==-1 ||
			best_modelunit_so_far_int.key==-1 || best_segment_so_far_int.key==-1)
			throw new Throwable ("selectOptimumModelAbstractionEuclid: no model computed within the desired time!")

		// print outcomes for all distances to a file
		var String pta2_output = IdslConfiguration.Lookup_value("PTA_model_checking2_output_directory")
		var List<String> distances_str = new ArrayList<String>
		distances_str.add("Euclid: " +     samplingmethod_values.reverse.get (best_euclid_so_far_int.key) +"->"+ modeltimeunit_values.reverse.get  (best_euclid_so_far_int.value)) + "\r\n"	
		distances_str.add("Lowest_max: " + samplingmethod_values.reverse.get (best_lowest_max_so_far_int.key) +"->"+ modeltimeunit_values.reverse.get  (best_lowest_max_so_far_int.value)) + "\r\n"
		distances_str.add("Manhattan: " +  samplingmethod_values.reverse.get (best_manhattan_so_far_int.key) +"->"+ modeltimeunit_values.reverse.get  (best_manhattan_so_far_int.value)) + "\r\n"
		distances_str.add("Modelunit: " +  samplingmethod_values.reverse.get (best_modelunit_so_far_int.key) +"->"+ modeltimeunit_values.reverse.get  (best_modelunit_so_far_int.value)) + "\r\n"
		distances_str.add("Segment: " +    samplingmethod_values.reverse.get (best_segment_so_far_int.key) +"->"+ modeltimeunit_values.reverse.get  (best_segment_so_far_int.value)) + "\r\n"
		IdslGeneratorSyntacticSugarECDF.listToFile(modes_theo_bounds+"_dynamic_mc_distances.dat", distances_str) 
		IdslGeneratorSyntacticSugarECDF.listToFile(pta2_output+IdslGeneratorPerformExperimentPTAModelCheck2.repl_backsl_sl_by_uscore(modes_theo_bounds.replace("Y:/","/"))+"_dynamic_mc_distances.dat", distances_str)

		if(distance_measure.equals("euclid"))     
			return samplingmethod_values.reverse.get (best_euclid_so_far_int.key)     -> modeltimeunit_values.reverse.get  (best_euclid_so_far_int.value)
		if(distance_measure.equals("lowest_max")) 
			return samplingmethod_values.reverse.get (best_lowest_max_so_far_int.key) -> modeltimeunit_values.reverse.get  (best_lowest_max_so_far_int.value)
		if(distance_measure.equals("manhattan"))  
			return samplingmethod_values.reverse.get (best_manhattan_so_far_int.key)  -> modeltimeunit_values.reverse.get  (best_manhattan_so_far_int.value)
		if(distance_measure.equals("modelunit"))  
			return samplingmethod_values.reverse.get (best_modelunit_so_far_int.key)  -> modeltimeunit_values.reverse.get  (best_modelunit_so_far_int.value)
		if(distance_measure.equals("segment"))  
			return samplingmethod_values.reverse.get (best_segment_so_far_int.key)    -> modeltimeunit_values.reverse.get  (best_segment_so_far_int.value)
		throw new Throwable("selectOptimumModelAbstraction: Invalid distance measure.")
	}	
	
	def static List<String> samplingmethod_values(){
		var num_segments = new Integer(IdslConfiguration.Lookup_value("number_of_simplified_models_with_nondeterministic_segments"))
		var List<String> values = new ArrayList<String>
		for(int power2:0..num_segments)
			values.add("ecdf"+Math.pow(2,power2) as int)
		return values
	}
	
	def static List<String> modeltimeunit_values(){
		var timeunits = new Integer(IdslConfiguration.Lookup_value("number_of_simplified_models_with_modeltimeunits"))
		var List<String> values = new ArrayList<String>
		for(int power2:0..timeunits)
			values.add(""+Math.pow(2,power2) as int)
		return values		
	}
	
	def static double loi_value(String ecdf){ // input: "ecdf1" or "ecdf2" etc.
		throw new Throwable("loi_value: not implemented yet")
	}
	
	def static List<String> lop_loi_contents (String modes){
		var lines = Files.readAllLines(new File(modes_to_mainstudyfoldername(modes)+"lop_and_loi.dat").toPath)
		var ret = new ArrayList<String>
		for(line:lines){
			if(line.split(" ").get(0).equals(modes_to_processname(modes))) // of the right process type
				ret.add(line)
		}
		return ret 
	}
	
	def static String modes_to_processname(String modes){
		return modes.split("/").last.substring(18) // pick the part after the last / + remove "modes_theo_bounds_"
	}
	
	def static String modes_to_mainstudyfoldername(String modes){
		return modes.split("/").get(0) + "/" + modes.split("/").get(1) + "/"
	}
}