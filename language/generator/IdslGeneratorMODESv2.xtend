// Improved version of IdslGeneratorMODES which is more efficient with Model Checking

package org.idsl.language.generator

import java.util.ArrayList
import java.util.LinkedHashSet
import java.util.List
import java.util.Set
import org.idsl.language.idsl.AbstractionProcessModel
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.AtomicProcessModel
import org.idsl.language.idsl.DesAltProcessModel
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.FreqValue
import org.idsl.language.idsl.LBExpr
import org.idsl.language.idsl.LBIdentifier
import org.idsl.language.idsl.LBLastIdentifier
import org.idsl.language.idsl.LBNumServers
import org.idsl.language.idsl.LBQueueSize
import org.idsl.language.idsl.LBRandom
import org.idsl.language.idsl.LBValue
import org.idsl.language.idsl.LBenergyOn
import org.idsl.language.idsl.LBenergyShutdown
import org.idsl.language.idsl.LBenergySleep
import org.idsl.language.idsl.LBenergyStartup
import org.idsl.language.idsl.LBstateOn
import org.idsl.language.idsl.LBstateShutdown
import org.idsl.language.idsl.LBstateSleep
import org.idsl.language.idsl.LBstateStartup
import org.idsl.language.idsl.LBtimeShutdown
import org.idsl.language.idsl.LBtimeStartUp
import org.idsl.language.idsl.LastDelayExploit
import org.idsl.language.idsl.LastDelayExplore
import org.idsl.language.idsl.LbtimeOutTime
import org.idsl.language.idsl.LoadBalancerConfiguration
import org.idsl.language.idsl.LoadBalancerPolicy
import org.idsl.language.idsl.LoadBalancerProcessModel
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.MutexProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.ProcessResource
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.Scenario
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.Service
import org.idsl.language.idsl.ServiceRequest
import org.idsl.language.idsl.TimeSchedule
import org.idsl.language.idsl.TimeScheduleCDF
import org.idsl.language.idsl.TimeScheduleExp
import org.idsl.language.idsl.TimeScheduleFixedIntervals
import org.idsl.language.idsl.TimeScheduleLatencyJitter
import org.idsl.language.idsl.impl.IdslFactoryImpl

import static org.idsl.language.generator.IdslGeneratorGlobalVariables.*

class IdslGeneratorMODESv2 {
		// three functions to add a stopwatch and instance counter to a processmodel
		
		def static declareBufferAndListDataType()'''
			datatype list = { int head, list? tail };
			function list addFirst(list? ls, int item) = list { head: item, tail: ls };
			function int getLast(list ls) = if ls.tail == null then ls.head else getLast(ls.tail!);
			function list? removeLast(list ls) = if ls.tail == null then none else list { head: ls.head, tail: removeLast(ls.tail!) };
			
			datatype buffer = { int count, list? elements };
			function buffer add(buffer b, int item) = buffer { count: b.count + 1, elements: addFirst(b.elements, item) };
			function int get(buffer b) = getLast(b.elements!);
			function buffer remove(buffer b) = buffer { count: b.count - 1, elements: removeLast(b.elements!) };
		'''
		
		def static StopwatchStartModest (String name, String urgent, boolean visible, boolean is_main_process)'''
			«IF visible && ((IdslConfiguration.Lookup_value("evaluate_lower_level_latencies")=="true" || is_main_process))»«/* visible and main-process or config(lower-level latencies) */»
			«urgent» tau {= stopwatch_«name» = 0, stopwatch_«name»_done = false =};«ENDIF»'''
			
		def static StopwatchStartModest (String name, String urgent, boolean visible){
			StopwatchStartModest(name, urgent, visible, false) // not a main process
		}

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

		def static SimulationProperties(String extproc_name,  String processToMeasure)'''
			«IF extproc_name==processToMeasure»
				int stopwatch_counter_«extproc_name»=0;
				
				«FOR cnt:1..new Integer(IdslConfiguration.Lookup_value("pta_model_checking2_simulation_length"))»
					property property_«extproc_name»_«cnt» = Xmax( stopwatch_«extproc_name» | stopwatch_counter_«extproc_name»==«cnt»);
				«ENDFOR»
			«ENDIF»
		
		'''

		def static UPPAALproperties (String extproc_name, boolean isUPPAAL, boolean isUPAALupper, String processToMeasure, String Pmin_or_Pmax)'''
			«IF isUPPAAL && extproc_name==processToMeasure»	
				«IF IdslConfiguration.Lookup_value("MCTAU_analysis_mode")=="binary_search"»
					«IF isUPAALupper»
						const int VAL; // Experiment parameter: upper bound
						property prob = «Pmin_or_Pmax»(<> ( !stopwatch_«extproc_name»_final && stopwatch_«extproc_name»_done && stopwatch_«extproc_name» > VAL) );
					«ELSE»
						const int VAL; // Experiment parameter: lower bound
						property prob = «Pmin_or_Pmax»(<> ( !stopwatch_«extproc_name»_final && stopwatch_«extproc_name»_done && stopwatch_«extproc_name» <= VAL) );
					«ENDIF»
				«ELSEIF IdslConfiguration.Lookup_value("MCTAU_analysis_mode")=="brute_force_search"»	
					// UPPAAL PROPERTIES FOR INSTANCE «extproc_name»
					«FOR cnt:UPPAALpropertyValuesToCheck»/* relate these values to the expected outcomes */
						 property lowerbound_«extproc_name»_smaller_«cnt» = «Pmin_or_Pmax»(<> !stopwatch_«extproc_name»_final && stopwatch_«extproc_name»_done && stopwatch_«extproc_name» <= «cnt»);
						 property lowerbound_«extproc_name»_greater_«cnt» = «Pmin_or_Pmax»(<> !stopwatch_«extproc_name»_final && stopwatch_«extproc_name»_done && stopwatch_«extproc_name» >= «cnt»);								
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

		def static printGenerator(int num_activityis, List<Service> ai_activity_id, String extproc_name, TimeSchedule ts, DesignSpaceModel dsi, String variableType){
			switch(ts){
				TimeScheduleFixedIntervals: return printGenerator_fixed_intervals(num_activityis, ai_activity_id, extproc_name, ts, dsi, variableType)
				TimeScheduleLatencyJitter:  return printGenerator_latency_jitter(num_activityis, ai_activity_id, extproc_name, ts, dsi, variableType)
				TimeScheduleExp: 			return printGenerator_exponential(num_activityis, ai_activity_id, extproc_name, ts, dsi, variableType)
				TimeScheduleCDF: 			return printGenerator_CDF(num_activityis, ai_activity_id, extproc_name, "-1", ts, dsi, variableType)
			}	
			throw new Throwable("printGenerator: TimeSchedule not supported!")
		}
		
		def static create_and_reset_clock ()
		'''clock c; tau {= c=0 =};
		'''
		
		def static trigger_or_timeout (String extproc_name, String variableType){
			var multiplier = ""
			if (variableType=="real") multiplier=" * "+IdslConfiguration.Lookup_value("small_multiplier_when_reals_used")	
			'''
			alt{
				:: urgent generator_«extproc_name»!
				:: delay(1 «multiplier») 
						«IF (IdslConfiguration.Lookup_value("count_timeouts")=="yes")»
							tau {= timeouts_«extproc_name» = timeouts_«extproc_name» +1 =}
						«ELSE»
						tau
						«ENDIF»
			};			
			'''
		}
		
		def static delay1()'''
			// delay of 1 to not have two service request at the same time
			delay(1)
				tau;
		'''
		
		// convert the exp to a CDF and then make a call to printGenerator_CDF			
		def static printGenerator_exponential(int num_activityis, List<Service> ai_activity_id, String extproc_name, TimeScheduleExp
			ts, DesignSpaceModel dsi, String variableType){				
			var TimeScheduleCDF ts_cdf = IdslFactoryImpl::init.createTimeScheduleCDF
			ts_cdf.ecdf.add(IdslGeneratorSyntacticSugar.replace_exponentialDistributionCDF(ts.exp.head))
			return printGenerator_CDF(num_activityis, ai_activity_id, extproc_name, ts.exp.head.value, ts_cdf, dsi, variableType)
		}
		
		def static printGenerator_CDF_freqvalue(FreqValue freqval, List<Service> ai_activity_id, String variableType){
			'''
				when (c >= «IF variableType=="real"»(int)«ENDIF»«freqval.value.head»)
					urgent (c >= «IF variableType=="real"»(int)«ENDIF»«freqval.value.head»)
					generator_«ai_activity_id.head.name»()
			'''
			
		}
		
		def static printGenerator_CDF(int num_activityis, List<Service> ai_activity_id, String extproc_name, 
									  String rate, TimeScheduleCDF ai_time_head, DesignSpaceModel dsi, String variableType){
			var MVExpECDF ecdf = ai_time_head.ecdf.head // the cdf with arrival times/probabilities
			'''
			// GENERATOR CODE GOES HERE (using printGenerator_CDF)
			process generator_«ai_activity_id.head.name»(){
				real expo=Exponential(«rate»);
				«create_and_reset_clock»
				«trigger_or_timeout(extproc_name, variableType)»
				«/*delay1*/»
			
			«IF !rate.equals("-1") || IdslConfiguration.Lookup_value("negative_exponential_distribution_arrivals_use_math")=="yes"»
				«printGenerator_CDF_math (ai_activity_id, rate)»
			«ELSE»
				«printGenerator_CDF_palt (extproc_name, ecdf, ai_activity_id, variableType)»
			«ENDIF»
			}
			«add_generator_to_main("0",ai_activity_id.head.name)»
			binary action generator_«extproc_name»;
			int timeouts_«extproc_name» = 0;
			property property_timeouts_«extproc_name» = Xmax( timeouts_«extproc_name» | stopwatch_counter_all_instances_«extproc_name»==«num_activityis»);
			'''	
		}		
		
		def static printGenerator_CDF_palt(String extproc_name, MVExpECDF ecdf, List<Service> ai_activity_id, String variableType)
		'''
			// SELECT ONE OPTION OF THE CDF
			palt {
				«FOR freqval:ecdf.freqval»
				: «freqval.freq.head»  : «printGenerator_CDF_freqvalue(freqval, ai_activity_id, variableType)»
				«ENDFOR»	
			}
		'''	
		
		def static printGenerator_CDF_math(List<Service> ai_activity_id, String rate)
		'''
			// SELECT ONE OPTION OF THE CDF
			when urgent (c>=expo)
				generator_«ai_activity_id.head.name»()
		'''
		
		def static printGenerator_latency_jitter(int num_activityis, List<Service> ai_activity_id, String extproc_name, TimeScheduleLatencyJitter 
			ts_latency_jitter, DesignSpaceModel dsi, String variableType){		
			'''
			// GENERATOR CODE GOES HERE (using printGenerator_latency_jitter)
			process generator_«ai_activity_id.head.name»(){
				«create_and_reset_clock»
				«trigger_or_timeout(extproc_name, variableType)»
				«delay1»
				
				when (c >= («IF variableType=="real"»(int)«ENDIF»«IdslGeneratorExpression.printAExp(ts_latency_jitter.period,dsi,variableType)») - («IdslGeneratorExpression.printAExp(ts_latency_jitter.jitter,dsi,variableType)») )
					urgent (c >= («IF variableType=="real"»(int)«ENDIF»«IdslGeneratorExpression.printAExp(ts_latency_jitter.period,dsi,variableType)») + («IdslGeneratorExpression.printAExp(ts_latency_jitter.jitter,dsi,variableType)») )
					generator_«ai_activity_id.head.name»()
			}

			«add_generator_to_main("0",ai_activity_id.head.name)»
			binary action generator_«extproc_name»;
			'''
		}

		def static printGenerator_fixed_intervals(int num_activityis, List<Service> ai_activity_id, String extproc_name, TimeScheduleFixedIntervals 
			ai_time_head, DesignSpaceModel dsi, String variableType){					
			'''
			// GENERATOR CODE GOES HERE (using printGenerator_fixed_intervals)
			process generator_«ai_activity_id.head.name»(){
				«create_and_reset_clock»
				«trigger_or_timeout(extproc_name, variableType)»
				when urgent (c >= («IF variableType=="real"»(int)«ENDIF»«IdslGeneratorExpression.printAExp(ai_time_head.interval,dsi,variableType)») - («IdslGeneratorExpression.printAExp(ai_time_head.start,dsi,variableType)») )
					generator_«ai_activity_id.head.name»()
			}
			
			«add_generator_to_main(IdslGeneratorExpression.printAExp(ai_time_head.start,dsi,variableType).toString,ai_activity_id.head.name)»
			binary action generator_«extproc_name»;
			'''
		}
		
		def static add_generator_to_main (String init_time, String activity_name){ // adds a generator to the main Modest process
			(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(''':: when urgent (cinit>=(«init_time»))  generator_«activity_name»() //tx3'''))
		}

		def static PrintProcessInstance(ExtendedProcessModel extproc, boolean isUPPAAL, 
										String urgent, String process_to_measure, int gran, boolean simulation, 
										boolean probabilism_enabled, boolean oneStopwatchPerInstance){ // overloads for request_selection_rate
			PrintProcessInstance(extproc, isUPPAAL, urgent, 10, process_to_measure, gran, simulation, probabilism_enabled, oneStopwatchPerInstance) // default: request_selection_rate=10
		}

		def static PrintProcessInstance(ExtendedProcessModel extproc, boolean isUPPAAL, String urgent, int request_selection_rate, 
										String process_to_measure, int gran, boolean simulation, boolean probabilism_enabled,
										boolean oneStopwatchPerInstance){
			var int image_select_rate = new Integer(IdslConfiguration.Lookup_value("PTA_select_image"))
			'''
			// PRINTING PROCESS INSTANCE «extproc.name»	WITH STOPWATCH
			process «extproc.name»_instance(){
				generator_«extproc.name»? «IF extproc.name==process_to_measure»{= stopwatch_«extproc.name» = 0, stopwatch_«extproc.name»_done = false =}«ENDIF» ; 	
				«var pm=extproc.pmodel»«pm.head.name»(-1);
				
				«IF extproc.name==process_to_measure»
					«IF simulation»
						urgent tau {= stopwatch_«extproc.name»_done = true, stopwatch_counter_«extproc.name»++ =};
					«ELSE»
					 «IF !probabilism_enabled»
				 		«urgent» tau {= stopwatch_«extproc.name»_done = true =};
			 			«urgent» tau {= stopwatch_«extproc.name» = 0, stopwatch_«extproc.name»_done = false =};
			 		 «ELSE»
					    urgent palt { // exponential selection of a service request with probablity=a/b
		 					/* a */ :1: «urgent» tau {= stopwatch_«extproc.name»_done = true«IF !isUPPAAL», stopwatch_counter_«extproc.name»++«ENDIF» =};
	 									  urgent tau {= stopwatch_«extproc.name»_final = true, stopwatch_«extproc.name»_done = false =}
 							/* «image_select_rate» */ :«request_selection_rate»: urgent tau // continue with next service request 
						}; 
					 «ENDIF»
					«ENDIF»
				«ELSE»
					// no exponential selection of a service request here, because this process it not measured
				«ENDIF»
				urgent tau «IF extproc.name==process_to_measure»{= stopwatch_«extproc.name» = 0, stopwatch_«extproc.name»_done = false =}«ENDIF»

			}

			// PRINTING PROCESS INSTANCE «extproc.name»	WITHOUT STOPWATCH
			process «extproc.name»_instance_no_stopwatch(){
				generator_«extproc.name»?;
				«pm.head.name»(-1)
				}
			'''
		}

		def static CharSequence DSEScenarioToModest(int num_activityis, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi, 
								List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources,
								boolean stopwatchEnabled, boolean utilizationEnabled, boolean throughputCalcEnabled, boolean isUPPAAL, String urgent, 
								String variableType, int gran, boolean simulation, boolean probabilism_enabled, boolean oneStopwatchPerInstance){
			 // Huge overload to allow an extra, optional UPPAAL parameter at the end
			 DSEScenarioToModest(num_activityis, s, dsm, dsi, activities, epms, mappings, resources,
								stopwatchEnabled,  utilizationEnabled,  throughputCalcEnabled,  isUPPAAL,  urgent,  variableType, true, "", gran, simulation, probabilism_enabled, oneStopwatchPerInstance)
		}

		def static CharSequence DSEScenarioToModest(int num_activityis, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi,
								List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources,
								boolean stopwatchEnabled, boolean utilizationEnabled, boolean throughputCalcEnabled, boolean isUPPAAL, String urgent, 
								String variableType, boolean isUPAALupper, String processToMeasure, int gran, boolean simulation, boolean probabilism_enabled, boolean oneStopwatchPerInstance){ // overloading for Pmin_or_Pmax with default: Pmin 
			return DSEScenarioToModest (num_activityis, s, dsm, dsi, activities, epms, mappings, resources, stopwatchEnabled, utilizationEnabled, throughputCalcEnabled, 
										isUPPAAL, urgent, variableType, isUPAALupper, processToMeasure, "Pmin", gran, simulation, probabilism_enabled, oneStopwatchPerInstance)
		}

		def static CharSequence DSEScenarioToModest(int num_activityis, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi,
								List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources,
								boolean stopwatchEnabled, boolean utilizationEnabled, boolean throughputCalcEnabled, boolean isUPPAAL, String urgent, 
								String variableType, boolean isUPAALupper, String processToMeasure, String Pmin_or_Pmax, int gran, boolean simulation, boolean probabilism_enabled, boolean oneStopwatchPerInstance){
			IdslGeneratorGlobalVariables.global_processes_to_print=new LinkedHashSet<String>() // for abstract processes
			IdslGeneratorGlobalVariables.global_resources_to_print=new LinkedHashSet<Pair<String,LoadBalancerConfiguration>> // to create resources eventually
			IdslGeneratorGlobalVariables.global_processresources_to_print=new LinkedHashSet<ProcessResource>() // the mappings from process to resource to print
	 		IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add (variableType + " sync_buffer;  \n"+variableType+" sync_buffer2; \nclock cinit;\nclosed par{")
	 		
	 		var List<String> final_properties=new ArrayList<String> // to store the stopwatch_«ext_proc>_final names that immediately stop the resource when true.
	 		var Set<String> ai_unique = new LinkedHashSet<String>()
	 		var Set<String> p_unique  = new LinkedHashSet<String>()
			'''
			«declareBufferAndListDataType»
			
			«FOR ai:s.ainstance»
				«var Service am=ai.activity_id.head»
				«var ExtendedProcessModel extproc = IdslGenerator.filterExtProcess(epms,am.extprocess_id.name)»
				«var Mapping mapping = am.mapping.head»
				
				«final_properties.add(extproc.name).toString.substring(0,0)»
				
				«IF !ai_unique.contains(ai.activity_id.head)»
					«IF simulation»
						«SimulationProperties(extproc.name, processToMeasure)»
					«ELSE»
						«UPPAALproperties(extproc.name, isUPPAAL, isUPAALupper, processToMeasure, Pmin_or_Pmax)»
					«ENDIF»	
					«PrintProcessInstance(extproc, isUPPAAL, urgent, processToMeasure, gran, simulation, probabilism_enabled, oneStopwatchPerInstance)»
					«PrintStopwatches(num_activityis, processToMeasure, ai, extproc, dsi, isUPPAAL, throughputCalcEnabled, variableType, oneStopwatchPerInstance)»
					«ExtProcessMappingToText(ai.activity_id.head.extprocess_id.name /* EDITED 8/1/2016 */ , num_activityis, stopwatchEnabled, extproc,mapping, dsm, dsi, urgent, variableType, probabilism_enabled)»
				«ENDIF»
				«ai_unique.add(ai.activity_id.head.name).toString.substring(0,0)»«/* TODO: work in progress. what name should the generators have (process name, many to one link)? How to link them to processes?*/»
				«p_unique.add(ai.activity_id.head.extprocess_id.name.toString).toString.substring(0,0)»
				
				«printGenerator(num_activityis, ai.activity_id, extproc.name, ai.time.head, dsi,variableType)»
			«ENDFOR»
			
			«FOR cnt:1..IdslGeneratorGlobalVariables.global_resources_to_print.length»
				«var res=IdslGeneratorGlobalVariables.global_resources_to_print.get(cnt-1)»
				«IdslGeneratorMODESSchedulingv2.ResourceNameToText(cnt, num_activityis, p_unique, res, resources, mappings, dsi, utilizationEnabled, urgent, variableType, "")»«/*CHANGED from v1 to v2 and added "" parameter in the end*/»
			«ENDFOR»
			«IdslGeneratorMODESSchedulingv2.ProcessResourcesToPrint(num_activityis, urgent, variableType, stopwatchEnabled)»
			
			«PrintDSLInstanceInComment»
			'''
		}
	
	def static flatten_final_properties(List<String> list_strings){
		var ret_str = ""
		for(str:list_strings)
			ret_str=ret_str+" && !stopwatch_"+str+"_final "
		return ret_str
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
	
	def static PrintStopwatches(int num_activityis, String chosen_process, ServiceRequest ai, ExtendedProcessModel extproc, 
		DesignSpaceModel dsi, boolean isUPPAAL, boolean throughputCalcEnabled, String variableType, boolean oneStopwatchPerInstance){'''
		«IF throughputCalcEnabled»
			«FOR cnt:(1..30)/* might be nice to make 30 a variable for computing the throughput */»
				«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: do {" + extproc.name + "_instance() }"))»
			«ENDFOR»
			«FOR cnt:(1..num_activityis)»
				property property_throughput_«extproc.name»_«cnt» = Xmax( time | stopwatch_«extproc.name»_done && stopwatch_counter_«extproc.name»==«cnt»);
			«ENDFOR»				
		«ELSE /* in non-throughput mode only one instance is stopwatched to save performance */»
			«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add(" :: do {" + extproc.name + "_instance() }"))»
		
			«IF ai.time.head.num_instances!=null»«var n=new Integer(IdslGeneratorExpression.printAExp(ai.time.head.num_instances,dsi,variableType).toString.substring(5)/* remove preceding (int) */)»«IF n>1»
				«FOR cnt:(1..(n-1))»
					«(IdslGeneratorGlobalVariables.global_main_modest_class_to_print_add( " :: do {" + extproc.name + "_instance_no_stopwatch() }"))»
				«ENDFOR»
			«ENDIF»«ENDIF»		
		«ENDIF»
		
		«IF !isUPPAAL»
			// Counts all the instances of «extproc.name» instead of only the stopwatch one
			// int stopwatch_counter_all_instances_«extproc.name»=0;
			property property_«extproc.name»_total = Xmax( stopwatch_counter_all_instances_«extproc.name» | stopwatch_counter_«extproc.name»==«num_activityis»);			
			
			int stopwatch_counter_«extproc.name»=0;
			«FOR cnt:(1..num_activityis)»property property_«extproc.name»_«cnt» = Xmax( stopwatch_«extproc.name» | stopwatch_counter_«extproc.name»==«cnt»);
			«ENDFOR»		
		«ENDIF»
		«IF extproc.name==chosen_process»
			clock stopwatch_«extproc.name»=0;
			bool stopwatch_«extproc.name»_done;
			bool stopwatch_«extproc.name»_final=false;
		«ENDIF»
		'''
	}
	
	def static ExtProcessMappingToText(String activity_id, int num_activityis, boolean stopwatchEnabled, ExtendedProcessModel extprocess, 
									   Mapping mapping, DesignSpaceModel dsm, DesignSpaceModel dsi, String urgent, 
									   String variableType, boolean probabilism_enabled){
		// PRINTING PROCESS «extproc.name»
		IdslGeneratorGlobalVariables.global_processes_to_print=new LinkedHashSet<String>() // for abstract processes
		'''«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, extprocess.pmodel.head, mapping, dsm, dsi, urgent, variableType, probabilism_enabled)»
		«FOR gl:IdslGeneratorGlobalVariables.global_processes_to_print»
			«FOR spm:extprocess.spm»
				«IF IdslGeneratorGlobalVariables.global_processes_to_print.contains(spm.name.head)»
					process «spm.name.head» («variableType» parent){ 
						«StopwatchStartModest (spm.name.head, urgent, stopwatchEnabled, true)»
						«urgent» «spm.pmodel.head.name» (parent)
						«StopwatchStopModest (spm.name.head, urgent, stopwatchEnabled, true)»
					} // to connect the called process with subprocess
					«StopwatchDeclare (spm.name.head, num_activityis, stopwatchEnabled, true)»
					«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, spm.pmodel.head, mapping, dsm, dsi, urgent, variableType, probabilism_enabled)»«
				ENDIF»
			«ENDFOR»
		«ENDFOR»'''
	}		
	
	def static String printTaskloads (ProcessModel pm, String variableType, DesignSpaceModel dsi){
		switch(pm){
			AtomicProcessModel: '''«IF pm.taskload_nondet.empty»«IdslGeneratorExpression.printExp(pm.taskload.head.load,dsi,variableType)»,«IdslGeneratorExpression.printExp(pm.taskload.head.load,dsi,variableType)»«ELSE»«IdslGeneratorExpression.printExp(pm.taskload.head.load,dsi,variableType)»,«IdslGeneratorExpression.printExp(pm.taskload_nondet.head.load,dsi,variableType)»«ENDIF»'''
			default: 			'''«IF pm.taskload.head!=null»«IdslGeneratorExpression.printExp(pm.taskload.head.load,dsi,variableType)»«ELSEIF pm.taskload.head==null»parent«ELSE»«IdslGeneratorExpression.printExp(pm.taskload.head.load,dsi,variableType)»«ENDIF»'''
		}
	}
	
	// compares process APM with all other processes to see if it has the smallest policy value
	def static CharSequence evaluateLoadBalancerPolicyEquation (LoadBalancerPolicy policy, LoadBalancerConfiguration config, 
																String lb_name, AtomicProcessModel apm, List<AtomicProcessModel> apms, 
																Mapping mapping, DesignSpaceModel dsi, int rnd_offset){
		var int randoms_per_policy  = numberOfRandomsInLoadBalancerPolicy (policy)
		'''
		«FOR cnt:(0..apms.length-1)»
			«var other_apm=apms.get(cnt)»
			«var other_rnd_offset=cnt * randoms_per_policy»
			«IF apm.name!=other_apm.name»
				«(IdslGeneratorGlobalVariables.global_random_counter=rnd_offset).toString.substring(0,0)»
				(«evaluateLoadBalancerPolicy(policy,config,lb_name,apm,mapping,dsi)»
				«(IdslGeneratorGlobalVariables.global_random_counter=other_rnd_offset).toString.substring(0,0)»
				<=«evaluateLoadBalancerPolicy(policy,config,lb_name,other_apm,mapping,dsi)»)&&
			«ENDIF»
		«ENDFOR»true
	'''}
	
	def static CharSequence evaluateLoadBalancerPolicy (LoadBalancerPolicy policy, LoadBalancerConfiguration config, 
														String lb_name, AtomicProcessModel apm, Mapping mapping, DesignSpaceModel dsi){
		switch(policy){
			LBNumServers:		'''lb_«lb_name»_num_servers'''
			LastDelayExploit:   '''lb_«lb_name»_lastDelay0'''
			LastDelayExplore:	'''lb_«lb_name»_lastDelayINF'''
			LBLastIdentifier:	'''lb_«lb_name»_lastID'''
			LBValue:  			'''«IdslGeneratorExpression.printExp(policy.value,dsi,"int")»''' 
			LBIdentifier:		'''«indexOfProcessInMapping(apm,mapping)»'''
			LBRandom:			'''«(IdslGeneratorGlobalVariables.global_random_counter=IdslGeneratorGlobalVariables.global_random_counter+1).toString.substring(0,0)»random_«IdslGeneratorGlobalVariables.global_random_counter»''' 
			//LBRandom:			'''(int)Uniform(0,1000)/1000'''
			LBExpr:   			'''(«evaluateLoadBalancerPolicy(policy.a1.head,config,lb_name,apm,mapping,dsi)»
								   		«policy.op.head»«evaluateLoadBalancerPolicy(policy.a2.head,config,lb_name,apm,mapping,dsi)»)'''
			LBenergyOn:			'''«IdslGeneratorExpression.printAExp(config.energyOn.head,dsi,"int")»'''
			LBenergyShutdown:	'''«IdslGeneratorExpression.printAExp(config.energyShutdown.head,dsi,"int")»'''
			LBenergySleep:		'''«IdslGeneratorExpression.printAExp(config.energySleep.head,dsi,"int")»'''
			LBenergyStartup:	'''«IdslGeneratorExpression.printAExp(config.energyStartup.head,dsi,"int")»'''
			LBstateOn:			'''state_«findResourceForProcess(apm,mapping)»_on'''
			LBstateShutdown:	'''state_«findResourceForProcess(apm,mapping)»_shutdown'''
			LBstateSleep:		'''state_«findResourceForProcess(apm,mapping)»_sleep'''
			LBstateStartup:		'''state_«findResourceForProcess(apm,mapping)»_startup'''
			LBtimeShutdown:		'''«IdslGeneratorExpression.printAExp(config.timeShutdown.head,dsi,"int")»'''
			LBtimeStartUp:		'''«IdslGeneratorExpression.printAExp(config.timeStartUp.head,dsi,"int")»'''
			LbtimeOutTime:		'''«IdslGeneratorExpression.printAExp(config.timeOutTime.head,dsi,"int")»'''
			LBQueueSize:	    '''«findResourceForProcess(apm,mapping)»_buffer_processid_low_instance.count+
										«findResourceForProcess(apm,mapping)»_buffer_processid_medium_instance.count+
										«findResourceForProcess(apm,mapping)»_buffer_processid_high_instance.count'''
		}
	}
	
	def static int numberOfRandomsInLoadBalancerPolicy (LoadBalancerPolicy policy){ // how many random constructs does the policy contain?
		switch(policy){
			LBExpr:		numberOfRandomsInLoadBalancerPolicy(policy.a1.head) + numberOfRandomsInLoadBalancerPolicy(policy.a2.head)
			LBRandom:	return 1
			default: 	return 0
		}
	}
	

	// assigns an ID to a process by looking up its position in the mapping
	def static int indexOfProcessInMapping(AtomicProcessModel apm, Mapping mapping){
		for(cnt:0..mapping.prassignment.length-1){
			var pr=mapping.prassignment.get(cnt)
			if(pr.process.equals(apm.name))
				return cnt
		}
	}

	def static String findResourceForProcess (ProcessModel p, Mapping m){
		for(ass:m.prassignment)
			if(ass.process==p.name) // process found
				return ass.resource
		throw new Throwable("findResourceForProcess: process not found in the mapping")	
	}

	def static String ProcessMappingToText(String activity_id, int num_activityis, boolean stopwatchEnabled, ProcessModel pmodel, Mapping mapping, 
									DesignSpaceModel dsm, DesignSpaceModel dsi, String urgent, String variableType, boolean probabilism_enabled){
		return ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, pmodel, mapping, 
									dsm, dsi, urgent, variableType, probabilism_enabled, null) // default: parent p is not a loadbalancer
	}

	def static String ProcessMappingToText(String activity_id, int num_activityis, boolean stopwatchEnabled, ProcessModel pmodel, Mapping mapping, 
									DesignSpaceModel dsm, DesignSpaceModel dsi, String urgent, String variableType, boolean probabilism_enabled,
									LoadBalancerConfiguration lb_config_if_parent_of_p_is_loadbalancer){
		 for (a:mapping.prassignment){ 
		 	if(pmodel.name==a.process){
		 		IdslGeneratorGlobalVariables.global_resources_to_print.add(a.resource -> lb_config_if_parent_of_p_is_loadbalancer) 
		 		IdslGeneratorGlobalVariables.global_processresources_to_print.add(a)
				return ""
		 	} 
		 }
		 
		
		 switch (pmodel){ AbstractionProcessModel: IdslGeneratorGlobalVariables.global_processes_to_print.add(pmodel.name) }
		 switch (pmodel){ AtomicProcessModel:			return ""//"/*"+printAExp(pmodel.taskload.load,dsm,dsi)+"*/" // does not need code, since its parent will list its name
						  AbstractionProcessModel:		return ""//"/*"+printAExp(pmodel.taskload.load,dsm,dsi)+"*/" // does not need code, since its parent will list its name
		 
		 					DesAltProcessModel: 
		 { 
			var value_index=IdslGeneratorDesignSpace.lookupValuePositionDSM(pmodel.param.head, dsi, pmodel.pmodel)
			var chosen_process = pmodel.pmodel.get(value_index).pmodel.head
			'''«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, chosen_process, mapping, dsm, dsi, urgent, variableType, probabilism_enabled)»
			
			process «pmodel.name»(«variableType» parent){
				«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
				«urgent» «chosen_process.name»(«printTaskloads (chosen_process, variableType, dsi)»)
				«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
				
			}
			«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
			'''
		}
		// ************************************
							LoadBalancerProcessModel:'''
		«FOR p:pmodel.pmodel»
			«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType, probabilism_enabled, pmodel.lb_config)»
		«ENDFOR»
			«var selectedPolicy=selectPolicyBasedOnDSI(pmodel.name, pmodel.lb_policies, dsi)»
			«var randoms_per_policy=numberOfRandomsInLoadBalancerPolicy(selectedPolicy)»
			
		process «pmodel.name»(«variableType» parent){		// load balancer «pmodel.name»
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«loadBalancerDeclareRandoms(selectedPolicy, pmodel.pmodel.length /* number of systems */)»
			«IF pmodel.pmodel.length>1»alt{
				«FOR cnt:(0..pmodel.pmodel.length-1)»
					«var p=pmodel.pmodel.get(cnt)»
					«var rnd_offset=cnt * randoms_per_policy»
					
				    :: //one load balancer option
				    when urgent («evaluateLoadBalancerPolicyEquation(selectedPolicy,pmodel.lb_config,pmodel.name,p,pmodel.pmodel,mapping,dsi, rnd_offset)»)
					urgent tau {= lb_«pmodel.name»_lastID = «cnt» =};
					«p.name»(«printTaskloads (p, variableType, dsi)»);
					tau {= lb_«pmodel.name»_«p.name»_count++,
					       lb_«pmodel.name»_«p.name»_lastDelay0   = 999, /* ERROR: not implemented yet */ 
					       lb_«pmodel.name»_«p.name»_lastDelayINF = 999 /* ERROR: not implemented yet */ =}
				«ENDFOR»
			}«ELSE»
				throw new Throwable("ProcessMappingToText: A load balancer with one system is not supported!!")
			«ENDIF»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«LoadBalancerDeclareSomeVariables(pmodel.name, pmodel.pmodel)»
		«LoadBalancerDeclareMachineCountersAndProperties(activity_id, pmodel.name, pmodel.pmodel, num_activityis)»
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// «FOR p:pmodel.pmodel»	:: when urgent («evaluateLoadBalancerPolicy(pmodel.lb_policy, pmodel.lb_config, p, dsi)») «p.name»(«printTaskloads (p, variableType, dsi)»)
		
		// ************************************
							AltProcessModel:'''
		«FOR p:pmodel.pmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType, probabilism_enabled)»«ENDFOR»
		
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«IF pmodel.pmodel.length>1»alt{
				«FOR p:pmodel.pmodel»	:: «urgent» «p.name»(«printTaskloads (p, variableType, dsi)»)
				«ENDFOR»
			}«ELSE»
				«FOR p:pmodel.pmodel»«urgent» «p.name»(«printTaskloads (p, variableType, dsi)»)
				«ENDFOR»			
			«ENDIF»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// ************************************
					PaltProcessModel:'''
		«FOR p:pmodel.ppmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p.pmodel.head, mapping, dsm, dsi, urgent, variableType,probabilism_enabled)»«ENDFOR»
		
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«IF pmodel.ppmodel.length>1»«IF probabilism_enabled»palt«ELSE»alt«ENDIF»{
				«FOR q:pmodel.ppmodel»	:«IF probabilism_enabled»«q.prob.head.toString»«ENDIF»:  «urgent» «FOR p:q.pmodel»«p.name»(«printTaskloads (p, variableType, dsi)»)«ENDFOR»
				«ENDFOR»
			}«ELSE»
				«FOR q:pmodel.ppmodel»«urgent» «FOR p:q.pmodel»«p.name»(«printTaskloads (p, variableType, dsi)»)«ENDFOR»
				«ENDFOR»	
			«ENDIF»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// ************************************
					ParProcessModel:'''
		«FOR p:pmodel.pmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType, probabilism_enabled)»«ENDFOR»
		
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«IF pmodel.pmodel.length>1»par{
				«FOR p:pmodel.pmodel»	:: «urgent» «p.name»(«printTaskloads (p, variableType, dsi)»)
				«ENDFOR»
			}«ELSE»
				«FOR p:pmodel.pmodel»«urgent» «p.name»(«printTaskloads (p, variableType, dsi)»)
				«ENDFOR»			
			«ENDIF»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// ************************************
					SeqProcessModel:'''
		«FOR p:pmodel.pmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType, probabilism_enabled)»«ENDFOR»
		
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
		«FOR p:pmodel.pmodel SEPARATOR '; /* separator seq */'»	«urgent» «p.name»(«printTaskloads (p, variableType, dsi)»)
		«ENDFOR»
			«StopwatchStopModest (pmodel.name, urgent, stopwatchEnabled)»
		}
		«StopwatchDeclare (pmodel.name, num_activityis, stopwatchEnabled)»
		'''
		// ************************************
					MutexProcessModel:''' 
		«FOR p:pmodel.pmodel»«ProcessMappingToText(activity_id, num_activityis, stopwatchEnabled, p, mapping, dsm, dsi, urgent, variableType, probabilism_enabled)»«ENDFOR»
		process «pmodel.name»(«variableType» parent){
			«StopwatchStartModest (pmodel.name, urgent, stopwatchEnabled)»
			«urgent» mutex_«pmodel.name»_start!;
		«FOR p:pmodel.pmodel»	«urgent» «p.name»(«printTaskloads (p, variableType, dsi)»);
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
	
	def static LoadBalancerDeclareSomeVariables(String lb_name, List<AtomicProcessModel> servers)'''
		int lb_«lb_name»_lastID = 0; // arbitrary init value
		int lb_«lb_name»_num_servers = «servers.length»;
		«FOR server:servers»
			int lb_«lb_name»_«server.name»_lastDelay0 = 0;
			int lb_«lb_name»_«server.name»_lastDelayINF = 99999;
		«ENDFOR»
	'''
	
	// determine the number of randoms and declare even so many variables
	def static CharSequence loadBalancerDeclareRandoms (LoadBalancerPolicy lb_policy, int num_systems){
		var     uniform_options = IdslConfiguration.Lookup_value("load_balancer_policy_random_number_of_options")
		var int randoms_per_policy = numberOfRandomsInLoadBalancerPolicy(lb_policy)
		var int num_randoms     =  randoms_per_policy * num_systems
		'''«FOR cnt:(1..num_randoms)»
			real random_«cnt.toString» = Uniform(1,«uniform_options») / «uniform_options»; // random number  
		«ENDFOR»
		'''
	}
	
	def static LoadBalancerPolicy selectPolicyBasedOnDSI (String lb_name, List<LoadBalancerPolicy> policies, DesignSpaceModel dsi){
		var index  = new Integer(IdslGeneratorDesignSpace.loopUpDSEValue("lb_policy_"+lb_name,dsi))
		var policy = policies.get(index)
		return policy
	}
	
	def static LoadBalancerDeclareMachineCountersAndProperties(String activity_id, String lb_name, List<AtomicProcessModel> pms, int num_activities)'''
		«FOR pm:pms»
			int lb_«lb_name»_«pm.name»_count=0;
			«FOR cnt:(1..num_activities)»
				property property_lb_«lb_name»_«pm.name»_«cnt» = Xmax( lb_«lb_name»_«pm.name»_count | stopwatch_counter_all_instances_«activity_id»==«cnt»);
			«ENDFOR»
		«ENDFOR»
	'''
	
	def static CharSequence global_counter()'''
	int global_timer;
	process global_time(){
		delay(1)
			tau{= global_timer++ =}
	}
	'''
}
