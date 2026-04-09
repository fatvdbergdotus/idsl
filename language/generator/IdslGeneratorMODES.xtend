package org.idsl.language.generator

import java.util.ArrayList
import java.util.LinkedHashSet
import java.util.List
import java.util.Set
import org.idsl.language.idsl.AbstractionProcessModel
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.AtomicProcessModel
import org.idsl.language.idsl.CompoundResourceTree
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.MutexProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.ProcessResource
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.ResourceTree
import org.idsl.language.idsl.Scenario
import org.idsl.language.idsl.SchedulingPolicy
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.Service
import org.idsl.language.idsl.ServiceRequest
import org.idsl.language.idsl.TimeSchedule
import org.idsl.language.idsl.TimeSlice

import static extension org.idsl.language.generator.IdslGenerator.*
import java.util.HashSet
import org.idsl.language.idsl.DesAltProcessModel
import org.idsl.language.idsl.TimeScheduleFixedIntervals
import org.idsl.language.idsl.TimeScheduleLatencyJitter
import org.idsl.language.idsl.AExp
import org.idsl.language.idsl.AExpVal
import org.idsl.language.idsl.LoadBalancerConfiguration

class IdslGeneratorMODES {
		// three functions to add a stopwatch and instance counter to a processmodel
		
		def static StopwatchStartModest (String name, String urgent, boolean visible, boolean is_main_process)'''
			«IF visible && ((IdslConfiguration.Lookup_value("evaluate_lower_level_latencies")=="true" || is_main_process))»«/* visible and main-process or config(lower-level latencies) */»
			«urgent» tau {= stopwatch_«name» = 0, stopwatch_«name»_done = false =};«ENDIF»'''
			
		def static StopwatchStartModest (String name, String urgent, boolean visible){
			StopwatchStartModest(name, urgent, visible, false) // not a main process
		}
		
/* 		def static StopwatchStopModest (String name, String urgent, boolean visible)'''
			«IF visible»; // previous line does not have a semicolon
			«urgent» tau {= stopwatch_«name»_done = true, stopwatch_counter_«name»++ =};
			«urgent» tau {= stopwatch_«name» = 0, stopwatch_«name»_done = false =}«ENDIF»''' */
	
		def static StopwatchStopModest (String name, String urgent, boolean visible, boolean is_main_process)'''
			«IF visible && ((IdslConfiguration.Lookup_value("evaluate_lower_level_latencies")=="true" || is_main_process))»«/* visible and main-process or config(lower-level latencies) */»
			; // previous line does not have a semicolon
			«urgent» tau {= stopwatch_«name»_done = true, stopwatch_counter_«name»++ =};
			«urgent» tau {= stopwatch_«name» = 0, stopwatch_«name»_done = false =}«ENDIF»'''

		def static StopwatchStopModest (String name, String urgent, boolean visible) {
			StopwatchStopModest(name, urgent, visible, false) // not a main process
		}

		def static StopwatchDeclare (String name, int num_activityis, boolean visible, boolean is_main_process)'''
			«IF visible && ((IdslConfiguration.Lookup_value("evaluate_lower_level_latencies")=="true" || is_main_process))»«/* visible and main-process or config(lower-level latencies) */»
				int stopwatch_counter_«name»=0;	clock stopwatch_«name»=0; bool stopwatch_«name»_done;
				«FOR cnt:(1..num_activityis)»property property_latency_«name»_«cnt» = Xmax( stopwatch_«name» | stopwatch_«name»_done && stopwatch_counter_«name»==«cnt»);
				«ENDFOR»
			«ENDIF»'''

		def static StopwatchDeclare (String name, int num_activityis, boolean visible){ // not a main process
			return StopwatchDeclare(name, num_activityis, visible, false)
		}

		def static UtilizationIncrementModest (String name, String taskrate, String urgent, boolean visible)'''
			«IF visible»«urgent» tau {= util_counter_«name»=util_counter_«name»+( taskload / «taskrate» ) =};
			«ENDIF»'''			
			
		def static UtilizationDeclare (String name, int util_time, boolean visible, String variableType) '''
			«IF visible»«variableType» util_counter_«name»=0;
			property property_utilization_«name» = Xmax ( util_counter_«name»/«util_time» | time == «util_time»);
			«ENDIF»'''

		def static UPPAALproperties (String extproc_name, boolean isUPPAAL, boolean isUPAALupper, String processToMeasure)'''
			«IF isUPPAAL && extproc_name==processToMeasure»	
				«IF IdslConfiguration.Lookup_value("MCTAU_analysis_mode")=="binary_search"»
					«IF isUPAALupper»
						const int VAL; // Experiment parameter: upper bound
						property upperbound_«extproc_name»_greater = Pmax(<> stopwatch_«extproc_name»_done && stopwatch_«extproc_name» > VAL );
					«ELSE»
						const int VAL; // Experiment parameter: lower bound 
						property lowerbound_«extproc_name»_smaller = Pmax(<> stopwatch_«extproc_name»_done && stopwatch_«extproc_name» < VAL );
					«ENDIF»
				«ELSEIF IdslConfiguration.Lookup_value("MCTAU_analysis_mode")=="brute_force_search"»	
					// UPPAAL PROPERTIES FOR INSTANCE «extproc_name»
					«FOR cnt:UPPAALpropertyValuesToCheck»/* relate these values to the expected outcomes */
						 property lowerbound_«extproc_name»_smaller_«cnt» = Pmax(<> stopwatch_«extproc_name»_done && stopwatch_«extproc_name» < «cnt»);
						 property lowerbound_«extproc_name»_greater_«cnt» = Pmax(<> stopwatch_«extproc_name»_done && stopwatch_«extproc_name» > «cnt»);								
					«ENDFOR»
				«ENDIF»
			«ENDIF»'''

		def static List<Integer> UPPAALpropertyValuesToCheck(){
			var List<Integer> nums = new ArrayList<Integer>
			val interval = new Integer(IdslConfiguration.Lookup_value("interval_of_UPPAAL_properties"))
			val number = new Integer(IdslConfiguration.Lookup_value("number_of_UPPAAL_properties"))
			for(cnt:(0..number-1))
				nums.add(cnt*interval)
			return nums
		}

		def static printGenerator(int num_activityis, List<Service> ai_activity_id, String extproc_name, TimeSchedule ai_time_head, DesignSpaceModel dsi, String variableType){
			return IdslGeneratorMODESv2.printGenerator(num_activityis, ai_activity_id, extproc_name, ai_time_head, dsi, variableType)
			/* OLD CODE REPLACES BY IdslGeneratorMODESv2 
			switch(ai_time_head){
				TimeScheduleFixedIntervals: return printGenerator_fi(num_activityis, ai_activity_id, extproc_name, ai_time_head, dsi, variableType)
				//TimeScheduleLatencyJitter:  return DesignSpaceVariablesUsed_lj(ts)
			}	
			throw new Throwable("printGenerator: TimeSchedule not supported!") */
		}

		def static printGenerator_fi(int num_activityis, List<Service> ai_activity_id, String extproc_name, TimeScheduleFixedIntervals ai_time_head, 
			DesignSpaceModel dsi, String variableType){
			var multiplier = ""
			if (variableType=="real") multiplier=" * "+IdslConfiguration.Lookup_value("small_multiplier_when_reals_used")
					
			'''
			// GENERATOR CODE GOES HERE FOR «ai_activity_id.head»
			process generator_«ai_activity_id.head.name»(){
				clock c;
				tau {= c=0 =};
			
			// REPLACED BY IF/ELSE/ENDIF BELOW
			//	alt{
			//		:: generator_«extproc_name»!
			//		:: delay(1«multiplier») 
			//				tau {= timeout_counter_«extproc_name»++ =} // time-out
			//	};
			
			alt{
				:: urgent generator_«extproc_name»!
				:: delay(1 «multiplier») 
			«IF (IdslConfiguration.Lookup_value("count_timeouts")=="yes")»
					tau {= timeouts_«extproc_name» = timeouts_«extproc_name» +1 =}
			«ELSE»
				tau
			«ENDIF»
			
			};	
				when urgent (c >= ((int)«IdslGeneratorExpression.printAExp(ai_time_head.interval,dsi,variableType)») - («IdslGeneratorExpression.printAExp(ai_time_head.start,dsi,variableType)») )
					generator_«ai_activity_id.head.name»()
			}
			int timeout_counter_«extproc_name»=0;
			property property_timeout_counter_«extproc_name» = Xmax( timeout_counter_«extproc_name» | stopwatch_counter_«extproc_name»==«num_activityis»);
			
			process init_generator_«ai_activity_id.head.name»()
				{  delay («IdslGeneratorExpression.printAExp(ai_time_head.start,dsi,variableType)»)  generator_«ai_activity_id.head.name»() }
			«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: init_generator_" + ai_activity_id.head.name + "()"))»
			binary action generator_«extproc_name»;«/* TODO: impement  ActivityInstance:  Time A repeat every B for C times, using D instances */»'''
		}

		def static PrintProcessInstance(ExtendedProcessModel extproc, boolean isUPPAAL, String urgent, 
										boolean oneStopwatchPerInstance, boolean OneGlobalStopwatchForInstances, AExp num_instances_exp){
		var int num_instances=0
		switch(num_instances_exp){
			AExpVal: num_instances = num_instances_exp.value
			default: {System.out.println("Warning: set num_instances=1"); num_instances=1}
			//default: throw new Throwable("PrintStopwatches_properties_for_each_instance: only values (AExpVal) are accepted for num_instances.")					
		}
			'''			
			// PRINTING PROCESS INSTANCE «extproc.name»	WITH STOPWATCH
			process «extproc.name»_instance(){
				generator_«extproc.name»?;
				«urgent» tau {= stopwatch_«extproc.name» = 0, stopwatch_«extproc.name»_done = false =}; 	
				«var pm=extproc.pmodel»«pm.head.name»(-1);
				«urgent» tau {= stopwatch_«extproc.name»_done = true«IF !isUPPAAL», stopwatch_counter_«extproc.name»++«ENDIF» =};  									
				«urgent» tau {= stopwatch_«extproc.name» = 0, stopwatch_«extproc.name»_done = false =};
				«urgent» tau {= stopwatch_counter_all_instances_«extproc.name»++ =}
			}
			
			«IF !oneStopwatchPerInstance && !OneGlobalStopwatchForInstances»
				// PRINTING PROCESS INSTANCE «extproc.name»	WITHOUT STOPWATCH			
				process «extproc.name»_instance_no_stopwatch(){
					generator_«extproc.name»?;
					«pm.head.name»(-1);
					«urgent» tau {= stopwatch_counter_all_instances_«extproc.name»++ =}
					}			
			«ELSEIF oneStopwatchPerInstance»
				«IF num_instances>1»«FOR cnt:(1..num_instances-1)»
				process «extproc.name»_instance_«cnt»(){
					generator_«extproc.name»?;
					«urgent» tau {= stopwatch_instance_«cnt»_«extproc.name» = 0, stopwatch_instance_«cnt»_«extproc.name»_done = false =}; 	
					«pm.head.name»(-1);
					«urgent» tau {= stopwatch_instance_«cnt»_«extproc.name»_done = true«IF !isUPPAAL», stopwatch_counter_instance_«cnt»_«extproc.name»++«ENDIF» =};  									
					«urgent» tau {= stopwatch_instance_«cnt»_«extproc.name» = 0, stopwatch_instance_«cnt»_«extproc.name»_done = false =};
					«urgent» tau {= stopwatch_counter_all_instances_«extproc.name»++ =}
				}
				«ENDFOR»«ENDIF»
			«ELSEIF OneGlobalStopwatchForInstances»
				clock stopwatch_«extproc.name» = 0;
				bool stopwatch_«extproc.name»_done;
				
				«IF num_instances>1»«FOR cnt:(1..num_instances-1)»
				process «extproc.name»_instance_«cnt»(){
					generator_«extproc.name»?;
					«urgent» tau {= stopwatch_instance_«cnt»_«extproc.name» = 0, stopwatch_instance_«cnt»_«extproc.name»_done = false =}; 	
					«pm.head.name»(-1);
					urgent tau {= stopwatch_global_«extproc.name» = stopwatch_instance_«cnt»_«extproc.name», stopwatch_instance_«cnt»_«extproc.name»_done = true«IF !isUPPAAL», stopwatch_counter_all_instances_«extproc.name»++«ENDIF» =};  									
					urgent tau {= stopwatch_instance_«cnt»_«extproc.name» = 0, stopwatch_instance_«cnt»_«extproc.name»_done = false =}
				}
				clock stopwatch_instance_«cnt»_«extproc.name»=0;
				bool stopwatch_instance_«cnt»_«extproc.name»_done;
				«ENDFOR»«ENDIF»
				int stopwatch_global_«extproc.name»; // to temporary copy a instance stopwatch to
			«ENDIF»
		'''}

		def static CharSequence DSEScenarioToModest(int num_activityis, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi, 
								List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources,
								boolean stopwatchEnabled, boolean utilizationEnabled, boolean throughputCalcEnabled, 
								boolean isUPPAAL, String urgent, String variableType, boolean oneStopwatchPerInstance){
			// Huge overload to allow ommision of OneGlobalStopwatchForInstances (default: false)
			DSEScenarioToModest(num_activityis, s, dsm, dsi, activities, epms, mappings, resources,
								stopwatchEnabled,  utilizationEnabled,  throughputCalcEnabled,  isUPPAAL,  
								urgent,  variableType, true, "", oneStopwatchPerInstance, false)								
		}
		
		def static CharSequence DSEScenarioToModest(int num_activityis, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi, 
								List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources,
								boolean stopwatchEnabled, boolean utilizationEnabled, boolean throughputCalcEnabled, 
								boolean isUPPAAL, String urgent, String variableType, boolean oneStopwatchPerInstance,
								boolean OneGlobalStopwatchForInstances){
			 // Huge overload to allow an extra, optional UPPAAL parameter at the end
			 DSEScenarioToModest(num_activityis, s, dsm, dsi, activities, epms, mappings, resources,
								stopwatchEnabled,  utilizationEnabled,  throughputCalcEnabled,  isUPPAAL,  
								urgent,  variableType, true, "", oneStopwatchPerInstance, OneGlobalStopwatchForInstances)
		}

		def static CharSequence DSEScenarioToModest(int num_activityis, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi,
								List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources,
								boolean stopwatchEnabled, boolean utilizationEnabled, boolean throughputCalcEnabled, boolean isUPPAAL, String urgent, 
								String variableType, boolean isUPAALupper, String processToMeasure, 
								boolean oneStopwatchPerInstance, boolean oneGlobalStopwatchForInstances){
			if(oneStopwatchPerInstance && oneGlobalStopwatchForInstances) // they cannot both be true
				throw new Throwable("DSEScenarioToModest: both oneStopwatchPerInstance and OneGlobalStopwatchForInstances are true")									
									
			IdslGeneratorGlobalVariables.global_processes_to_print=new LinkedHashSet<String>() // for abstract processes
			IdslGeneratorGlobalVariables.global_resources_to_print=new LinkedHashSet<Pair<String,LoadBalancerConfiguration>> // to create resources eventually
			IdslGeneratorGlobalVariables.global_processresources_to_print=new LinkedHashSet<ProcessResource>() // the mappings from process to resource to print
	 		// OLD: IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add (variableType + " sync_buffer;  \nint sync_buffer2; \nclosed par{")
	 		IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add (variableType + " sync_buffer;  \n"+variableType+" sync_buffer2; \nclock cinit;\nclosed par{")
	 		
	 		if(IdslGeneratorGlobalVariables.add_global_counter_to_modest_code)
				IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add( " :: global_time()")
	 		
	 		var Set<String> ai_unique = new LinkedHashSet<String>()
	 		var Set<String> p_unique  = new LinkedHashSet<String>()
			'''
			«IdslGeneratorMODESv2.declareBufferAndListDataType»
			
			«FOR ai:s.ainstance»
				«var Service am=ai.activity_id.head»
				«var ExtendedProcessModel extproc = IdslGenerator.filterExtProcess(epms,am.extprocess_id.name)»
				«var Mapping mapping = am.mapping.head»
				
				«IF !ai_unique.contains(ai.activity_id.head)»
					«UPPAALproperties(extproc.name, isUPPAAL, isUPAALupper, processToMeasure)»
					«PrintProcessInstance(extproc, isUPPAAL, urgent, oneStopwatchPerInstance, oneGlobalStopwatchForInstances, ai.time.head.num_instances)»
					«PrintStopwatches(num_activityis, ai, extproc, dsi, isUPPAAL, throughputCalcEnabled, 
									  variableType, oneStopwatchPerInstance, oneGlobalStopwatchForInstances)»
					«ExtProcessMappingToText(ai.activity_id.head.extprocess_id.name, num_activityis, stopwatchEnabled, extproc,mapping, dsm, dsi, urgent, variableType)»
				«ENDIF»
				«ai_unique.add(ai.activity_id.head.name).toString.substring(0,0)»«/* TODO: work in progress. what name should the generators have (process name, many to one link)? How to link them to processes?*/»
				«p_unique.add(ai.activity_id.head.extprocess_id.name.toString).toString.substring(0,0)»
	
				«printGenerator(num_activityis, ai.activity_id, extproc.name, ai.time.head, dsi,variableType)»
			«ENDFOR»
			
			«IF IdslGeneratorGlobalVariables.global_resources_to_print.length>0»
				«FOR cnt:1..IdslGeneratorGlobalVariables.global_resources_to_print.length»
					«var res=IdslGeneratorGlobalVariables.global_resources_to_print.get(cnt-1)»
					«IdslGeneratorMODESSchedulingv2.ResourceNameToText(cnt, num_activityis, p_unique, res, resources, mappings, dsi, utilizationEnabled, urgent, variableType, "")»«/*CHANGED from v1 to v2 and added "" parameter in the end*/»
				«ENDFOR»
			«ENDIF»
			«IdslGeneratorMODESScheduling.ProcessResourcesToPrint(num_activityis, urgent, variableType, stopwatchEnabled)»
			
			«PrintDSLInstanceInComment»
			'''
		}
	
	def static PrintDSLInstanceInComment()'''
			«IF IdslConfiguration.Lookup_value("Append_DSL_instance_to_Modest_code")=="true"»
			
			// This code is auto-generated by iDSL (i-dsl.org) and based on the following DSL instance:
			
			«CommentText(IdslGeneratorGlobalVariables.global_DSL_text)»					
			«ENDIF»
	'''
	
	def static CommentText(String text)'''
		«IF text!=null»«FOR line:text.split("\n")»// «line»
		«ENDFOR»«ENDIF»'''
	
	def static PrintStopwatches(int num_activityis, ServiceRequest ai, ExtendedProcessModel extproc, DesignSpaceModel dsi, 
		boolean isUPPAAL, boolean throughputCalcEnabled, String variableType, boolean oneStopwatchPerInstance, boolean oneGlobalStopwatchForInstances){
		'''
		«IF throughputCalcEnabled»
			«FOR cnt:(1..30)/* might be nice to make 30 a variable for computing the throughput */»
				«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: do {" + extproc.name + "_instance() }"))»
			«ENDFOR»
			«FOR cnt:(1..num_activityis)»
				property property_throughput_«extproc.name»_«cnt» = Xmax( time | stopwatch_«extproc.name»_done && stopwatch_counter_«extproc.name»==«cnt»);
			«ENDFOR»				
		«ELSE /* in non-throughput mode only one instance is stopwatched to save performance */»
			«addProcessInstancesToMain(ai, extproc, oneStopwatchPerInstance, oneGlobalStopwatchForInstances,  dsi, variableType)»
		«ENDIF»
		
		«IF oneStopwatchPerInstance»
			«PrintStopwatches_properties_for_each_instance(ai.time.head.num_instances, dsi, num_activityis, extproc, isUPPAAL)»
		«ELSEIF oneGlobalStopwatchForInstances»
			«PrintStopwatches_properties_global(num_activityis, ai.time.head.num_instances, dsi, extproc)»
		«ELSE»
			«PrintStopwatches_properties_for_one_instance_in_total(num_activityis, extproc, isUPPAAL)»
		«ENDIF»
		'''
	}
	
	def static addProcessInstancesToMain(ServiceRequest ai, ExtendedProcessModel extproc, boolean oneStopwatchPerInstance, 
										 boolean oneGlobalStopwatchForInstances, DesignSpaceModel dsi, String variableType)'''
		«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: do {" + extproc.name + "_instance() }"))»
		
		«IF ai.time.head.num_instances!=null»«var n=new Integer(IdslGeneratorExpression.printAExp(ai.time.head.num_instances,dsi,variableType).toString)»«IF n>1»
			«FOR cnt:(1..(n-1))»
				«IF oneStopwatchPerInstance || oneGlobalStopwatchForInstances»
					«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add( " :: do {" + extproc.name + "_instance_"+cnt+"() }"))»
				«ELSE»
					«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add( " :: do {" + extproc.name + "_instance_no_stopwatch() }"))»«ENDIF»
			«ENDFOR»
		«ENDIF»«ENDIF» 	
	'''

	
	def static PrintStopwatches_properties_for_one_instance_in_total (int num_activityis, ExtendedProcessModel extproc, boolean isUPPAAL)
		'''
		«IF !isUPPAAL»
			// Counts all the instances of «extproc.name» instead of only the stopwatch one
			int stopwatch_counter_all_instances_«extproc.name»=0;
			//property property_«extproc.name»_total = Xmax( stopwatch_counter_all_instances_«extproc.name» | stopwatch_counter_«extproc.name»==«num_activityis»); CHANGED!!!			
			
			// INSTANCE DEFAULT
			int stopwatch_counter_«extproc.name»=0;
			«FOR cnt:(1..num_activityis)»property property_«extproc.name»_«cnt» = Xmax( stopwatch_«extproc.name» | stopwatch_counter_«extproc.name»==«cnt»);
			«ENDFOR»		
		«ENDIF»
		clock stopwatch_«extproc.name»=0;
		bool stopwatch_«extproc.name»_done;
		'''
	
	def static PrintStopwatches_properties_global(int num_activityis, AExp num_instances_exp,DesignSpaceModel dsi, ExtendedProcessModel extproc){
		var int num_instances=0
		switch(num_instances_exp){
			AExpVal: num_instances = num_instances_exp.value
			default: throw new Throwable("PrintStopwatches_properties_for_each_instance: only values (AExpVal) are accepted for num_instances.")
		} 
		var num_properties = num_instances * num_activityis
		'''
			int stopwatch_counter_«extproc.name»=0;
			int stopwatch_counter_all_instances_«extproc.name»=0;
		
			// GLOBAL INSTANCES
			«FOR cnt_instances:(1..num_properties)»
			property property_«extproc.name»_global_«cnt_instances» = Xmax( stopwatch_global_«extproc.name» | stopwatch_counter_all_instances_«extproc.name»==«cnt_instances»);
			«ENDFOR»
		'''		
	}

	def static PrintStopwatches_properties_for_each_instance (AExp num_instances_exp, DesignSpaceModel dsi, int num_activityis, 
			   ExtendedProcessModel extproc, boolean isUPPAAL){
		var int num_instances=0
		switch(num_instances_exp){
			AExpVal: num_instances = num_instances_exp.value
			default: throw new Throwable("PrintStopwatches_properties_for_each_instance: only values (AExpVal) are accepted for num_instances.")
		}   	
		'''
		«PrintStopwatches_properties_for_one_instance_in_total(num_activityis, extproc, isUPPAAL)»
		«IF !isUPPAAL && num_instances>1»
			«FOR cnt_instances:(1..num_instances-1)»
			// INSTANCE «cnt_instances»
			int stopwatch_counter_instance_«cnt_instances»_«extproc.name»=0;
			«FOR cnt_activities:(1..num_activityis)»property property_instance_«cnt_instances»_«extproc.name»_«cnt_activities» = Xmax(stopwatch_instance_«cnt_instances»_«extproc.name» | stopwatch_counter_instance_«cnt_instances»_«extproc.name»==«cnt_activities»);
			«ENDFOR»
			clock stopwatch_instance_«cnt_instances»_«extproc.name»=0;
			bool stopwatch_instance_«cnt_instances»_«extproc.name»_done;
			«ENDFOR»
		«ENDIF»
		'''
		}
	
	def static ExtProcessMappingToText(String activity_id, int num_activityis, boolean stopwatchEnabled, ExtendedProcessModel extprocess, 
									   Mapping mapping, DesignSpaceModel dsm, DesignSpaceModel dsi, String urgent, String variableType){
		// PRINTING PROCESS «extproc.name»
		IdslGeneratorGlobalVariables.global_processes_to_print=new LinkedHashSet<String>() // for abstract processes
		'''«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, extprocess.pmodel.head, mapping, dsm, dsi, urgent, variableType)»
		«FOR gl:IdslGeneratorGlobalVariables.global_processes_to_print»
			«FOR spm:extprocess.spm»
				«IF IdslGeneratorGlobalVariables.global_processes_to_print.contains(spm.name.head)»
					process «spm.name.head» («variableType» parent){ 
						«StopwatchStartModest (spm.name.head, urgent, stopwatchEnabled, true)»
						«urgent» «spm.pmodel.head.name» (parent)
						«StopwatchStopModest (spm.name.head, urgent, stopwatchEnabled, true)»
					} // to connect the called process with subprocess
					«StopwatchDeclare (spm.name.head, num_activityis, stopwatchEnabled, true)»
					«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, spm.pmodel.head, mapping, dsm, dsi, urgent, variableType)»«
				ENDIF»
			«ENDFOR»
		«ENDFOR»'''
	}		
	
	def static String ProcessMappingToText(String activity_id, int num_activityis, boolean stopwatchEnabled, ProcessModel pmodel, 
									Mapping mapping, 
									DesignSpaceModel dsm, DesignSpaceModel dsi, String urgent, String variableType){
		 // REDIRECTION:
		 // def static String ProcessMappingToText(int num_activityis, boolean stopwatchEnabled, ProcessModel pmodel, Mapping mapping, 
		 // DesignSpaceModel dsm, DesignSpaceModel dsi, String urgent, String variableType, boolean probabilism_enabled){
		 return IdslGeneratorMODESv2.ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, pmodel, mapping, dsm, dsi, urgent, variableType, true)
	}
	
	// OLD VERSION BELOW
	def static String ProcessMappingToText_old(String activity_id, int num_activityis, boolean stopwatchEnabled, ProcessModel pmodel, Mapping mapping, 
									DesignSpaceModel dsm, DesignSpaceModel dsi, String urgent, String variableType){		 
		 for (a:mapping.prassignment){ 
		 	if(pmodel.name==a.process){
		 		IdslGeneratorGlobalVariables.global_resources_to_print.add(a.resource -> null) 
		 		IdslGeneratorGlobalVariables.global_processresources_to_print.add(a)
				return ""
		 	} 
		 }
		 
		 /*System.out.println("Print DSI params")
		 for(param:dsi.dsparam){
		 	System.out.println(param.variable.head)
		 	System.out.println(param.value.toString)
		 	System.out.println(IdslGeneratorDesignSpace.lookupValuePositionDSM(param.variable.head, dsm, dsi))
		 }
		 System.out.println("/Print DSI params")*/
		 		
		 switch (pmodel){ AbstractionProcessModel: IdslGeneratorGlobalVariables.global_processes_to_print.add(pmodel.name) }
		 
		 switch (pmodel){ AtomicProcessModel:			return ""//"/*"+printAExp(pmodel.taskload.load,dsm,dsi)+"*/" // does not need code, since its parent will list its name
						  AbstractionProcessModel:		return ""//"/*"+printAExp(pmodel.taskload.load,dsm,dsi)+"*/" // does not need code, since its parent will list its name
		 
		 					DesAltProcessModel: 
		 { // select the right branch and make a recursive call
			var param		   = pmodel.param.head
			// ORIGINALLY:  var value_index    = IdslGeneratorDesignSpace.lookupValuePositionDSM(param, dsm, dsi)
			var value_index=IdslGeneratorDesignSpace.lookupValuePositionDSM(pmodel.param.head, dsi, pmodel.pmodel)
			var chosen_process = pmodel.pmodel.get(value_index).pmodel.head
			'''«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, chosen_process, mapping, dsm, dsi, urgent, variableType)»
			
			process «pmodel.name»(«variableType» parent){
				«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
				«urgent» «chosen_process.name»(«IF chosen_process.taskload.head!=null»«IdslGeneratorExpression.printExp(chosen_process.taskload.head.load,dsi,variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»)
				«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
				
			}
			«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
			'''
		}
							AltProcessModel:'''
		«FOR p:pmodel.pmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType)»«ENDFOR»
		
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«IF pmodel.pmodel.length>1»alt{
				«FOR p:pmodel.pmodel»	:: «urgent» «p.name»(«IF p.taskload.head!=null»«IdslGeneratorExpression.printExp(p.taskload.head.load,dsi,variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»)
				«ENDFOR»
			}«ELSE»
				«FOR p:pmodel.pmodel»«urgent» «p.name»(«IF p.taskload.head!=null»«IdslGeneratorExpression.printExp(p.taskload.head.load,dsi,variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»)
				«ENDFOR»			
			«ENDIF»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// ************************************
					PaltProcessModel:'''
		«FOR p:pmodel.ppmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p.pmodel.head, mapping, dsm, dsi, urgent, variableType)»«ENDFOR»
		
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«IF pmodel.ppmodel.length>1»palt{
				«FOR q:pmodel.ppmodel»	: «q.prob.head.toString» :  «urgent» «FOR p:q.pmodel»«p.name»(«IF p.taskload.head!=null»«IdslGeneratorExpression.printExp(p.taskload.head.load,dsi,variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»«ENDFOR»)
				«ENDFOR»
			}«ELSE»
				«FOR q:pmodel.ppmodel»«urgent» «FOR p:q.pmodel»«p.name»(«IF p.taskload.head!=null»«IdslGeneratorExpression.printExp(p.taskload.head.load,dsi,variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»«ENDFOR»)
				«ENDFOR»	
			«ENDIF»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// ************************************
					ParProcessModel:'''
		«FOR p:pmodel.pmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType)»«ENDFOR»
		
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«IF pmodel.pmodel.length>1»par{
				«FOR p:pmodel.pmodel»	:: «urgent» «p.name»(«IF p.taskload.head!=null»«IdslGeneratorExpression.printExp(p.taskload.head.load,dsi,variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»)
				«ENDFOR»
			}«ELSE»
				«FOR p:pmodel.pmodel»«urgent» «p.name»(«IF p.taskload.head!=null»«IdslGeneratorExpression.printExp(p.taskload.head.load,dsi,variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»)
				«ENDFOR»			
			«ENDIF»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// ************************************
					SeqProcessModel:'''
		«FOR p:pmodel.pmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType)»«ENDFOR»
		
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
		«FOR p:pmodel.pmodel SEPARATOR '; /* separator seq */'»	«urgent» «p.name»(«IF p.taskload.head!=null»«IdslGeneratorExpression.printExp(p.taskload.head.load,dsi,variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»)
		«ENDFOR»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// ************************************
					MutexProcessModel:''' 
		«FOR p:pmodel.pmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType)»«ENDFOR»
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«urgent» mutex_«pmodel.name»_start!;
		«FOR p:pmodel.pmodel»	«urgent» «p.name»(«IF p.taskload.head!=null»«IdslGeneratorExpression.printExp(p.taskload.head.load, dsi, variableType)»«ELSEIF pmodel.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pmodel.taskload.head.load,dsi,variableType)»«ENDIF»);
		«ENDFOR»
			mutex_«pmodel.name»_stop?
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		binary action mutex_«pmodel.name»_start, mutex_«pmodel.name»_stop;
		
		
		«IF pmodel.num_instances==0»«pmodel.num_instances=1/* not entering a value (i.e., zero value) leads to default 1 */»«ENDIF»
		process mutex_«pmodel.name»(){
			mutex_«pmodel.name»_start?;
			«urgent» mutex_«pmodel.name»_stop!;
			mutex_«pmodel.name»()
		}
		«FOR cnt:(1..pmodel.num_instances)»
			«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: mutex_"+pmodel.name+"()")).toString»
		«ENDFOR»
		'''		 			 			 	
		}	 	
	}

}
