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
import org.eclipse.emf.ecore.util.Switch
import org.idsl.language.idsl.TaskLoad

class IdslGeneratorMODESScheduling  {
	def static CharSequence ResourceNameToText (String res, List<ResourceModel> resources, List<Mapping> mappings, DesignSpaceModel dsi, boolean utilizationEnabled, String urgent, String variableType) {
		IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: machine_"+res+"()")
		var boolean isPreemptive
		var String buffer_input // the position at which packages are inserted in the queue. For FIFO: position 1. For Non-Deterministic position end
		var taskrate="/( " + ResourceTaskRate(res, resources, dsi, variableType) + ")"
		if (variableType=="int") taskrate="" // Taskrates are 1 for int to avoid divisions
		
		var spolicy = ResourceNameToSchedulingPolicy(res, mappings)
		switch (spolicy){
			SchedulingPolicyNonDet: buffer_input="_end"
			SchedulingPolicyFIFO:	buffer_input="1"
		}
		if (IdslConfiguration.Lookup_value("always_non_deterministich_when_integers_used")=="true" && variableType=="int"){ buffer_input="_end" } //override
		
		var time_slice = ResourceNameToTimeSlice(res, mappings).time
		switch (time_slice){
			AExpVal: isPreemptive = time_slice.value!=0
			default: isPreemptive = true	
		}
		// override when timeslicing is disabled for integers
		if (IdslConfiguration.Lookup_value("always_no_timeslice_when_integers_used")=="true" && variableType=="int") isPreemptive=false
		
		var multiplier = ""
		if (variableType=="real") multiplier=" * "+IdslConfiguration.Lookup_value("small_multiplier_when_reals_used")
		
		var num_processes = ResourceNameToCallingProcesses(res,mappings).length
		'''
			process machine_«res»(){
				// taskrate: «taskrate»
				«variableType» taskload;
				int process_id;
				«IF isPreemptive»«variableType» time_slice=«IdslGeneratorExpression.printAExp(ResourceNameToTimeSlice(res, mappings).time,dsi,variableType)»;«ENDIF»
							
				alt{ // fetch a package from the buffer, adhering to the priorities
				:: «res»_buffer_end_high? 		{= taskload=sync_buffer, process_id=sync_buffer2 =}
				:: «res»_buffer_end_medium?		{= taskload=sync_buffer, process_id=sync_buffer2 =}
				:: «res»_buffer_end_low? 		{= taskload=sync_buffer, process_id=sync_buffer2 =}
				};			

				// TEMPORARILY NO DELAYS
				//::	delay(1«multiplier») «res»_buffer_end_medium?		{= taskload=sync_buffer, process_id=sync_buffer2 =}
				//::	delay(2«multiplier») «res»_buffer_end_low? 		{= taskload=sync_buffer, process_id=sync_buffer2 =}

			
				// perform the delay
				«IF isPreemptive»alt{ 
						:: when ((taskload«taskrate»)<=time_slice) delay((taskload«taskrate»))  //preemption occured
							tau «IF utilizationEnabled» {= util_counter_«res» = util_counter_«res» + (taskload«taskrate») =} «ENDIF»
						:: when ((taskload«taskrate»)>time_slice) delay(time_slice) // task has finished
							tau «IF utilizationEnabled» {= util_counter_«res» = util_counter_«res» + time_slice =} «ENDIF»
				};
				«ELSE»delay(taskload«taskrate») tau «IF utilizationEnabled» {= util_counter_«res» = util_counter_«res» + (taskload«taskrate») =} «ENDIF»;
				«ENDIF»

				«ResourceNameReturnResult(res, mappings, num_processes, isPreemptive, variableType)»
				
				machine_«res»() // recursion to keep the machine alive forever
			}	
			
			«val util_sampling_time=new Integer(IdslConfiguration.Lookup_value("utilization_sampling_time"))»
			«IdslGeneratorMODES.UtilizationDeclare (res, util_sampling_time, utilizationEnabled, variableType)»«/*TODO: update 10000 and true for variables*/»
				
			«ResourceCreateBuffers(res, mappings, num_processes+1,variableType)»
				
			//Abstract functions for calling «res»
			«var cnt=1»«FOR proc:ResourceNameToCallingProcesses(res,mappings)»
				
			process machine_call_«proc» («variableType» taskload){
					«res»_buffer«buffer_input»_«procResourcePriorityText(proc, res, mappings, variableType)»! {= sync_buffer=taskload, sync_buffer2=«cnt» =};
					«res»_stop_«cnt»?
			}
			binary action «res»_stop_«cnt»;
			«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
	'''}
	
	def static procResourcePriorityText(String process, String resource, List<Mapping>mappings, String variableType){
		if (IdslConfiguration.Lookup_value("always_no_priorities_when_integers_used")=="true" && variableType=="int"){
			return 'high /* because of disabling of priorities */' // everything becomes high priority, to avoid delays in machine_«res»
		}
		
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

	def static ResourceCreateBuffers(String res, List<Mapping> mappings, int size, String variableType){
		var spolicy = ResourceNameToSchedulingPolicy(res, mappings)
		
		// These binary communications are always needed, regardless of the existence of buffers.
		var buffer_end = "binary action "+res+"_buffer_end_high; \nbinary action "+res+"_buffer_end_medium; \nbinary action "+res+"_buffer_end_low;"
		
		// Buffers are not needed when non-determinism, in two cases:
		switch (spolicy){ SchedulingPolicyNonDet: return buffer_end }
		if (IdslConfiguration.Lookup_value("always_non_deterministich_when_integers_used")=="true" && variableType=="int") return buffer_end  
	
		var boolean need_low_buffer=false // is a low buffer needed?
		var boolean need_medium_buffer=false
		var boolean need_high_buffer=false
		
		for (pr:ResourceNameToProcessPriorities(res, mappings))
			 switch (pr.plevel.head){
			 	PriorityLevelLow: need_low_buffer=true
			 	PriorityLevelMedium: need_medium_buffer=true
			 	PriorityLevelHigh: need_high_buffer=true
			}
			
		if (IdslConfiguration.Lookup_value("always_no_priorities_when_integers_used")=="true" && variableType=="int"){
			need_low_buffer=false; need_medium_buffer=false; need_high_buffer=true // everything becomes high priority, to avoid delays in machine_«res» 
		}
		
		'''
		«IF need_low_buffer»«ResourceCreateBuffers(res,size,"low")»«ENDIF»
		«IF need_medium_buffer»«ResourceCreateBuffers(res,size,"medium")»«ENDIF»
		«IF need_high_buffer»«ResourceCreateBuffers(res,size,"high")»«ENDIF»
		
		// «res» buffer element class
		process «res»_buffer(){
			«variableType» taskload;
			int process_id;
			«res»_buffer_in? {= taskload=sync_buffer, process_id=sync_buffer2 =};
			«res»_buffer_out! {= sync_buffer=taskload, sync_buffer2=process_id =};
			«res»_buffer()
		} 
		binary action «res»_buffer_in, «res»_buffer_out;
		«buffer_end»
	'''}
		
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

	def static ProcessResourcesToPrint(int num_activityis, String urgent, String variableType, boolean stopwatchEnabled){'''
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