package org.idsl.language.generator

import java.util.List
import java.io.File
import java.util.ArrayList
import org.idsl.language.idsl.MVExpECDF
import org.eclipse.xtext.util.Triple
import java.io.FileInputStream
import java.security.MessageDigest
import java.io.InputStream
import java.math.BigInteger
import java.io.BufferedReader
import java.io.FileReader
import java.io.PrintWriter

class IdslGeneratorPerformExperimentPTAModelCheck {	
	var static private List<Pair<Pair<String,Integer>,Double>> cache_contents 					= PTAmodelCheckRetrieveCache // init cache
	var static private List<Pair<String,String>>			   cache_for_filename_and_hashvalue	= new ArrayList <Pair<String,String>> // cache for hash values per filename, gets removed every session
	
	def static synchronized String hashFile(String filename){ // create a hashcode for a given filename
 	    // check the hash cash first  
 	    var try_cache = cache_for_filename_and_hashvalue.filter[ i | i.key==filename]
 	    if(!try_cache.empty) // return the value
 	    	return try_cache.head.value
 	    
 	    var BufferedReader reader        = new BufferedReader( new FileReader (filename))
	    var String         line          = null
	    var StringBuilder  stringBuilder = new StringBuilder
	    var String         ls 			 = System.getProperty("line.separator")
	
	    while( ( line = reader.readLine() ) != null ) {
	        stringBuilder.append( line )
	        stringBuilder.append( ls )
	    }
	
	    var String s = stringBuilder.toString
  		var MessageDigest md5 = MessageDigest.getInstance("MD5");
   		md5.update(s.getBytes,0,s.length)
   		var String signature = new BigInteger(1,md5.digest()).toString(16)
   		
   		// add to cache and return value
   		cache_for_filename_and_hashvalue.add(filename -> signature.toString) 		
   		return signature.toString
	}
	
	def static String PTAmodelcheck_benchmark (List<String> model_names){ // returns the model that can be evaluated within a certain threshold
		var max_time = new Integer(IdslConfiguration.Lookup_value("PTA_dynamic_model_complexity_determination_threshold_in_seconds"))
		// needed parameters:
		// threshold time: how fast should one model check go (in seconds)
		// value to check: for which value is the benchmark done?
		throw new Throwable("Not implemented yet")
	}

	def static Pair<List<Integer>,List<Double>> PTAmodelcheck (String model_name, int min, int max){
		return PTAmodelcheck (model_name, (min..max).toList)
	}
	
	def static Pair<List<Integer>,List<Double>> PTAmodelcheck (String model_name, List<Integer> values){ // multicore and brute-force
		val int granularity = new Integer(IdslConfiguration.Lookup_value("PTA_granularity")) // how many values to retrieve?
		var int num_threads = new Integer(IdslConfiguration.Lookup_value("number_of_threads_to_use_for_pta_model_checking"))
		var int val_per_thread = (values.length / num_threads) +1
		
		var List<Integer> valuescopy = new ArrayList<Integer>
		if(values.length<granularity){ // hardcopy all the values
			for(value:values)
				valuescopy.add(value)
		} else { // take the proper subset of size "granularity"
			for(cnt:(0..values.length-1).filter[i | i %(values.length/(granularity-1)) == 0])
				valuescopy.add(values.get(cnt))
		}
		
		var List<RunnablePTAs> runnablePTAs = new ArrayList<RunnablePTAs> // now distribute the values over the thread
		for (cnt:0..num_threads-1){
			var vals_thread = new ArrayList<Integer>
			for(cnt_val:1..val_per_thread)
				if(!valuescopy.empty)
					vals_thread.add ( valuescopy.remove(0) )
			runnablePTAs.add( new RunnablePTAs( "Thread-"+(cnt+1).toString, model_name, vals_thread ) )
		}
		
		// ************** MULTITHREADING start *************************
		for (runPTA:runnablePTAs) // Starts all runnables 
			runPTA.start
		
		for (runPTA:runnablePTAs){ // accesses t.join to make this thread wait for them
			var Thread t = runPTA.thread
			t.join
		}
		// ************** MULTITHREADING end *************************

		var List<Integer> vals   = new ArrayList<Integer>
		var List<Double>  probs  = new ArrayList<Double>
	
		for	(runPTA:runnablePTAs){ // process the results per thread
			vals.addAll(runPTA.result.key)
			probs.addAll(runPTA.result.value)
		}
		return vals -> probs 
	}
	
	def static int benchmarkPTAmodelcheck (String model_name, Integer i_value){ // to test which model complexity is suitable
		var starttime = IdslConfiguration.writeTimeToTimestampFile("PTA benchmark start")
		var boolean useCache=false
		//todo: no cache option
		PTAmodelcheck (model_name, i_value)
		var endtime   = IdslConfiguration.writeTimeToTimestampFile("PTA benchmark stop")
		return (endtime - starttime) as int
	}
	
	def static Pair<Integer,Double> PTAmodelcheck (String model_name, Integer i_value){ // overloading: no number of retries supplied
		val retries=new Integer(IdslConfiguration.Lookup_value("execution_retry_runs"))
		return PTAmodelcheck (model_name, i_value, retries)
	}
	
	def static synchronized List<Pair<Pair<String,Integer>,Double>> PTAmodelCheckRetrieveCache (){
		var cache_filename   = IdslConfiguration.Lookup_value("PTA_location_of_cache")
		
		if (IdslConfiguration.Lookup_value("PTA_clear_cache_on_start").equals("true")){ //delete cache file 
			var file = new File(cache_filename)
			file.delete
			return new ArrayList<Pair<Pair<String,Integer>,Double>>
		} else { // read cache file from disk and and return contents		
			var _cache_contents  = new ArrayList<Pair<Pair<String,Integer>,Double>>
			var List<String> cache_file_contents = IdslGeneratorSyntacticSugarECDF.fileToList(cache_filename)
			
			if(!(cache_file_contents.empty))
				for(cnt:(0..cache_file_contents.length-1).filter[ i | i % 3 == 0]){ // a new record every three lines
					_cache_contents.add( (cache_file_contents.get(cnt) -> new Integer(cache_file_contents.get(cnt+1)) ) 
																					-> new Double(cache_file_contents.get(cnt+2) ) )
			}	
			return _cache_contents
		}
	}
	
	def static synchronized List<Double>  PTAmodelCheckCache (String model_name, Integer i_value){
		for(content:cache_contents){
			var cache_model_hash = content.key.key
			var cache_i_value = content.key.value
			var model_hash=hashFile(model_name)
			if(model_hash== cache_model_hash && i_value==cache_i_value){ // cache hit!
				System.out.println("Cache hit for model "+model_name+" value "+i_value)
				return #[content.value]	
			}
		}
		return #[]
	}
	
	def static synchronized PTAmodelAddToCacheIfNotExists (String model_name, Integer i_value, Double result){
		var hash_model_name = hashFile(model_name)
		var Pair<Pair<String,Integer>,Double> content_triple = (hash_model_name -> i_value) -> result
		
		for(content:cache_contents)
			if(hash_model_name==content.key.key && i_value==content.key.value) // cache hit!
				return null // found it. No need to add it
		cache_contents.add(content_triple)
		
		// write change to file
		var cache_filename = IdslConfiguration.Lookup_value("PTA_location_of_cache")
		var List<String> lines = new ArrayList<String>
		lines.add(hash_model_name)
		lines.add(i_value.toString)
		lines.add(result.toString)
		IdslGeneratorSyntacticSugarECDF.listToFile(cache_filename, lines)
	}
	
	def static Pair<Integer,Integer> PTAmodelcheck_retrieve_num_states (String model_name){
		System.out.println ("Checking the minimum and maximum number of states for model "+model_name)
		
		val retries=new Integer(IdslConfiguration.Lookup_value("execution_retry_runs"))
		PTAmodelcheck_retrieve_num_states (model_name, retries)
	}
	
	def static Pair<Integer,Integer> PTAmodelcheck_retrieve_num_states (String model_name, int num_retries_left) { 
		if(num_retries_left==-1)
			throw new Throwable("Execution of PTA model checking failed many times! Please check your input model.")
	
		// retrieves the minimum and maximum number of states by executing the model for very low and high values.
		val String tool = IdslConfiguration.Lookup_value("PTA_model_checking_tool") // the model checking tool, e.g., MC or MCSTA
		
		// Execute model checking
		var temp_output = IdslConfiguration.Lookup_value("temporary_working_directory")+"mc_temp666".toString // temporary file_name that will be used
		var File file = new File(temp_output); file.delete // delete the temporary file with result, if exists
		IdslGeneratorConsole.execute(tool+" "+model_name+" -E \"VAL=0\" -E \"VAL=1800000000\" | find \"States\" | gawk \"{printf \\\"%s \\\",$2}\" >>"+temp_output)	

		// Post-processing
		val firstLine = IdslGeneratorMODESBinarySearch.readOneLineFromFile(temp_output)
		if (firstLine==null){ // execution has failed, retry
			System.out.println("Execution has failed. Retrying: "+(num_retries_left-1)+" retries left.")
			return PTAmodelcheck_retrieve_num_states (model_name, num_retries_left-1)
		}
		
		// return the result
		var parts     = firstLine.split(" ").iterator.toList
		return (new Integer(parts.get(0))) -> (new Integer(parts.get(1)))
	}
	
	def static Pair<Integer,Double> PTAmodelcheck (String model_name, Integer i_value, int num_retries_left){
		return PTAmodelcheck ( model_name, i_value, num_retries_left, false) // overloading pre_comp_p0p1 default:false
	}
	
	def static Pair<Integer,Double> PTAmodelcheck (String model_name, Integer i_value, int num_retries_left, boolean pre_comp_p0p1){
		if(i_value<0){
			System.out.println("PTAmodelcheck: i_value<0 (negative time")
			return i_value -> 0.0
		}
		
		if(num_retries_left==-1)
			throw new Throwable("Execution of PTA model checking failed many times! Please check your input model.")
		
		var cache_value = PTAmodelCheckCache(model_name, i_value) // see if they model i_value combination is in cache
		if(cache_value.length>0)
			return i_value -> cache_value.head
		
		val String tool = IdslConfiguration.Lookup_value("PTA_model_checking_tool") // the model checking tool, e.g., MC or MCSTA
		IdslConfiguration.writeTimeToTimestampFile("START PTAmodelcheck_unit")
		
		// Execute model checking
		var temp_output = IdslConfiguration.Lookup_value("temporary_working_directory")+"mc_temp"+i_value.toString // temporary file_name that will be used
		var File file = new File(temp_output); file.delete // delete the temporary file with result, if exists
		if (pre_comp_p0p1)
			IdslGeneratorConsole.execute(tool+" "+model_name+" --p0 --p1 -E \"VAL="+i_value.toString+"\" | find \"Result:\" | gawk \"{print \""+i_value.toString+"\",$2}\""+">>"+temp_output)
		else
			IdslGeneratorConsole.execute(tool+" "+model_name+" -E \"VAL="+i_value.toString+"\" | find \"Result:\" | gawk \"{print \""+i_value.toString+"\",$2}\""+">>"+temp_output)
		// command: mc modes_theo_bounds_p1-lb-pmax.modest -E "VAL=%1" | find "Result:" | gawk "{print %1,$2}"
		
		// Post-processing
		val firstLine = IdslGeneratorMODESBinarySearch.readOneLineFromFile(temp_output)
		if (firstLine==null){ // execution has failed, retry
			System.out.println("Execution has failed. Retrying: "+(num_retries_left-1)+" retries left.")
			return PTAmodelcheck (model_name, i_value, num_retries_left-1)
		}
		
		var parts = firstLine.split(" ").iterator
		val value= new Integer(parts.next)
		val prob=  new Double(parts.next)
		file = new File(temp_output); file.delete // delete the temporary file with result
		System.out.println (value+" AND "+prob)
		
		IdslConfiguration.writeTimeToTimestampFile("STOP PTAmodelcheck_unit")
		
		if(cache_value.empty)
			PTAmodelAddToCacheIfNotExists(model_name, i_value, prob)
		
		return value->prob
	}
	
	def static Pair<Integer,Integer> efficient_pta_model_checking(String model){ // determines the exact bounds via 2 binary searches
		// quick exponential scan to determine in what power of 2 the lb and ub are located.
		var min_max = PTAModelcheck_find_lb_and_ub(model)
		System.out.println("minimum: "+min_max.key + ",  maximum: "+min_max.value )
		
		// binary searches to both find the exact lower and upper bounds
		var exact_min = PTAModelcheck_find_lb(model, min_max.key, min_max.key*2)
		var exact_max = PTAModelcheck_find_up(model, min_max.value/2, min_max.value)
		System.out.println("exact minimum: "+exact_min+",   exact maximum: "+exact_max )
		return exact_min-1 -> exact_max+1 		// -1 and +1 to be sure to capture the whole area of interest.
	}
	
	def static void PTAModelcheck (String modes_theo_bounds, String DSI_and_SPACE_and_service_String){ 
		val String DSI 		= DSI_and_SPACE_and_service_String.split(" ").get(0)
		val String service  = DSI_and_SPACE_and_service_String.split(" ").get(1)
		
		// Computation range
		val comp_range = new Integer(IdslConfiguration.Lookup_value("PTA_compute_range"))
		
		// All Pmin/Pmax and lb/ub combinations
		var modes_theo_bounds_filename_lb_pmin=			modes_theo_bounds+"-lb-pmin.modest"
		var modes_theo_bounds_filename_lb_pmax=			modes_theo_bounds+"-lb-pmax.modest"

		var modes_theo_bounds_filename_lb_pmin_result=	modes_theo_bounds+"-lb-pmin-results.dat"
		var modes_theo_bounds_filename_lb_pmax_result=	modes_theo_bounds+"-lb-pmax-results.dat"

		var modes_theo_bounds_filename_lb_pmin_cdf = 	modes_theo_bounds+"-lb-pmin-cdf.out"
		var modes_theo_bounds_filename_lb_pmax_cdf =	modes_theo_bounds+"-lb-pmax-cdf.out"
		
		var modes_theo_bounds_graph =					modes_theo_bounds+"-graph"
		var modes_theo_bounds_numstates =				modes_theo_bounds+"-num-states.dat"
		
		var modes_theo_bounds_seg =				     	modes_theo_bounds.split("/").toList
		var graph_title=								modes_theo_bounds_seg.get(modes_theo_bounds_seg.length-3) + " " +
														modes_theo_bounds_seg.get(modes_theo_bounds_seg.length-1) // DSI and filename
		
		// compute and store the minimum and maximum number of states first
		if(IdslConfiguration.Lookup_value("retrieve_number_of_states_before_model_checking")=="true"){
			var pmin_min_max_states = PTAmodelcheck_retrieve_num_states(modes_theo_bounds_filename_lb_pmin)
			var pmax_min_max_states = PTAmodelcheck_retrieve_num_states(modes_theo_bounds_filename_lb_pmax)
		
			var PrintWriter writer = new PrintWriter(modes_theo_bounds_numstates, "UTF-8")
			writer.println("pmin min_states = "+pmin_min_max_states.key + " max_states = " + pmin_min_max_states.value)
			writer.println("pmax min_states = "+pmax_min_max_states.key + " max_states = " + pmax_min_max_states.value)
			writer.close
		}
		
		var Pair<List<Integer>,List<Double>> p_max
		var Pair<List<Integer>,List<Double>> p_min
		
		if(IdslConfiguration.Lookup_value("PTA_brute_force_model_checking")=="true"){ // compute from 0 to comp_range
			p_max  = PTAmodelcheck(modes_theo_bounds_filename_lb_pmax, 0, comp_range)
			p_min  = PTAmodelcheck(modes_theo_bounds_filename_lb_pmin, 0, comp_range)
		}
		else if (IdslConfiguration.Lookup_value("PTA_brute_force_model_checking")=="script") { // create a batch file script to execute the commands on another computer, leading to a cache file 
			System.out.println("Creating batch script for "+modes_theo_bounds)
			var pmax_min_max = efficient_pta_model_checking(modes_theo_bounds_filename_lb_pmax)
			var pmin_min_max = efficient_pta_model_checking(modes_theo_bounds_filename_lb_pmin)
			PTAmodelcheck_create_script(modes_theo_bounds_filename_lb_pmax, (pmax_min_max.key..pmax_min_max.value).toList)
			PTAmodelcheck_create_script(modes_theo_bounds_filename_lb_pmin, (pmin_min_max.key..pmin_min_max.value).toList)
		}
		else{ // for pmin and pmax, determine the absolute bounds first, and scan between them
			System.out.println("Efficient model checking started for "+modes_theo_bounds)
			var pmax_min_max = efficient_pta_model_checking(modes_theo_bounds_filename_lb_pmax)
			var pmin_min_max = efficient_pta_model_checking(modes_theo_bounds_filename_lb_pmin)
			p_max  = PTAmodelcheck(modes_theo_bounds_filename_lb_pmax, (pmax_min_max.key..pmax_min_max.value).toList)
			p_min  = PTAmodelcheck(modes_theo_bounds_filename_lb_pmin, (pmin_min_max.key..pmin_min_max.value).toList)
			PTAmodelcheck_create_script(modes_theo_bounds_filename_lb_pmax, (pmax_min_max.key..pmax_min_max.value).toList) // create this anyways since it is little effort
			PTAmodelcheck_create_script(modes_theo_bounds_filename_lb_pmin, (pmin_min_max.key..pmin_min_max.value).toList) // create this anyways since it is little effort	
		}
		// write the results to the DSL: for both pmin and pmax
		IdslGeneratorDesignSpaceMeasurements.writePTAProbabilitiesToDSL (DSI, service, "pmax", p_max)
		IdslGeneratorDesignSpaceMeasurements.writePTAProbabilitiesToDSL (DSI, service, "pmin", p_min)
		
		//write values to CDF file
		var List<String> p_max_cdf = IdslGeneratorDesignSpaceMeasurements.convertPTAProbabilitiesToListOfCDFValues("pmax", p_max)
		var List<String> p_min_cdf = IdslGeneratorDesignSpaceMeasurements.convertPTAProbabilitiesToListOfCDFValues("pmin", p_min)
		var fsa2 = new fsa2
		fsa2.generateFile(modes_theo_bounds_filename_lb_pmax_cdf, list_to_String(p_max_cdf))
		fsa2.generateFile(modes_theo_bounds_filename_lb_pmin_cdf, list_to_String(p_min_cdf))
		
		// write the obtained value/probabilities to files
		values_list_and_probs_list_to_file(#[modes_theo_bounds_filename_lb_pmin_result, modes_theo_bounds_filename_lb_pmax_result],
										   #[p_min.key, p_max.key], #[p_min.value, p_max.value])	
										   										 
		// write the obtained values to a graph (interpolated)
		var p_max_sc = intermediate_points (p_max, "pmax") // add intermediate points to create a staircase graph
		var p_min_sc = intermediate_points (p_min, "pmin")
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file_double(graph_title, modes_theo_bounds_graph, 
																					  #[p_min_sc.key,p_max_sc.key], #[p_min_sc.value,p_max_sc.value], 
																					  #[list_integer_double(p_min.key), list_integer_double(p_max.key)],
																					  #[p_min.value, p_max.value])			
	}
	
	def static String list_to_String (List<String> string_list)
	'''«FOR string:string_list»«string»
	«ENDFOR»'''
	
	def static PTAmodelcheck_create_script(String modes_theo_bounds, List<Integer> i_values){
		// create a batch file script to execute the commands on another computer, leading to a cache file
		val String hashcode        = hashFile(modes_theo_bounds)
		val String script_filename = modes_theo_bounds+"-script.bat"
		val String output_filename = "output.dat"
		val String mcsta_tool      = IdslConfiguration.Lookup_value("PTA_model_checking_tool")
		 
		var PrintWriter writer = new PrintWriter(script_filename, "UTF-8")
		for(value:i_values){
			val execute = mcsta_tool+" "+modes_theo_bounds+" -E \"VAL="+value.toString+"\" | find \"Result:\" | gawk \"{print $2}\""
			writer.println( "echo " + hashcode + "  >>" +output_filename )
			writer.println( "echo " + value    + "  >>" +output_filename )
			writer.println( execute  		  + "  >>" +output_filename )
		}
		writer.close		
	}
	
	def static void PTAModelcheckDynamic (String modes_theo_bounds){ 
		System.out.println(modes_theo_bounds)
		// for-loop
		// use: def static int benchmarkPTAmodelcheck (String model_name, Integer i_value){
		// DISABLE CACHE TO HAVE PROPER BENCHMARKS!!!!!

	}
	
	def static list_integer_double (List<Integer> integer_list){
		var List<Double> double_list = new ArrayList<Double>
		for(integer:integer_list)
			double_list.add(integer as double)
		return double_list
	}
	
	def static Pair<List<Double>,List<Double>> intermediate_points (Pair<List<Integer>,List<Double>> input_val_probs){ // overloading: default staircase
		intermediate_points (input_val_probs, "staircase")
	}
	
	def static Pair<List<Double>,List<Double>> intermediate_points (Pair<List<Integer>,List<Double>> input_val_probs, String interpolation_method){
		var List<Integer> input_vals  = input_val_probs.key
		var List<Double>  input_probs = input_val_probs.value
		
		var List<Double>  vals   = new ArrayList<Double>
		var List<Double>  probs  = new ArrayList<Double>
		
		for(cnt:0..input_vals.length-2){
			vals.add(input_vals.get(cnt) as double) // regular point
			probs.add(input_probs.get(cnt))			// regular point
			
			// additional points, depending on the interpolation method
			if(interpolation_method=="staircase"){ //staircase
				vals.add((input_vals.get(cnt)+input_vals.get(cnt+1) as double) /2) // in the middle of two values
				probs.add(input_probs.get(cnt))
				vals.add((input_vals.get(cnt)+input_vals.get(cnt+1) as double) /2) // in the middle of two values
				probs.add(input_probs.get(cnt+1))
			}
			
			if (interpolation_method=="pmin"){ // interpolate low
				vals.add(input_vals.get(cnt+1) as double)
				probs.add(input_probs.get(cnt))
			}
			
			if (interpolation_method=="pmax"){ // interpolate high  
				vals.add(input_vals.get(cnt) as double)
				probs.add(input_probs.get(cnt+1))
			}
			
		}
		// manually add the last one
		vals.add(input_vals.last as double)
		probs.add(input_probs.last)
		return vals -> probs
	}
	
	def static public void values_list_and_probs_list_to_file(List<String> filepaths, List<List<Integer>> values_list, List<List<Double>> probs_list){
		for(cnt:1..values_list.length) // write eCDFs to file  
			IdslGeneratorSyntacticSugarECDF.listToFile(filepaths.get(cnt-1), IdslGeneratorSyntacticSugarECDF.value_probability_string_int(values_list.get(cnt-1), probs_list.get(cnt-1)))	
	}

	// finds the highest value range [2^n:2^n+1] containing p=0, and the lowest value range [2^m:2^m+1] containing p=1
	def static Pair<Integer,Integer> PTAModelcheck_find_lb_and_ub (String model_name){ PTAModelcheck_find_lb_and_ub (model_name, 1, 0) }
	
	def static Pair<Integer,Integer> PTAModelcheck_find_lb_and_ub (String model_name, int current_value, int lb){
		val int    upper_search_bound = new Integer(IdslConfiguration.Lookup_value("PTA_binary_search_upperbound"))
		val double threshold          = new Double(IdslConfiguration.Lookup_value("PTA_binary_search_threshold"))
		var int new_lb=lb

		// compute the probability for current_value
		val Pair<Integer,Double> val_prob = IdslGeneratorPerformExperimentPTAModelCheck.PTAmodelcheck(model_name,current_value)
		val prob=val_prob.value

		// lb is raised whenever result=0
		if (prob<threshold)
			new_lb=current_value // still in the lower bound
		
		if ((1-prob)<threshold) // found an upper bound
			return new_lb -> current_value
		else if (current_value*2 > upper_search_bound) // unfortunately, the search has ended
			return new_lb -> upper_search_bound
		else // the search continues
			return PTAModelcheck_find_lb_and_ub(model_name, current_value*2, new_lb)
	}
	
	// finds, given a value range, the highest value for which p=0
	def static int PTAModelcheck_find_lb(String model_name, int range_min, int range_max){
		val double threshold          = new Double(IdslConfiguration.Lookup_value("PTA_binary_search_threshold"))
		
		if(Math.abs(range_min-range_max)<=1) // the range is small enough, return the value
			return range_min
		
		val int range_middle=(range_min+range_max)/2
		
		val Pair<Integer,Double> val_prob = IdslGeneratorPerformExperimentPTAModelCheck.PTAmodelcheck(model_name,range_middle)
		if (val_prob.value<threshold) // prob=0: continue with higher half of range
			return PTAModelcheck_find_lb(model_name,range_middle,range_max)
		else
			return PTAModelcheck_find_lb(model_name,range_min,range_middle)
	}
	
	//finds, given a value range, the lowest value for which p=1
	def static int PTAModelcheck_find_up(String model_name, int range_min, int range_max){
		val double threshold          = new Double(IdslConfiguration.Lookup_value("PTA_binary_search_threshold"))
		val int    upper_search_bound = new Integer(IdslConfiguration.Lookup_value("PTA_binary_search_upperbound"))
		
		if(range_max>upper_search_bound) // truncate the range to be within the maximum allowed
			return PTAModelcheck_find_up(model_name,range_min,upper_search_bound)		
		if(Math.abs(range_min-range_max)<=1) // the range is small enough, return the value
			return range_min
		
		val int range_middle=(range_min+range_max)/2
		
		val Pair<Integer,Double> val_prob = IdslGeneratorPerformExperimentPTAModelCheck.PTAmodelcheck(model_name,range_middle)
		if ((1-val_prob.value)<threshold) // prob=1: continue with lower half of range
			return PTAModelcheck_find_up(model_name,range_min,range_middle)
		else
			return PTAModelcheck_find_up(model_name,range_middle,range_max)		
	}
	

	def static void main(String[] args) {
		// some_brute_force_experiments // SEE BELOW!!
		
		// MODEL SELECTION		
		//val String filename = "simple.idsl_15-1-2015fmodes_theo_bounds_p2-ub-pmin.modest"
		//val String filename = "biplane-paper_one_design.idsl_15-1-2015emodes_theo_bounds_Image_Processing-lb-pmax.modest"
		//val String filename ="biplane-paper_one_design.idsl_15-1-2015_simple3functionsmodes_theo_bounds_Image_Processing-lb-pmin.modest"
		//var filename0_max  = "simple.idsl_16-1-2015proto__SCN_sc_DSE_offset_0__modes_theo_bounds_p1-lb-pmax.modest.modest"
		//var filename0_min  = "simple.idsl_16-1-2015proto__SCN_sc_DSE_offset_0__modes_theo_bounds_p1-lb-pmin.modest.modest"
		//var filename10_max = "simple.idsl_16-1-2015proto__SCN_sc_DSE_offset_10__modes_theo_bounds_p1-lb-pmax.modest.modest"
		//var filename10_min = "simple.idsl_16-1-2015proto__SCN_sc_DSE_offset_10__modes_theo_bounds_p1-lb-pmin.modest.modest"
		//var filename15_max = "simple.idsl_16-1-2015proto__SCN_sc_DSE_offset_15__modes_theo_bounds_p1-lb-pmax.modest.modest"
		//var filename15_min = "simple.idsl_16-1-2015proto__SCN_sc_DSE_offset_15__modes_theo_bounds_p1-lb-pmin.modest.modest"
		//var filename5_max  = "simple.idsl_16-1-2015proto__SCN_sc_DSE_offset_5__modes_theo_bounds_p1-lb-pmax.modest.modest"
		//var filename5_min  = "simple.idsl_16-1-2015proto__SCN_sc_DSE_offset_5__modes_theo_bounds_p1-lb-pmin.modest.modest"

		/*var filename0_max  = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_0__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename0_min  = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_0__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename10_max = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_10__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename10_min = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_10__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename15_max = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_15__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename15_min = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_15__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename5_max  = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_5__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename5_min  = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_5__modes_theo_bounds_p1-lb-pmin.modest.modest"*/

		/*var filename0_max  = "R:\\Simple4.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_0__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename0_min  = "R:\\Simple4.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_0__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename10_max  = "R:\\Simple4.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_10__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename10_min  = "R:\\Simple4.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_10__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename15_max  = "R:\\Simple4.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_15__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename15_min  = "R:\\Simple4.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_15__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename5_max  = "R:\\Simple4.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_5__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename5_min  = "R:\\Simple4.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_5__modes_theo_bounds_p1-lb-pmin.modest.modest"

		var min_max = PTAModelcheck_find_lb_and_ub(filename0_max)
		System.out.println("minimum: "+min_max.key )
		System.out.println("maximum: "+min_max.value )
		
		var exact_min = PTAModelcheck_find_lb(filename0_max, min_max.key, min_max.key*2)
		var exact_max = PTAModelcheck_find_up(filename0_max, min_max.value/2, min_max.value)
		System.out.println("exact minimum: "+exact_min )
		System.out.println("exact maximum: "+exact_max )*/
		
		System.out.println(hashFile("c:\\temp\\freekvdb"))
		
		//var Pair<List<Integer>,List<Double>> f0_max  = PTAmodelcheck(filename0_max,2,23)
		//var Pair<List<Integer>,List<Double>> f0_min  = PTAmodelcheck(filename0_min,2,23)
		//IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file("r:\\graph00_2", #[f0_min.key,f0_max.key], #[f0_min.value,f0_max.value])
		
		/*var Pair<List<Integer>,List<Double>> f10_max = PTAmodelcheck(filename10_max,0,20,"output2")
		var Pair<List<Integer>,List<Double>> f10_min = PTAmodelcheck(filename10_min,0,20,"output2")
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file("r:\\graph10_2", #[f10_min.key,f10_max.key], #[f10_min.value,f10_max.value])
		
		var Pair<List<Integer>,List<Double>> f15_max = PTAmodelcheck(filename15_max,0,20,"output2")
		var Pair<List<Integer>,List<Double>> f15_min = PTAmodelcheck(filename15_min,0,20,"output2")
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file("r:\\graph15_2", #[f15_min.key,f15_max.key], #[f15_min.value,f15_max.value])
		
		var Pair<List<Integer>,List<Double>> f5_max  = PTAmodelcheck(filename5_max,0,20,"output2")
		var Pair<List<Integer>,List<Double>> f5_min  = PTAmodelcheck(filename5_min,0,20,"output2")
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file("r:\\graph05_2", #[f5_min.key,f5_max.key], #[f5_min.value,f5_max.value])*/
	}


	def some_brute_force_experiments(){
		var filename0_max  = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_0__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename0_min  = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_0__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename10_max = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_10__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename10_min = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_10__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename15_max = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_15__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename15_min = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_15__modes_theo_bounds_p1-lb-pmin.modest.modest"
		var filename5_max  = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_5__modes_theo_bounds_p1-lb-pmax.modest.modest"
		var filename5_min  = "R:\\simple.idsl_22-1-2015binarysearch__SCN_sc_DSE_offset_5__modes_theo_bounds_p1-lb-pmin.modest.modest"

		var Pair<List<Integer>,List<Double>> f0_max  = PTAmodelcheck(filename0_max,2,23)
		var Pair<List<Integer>,List<Double>> f0_min  = PTAmodelcheck(filename0_min,2,23)
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file("r:\\graph00_2", #[f0_min.key,f0_max.key], #[f0_min.value,f0_max.value])
		
		/*var Pair<List<Integer>,List<Double>> f10_max = PTAmodelcheck(filename10_max,0,20,"output2")
		var Pair<List<Integer>,List<Double>> f10_min = PTAmodelcheck(filename10_min,0,20,"output2")
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file("r:\\graph10_2", #[f10_min.key,f10_max.key], #[f10_min.value,f10_max.value])
		
		var Pair<List<Integer>,List<Double>> f15_max = PTAmodelcheck(filename15_max,0,20,"output2")
		var Pair<List<Integer>,List<Double>> f15_min = PTAmodelcheck(filename15_min,0,20,"output2")
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file("r:\\graph15_2", #[f15_min.key,f15_max.key], #[f15_min.value,f15_max.value])
		
		var Pair<List<Integer>,List<Double>> f5_max  = PTAmodelcheck(filename5_max,0,20,"output2")
		var Pair<List<Integer>,List<Double>> f5_min  = PTAmodelcheck(filename5_min,0,20,"output2")
		IdslGeneratorSyntacticSugarECDF.write_valueprobs_GNUplot_graph_to_file("r:\\graph05_2", #[f5_min.key,f5_max.key], #[f5_min.value,f5_max.value])*/		
	}
}





// ************************************* CLASS THAT ENABLES MULTITHREADING *************************************
// number of threads is defined in config: IdslConfiguration.Lookup_value("number_of_threads_to_use_for_pta_model_checking")
class RunnablePTAs implements Runnable {
	   var private Thread t
	   var private String threadName
	   var private String model
	   var private List<Integer> values
	   var private List<Double> probs = new ArrayList<Double>
		
	   new(String name, String model_name, List<Integer> vals) {
	       values=vals
	       threadName = name
	       model = model_name
	       System.out.println("Creating " +  threadName )
	   }
	      
	   override public void run() {
	      System.out.println("Running " +  threadName )
	      try {
	         for(i:values) {
	            System.out.println("Thread: " + threadName + ", " + i)
	            val Pair<Integer,Double> val_prob = IdslGeneratorPerformExperimentPTAModelCheck.PTAmodelcheck(model,i)
	            probs.add(val_prob.value)
	         }
	     } catch (InterruptedException e) {
	         System.out.println("Thread " +  threadName + " interrupted.")
	     }
	     System.out.println("Thread " +  threadName + " exiting.")
	   }
	   
	   def Pair<List<Integer>,List<Double>> result (){ return values -> probs } // returns the final result of the number of computations.
	   def public Thread thread(){ return t } // to enable a join (wait for it to finish) at a higher level }
	   
	   def public void start () {
	      System.out.println("Starting " +  threadName )
	      if (t == null){
	      	t = new Thread (this, threadName)
	      	t.start
	      }
	   }
}