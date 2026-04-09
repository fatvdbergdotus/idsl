package org.idsl.language.generator

import java.io.File
import java.nio.charset.Charset
import java.nio.file.Files
import java.util.ArrayList
import java.util.Collections
import java.util.List
import org.eclipse.xtext.generator.IFileSystemAccess
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.DesignSpaceParam
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.LoadBalancerProcessModel
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.MeasurementPTAModelChecking
import org.idsl.language.idsl.MeasurementPTAModelChecking2
import org.idsl.language.idsl.MutexProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.Scenario
import org.idsl.language.idsl.SeqParProcessModel
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.Service
import org.idsl.language.idsl.ServiceRequest
import org.idsl.language.idsl.impl.IdslFactoryImpl
import java.util.Set
import java.util.HashSet
import org.idsl.language.idsl.StopwatchDistribution

class IdslGeneratorPerformExperiment {	// int granularity, int num_threads
	def static int setvalue (List<Integer> listint, String configdefault){
		if (listint.empty)
			return new Integer(IdslConfiguration.Lookup_value(configdefault))
		else 
			return listint.head
	}

	def static int setvalue (List<Integer> listint, int alternative_value){
		if (listint.empty)
			return alternative_value
		else 
			return listint.head
	}	
	
	def static int try_first_otherwise_lookup_in_configuration(List<String> intStrList, String config_lookup){
		if(!intStrList.empty)
			return new Integer(intStrList.head)
		else
			return new Integer(IdslConfiguration.Lookup_value(config_lookup))
	}
	
	def static boolean ext_processes_contains_load_balancer(List<ExtendedProcessModel> epms){
		return !load_balancers_in_extprocesses(epms).empty
	}
	
	def static boolean process_contains_load_balancer(ProcessModel pm){
		return !load_balancers_in_process(pm).empty
	}
	 
	def static List<Pair<String,Integer>> load_balancers_in_extprocesses (List<ExtendedProcessModel> epms){
		var Set<Pair<String,Integer>> lbs = new HashSet<Pair<String,Integer>> // load balancer name + number of policies
		for (epm:epms)
			lbs.addAll(load_balancers_in_process(epm.pmodel.head))
		return lbs.toList
	}
	
	def static List<Pair<String,Integer>> load_balancers_in_process (ProcessModel pm){
		var Set<Pair<String,Integer>> lbs = new HashSet<Pair<String,Integer>> // load balancer name + number of policies
		switch(pm){ // recursive function
 			ParProcessModel:				for(el:pm.pmodel)  lbs.addAll(load_balancers_in_process(el))
 			AltProcessModel:				for(el:pm.pmodel)  lbs.addAll(load_balancers_in_process(el))
			SeqProcessModel:				for(el:pm.pmodel)  lbs.addAll(load_balancers_in_process(el))
			PaltProcessModel:				for(el:pm.ppmodel) lbs.addAll(load_balancers_in_process(el.pmodel.head))
			MutexProcessModel:				for(el:pm.pmodel)  lbs.addAll(load_balancers_in_process(el))
			SeqParProcessModel:				for(el:pm.pmodel)  lbs.addAll(load_balancers_in_process(el))
			LoadBalancerProcessModel:		for(el:pm.pmodel)  lbs.add(pm.name -> pm.lb_policies.length)
			//PowerFailurePerformanceProcessModel: throw new Throwable("load_balancers_in_process: PowerFailurePerformanceProcessModel now supported!")		
		}
		return lbs.toList
	}

	def static public performExperimentPTAModelChecking2(MeasurementPTAModelChecking2 measure, IFileSystemAccess fsa, String extPath, 
										   Scenario scenario, DesignSpaceModel dsm, DesignSpaceModel dsi, List<Service> activities,
										   List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, 
										   String urgent, String variableType){							   		
		/*var int dynamicallySelectingModelTimeout= first_otherwise_lookup_in_configuration(measure.dynamically_selecting_model_timeout,
		var int	modelTimeUnitStepSize 			= first_otherwise_lookup_in_configuration(measure.model_time_unit_step_size,
		var int	modelTimeUnitNumSteps			= first_otherwise_lookup_in_configuration(measure.model_time_unit_num_steps,
		var int	segmentStepSize     			= first_otherwise_lookup_in_configuration(measure.segement_step_size,
		var int	segmentNumSteps        			= first_otherwise_lookup_in_configuration(measure.segment_num_steps,
		var int	simulationNumRuns  	 			= first_otherwise_lookup_in_configuration(measure.simulation_num_runs,
		var int	simulationRunLength     		= first_otherwise_lookup_in_configuration(measure.simulation_run_length, 
		var int	kmeansOverallIterations   		= first_otherwise_lookup_in_configuration(measure.kmeans_overall_iterations,
		var int	kmeansBalancingIterations  		= first_otherwise_lookup_in_configuration(measure.kmeans_balancing_iterations,
		var int	numberOfCores					= first_otherwise_lookup_in_configuration(measure.num_cores,
		var int	findingBoundsMethodNumber		= first_otherwise_lookup_in_configuration(measure.find_bounds_method_number,*/
		
		// Select only one dsi per samplingmethod and modeltimeunit
		//var List<Pair<String,String>> modes_theo_bounds_and_activitymodels = new ArrayList<Pair<String,String>>
		
		for (ServiceRequest ainstance:scenario.ainstance){
			for(path:#[extPath]){
				var activitymodel = ainstance.activity_id.head
				var dirPath=								"ExpPTAModelChecking2/"
				var modes_theo_bounds_prefix=				path+dirPath+"modes_theo_bounds_"
				var modes_theo_bounds=						modes_theo_bounds_prefix + activitymodel.extprocess_id.name
				
				//if(IdslGeneratorDesignSpace.DSMparamToValue(dsi, "samplingmethod")=="ecdf1" &&
				//	IdslGeneratorDesignSpace.DSMparamToValue(dsi, "modeltimeunit")=="1" )
				//		modes_theo_bounds_and_activitymodels.add(modes_theo_bounds -> activitymodel.name)

				// All Pmin lb + Pmax lb + Pmin Lb (noprob) + Pmax lb (noprob) + simulation + best-case
				var modes_theo_bounds_filename_lb_pmin=			modes_theo_bounds+"-lb-pmin.modest"		
				var modes_theo_bounds_filename_lb_pmax=			modes_theo_bounds+"-lb-pmax.modest"	
				var modes_theo_bounds_filename_lb_pmin_noprob=	modes_theo_bounds+"-lb-pmin-noprob.modest"		
				var modes_theo_bounds_filename_lb_pmax_noprob=	modes_theo_bounds+"-lb-pmax-noprob.modest"	
				
				var modes_theo_bounds_filename_ub_pmin=			modes_theo_bounds+"-ub-pmin.modest"		
				var modes_theo_bounds_filename_ub_pmax=			modes_theo_bounds+"-ub-pmax.modest"	
				var modes_theo_bounds_filename_ub_pmin_noprob=	modes_theo_bounds+"-ub-pmin-noprob.modest"		
				var modes_theo_bounds_filename_ub_pmax_noprob=	modes_theo_bounds+"-ub-pmax-noprob.modest"
				
				var modes_theo_bounds_filename_sim=			    modes_theo_bounds+"-sim.modest"
				var filename_bestcase=							modes_theo_bounds+"-bestcase.dat"
	
				// Create the pmin and pmax Modest files for the current Service
					//lower bound
					fsa.generateFile(modes_theo_bounds_filename_lb_pmin, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, false, activitymodel.extprocess_id.name, "Pmin", 0, false, true, false)) //lower bound, pmin
					fsa.generateFile(modes_theo_bounds_filename_lb_pmax, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, false, activitymodel.extprocess_id.name, "Pmax", 0, false, true, false)) //lower bound, pmax
					//upper bound
					fsa.generateFile(modes_theo_bounds_filename_ub_pmin, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, true,  activitymodel.extprocess_id.name, "Pmin", 0, false, true, false)) //lower bound, pmin
					fsa.generateFile(modes_theo_bounds_filename_ub_pmax, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, true,  activitymodel.extprocess_id.name, "Pmax", 0, false, true, false)) //lower bound, pmax
				
				// Create the pmin and pmax Modest files for the current Service (without probabilities)
					//lower bound
					fsa.generateFile(modes_theo_bounds_filename_lb_pmin_noprob, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, false, activitymodel.extprocess_id.name, "Pmin", 0, false, false, false)) //lower bound, pmin
					fsa.generateFile(modes_theo_bounds_filename_lb_pmax_noprob, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, false, activitymodel.extprocess_id.name, "Pmax", 0, false, false, false)) //lower bound, pmax				
					//upper bound
					fsa.generateFile(modes_theo_bounds_filename_ub_pmin_noprob, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, true, activitymodel.extprocess_id.name, "Pmin", 0, false, false, false)) //lower bound, pmin
					fsa.generateFile(modes_theo_bounds_filename_ub_pmax_noprob, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, true, activitymodel.extprocess_id.name, "Pmax", 0, false, false, false)) //lower bound, pmax				
				
				// Create simulation file for the current Service
				fsa.generateFile(modes_theo_bounds_filename_sim, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, 
					resources, false, false, false, true, urgent, variableType, false, activitymodel.extprocess_id.name, "Pmax", 0, true /* simulation */, true, false)) //lower bound, pmax

				// Compute the best-case for pmin and pmax, for all processes
				fsa.generateFile(filename_bestcase, IdslGeneratorBestCase.computeStr(epms,activities,dsi))
				
				if(IdslGeneratorDesignSpace.DSMparamToValue(dsi, "samplingmethod")=="ecdf1" &&
					IdslGeneratorDesignSpace.DSMparamToValue(dsi, "modeltimeunit")=="1" )
						IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(modes_theo_bounds, 
											IdslGeneratorDesignSpace.DSMvalues(dsi)+" "+activitymodel.name, "PTA Model checking2"
					)				
			}

			
		}
		// copy the different services and beloging models to class IdslGeneratorPerformExperimentPTAModelCheck2 
		//IdslGeneratorPerformExperimentPTAModelCheck2.modes_theo_bounds_and_activitymodels.addAll(modes_theo_bounds_and_activitymodels)
		
		//IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(modes_theo_bounds, IdslGeneratorDesignSpace.DSMvalues(dsi)+" "+activitymodel.name, "PTA Model checking2")


	}
	
	def static public performExperimentPTAModelChecking(MeasurementPTAModelChecking measure, IFileSystemAccess fsa, String extPath, 
										   Scenario scenario, DesignSpaceModel dsm, DesignSpaceModel dsi, List<Service> activities,
										   List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, String urgent, String variableType){
		// in case the granularity has not been entered:
		var int gran 			     		= setvalue(measure.granularity, "PTA_select_image")
		var int num_threads		     		= setvalue(measure.num_threads, "number_of_threads_to_use_for_pta_model_checking")
		var int image_selection_rate 		= setvalue(measure.image_selection_rate, "PTA_select_image") 
		var int num_segments				= setvalue(measure.num_segments, 0) // 0 means original model
		var int ptamodelchecktime_seconds   = setvalue(measure.ptamodelchecktime_seconds, 0) // 0 means no dynamic model checking
		
		// a model will be selected dynamically based on the dynamically determined execution times
		if (ptamodelchecktime_seconds>0) // dynamic model choice
			performExperimentPTAModelChecking_DynamicModel(measure, fsa, extPath, scenario, dsm, dsi, activities, epms, mappings, resources, urgent, variableType)		
		else{ // regular model
			for (ainstance:scenario.ainstance){
				for(path:#[extPath]){
					var activitymodel = ainstance.activity_id.head
					
					var dirPath=								"ExpPTAModelChecking/"
					var modes_theo_bounds_prefix=				path+dirPath+"modes_theo_bounds_"
					var modes_theo_bounds=						modes_theo_bounds_prefix+activitymodel.extprocess_id.name
	
					// All Pmin/Pmax and lb/ub combinations
					var modes_theo_bounds_filename_lb_pmin=			modes_theo_bounds+"-lb-pmin.modest"
					var modes_theo_bounds_filename_ub_pmin=			modes_theo_bounds+"-ub-pmin.modest"		
					var modes_theo_bounds_filename_lb_pmax=			modes_theo_bounds+"-lb-pmax.modest"
					var modes_theo_bounds_filename_ub_pmax=			modes_theo_bounds+"-ub-pmax.modest"		
					
					// select the right model by adjusting the sampling method in the design space		
					var DesignSpaceModel dsi2 
					if (num_segments>0)
						dsi2 = changeSamplingMethodInDSI(dsi, "ecdf"+num_segments)
					else
						dsi2 = dsi // the regular model for 0 segments			
					
					// Create the upperbound and lowerbound, pmax and min Modest files for the current Service
					var boolean generateUb = IdslConfiguration.Lookup_value("PTA_generate_upper_bound_files")=="true" // note: only the lowerbound is needed for generating eCDFs
					fsa.generateFile(modes_theo_bounds_filename_lb_pmin, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi2, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, false, activitymodel.extprocess_id.name, "Pmin", gran, false, true, false)) //lower bound, pmin
					fsa.generateFile(modes_theo_bounds_filename_lb_pmax, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi2, activities, epms, mappings, 
						resources, false, false, false, true, urgent, variableType, false, activitymodel.extprocess_id.name, "Pmax", gran, false, true, false)) //lower bound, pmax
					
					if(generateUb){
						fsa.generateFile(modes_theo_bounds_filename_ub_pmin, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi2, activities, epms, mappings, 
							resources, false, false, false, true, urgent, variableType, true, activitymodel.extprocess_id.name, "Pmin", gran, false, true, false))  //upper bound. pmin
						fsa.generateFile(modes_theo_bounds_filename_ub_pmax, IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, dsi2, activities, epms, mappings, 
							resources, false, false, false, true, urgent, variableType, true, activitymodel.extprocess_id.name, "Pmax", gran, false, true, false))  //upper bound, pmax
					}
					
					// Invoke eCDF computation and write it to graph, DSL and data file
					IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(modes_theo_bounds, IdslGeneratorDesignSpace.DSMvalues(dsi)+" "+activitymodel.name, "PTA Model checking")
				}
			}
		}								   									   	
	}
	
	def static public performExperimentPTAModelChecking_DynamicModel(MeasurementPTAModelChecking measure, IFileSystemAccess fsa, String extPath, 
										   Scenario scenario, DesignSpaceModel dsm, DesignSpaceModel dsi, List<Service> activities,
										   List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, String urgent, 
										   String variableType){
		for (ainstance:scenario.ainstance){
			var int gran 			     		= setvalue(measure.granularity, "PTA_select_image")
			var List<DesignSpaceModel> dsms 	= new ArrayList<DesignSpaceModel>
			var activitymodel 					= ainstance.activity_id.head
			var String model_list				= ""
			
			var dirPath=						"ExpPTAModelChecking/"
			var dirPathSamplingMethod=			dirPath+"SamplingMethod/"

			var modes_theo_bounds_sampling=		extPath+dirPathSamplingMethod+"modes_theo_bounds_"+activitymodel.extprocess_id.name
			
			for (int power2:0..new Integer(IdslConfiguration.Lookup_value("number_of_simplified_models_with_nondeterministic_segments")))
				dsms.add(changeSamplingMethodInDSI(dsi, "ecdf"+Math.pow(2,power2) as int))				
			dsms.add(dsi) // including the original model
			
			for (dsi3:dsms){ // create modest models for each sampling method
				model_list=model_list+"\n"+modes_theo_bounds_sampling+"_"+IdslGeneratorDesignSpace.DSMparamToValue(dsi3,"samplingmethod")+"_lb_pmin.modest"
				model_list=model_list+"\n"+modes_theo_bounds_sampling+"_"+IdslGeneratorDesignSpace.DSMparamToValue(dsi3,"samplingmethod")+"_lb_pmax.modest"
				
				fsa.generateFile(modes_theo_bounds_sampling+"_"+IdslGeneratorDesignSpace.DSMparamToValue(dsi3,"samplingmethod")+"_lb_pmin.modest", 
					IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, 
					dsi3, activities, epms, mappings, resources, false, false, false, true, urgent, variableType, false, 
					activitymodel.extprocess_id.name, "Pmin", gran, false, true, false)) //lower bound, pmin
				fsa.generateFile(modes_theo_bounds_sampling+"_"+IdslGeneratorDesignSpace.DSMparamToValue(dsi3,"samplingmethod")+"_lb_pmax.modest", 
					IdslGeneratorMODESv2.DSEScenarioToModest(1, scenario, dsm, 
					dsi3, activities, epms, mappings, resources, false, false, false, true, urgent, variableType, false, 
					activitymodel.extprocess_id.name, "Pmax", gran, false, true, false)) //lower bound, pmax							
			}
			fsa.generateFile(modes_theo_bounds_sampling+"_list.dat",model_list)	
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(modes_theo_bounds_sampling+"_list.dat", "", "Dynamic PTA Model checking")												   	
    	}
    }
	
	def static DesignSpaceModel changeSamplingMethodInDSI(DesignSpaceModel dsi, String new_sampling_method_value){
		var DesignSpaceModel d = IdslFactoryImpl::init.createDesignSpaceModel
		for(param:dsi.dsparam){
			var DesignSpaceParam p = IdslFactoryImpl::init.createDesignSpaceParam
			p.variable.add(param.variable.head)
			if (param.variable.head=="samplingmethod") // add the new value
				p.value.add(new_sampling_method_value)
			else
				p.value.add(param.value.head)
			d.dsparam.add(p)
		}
		return d
	}

	def static public performExperimentTheoreticalBounds(IFileSystemAccess fsa, String extPath, Scenario scenario, DesignSpaceModel dsm, DesignSpaceModel dsi, List<Service> activities,
										   List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, String urgent, String variableType, boolean oneStopwatchPerInstance){
		for (ainstance:scenario.ainstance){
			var activitymodel = ainstance.activity_id.head
			
			var dirPath=								"ExpTheoreticalBounds/"
			var modes_theo_bounds_prefix=				extPath+dirPath+"modes_theo_bounds_"
			var modes_theo_bounds=						modes_theo_bounds_prefix+activitymodel.extprocess_id.name
			var modes_theo_bounds_filename_lb=			modes_theo_bounds+"-lb.modest"
			var modes_theo_bounds_filename_ub=			modes_theo_bounds+"-ub.modest"		
			var modes_theo_bounds_output_filename_lb=	modes_theo_bounds+"-lb.out"
			var modes_theo_bounds_output_filename_ub=	modes_theo_bounds+"-ub.out"
			System.out.println(dsi.toString)
			
			// Create the upperbound and lowerbound Modest files for the current Service
			fsa.generateFile(modes_theo_bounds_filename_lb, IdslGeneratorMODES.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, resources, false, false, false, true, urgent, variableType, false, activitymodel.extprocess_id.name, oneStopwatchPerInstance, false)) //lower bound
			fsa.generateFile(modes_theo_bounds_filename_ub, IdslGeneratorMODES.DSEScenarioToModest(1, scenario, dsm, dsi, activities, epms, mappings, resources, false, false, false, true, urgent, variableType, true, activitymodel.extprocess_id.name, oneStopwatchPerInstance, false)) //upper bound
			fsa.generateFile(modes_theo_bounds_output_filename_lb,"0") // dummy
			fsa.generateFile(modes_theo_bounds_output_filename_ub,"9999999") // dummy
			
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(modes_theo_bounds, "", "Model checking") // lower and upper bound scheduled
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(modes_theo_bounds, activitymodel.extprocess_id.name, "Measure bounds") // Store measurements
			//value=IdslGeneratorMODESBinarySearch.binarySearch(modes_theo_bounds_filename_ub, 0, 600, false)
			//fsa.generateFile(modes_theo_bounds_output_filename_ub,value.toString) // overwrite
			
			//IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("mctau.exe "+modes_theo_bounds_filename+" > "+modes_theo_bounds_output_filename)
			//IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("gawk.exe -f "+modes_theo_bounds_parser+" "+modes_theo_bounds_output_filename+" > "+modes_theo_bounds_output_filename+"parsed")
			
			//Create a UPPAAL model, for manual evalution
			//IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("mctau.exe -M "+modes_theo_bounds_filename_lb+" -O "+modes_theo_bounds_upppaal_lb+" -P "+ modes_theo_bounds_upppaal_lb_props, "", "Create UPPAAL model")
			//IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("mctau.exe -M "+modes_theo_bounds_filename_ub+" -O "+modes_theo_bounds_upppaal_ub+" -P "+ modes_theo_bounds_upppaal_ub_props, "", "Create UPPAAL model")
			//fsa.generateFile(modes_theo_bounds+"_uppaal.bat","uppaal.jar "+modes_theo_bounds+".xml")
		}
	}
	
	def static public void performExperimentSimulation(int num_runs, int num_activityis, IFileSystemAccess fsa, String extPath, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi, 
									List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, String urgent, 
									String variableType, List<StopwatchDistribution> sd){  //boolean oneStopwatchPerInstance){
		if(ext_processes_contains_load_balancer(epms)) // different analysis is performed (e.g. energy consumption) when a load balancer is present
			IdslGeneratorPerformExperimentSimulationLoadBalancer.
				performExperimentSimulation_loadbalancing(num_runs, num_activityis, fsa, extPath, s, dsm, dsi, activities, 
												  epms, mappings, resources, urgent, variableType, sd)
		else
				performExperimentSimulation_regular(num_runs, num_activityis, fsa, extPath, s, dsm, dsi, activities, 
												epms, mappings, resources, urgent, variableType, sd)								
	}					

	def static public void performExperimentSimulation_regular(int num_runs, int num_activityis, IFileSystemAccess fsa, 
									String extPath, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi, 
									List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, 
									List<ResourceModel> resources, String urgent, 
									String variableType, List<StopwatchDistribution> sd){		
		var Pair<Boolean,Boolean> ospi_ogsfi = IdslGeneratorPerformExperimentSimulationLoadBalancer.ret_oneStopwatchPerInstance_OneGlobalStopwatchForInstances(sd)
		if (ospi_ogsfi.value==true) // OneGlobalStopwatchForInstances
			throw new Throwable("performExperimentSimulation_regular: OneGlobalStopwatchForInstances not supported!")
		if (ospi_ogsfi.key==true) // OneStopwatchPerInstance
			throw new Throwable("performExperimentSimulation_regular: OneStopwatchPerInstance not supported!")

		var dirPath= 							"ExpSimulation_"+num_runs.toString+"_"+num_activityis.toString+"/"
		var modes_sim_latency_filename=			extPath+dirPath+"modes_sim_latency.modest"
		
		//var firstSimulationMeasure=				IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.length==0 // only each first run of the first simulation measure is used for CDFs with design alternatives  				
		var List<String> filenames_cdf_runs=	 new ArrayList<String> // the filename templates of CDFS to plot per ServiceRequest
		
		// one "global" modest and AWK file for all experiment runs
		fsa.generateFile(modes_sim_latency_filename, IdslGeneratorMODES.DSEScenarioToModest(num_activityis, s, dsm, dsi, activities, epms, mappings, resources, 
																							true, true, false, false, urgent, variableType, ospi_ogsfi.key))
		
		for(run_nr:(1..num_runs)){
			var modes_sim_latency_output_filename=	extPath+dirPath+"run_"+run_nr.toString+"/modes_sim_latency.output"		
		
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(	IdslConfiguration.Lookup_value("modes_path")+
																					"modes.exe "+
																					IdslConfiguration.Lookup_value("modes_parameters")+" "+
																					modes_sim_latency_filename, modes_sim_latency_output_filename, "MODES simulation"
			)
			
			for (ainstance:s.ainstance){
				var activitymodel = ainstance.activity_id.head
				var extprocess =  activitymodel.extprocess_id
				var mapping = activitymodel.mapping
				var process_mapping_filename=extPath+dirPath+"run_"+run_nr.toString+"/ProcessMapping_"+activitymodel.extprocess_id.name
				var index = s.ainstance.indexOf(ainstance) // for sorting purposes

				filenames_cdf_runs.add((index+10000).toString+process_mapping_filename+"-cdf.out")
				if (run_nr==1 /* && firstSimulationMeasure */) { IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.add((index+10000).toString+process_mapping_filename+"-cdf.out") }
				
				fsa.generateFile(process_mapping_filename+".gvt", IdslGeneratorGraphViz.ExtProcessMappingToGraph("Latency breakdown of ProcessMapping_"+activitymodel.extprocess_id.name, extprocess, mapping.head, true, dsm, dsi))
				fsa.generateFile(process_mapping_filename+"-gviz.awk", IdslGeneratorGAWK.create_gawk_aggregated_util_and_latency_in_graphviz(process_mapping_filename.replace("/","\\\\")+".gvt"))
				fsa.generateFile(process_mapping_filename+"-latencies.awk", IdslGeneratorGAWK.create_gawk_latency_in_gnuplot)
				fsa.generateFile(process_mapping_filename+".gnuplot", IdslGeneratorGNUplot.create_gnuplot_bar_graph("Latencies of ProcessMapping_"+activitymodel.extprocess_id.name, process_mapping_filename+"-latencies.out", process_mapping_filename+"-latencies."+IdslConfiguration.Lookup_value("Output_format_graphics")))
				fsa.generateFile(process_mapping_filename+"-cdf.gnuplot", IdslGeneratorGNUplot.create_gnu_plot_cdf("CDF of ProcessMapping_"+activitymodel.extprocess_id.name, process_mapping_filename+"-cdf.out", process_mapping_filename+"-cdf."+IdslConfiguration.Lookup_value("Output_format_graphics")))
				fsa.generateFile(process_mapping_filename+"-cdf.awk", IdslGeneratorGAWK.latency_to_cdf)
				
				// create the script to fill in the placeholders in the GraphViz graph with average latencies, execute it and plot the Graph with latency values
				if (IdslConfiguration.Lookup_value("evaluate_performanceGraphs")=="true"){
					IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe -f "+process_mapping_filename+"-gviz.awk "+modes_sim_latency_output_filename, process_mapping_filename+"-gviz.bat", "GraphViz performance")  
					IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(process_mapping_filename+"-gviz.bat", "", "GraphViz performance")
					IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"dot.exe "+process_mapping_filename+".gvt -T"+IdslConfiguration.Lookup_value("Output_format_graphics")+" -O"+process_mapping_filename+"."+IdslConfiguration.Lookup_value("Output_format_graphics"), "", "GraphViz performance")
				}
				
				// generate a summary of the modest output
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe -f "+process_mapping_filename+"-latencies.awk "+modes_sim_latency_output_filename, process_mapping_filename+"-all.out", "Modest summary")
				
				// derive the latencies values and plot a bar chart using gnuplot
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(do_not_find_commands("timeout_counter","utilization",activitymodel.extprocess_id.name)+process_mapping_filename+"-all.out", process_mapping_filename+"-latencies.out", "GNUplot bar chart")
				//OLD: IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(find_command("property_pm")+process_mapping_filename+"-all.out", process_mapping_filename+"-latencies.out", "GNUplot bar chart")
				//OLD: IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe -f "+process_mapping_filename+"-latencies.awk "+modes_sim_latency_output_filename+" | find \"property_"+activitymodel.extprocess_id.name+"\" ", process_mapping_filename+"-latencies.out", "GNUplot bar chart")
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gnuplot_path")+"gnuplot.exe "+process_mapping_filename+".gnuplot", "", "GNUplot bar chart")
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(process_mapping_filename+"-latencies.out",run_nr.toString+" "+activitymodel.extprocess_id.name,"Measure latencies") // Store measurements
				
				// derive the utilization values, to be used for design instance utilizations
				//OLD: IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe -f "+process_mapping_filename+"-latencies.awk "+modes_sim_latency_output_filename+" | find \"property_utilization_\"", extPath+dirPath+"run_"+run_nr.toString+"/utilizations.out", "Output utilizations")				
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(find_command("property_utilization_")+process_mapping_filename+"-all.out", extPath+dirPath+"run_"+run_nr.toString+"/utilizations.out", "Output utilizations")
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(extPath+dirPath+"run_"+run_nr.toString+"/utilizations.out",run_nr.toString+" "+activitymodel.extprocess_id.name,"Measure utilizations") // Store measurements

				// derive the timeout values, to be used for design instance utilizations
				//OLD: IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe -f "+process_mapping_filename+"-latencies.awk "+modes_sim_latency_output_filename+" | find \"_timeout_counter_\"", extPath+dirPath+"run_"+run_nr.toString+"/timeouts.out", "Output timeouts")				
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(find_command("_timeout_counter_")+process_mapping_filename+"-all.out", extPath+dirPath+"run_"+run_nr.toString+"/timeouts.out", "Output timeouts")
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(extPath+dirPath+"run_"+run_nr.toString+"/timeouts.out",run_nr.toString+" "+activitymodel.extprocess_id.name,"Measure timeouts") // Store measurements
			
				// derive the CDF values from the latencies values and plot a CDF graph from it
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe \"{print $3}\" "+process_mapping_filename+"-latencies.out", process_mapping_filename+"-latencies_column3.out", "Third column of latencies to create a CDF")
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe -f "+process_mapping_filename+"-cdf.awk "+process_mapping_filename+"-latencies_column3.out", process_mapping_filename+"-cdf.out", "GNUplot CDF graph")
				IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gnuplot_path")+"gnuplot "+process_mapping_filename+"-cdf.gnuplot", "", "GNUplot CDF graph")
			}		
		}
		
		// compute averages and confidence intervals over the runs
		for (ainstance:s.ainstance){
			var List<String> latency_filenames = new ArrayList<String>
			for(run_nr:(1..num_runs)){
				var activitymodel = ainstance.activity_id.head
				var process_mapping_filename=extPath+dirPath+"run_"+run_nr.toString+"/ProcessMapping_"+activitymodel.extprocess_id.name
				latency_filenames.add(process_mapping_filename+"-latencies.out")
			}
			//var String latency_filenames_concat=concatenate(latency_filenames) // DEBUG
			//System.out.println("XXX"+latency_filenames_concat) // DEBUG
			//compute_confidence_intervals(latency_filenames)
			//TODO: implement confidence intervals
		}
		
		// create the simulation global visualizations
		Collections.sort(filenames_cdf_runs)
		for(cnt:(0..filenames_cdf_runs.length-1))
			filenames_cdf_runs.set(cnt,filenames_cdf_runs.get(cnt).substring(5)) // remove the prefixed indices

		for(cnt:(0..s.ainstance.length-1)) {
			var activitymodel = s.ainstance.get(cnt).activity_id.head
			var process_mapping_filename=extPath+dirPath+"ProcessMapping_"+activitymodel.extprocess_id.name
			var datalegends = new ArrayList<String> // legends to show in the CDF graph
			for (cnt2:(0..num_runs)) { datalegends.add("run "+cnt2.toString) }
			fsa.generateFile(process_mapping_filename+"-cdf.gnuplot", IdslGeneratorGNUplot.create_gnu_plot_cdf("CDF of ProcessMapping_"+activitymodel.extprocess_id.name, filenames_cdf_runs.subList(cnt*num_runs,cnt*num_runs+(num_runs)), datalegends, process_mapping_filename+"-cdf."+IdslConfiguration.Lookup_value("Output_format_graphics")))
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("gnuplot "+process_mapping_filename+"-cdf.gnuplot", "","GNUplot combined CDF graph")
		}
	}
	
	def static List<Pair<String,String>> compute_confidence_intervals (List<String> files){
		var List<String> conf_int = new ArrayList<String>
		var List<List<String>> vals = files.map[x | file_to_list(x)]
		for(valnr:0..vals.get(0).length-1){
			var double sum=0
			var int    cnt=0
			for(runnr:0..vals.length-1){
				var value=vals.get(runnr).get(valnr).split(" ").get(2)
				sum = sum + new Double(value)
				cnt = cnt + 1
			}
			conf_int.add((sum/cnt).toString)
		}
		System.out.println(concatenate(conf_int))

		return null
	}
	
	def static List<String> file_to_list (String filename) {
		return Files.readAllLines(new File(filename).toPath, Charset.defaultCharset )
	}
	
	def static public performExperimentThroughput(int num_activityis, IFileSystemAccess fsa, String extPath, Scenario s, DesignSpaceModel dsm, DesignSpaceModel dsi,
						List<Service> activities, List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, String urgent, String variableType, boolean oneStopwatchPerInstance)
	{
		if(true)
			throw new Throwable("PerformExperimentThroughput has not been updated for a while and needs double checking")
		
		var dirPath=									"ExpThroughput_"+num_activityis.toString+"/"
		var modes_sim_throughput_filename=				extPath+dirPath+"modes_sim_throughput.modest"
		var modes_sim_throughput_output_filename=		extPath+dirPath+"modes_sim_throughput.out"
		
		fsa.generateFile(modes_sim_throughput_filename, IdslGeneratorMODES.DSEScenarioToModest(num_activityis, s, dsm, dsi, activities, epms, mappings, resources, false, false, true, false,  urgent, variableType, oneStopwatchPerInstance))
		
		IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("modes.exe -R Uniform -S ASAP --max-run-length 50000 -N 1 "+modes_sim_throughput_filename, modes_sim_throughput_output_filename, "MODES throughput")
		
		var List<String> activity_names= new ArrayList();
		
		for (ainstance:s.ainstance){
			var activitymodel = ainstance.activity_id.head

			activity_names.add(activitymodel.extprocess_id.name)							
			fsa.generateFile(extPath+dirPath+activitymodel.extprocess_id.name+".awk", IdslGeneratorGAWK.create_gawk_throughput_in_graphviz(activitymodel.extprocess_id.name))
			
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe -f "+extPath+dirPath+activitymodel.extprocess_id.name+".awk "+modes_sim_throughput_output_filename+" | find \"property_throughput_\"", extPath+dirPath+activitymodel.extprocess_id.name+".out", "GAWK throughput")
		}
		fsa.generateFile(extPath+dirPath+"throughput.gnuplot", IdslGeneratorGNUplot.create_gnu_plot_point_throughput("Throughput per activity", extPath+dirPath, activity_names, "throughput."+IdslConfiguration.Lookup_value("Output_format_graphics")))
		IdslGeneratorGlobalVariables.global_contents_of_main_batch_file_add("gnuplot.exe "+extPath+dirPath+"throughput.gnuplot")
	}
	
	def static String find_command (String search_string){ // used as an alternative to find, since it does not print the filename of the file being searched
		return IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe \"{if(index($0,\\\""+search_string+"\\\")>0)print $0}\" "
	}
	
	def static String do_not_find_commands (String search_string1, String search_string2, String filter){
		return IdslConfiguration.Lookup_value("gawk_path")+"gawk.exe \"{if(index($0,\\\""+search_string1+"\\\")==0&&(index($0,\\\""+search_string2+"\\\")==0&&index($1,\\\""+filter+"\\\")>0))print $0}\" "
	}
	
	def static String concatenate (List<String> elems)'''«FOR elem:elems»«elem» «ENDFOR»'''
}
