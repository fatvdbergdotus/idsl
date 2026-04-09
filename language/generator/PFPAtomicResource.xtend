package org.idsl.language.generator

import java.util.List
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.PFPAtomicResourceTree
import org.idsl.language.idsl.Distribution

class PFPAtomicResource {

	
	def static CharSequence ResourceNameToText (int num_activityis, PFPAtomicResourceTree resource, String res, 
								   List<ResourceModel> resources, List<Mapping> mappings, DesignSpaceModel dsi, 
								   boolean utilizationEnabled, String urgent, String variableType, String final_properties) {		
		
		
		// add global processes
		IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: machine_"+res+"()")
		var taskrate="/( " + IdslGeneratorMODESSchedulingv2.ResourceTaskRate(res, resources, dsi, variableType) + ")"
		
		if (variableType=="int") 
			taskrate="" // Taskrates are 1 for int to avoid divisions
		
		var time_slice 				= IdslGeneratorMODESSchedulingv2.ResourceNameToTimeSlice(res, mappings).time
		var boolean isPreemptive 	= IdslGeneratorMODESSchedulingv2.isPremptivAExp(time_slice)

		// override when timeslicing is disabled for integers
		if (IdslConfiguration.Lookup_value("always_no_timeslice_when_integers_used")=="true" && variableType=="int") isPreemptive=false
		
		var multiplier = ""
		if (variableType=="real") 
			multiplier=" * "+IdslConfiguration.Lookup_value("small_multiplier_when_reals_used")	
		
			'''
	//	'powerOn' «resource.powerOn»
	//	'powerOff' «resource.powerOff»
	//	'shutdownTime' «resource.shutdownTime»
	//	'startupTime' «resource.startupTime»
	//	'shutdownPolicy' «resource.shutdownPolicy»
	//	'toFailure' «distributionToString(resource.toFailure)»
	//	'toRepair' «distributionToString(resource.toRepair)»

	
	// Resource «res»: actions and rewards
	binary action «res»_stop, «res»_start;
	
	reward «res»_energy;
	
	//reward time_«res»_on; 
	//reward time_«res»_sleep;
	//reward time_«res»_shutdown;
	//reward time_«res»_startup;
	//reward time_«res»_idle;
	//reward time_«res»_broken;
	//reward time_«res»_recovering;

	//int state_«res»_on=1;
	//int state_«res»_sleep=0;
	//int state_«res»_shutdown=0;
	//int state_«res»_startup=0;
	//int state_«res»_idle=0;
	//int state_«res»_broken=0;
	//int state_«res»_recovering=0;
	
	property property_r3_energy		= Xmax( «res»_energy  	  	 | stopwatch_counter_p==«num_activityis»);
	property property_r3_avg_power	= Xmax( «res»_energy / time  | stopwatch_counter_p==«num_activityis»);
	
	// Resource «res»
	process machine_call_«res»(){
		«res»_start! {sync_buffer=taskload};
		«res»_stop?
	}
	
	process machine_«res»(){
		int taskload;
		int failure;
		
		// compute tofailure time
		palt{
			«FOR probval:resource.toFailure.pv»: «probval.prob» : failure=Uniform(1,«probval.^val»)
			«ENDFOR»
		}
		
		invariant(der(«res»_energy) == «resource.powerOn» /* powerOn */);
		alt{
			:: when urgent (failure<taskload && failure<«resource.shutdownTime») machine_broken_«res»()
			:: when urgent (taskload<failure && taskload<«resource.shutdownTime») «res»_start? {taskload=sync_buffer}; delay(taskload) tau; «res»_stop!; machine_«res»()
			:: when urgent («resource.shutdownTime»<taskload && «resource.shutdownTime»<failure) machine_shutdown_«res»()
		}

		machine_«res»() // recursion to keep the machine alive forever
	}
	
	process machine_broken_«res»(){
		invariant(der(«res»_energy) == 0);
		palt{
			«FOR probval:resource.toRepair.pv»: «probval.prob» : delay(«probval.^val») tau
			«ENDFOR»
		};	
		machine_«res»()
	}
	
	process machine_shutdown(){
		int taskload;
		
		invariant(der(«res»_energy) == «resource.powerOff» /* powerOff */);
		«res»_start? {taskload=sync_buffer}; // wake up!
		machine_«res»();
		«res»_start! {sync_buffer=taskload}
	}
}
	
'''}

	def static CharSequence distributionToString (Distribution d)
		'''«FOR pv:d.pv»(«pv.prob»:«pv.^val»)«ENDFOR»'''
	
}