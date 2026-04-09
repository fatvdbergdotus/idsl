package org.idsl.language.generator

import java.io.File
import java.util.List
import org.eclipse.xtext.generator.IFileSystemAccess
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.Scenario
import org.idsl.language.idsl.Service

import static org.idsl.language.generator.IdslGeneratorGlobalVariables.*
import java.util.ArrayList
import org.idsl.language.idsl.StopwatchDistribution
import org.idsl.language.idsl.OneStopwatchPerInstance
import org.idsl.language.idsl.OneGlobalStopwatchForInstances


class IdslGeneratorPerformExperimentSimulationLoadBalancer {
		def static Pair<Boolean,Boolean> ret_oneStopwatchPerInstance_OneGlobalStopwatchForInstances(List<StopwatchDistribution> sd){
			if(sd.empty)
				return false -> false
			/*switch(sd.head){
				case OneStopwatchPerInstanceImpl: 		 	return true -> null
				case OneGlobalStopwatchForInstancesImpl: 	return null -> true 
			}*/
			// TEMPORARY QUICK FIX (to replace the above):
			if (sd.head.toString.contains("OneStopwatchPerInstanceImpl")) 			
				return true -> false
			if (sd.head.toString.contains("OneGlobalStopwatchForInstancesImpl")) 		
				return false -> true 
			throw new Throwable ("ret_oneStopwatchPerInstance_OneGlobalStopwatchForInstances: sd type not supported!")
		}

		def static public performExperimentSimulation_loadbalancing(int num_runs, int num_activityis, IFileSystemAccess fsa, 
									String extPath, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi, 
									List<Service> activities, List<ExtendedProcessModel> epms, 
									List<Mapping> mappings, List<ResourceModel> resources, String urgent, 
									String variableType, List<StopwatchDistribution> sd){
		var dirPath= 							"ExpSimulation_"+num_runs.toString+"_"+num_activityis.toString+"/"
		var modes_sim_latency_filename=			extPath+dirPath+"modes_sim_latency.modest"
		var dirPathB=							IdslGeneratorGNUplot.path_slash_to_backslash(dirPath)
		var extPathB=							IdslGeneratorGNUplot.path_slash_to_backslash(extPath)

		//IdslConfiguration.writeTimeToTimestampFile("PerformExperimentSimulationLoadBalancer START")

		var Pair<Boolean,Boolean> ospi_ogsfi = ret_oneStopwatchPerInstance_OneGlobalStopwatchForInstances(sd)
		//if (ospi_ogsfi.key==null)
		//	throw new Throwable("performExperimentSimulation_loadbalancing: OneGlobalStopwatchForInstances not supported!")
		fsa.generateFile(
			modes_sim_latency_filename,
			IdslGeneratorMODES.DSEScenarioToModest(num_activityis, s, dsm, dsi, activities, epms, mappings, resources, 
												   true, true, false, false, urgent, variableType, ospi_ogsfi.key, ospi_ogsfi.value).toString)
		// ONLY NEEDED FOR lastDelay: IdslGeneratorGlobalVariables.add_global_counter_to_modest_code=true // add "global_time" process to the modest code
		// ONLY NEEDED FOR lastDelay: 		IdslGeneratorGlobalVariables.add_global_counter_to_modest_code=false  
		// IdslGeneratorMODESv2.global_counter.toString /* the counter is used to determine the lastDelay of a system */+
		
		new File(extPath+dirPath+"results").mkdir
		
		
		/*var int num_threads = new Integer(IdslConfiguration.Lookup_value("number_of_threads_to_use_for_pta_model_checking"))

		
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
		}*/
		
		
		
		for(cnt:1..num_runs){ // seperate simulation runs and post-processing
			var modes_sim_latency_output_filename_1run 		 = extPath+dirPath+"results/modes_sim_latency_run"+cnt+".output"
			var modes_sim_latency_output_filename_1run_short = extPath+dirPath+"results/modes_sim_latency_run"+cnt+"_short.output"
			
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add( // perform 1 simulation run
				IdslConfiguration.Lookup_value("modes2_path")+"modes2.exe "+
				IdslConfiguration.Lookup_value("modes2_parameters")+" "+modes_sim_latency_filename, 
				modes_sim_latency_output_filename_1run, "MODES2 simulation")
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add( // parse results
				"gawk \"{if ($2==\\\"Property\\\") printf \\\""+cnt.toString+" %s \\\",$3; if ($1==\\\"Mean:\\\") print $2}\" "+
				modes_sim_latency_output_filename_1run,	
				modes_sim_latency_output_filename_1run_short, "MODES2 parsing")
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add( // add results to global result file
				"type "+extPathB+dirPathB+"results\\modes_sim_latency_run"+cnt+"_short.output >> "
				+extPathB+dirPathB+"results\\modes_sim_latency_all_short.output",
				"","MODES2 merge results")															 
		}
		IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add( // extract latencies from global result file
			"type "+extPathB+dirPathB+"results\\modes_sim_latency_all_short.output | find \" property_instance\" |"+
			"gawk \"{print $3}\" >> " + extPathB+dirPathB+"results\\modes_sim_latency_latency_all_short.output",
			"","MODES2 extract results")
			
		IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add( // extract timeouts from global result file
			"type "+extPathB+dirPathB+"results\\modes_sim_latency_all_short.output | find \"_timeouts_\" |"+
			"gawk \"{print $3}\" >> " + extPathB+dirPathB+"results\\modes_sim_latency_timeout_all_short.output",
			"","MODES2 extract results")			
			
		IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add( // extract power from global result file
			"type "+extPathB+dirPathB+"results\\modes_sim_latency_all_short.output | find \"_avg_power \" |"+
			"gawk \"{print $3}\" >> " + extPathB+dirPathB+"results\\modes_sim_latency_avg_power_all_short.output",
			"","MODES2 extract results")

		IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add( // compute average latency and power (and confidence intervals??)
			IdslGeneratorDesignSpace.DSMvalues(dsi),
			extPathB+dirPathB,
			"ComputeAverageLatencyAndPower")

		//IdslConfiguration.writeTimeToTimestampFile("PerformExperimentSimulationLoadBalancer STOP")

		//		var modes_sim_latency_output_filename_nruns  =	extPath+dirPath+"/results/modes_sim_latency_nruns.output"
		//		IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("modes2_path")+"modes2.exe "+
		//  	IdslConfiguration.Lookup_value("modes2_parameters_100_runs")+" "+
		//		modes_sim_latency_filename, modes_sim_latency_output_filename_nruns, "MODES2 simulation")		
		// modes2 -R Uniform -S ASAP --runs 1 "modes_sim_latency.modest" | gawk "{if ($2==\"Property\") printf \"%s \",$3; if ($1==\"Mean:\") print $2}"					
	}	
	
	def static void extractAvgPowerAndLatencyWithCI(String DSIstring, String path){
		extractAvgPowerAndLatencyWithCI(DSIstring,
										path+"results\\modes_sim_latency_avg_power_all_short.output",
										path+"results\\modes_sim_latency_latency_all_short.output",
										path+"results\\modes_sim_latency_timeout_all_short.output",
										path+"results\\modes_sim_latency_summary.output",
										path+"..\\..\\modes_sim_latency_latency_csv.output") // ..\..\ => main folder of experiment
	}
	
	def static void extractAvgPowerAndLatencyWithCI(String DSIstring, String powerFile, String latencyFile, 
														String timeoutFile, String summaryFile, String latencyCSVFile
	){
		var powerList   = IdslGeneratorSyntacticSugarECDF.fileToList(powerFile)
		var latencyList = IdslGeneratorSyntacticSugarECDF.fileToList(latencyFile)
		var timeoutList = IdslGeneratorSyntacticSugarECDF.fileToList(timeoutFile)
		var outputList  = new ArrayList<String>
		
		// modes_sim_latency_latency_csv.output
		var CSVoutput = DSIstring
		for(latency:latencyList)
			CSVoutput = CSVoutput + "," + latency
		IdslGeneratorSyntacticSugarECDF.listToFile(latencyCSVFile, CSVoutput)
		
		// modes_sim_latency_summary.output
		outputList.add("designSpaceInstance " + DSIstring)
		outputList.add("averageLatency " 	  + average(latencyList.map[x | new Double(x)]).toString)
		outputList.add("CI99Latency "        + confidence_interval_99(latencyList.map[x | new Double(x)]).toString)
		outputList.add("averagePower "   	  + average(powerList.map[x | new Double(x)]).toString)
		outputList.add("totalTimeouts "       + sum(timeoutList.map[x | new Double(x)]).toString)
		outputList.add("")
		IdslGeneratorSyntacticSugarECDF.listToFile(summaryFile, outputList)
		
		// modes_sim_latency_summary.output (to screen)
		System.out.println("designSpaceInstance " + DSIstring)
		System.out.println("averageLatency " + average(latencyList.map[x | new Double(x)]).toString)
		System.out.println("CI99latency "    + confidence_interval_99(latencyList.map[x | new Double(x)]).toString)
		System.out.println("averagePower "   + average(powerList.map[x | new Double(x)]).toString)
		System.out.println("totalTimeouts "       + sum(timeoutList.map[x | new Double(x)]).toString)
		System.out.println("")	
	}
	
	//IdslGeneratorSyntacticSugarECDF.listToFile
	//IdslGeneratorSyntacticSugarECDF.fileToList
	
	def static double standard_deviation(List<Double> numbers){
        // first pass: read in data, compute sample mean
        var double dataSum = 0.0;
        for(number:numbers)
            dataSum = dataSum + number
        var double average = dataSum / numbers.length;

		// second pass
        var double variance1 = 0.0;
        for (cnt:(0..numbers.length-1))
            variance1 = variance1 + ((numbers.get(cnt) - average) * (numbers.get(cnt) - average))

        var double variance = variance1 / (numbers.length - 1)
        var double standardDaviation= Math.sqrt(variance)
		return standardDaviation
	}
	
	def static double confidence_interval_99 (List<Double> numbers){
		var low_up = IdslGeneratorStatistics.lower_and_upper_bound_pair(numbers,IdslGeneratorStatistics.twosided_column(99.0))
		var avg = (low_up.key + low_up.value) / 2
		return low_up.value-avg
	}
	
	def static double average(List<Double> numbers){
		var sum=0.0
		for(number:numbers)
			sum=sum+number
		return sum/numbers.length
	}
	
	def static double sum(List<Double> numbers){
		var sum=0.0
		for(number:numbers)
			sum=sum+number
		return sum		
	}
	
	def static void main(String[] args) {
		var numbers = #[8.0,7.0,8.0,6.5,7.0,8.0,5.4,6.5,7.6,8.7,9.9]
		var ci=confidence_interval_99(numbers)
		System.out.println(ci)
	}			
}

/*
class RunnableLBsim implements Runnable {
	   var private Thread t
	   var private String threadName
	   new(String name, String model_name, List<Integer> vals) {
	       //values=vals
	       threadName = name
	       //model = model_name
	       System.out.println("Creating " +  threadName )
	   }
	      
	   override public void run() {
	      System.out.println("Running " +  threadName )
	      try {


	     } catch (InterruptedException e) {
	         System.out.println("Thread " +  threadName + " interrupted.")
	     }
	     System.out.println("Thread " +  threadName + " exiting.")
	   }
	   
	   
	   def public void start () {
	      System.out.println("Starting " +  threadName )
	      if (t == null){
	      	t = new Thread (this, threadName)
	      	t.start
	      }
	   }
}  */ 