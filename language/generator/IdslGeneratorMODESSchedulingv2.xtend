// Improved version of IdslGeneratorMODESScheduling which is more efficient with Model Checking
package org.idsl.language.generator

import org.idsl.language.idsl.CompoundResourceTree
import org.idsl.language.idsl.ResourceTree
import java.util.List
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.TimeSlice
import org.idsl.language.idsl.SchedulingPolicy
import org.idsl.language.idsl.ProcessResource
import java.util.ArrayList
import java.util.HashSet
import java.util.Set
import org.idsl.language.idsl.AExpVal
import org.idsl.language.idsl.SchedulingPolicyNonDet
import org.idsl.language.idsl.SchedulingPolicyFIFO
import org.idsl.language.idsl.PriorityLevelHigh
import org.idsl.language.idsl.PriorityLevelMedium
import org.idsl.language.idsl.PriorityLevelLow
import org.idsl.language.idsl.LoadBalancerConfiguration
import org.idsl.language.idsl.AExp
import org.idsl.language.idsl.AtomicResourceTree
import org.idsl.language.idsl.PFPAtomicResourceTree

class IdslGeneratorMODESSchedulingv2  {
	// IdslGeneratorMODESSchedulingv2.ResourceNameToText(res, resources, mappings, dsi, utilizationEnabled, urgent, variableType, flatten_final_properties(final_properties))
	def static CharSequence ResourceNameToText ( int counter, int num_activityis, Set<String> processes,
								   Pair<String,LoadBalancerConfiguration> res_config, List<ResourceModel> resources, 
								   List<Mapping> mappings, DesignSpaceModel dsi, 
								   boolean utilizationEnabled, String urgent, String variableType, String final_properties) {
		if(res_config.value!=null)  // energy enabled resource 
 			return Energy_enabled_ResourceNameToText(
			 	counter, num_activityis, processes, res_config, resources, mappings, dsi, 
			 	utilizationEnabled, urgent, variableType, final_properties)			 
		
		var res=returnResource(res_config.key,resources)	 
		switch(res){
			AtomicResourceTree: return Regular_ResourceNameToText(
				res_config.key, resources, mappings, dsi, utilizationEnabled, urgent, variableType, final_properties)
 			PFPAtomicResourceTree: return PFPAtomicResource.ResourceNameToText(
				num_activityis, res, res_config.key, resources, mappings, dsi, utilizationEnabled, urgent, variableType, final_properties)
 			
 			default: throw new Throwable("ResourceNameToText: resource type not recognized!")
		}										   
	}
	
	def static ResourceTree returnResource(String resname, List<ResourceModel> resources){
		var List<ResourceTree> rts = returnAtomicResourceTreePFPAtomicResourceTree(resources)
		for(rt:rts)
			if(rt.name==resname)
				return rt
		
		throw new Throwable("returnResource: resource with name "+resname+" not found in list of resources!")
	}
	
	def static List<ResourceTree> returnAtomicResourceTreePFPAtomicResourceTree (List<ResourceModel> resources){
		var List<ResourceTree> ret = new ArrayList<ResourceTree>
		for(resource:resources){
			ret.addAll(returnAtomicResourceTreePFPAtomicResourceTree(resource.restree.head))	
		}
		return ret
	}
	
	def static List<ResourceTree> returnAtomicResourceTreePFPAtomicResourceTree (ResourceTree rt){
		var ret = new ArrayList<ResourceTree>
		ret.addAll(returnResourceTree(rt))
		return ret
	}
	
	def static List<ResourceTree> returnResourceTree (ResourceTree rt){
		var ret = new ArrayList<ResourceTree>
		switch(rt){
			PFPAtomicResourceTree: ret.add(rt)
			AtomicResourceTree: ret.add(rt)
			CompoundResourceTree: { for(rtree:rt.rtree) ret.addAll(returnResourceTree(rtree)) }
		}
		return ret
	}
	
	def static CharSequence Energy_enabled_ResourceNameToText (int counter, int num_activityis, Set<String> processes,
								   Pair<String,LoadBalancerConfiguration> res_lbconfig,  List<ResourceModel> resources, 
								   List<Mapping> mappings, DesignSpaceModel dsi, 
								   boolean utilizationEnabled, String urgent, String variableType, String final_properties) {	
		var int num_res_off = new Integer(IdslConfiguration.Lookup_value("how_many_energy_aware_resources_switched_off_at_start"))
		if(counter>num_res_off)
			IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: machine_"+res_lbconfig.key+"()")
		else
			IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: machine_"+res_lbconfig.key+"_off()")		
			
		var res 		= res_lbconfig.key
		var lbconfig 	= res_lbconfig.value
		
		var int buffersize= new Integer(IdslConfiguration.Lookup_value("buffersize_resources")) // the default queue size of resources
		var taskrate="/( " + ResourceTaskRate(res, resources, dsi, variableType) + ")"
		
		if (variableType=="int") 
			taskrate="" // Taskrates are 1 for int to avoid divisions
		
		var spolicy 				= ResourceNameToSchedulingPolicy(res, mappings)
		var boolean needBuffers 	= needBuffersSched(spolicy)
		var time_slice 				= ResourceNameToTimeSlice(res, mappings).time
		var boolean isPreemptive 	= isPremptivAExp(time_slice)
		var num_processes 			= ResourceNameToCallingProcesses(res, mappings).length
		var timeout_time			= IdslGeneratorExpression.printAExp(lbconfig.timeOutTime.head, dsi, variableType).toString
		var switchoff_time			= IdslGeneratorExpression.printAExp(lbconfig.timeShutdown.head, dsi, variableType).toString
		var turnon_time             = IdslGeneratorExpression.printAExp(lbconfig.timeStartUp.head, dsi, variableType).toString
		var energy_on				= IdslGeneratorExpression.printAExp(lbconfig.energyOn.head, dsi, variableType).toString
		var energy_off				= IdslGeneratorExpression.printAExp(lbconfig.energySleep.head, dsi, variableType).toString
		var energy_shutdown			= IdslGeneratorExpression.printAExp(lbconfig.energyShutdown.head, dsi, variableType).toString
		var energy_startup			= IdslGeneratorExpression.printAExp(lbconfig.energyStartup.head, dsi, variableType).toString

		if(!needBuffers)
			throw new Throwable("Energy_enabled_ResourceNameToText: non-deterministic resources not supported (yet)!")

		// override when timeslicing is disabled for integers
		if (IdslConfiguration.Lookup_value("always_no_timeslice_when_integers_used")=="true" && variableType=="int") isPreemptive=false

		var multiplier = ""
		if (variableType=="real") 
			multiplier=" * "+IdslConfiguration.Lookup_value("small_multiplier_when_reals_used")
	
	'''
	
	// Resource «res» (energy aware resource)
	process machine_«res»(){
		clock c;
		int process_id;
		
		urgent tau {= c=0, state_«res»_on=1, state_«res»_sleep=0, state_«res»_shutdown=0, state_«res»_startup=0 =};
		
		invariant(der(«res»_energy) == «energy_on» /* energy_on */ && der(time_«res»_on) == 1)
	  	«fetchPackageFromBuffer (res, "machine_"+res+"_continue()", timeout_time)»
	}
	
	process machine_«res»_continue(){ // not executed when timing out
		clock c;
		«variableType» taskload_min;
		«variableType» taskload_max;
	    
	    «retrieveTaskLoads(num_processes, res)»
		
		urgent tau {= c=0, state_«res»_on=1, state_«res»_sleep=0, state_«res»_shutdown=0, state_«res»_startup=0 =};
		invariant(der(«res»_energy) == «energy_on» /* energy_on */ && der(time_«res»_on) == 1)
		«perform_nonDeterminsticDelay(false)»
		«returnResult(num_processes, res)»

		machine_«res»() // recursion to keep the machine alive forever
	}
	
	
	process machine_«res»_off() { // the machine is turned off
		// switch off
		clock c;
		int process_id;
		
		// time to shutdown
		tau {= c=0, state_«res»_on=0, state_«res»_sleep=0, state_«res»_shutdown=1, state_«res»_startup=0 =};
		invariant(der(«res»_energy) == «energy_shutdown» /* energy_shutdown */ && der(time_«res»_shutdown) == 1)
		when urgent (c>=«switchoff_time»)
			tau {= c=0, state_«res»_on=0, state_«res»_sleep=1, state_«res»_shutdown=0, state_«res»_startup=0 =};
		
		invariant(der(«res»_energy) == «energy_off» /* energy_off */ && der(time_«res»_sleep) == 1)
		«fetchPackageFromBuffer (res, "urgent tau {= c=0, state_"+res+"_on=0, state_"+res+"_sleep=0, state_"+res+"_shutdown=0, state_"+res+"_startup=1 =}; invariant(der("+res+"_energy) == "+energy_startup+" /* energy_startup */ && der(time_"+res+"_startup) == 1) when urgent (c>="+turnon_time+") /*turnon_time*/ tau; machine_"+res+"_continue()", "0")»
	}	
	
	«defineBuffersAndSizes(res,buffersize)»
	
	«defineRewardsAndProperties(num_activityis, processes, res)»
	
	«abstractFunctionsCallingResource(res, mappings, variableType, needBuffers)»
	'''
		// TODO: finish function					  
	}
	
	def static CharSequence Regular_ResourceNameToText (String res, List<ResourceModel> resources, 
								   List<Mapping> mappings, DesignSpaceModel dsi, 
								   boolean utilizationEnabled, String urgent, String variableType, String final_properties) {		
		// add global processes
		IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: machine_"+res+"()")
		var int buffersize= new Integer(IdslConfiguration.Lookup_value("buffersize_resources")) // the default queue size of resources
		var taskrate="/( " + ResourceTaskRate(res, resources, dsi, variableType) + ")"
		
		if (variableType=="int") 
			taskrate="" // Taskrates are 1 for int to avoid divisions
		
		var spolicy 				= ResourceNameToSchedulingPolicy(res, mappings)
		var boolean needBuffers 	= needBuffersSched(spolicy)
		var time_slice 				= ResourceNameToTimeSlice(res, mappings).time
		var boolean isPreemptive 	= isPremptivAExp(time_slice)
		var num_processes 			= ResourceNameToCallingProcesses(res, mappings).length

		// override when timeslicing is disabled for integers
		if (IdslConfiguration.Lookup_value("always_no_timeslice_when_integers_used")=="true" && variableType=="int") isPreemptive=false
		
		var multiplier = ""
		if (variableType=="real") 
			multiplier=" * "+IdslConfiguration.Lookup_value("small_multiplier_when_reals_used")	
		
			'''
	// Resource «res»
	process machine_«res»(){
		clock c;
		«variableType» taskload_min;
		«variableType» taskload_max;
		int process_id;

	    «IF needBuffers»
	    	«fetchPackageFromBuffer (res)»;
	    	«retrieveTaskLoads(num_processes, res)»
		«ELSE»
			«fetchPackageNonDeterministically(num_processes, res)»
		«ENDIF»

		«perform_nonDeterminsticDelay(true)»
		«returnResult(num_processes, res)»

		machine_«res»() // recursion to keep the machine alive forever
	}	
	
	«IF needBuffers»
		«defineBuffersAndSizes(res, buffersize)»
	«ENDIF»	

	«abstractFunctionsCallingResource(res, mappings, variableType, needBuffers)»
	'''}
	
	def static defineBuffersAndSizes (String res, int buffersize)'''
		buffer «res»_buffer_processid_high_instance, «res»_buffer_processid_medium_instance, «res»_buffer_processid_low_instance;
		const int «res»_buffer_processid_N=«buffersize»;		
	'''
	
	def static defineRewardsAndProperties (int num_activityis, Set<String> processes, String res)'''
		// energy used
		reward «res»_energy;
		
		//time spend in various states
		reward time_«res»_on; 
		reward time_«res»_sleep;
		reward time_«res»_shutdown;
		reward time_«res»_startup;
		
		//is the system in a certain state? (indicator functions)
		int state_«res»_on=1;
		int state_«res»_sleep=0;
		int state_«res»_shutdown=0;
		int state_«res»_startup=0;

		// properties to retrieve the reward values
		«FOR p:processes»
		property property_time_«res»_on 	 	 = Xmax( time_«res»_on       | stopwatch_counter_«p»==«num_activityis»);
		property property_time_«res»_shutdown 	 = Xmax( time_«res»_shutdown | stopwatch_counter_«p»==«num_activityis»);
		property property_time_«res»_sleep 	 	 = Xmax( time_«res»_sleep    | stopwatch_counter_«p»==«num_activityis»);
		property property_time_«res»_startup 	 = Xmax( time_«res»_startup  | stopwatch_counter_«p»==«num_activityis»);
		property property_«res»_energy			 = Xmax( «res»_energy  	  	 | stopwatch_counter_«p»==«num_activityis»);
		property property_«res»_avg_power		 = Xmax( «res»_energy / time | stopwatch_counter_«p»==«num_activityis»);
		«ENDFOR»
	'''

	def static returnResult(int num_processes, String res)
	'''
		«IF num_processes>1»
			alt{ // return the result
				«FOR cnt:1..num_processes»:: when urgent (process_id==«cnt») «res»_stop_«cnt»!
				«ENDFOR»
			};
		«ELSE»
			// return the result
			urgent «res»_stop_1!;
		«ENDIF»
	'''

	def static retrieveTaskLoads(int num_processes, String res)'''
			«IF num_processes>1»
				alt{ // ask for the taskload_min and the taskload_max
					«FOR cnt:1..num_processes»:: when(process_id==«cnt») «res»_start_«cnt»? {= taskload_min = sync_buffer, taskload_max = sync_buffer2 =}
					«ENDFOR» 
				};
			«ELSE»
				«res»_start_1? {= taskload_min = sync_buffer, taskload_max = sync_buffer2 =};
			«ENDIF»
	'''

	def static fetchPackageFromBuffer (String res){
		return fetchPackageFromBuffer(res, "urgent tau", "0")  // default: no extra process executed in branches, no sleep possibility
	}

	def static fetchPackageFromBuffer (String res, String cont_process, String sleep_time)'''
			alt{ // fetch a package from the buffer, adhering to the priorities (or possibly sleep)
	    		«IF sleep_time!="0"»:: when urgent(c>=«sleep_time») machine_«res»_off() // go to sleep«ENDIF»
				:: when urgent («res»_buffer_processid_high_instance.count > 0) 
				     tau {= process_id = get(«res»_buffer_processid_high_instance), «res»_buffer_processid_high_instance = remove(«res»_buffer_processid_high_instance) =}«IF cont_process!=""»;«ENDIF»
				     «cont_process»
				:: when urgent ( «res»_buffer_processid_medium_instance.count > 0 && 
								 «res»_buffer_processid_high_instance.count == 0)
					 tau {= process_id = get(«res»_buffer_processid_medium_instance), «res»_buffer_processid_medium_instance = remove(«res»_buffer_processid_medium_instance) =}«IF cont_process!=""»;«ENDIF» 
					 «cont_process»
				:: when urgent ( «res»_buffer_processid_low_instance.count > 0 && 
								 «res»_buffer_processid_medium_instance.count == 0 && 
								 «res»_buffer_processid_high_instance.count == 0)
					 tau {= process_id = get(«res»_buffer_processid_low_instance), «res»_buffer_processid_low_instance = remove(«res»_buffer_processid_low_instance) =}«IF cont_process!=""»;«ENDIF»
					 «cont_process»
			}
	'''

	def static fetchPackageNonDeterministically (int num_processes, String res)'''
		«IF num_processes>1»
		    alt { // fetch a package from the buffer, non-deterministically
					«FOR cnt:1..num_processes»:: «res»_start_«cnt»? {= taskload_min =sync_buffer, taskload_max =sync_buffer2, process_id=«cnt» =}
				    «ENDFOR»
				};
		«ELSE»
			«res»_start_1? {= taskload_min =sync_buffer, taskload_max =sync_buffer2, process_id=1 =};
		«ENDIF»	
	'''

	def static perform_nonDeterminsticDelay(boolean includeClockReset) '''
			// perform the non-determinstically timed delay
			«IF includeClockReset»urgent tau {= c=0 =};«ENDIF»
			when(c>=taskload_min) 
			urgent(c>=taskload_max) 
			tau;
	'''
	
	def static abstractFunctionsCallingResource(String res, List<Mapping> mappings, String variableType, boolean needBuffers)
			'''
			//Abstract functions for calling resource «res»
			«var cnt=1»
			«FOR proc:ResourceNameToCallingProcesses(res,mappings)»
			«var priority = procResourcePriorityText(proc, res, mappings, variableType)»
			
			process machine_call_«proc»(«variableType» taskload, «variableType» taskload_end){
			«IF needBuffers»
				when urgent («res»_buffer_processid_«priority»_instance.count < «res»_buffer_processid_N) 
					tau {= «res»_buffer_processid_«priority»_instance= add(«res»_buffer_processid_«priority»_instance, «cnt») =};
				urgent «res»_start_«cnt»! {= sync_buffer=taskload, sync_buffer2=taskload_end =};
			«ELSE»
				urgent «res»_start_«cnt»! {= sync_buffer=taskload, sync_buffer2=taskload_end =};
			«ENDIF»
				«res»_stop_«cnt»?
			}
			binary action «res»_stop_«cnt», «res»_start_«cnt»;
			«(cnt=cnt+1).toString.substring(0,0)»
			«ENDFOR»
	'''
	
	def static procResourcePriorityText(String process, String resource, List<Mapping>mappings, String variableType){
		//if (IdslConfiguration.Lookup_value("always_no_priorities_when_integers_used")=="true" && variableType=="int"){
		//	return 'high' // everything becomes high priority, to avoid delays in machine_«res»
		//}
		
		for(mapping:mappings)
			for(pr:mapping.prassignment)
				if(pr.process==process && pr.resource==resource)
					switch(pr.plevel.head){
						PriorityLevelHigh:		return 'high'
						PriorityLevelMedium:	return 'medium'
						PriorityLevelLow:		return 'low'
					}	
		throw new Throwable("The mapping between process "+process+" and resource "+resource+" is undefined.")
	}
	
	def static ResourceNameReturnResult(String res, List<Mapping> mappings, int num_processes, boolean isPreemptive, String variableType){'''
		«IF isPreemptive»
			alt{ // return the result
			«FOR cnt:(1..num_processes)»«var proc=ResourceNameToCallingProcesses(res,mappings).get(cnt-1)»
			   :: when urgent (process_id==«cnt» && taskload<=time_slice) «res»_stop_«cnt»!
			   :: when urgent (process_id==«cnt» && taskload>time_slice)  «res»_buffer1_«procResourcePriorityText(proc,res,mappings,variableType)»! {= sync_buffer=taskload-time_slice, sync_buffer2=«cnt» =}
			«ENDFOR»
			};		
		«ELSEIF num_processes==1 /* 1 process, so no ALT needed (Modest does not accept an ALT with one option)*/»
			when urgent (process_id==1) «res»_stop_1!;
		«ELSE»
			alt{ // return the result
			«FOR cnt:(1..num_processes)»   :: when urgent (process_id==«cnt») «res»_stop_«cnt»!
			«ENDFOR»};
		«ENDIF»

	'''}
/*
 			FOR DEBUGGING PURPOSES, REMOVE WHEN NOT NEEDED ANYMORE
 			«var cnt=1»«FOR proc:ResourceNameToCallingProcesses(res,mappings)»
				
			process machine_call_«proc» («variableType» taskload){
					«res»_buffer«buffer_input»_«procResourcePriorityText(proc,res,mappings)»! {= sync_buffer=taskload, sync_buffer2=«cnt» =};
					«res»_stop_«cnt»?
			}
			binary action «res»_stop_«cnt»;
			«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
*/

	def static boolean isPremptivAExp (AExp aexp){
		switch (aexp){
			AExpVal: return aexp.value!=0
			default: return true	
		}		
	}
	
	def static boolean needBuffersSched (SchedulingPolicy sp){
		switch (sp){
			SchedulingPolicyNonDet: return false
			SchedulingPolicyFIFO:	return true
			default:				throw new Throwable("Scheduling policy not supported: "+sp.toString)
		}		
	}
	

	
	// Returns the time slicing policy for a resource
 	def static TimeSlice ResourceNameToTimeSlice(String res, List<Mapping> mappings){
		for(mapping:mappings){
			if(mapping.rspolicy!=null) 
				for(rspolicy:mapping.rspolicy) {
					if (rspolicy.resource==res)
						return rspolicy.timeslice
			}
		}
		throw new Throwable("Resource "+res+" is not defined in the mapping") 
	}

	// Returns the ordering policy for a resource
 	def static SchedulingPolicy ResourceNameToSchedulingPolicy(String res, List<Mapping> mappings){
		for(mapping:mappings){
			if(mapping.rspolicy!=null) 
				for(rspolicy:mapping.rspolicy) {
					if (rspolicy.resource==res)
						return rspolicy.policy
			}
		}
		throw new Throwable("Resource "+res+" is not defined in the mapping") 
	}
	
	// Returns the list of processes that call a resource
	def static List<String> ResourceNameToCallingProcesses(String res, List<Mapping> mappings){
		var Set<String> ret_proc = new HashSet<String> // Set: to eleminate duplicates
		for(pr:ResourceNameToProcessPriorities(res, mappings))
			ret_proc.add(pr.process)
		return ret_proc.toList
	}
	
	// Return the list of mappings (incl. priorities) for a resource
	def static ResourceNameToProcessPriorities(String res, List<Mapping> mappings){
		var List<ProcessResource> pr_list = new ArrayList<ProcessResource>
		for(mapping:mappings)
			for(pr_assign:mapping.prassignment)
				if (pr_assign.resource==res)
					pr_list.add(pr_assign)
		return pr_list
	}
		
	def static ResourceCreateBuffers(String res, int size, String priority){
		var String str = "" 
		
		for(cnt:(1..size)){
			var cnt_plus1 = (cnt+1).toString
			if(cnt+1>size) cnt_plus1 = "_end" // for the final buffer element
			
			str=str+"\nbinary action "+res+"_buffer"+cnt.toString+"_"+priority+";"
			
			// initialize buffer elements
			IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: relabel { "+res+"_buffer_in, "+res+"_buffer_out } by {"+res+"_buffer"+cnt.toString+"_"+priority+", "+res+"_buffer"+cnt_plus1+"_"+priority+"} "+res+"_buffer()")
		}
		//str=str+"\nbinary action "+res+"_buffer_end_"+priority+";"
		return str
	}
	
	def static ResourceTaskRate(String resname, List<ResourceModel> resources,  DesignSpaceModel dsi, String variableType)
		'''«FOR res:resources»«ResourceTreeTaskRate(resname, res.restree.head, dsi, variableType)»«ENDFOR»'''
	
	def static ResourceTreeTaskRate(String resname, ResourceTree rtree, DesignSpaceModel dsi, String variableType){
		if(rtree.name.toString==resname){ 
			return IdslGeneratorExpression.printAExp(rtree.taskrate.head.rate,dsi, variableType)
		}
		switch (rtree) { 
			CompoundResourceTree: '''
				«FOR sub_rt:rtree.rtree»«ResourceTreeTaskRate(resname,sub_rt,dsi, variableType)»«ENDFOR»'''
		}
	}

	def static CharSequence ProcessResourcesToPrint(int num_activityis, String urgent, String variableType, boolean stopwatchEnabled){'''
		«FOR pprs:IdslGeneratorGlobalVariables.global_processresources_to_print»process «pprs.process»(«variableType» taskload, «variableType» taskload_end){
		   «IdslGeneratorMODES.StopwatchStartModest (pprs.process, urgent, stopwatchEnabled)»
		   machine_call_«pprs.process»(taskload, taskload_end)
		   «IdslGeneratorMODES.StopwatchStopModest (pprs.process, urgent, stopwatchEnabled)»
		}
		«IdslGeneratorMODES.StopwatchDeclare (pprs.process, num_activityis, stopwatchEnabled)»
		«ENDFOR»
	
		«IdslGeneratorGlobalVariables.global_main_modest_class_to_print»«IdslGeneratorGlobalVariables.global_main_modest_class_to_print_reset»
		}'''
	} 
	
}