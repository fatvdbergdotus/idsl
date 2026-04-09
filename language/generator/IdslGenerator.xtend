package org.idsl.language.generator

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import java.io.PrintStream
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.ArrayList
import java.util.Collections
import java.util.Date
import java.util.List
import java.util.Random
import java.util.Set
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator
import org.idsl.language.idsl.Config
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.Measurement
import org.idsl.language.idsl.MeasurementPTAModelChecking
import org.idsl.language.idsl.MeasurementResults
import org.idsl.language.idsl.MeasurementSearchBruteForce
import org.idsl.language.idsl.MeasurementSearches
import org.idsl.language.idsl.MeasurementSimulation
import org.idsl.language.idsl.MeasurementTheoBounds
import org.idsl.language.idsl.MeasurementThroughput
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.Scenario
import org.idsl.language.idsl.Service
import org.idsl.language.idsl.ServiceRequest
import org.idsl.language.idsl.Study
import org.idsl.language.idsl.SubStudy
import org.idsl.language.idsl.Utility
import org.idsl.language.idsl.ValidityResults

import static extension org.idsl.language.generator.IdslConfiguration.*
import static extension org.idsl.language.generator.IdslGeneratorDesignSpaceMeasurements.*
import static extension org.idsl.language.generator.IdslGeneratorGlobalVariables.*
import org.idsl.language.idsl.MultiplyResults
import java.io.PrintWriter
import org.idsl.language.idsl.MeasurementSimulationINT
import org.idsl.language.idsl.MeasurementPTAModelChecking2
import org.idsl.language.idsl.AtomicProcessModel
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.DesAltProcessModel
import org.idsl.language.idsl.MutexProcessModel

class IdslGenerator implements IGenerator {	

	
	//           subst Y: "C:\Users\Freek\syncmaster\Google Drive\philipsDesktop\eclipse\workspaces\i-dslWorkSpace\runtime-EclipseXtext\iDSL-instance\src-gen"
	// OUTDATED: subst Y: "C:\Users\Freek\syncmaster\Google Drive\philipsDesktop\eclipse\workspaces\i-dslWorkSpace\runtime-EclipseXtext\org.idsl.specification\src-gen"
	// OUTDATED: subst Y: "C:\Users\Freek\syncmaster\Google Drive\philipsDesktop\eclipse\workspaces\runtime-EclipseXtext\freek\src-gen"
	
	//def static void main(String[] args) {
	//}	
	val String    path_begin = IdslConfiguration.Lookup_value("path_begin")			// the prefix of the path in which all files are written
	
	override public void doGenerate(Resource resource, IFileSystemAccess fsa){
		var DateFormat dateFormat = new SimpleDateFormat("yyyy/MM/dd HH:mm:ss")

		ClearScreen(30) // clear the screen
		IdslConfiguration.DSL_configuration = resource.allContents.toIterable.filter(typeof(Config)).head 
		
		//setup_system_out_outputfile(resource)
		
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("START doGenerate "+ resource.URI.lastSegment +"_"+IdslConfiguration.Lookup_value("postfix_target_directory")+dateFormat.format(new Date()))
		if (IdslConfiguration.Lookup_value("execute_this")=="false") {
			System.out.println("Execution of iDSL instance ("+resource.URI.lastSegment+") prevented due to negative \"execute_this\" parameter in the Section Configuration")
		} else {
			System.out.println("Execution of iDSL instance ("+resource.URI.lastSegment+") started...")
			doGenerate_proceed(resource, new fsa2, resource.URI.lastSegment) // Execute the evaluation of the iDSL instance
			//doGenerate_proceed(resource, new fsa2 /*  manual implementation of fsa that does not delete files */,resource.URI.lastSegment) // Execute the evaluation of the iDSL instance
			System.out.println("Execution of iDSL instance ("+resource.URI.lastSegment+") finished...")
		}
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("STOP doGenerate "+resource.URI.lastSegment)
	}  
	
	def setup_system_out_outputfile(Resource resource){
		// write all system.out.prtins also to a logfile
		var log_file = path_begin + resource.getURI().lastSegment + path_postfix() + "/log_files/logfile_"+System.nanoTime
		var File file = new File(log_file)
		var FileOutputStream fis = new FileOutputStream(file)
		var PrintStream out = new PrintStream(fis)
		System.setOut(out)
	}
	
	def static path_postfix(){
		var path_postfix = IdslConfiguration.Lookup_value("postfix_target_directory")
		if(path_postfix.length>0) // actual contents, add an underscore _
			return "_"+path_postfix
		else
			return path_postfix
	}
	
	def static determine_default_sampling_method (List<Measurement> measurements){
		for(measurement:measurements)
			switch(measurement){
				MeasurementPTAModelChecking: { 
					if(measurement.num_segments.empty)
						return "regular"
					if(measurement.num_segments.head>0)
						return "ecdf"+measurement.num_segments.head.toString
			}}
		return "regular"
	}
	
	def public doGenerate_proceed(Resource resource, IFileSystemAccess fsa, String model_name){	
		// Extend the DesignSpaceModel optionally
		var dsm = resource.allContents.toIterable.filter(typeof(DesignSpaceModel)).head // currently first one DesignSpaceModel, others DesignSpaceInstanceS
		var path = path_begin + resource.getURI().lastSegment + path_postfix() + "/"  
		var searches =resource.allContents.toIterable.filter(typeof(MeasurementSearches)).toList
		var scenarios = resource.allContents.toIterable.filter(typeof(Scenario)).toList
		var studies = resource.allContents.toIterable.filter(typeof(Study)).toList
		var extprocesses = resource.allContents.toIterable.filter(typeof(ExtendedProcessModel)).toList
		var resourcemodels = resource.allContents.toIterable.filter(typeof(ResourceModel)).toList
		var mappings = resource.allContents.toIterable.filter(typeof(Mapping)).toList	
		var experiments = resource.allContents.toIterable.filter(typeof(Measurement)).toList // Experiments are global
		service_list = resource.allContents.toIterable.filter(typeof(Service)).toList
		var mresults = resource.allContents.toIterable.filter(typeof(MeasurementResults)).head
		var multresults = resource.allContents.toIterable.filter(typeof(MultiplyResults)).head // multiplies results after a computation to compensate for 

		if(IdslConfiguration.Lookup_value("enable_dsi_sampling_method")=="true"){ // create an extra DesignSpaceModel param
			//var String samplingmethod_value = determine_default_sampling_method(experiments) // when there is a measurement relying on a different model, set it as default
			//IdslGeneratorSyntacticSugar.AddSamplingMethodToDesignSpaceModel(dsm, samplingmethod_value) //"regular"
			IdslGeneratorSyntacticSugar.AddSamplingMethodToDesignSpaceModel(dsm, null, true /* add a constraint for one value */)
		}
		
		if(IdslConfiguration.Lookup_value("enable_model_time_unit")=="true"){ // create an extra DesignSpaceModel param
			IdslGeneratorSyntacticSugar.AddModelTimeUnitToDesignSpaceModelAndMultiplyValues(dsm, multresults, true /* add a constraint for one value */)	
		}
		
		IdslGeneratorGlobalVariables.ptamodelchecking2 = measurements_contain_PTAmodelchecking2(experiments)!=null
		
		if(IdslGeneratorGlobalVariables.ptamodelchecking2){ // Add two dimensions to the design dspace in case of model checking 2.0
			var meas=measurements_contain_PTAmodelchecking2(experiments)
			if(!meas.segment_num_steps.empty)
				IdslGeneratorSyntacticSugar.AddSamplingMethodToDesignSpaceModel(dsm, null, true, new Integer(meas.segment_num_steps.head))
			else
				IdslGeneratorSyntacticSugar.AddSamplingMethodToDesignSpaceModel(dsm, null, true /* add a constraint for one value */)
			
			if(!meas.model_time_unit_num_steps.empty)
				IdslGeneratorSyntacticSugar.AddModelTimeUnitToDesignSpaceModelAndMultiplyValues(dsm, multresults, true, new Integer(meas.model_time_unit_num_steps.head))
			else
				IdslGeneratorSyntacticSugar.AddModelTimeUnitToDesignSpaceModelAndMultiplyValues(dsm, multresults, true /* add a constraint for one value */)
		} 
		
		IdslConfiguration.set_filesystem(fsa)
		
		// Ensures that the essential variables are accessible from IdslGeneratorGUI
		IdslGeneratorGUI.set_resource(resource)
		IdslGeneratorGUI.set_filesystem(fsa)
		IdslGeneratorGUI.set_measurements_results(mresults)
		IdslGeneratorGUI.set_path(path)

		//	for(param:dsm.dsparam) // DEBUG: to view the Design Space Variables and number of options
		//		System.out.println(param.variable.head+" "+param.value.length)
		IdslGeneratorDesignSpaceMeasurements.measurementResults = mresults
		IdslGeneratorDesignSpaceMeasurements.multiplyResults = multresults
		IdslConfiguration.DSL_configuration = resource.allContents.toIterable.filter(typeof(Config)).head 
		IdslGeneratorConsole.set_filesystem(fsa)
		IdslGeneratorGUI.set_filesystem(fsa)
		IdslGeneratorGUI.set_measurements_results(mresults)
		IdslConfiguration.writeTimeToTimestampFile_change_DSI_path(path) // here are the timestamps stored
		IdslConfiguration.writeTimeStamp_aggregation_script_and_batch(path, fsa) // aggregation script for timestamps
		
		iDSLinstanceToDisc("original", resource, fsa, path)
		
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("START syntactic_sugar")	
		IdslGeneratorSyntacticSugar.ApplySyntacticSugar(dsm, experiments, searches, extprocesses, resourcemodels, mappings, resource, scenarios, mresults)
		iDSLinstanceToDisc("syntacticsugar")
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("STOP syntactic_sugar")
		
		IdslGeneratorGlobalVariables.global_contents_of_main_batch_file_reset
		IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_reset
			
		// Process all studies
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("START main_processing")
		for (study:studies) // we currently assume only one study
			StudyGenerate(fsa, path/* +"SDY_"+study.name.head.toString*/, study, dsm, scenarios, service_list, extprocesses, mappings, 
						  resourcemodels, experiments, searches.head
			)
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("STOP main_processing")
		
		// Create a global execution batch file
		if(IdslConfiguration.Lookup_value("Create_gobat_and_goallbat")=="true"){
			fsa.deleteFile(path+"go-all.bat")
			fsa.generateFile(path+"go-all.bat",IdslGeneratorGlobalVariables.global_contents_of_main_batch_file)
		}

		// generate folder "validities" in advance
		fsa.generateFile(path+"validities/x",''''''); fsa.deleteFile(path+"validities/x")
		
		//IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("", "", "Post processing") // enable post-processing to be performed later
		
		// Start the GUI
		var evaluationGUI=new IdslGeneratorGUI
		for (study:studies) 
			for (substudy:study.substudy) 
				for (dsi:substudy.dspacem)
						evaluationGUI.addDesignInstance(IdslGeneratorDesignSpace.DSMvalues(dsi))
		evaluationGUI.start(model_name)
	}
	
	def static public doGenerate_postprocessing(IFileSystemAccess fsa, String path, Resource resource){
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("START post_processing")
		
		var MeasurementResults mresults      = resource.allContents.toIterable.filter(typeof(MeasurementResults)).head
		var ValidityResults validityResults  = resource.allContents.toIterable.filter(typeof(ValidityResults)).head
		var List<Utility> utilities          = mresults.utils
		
		// Post-processing: Compute Kolmogorovs and execution distances
		System.out.println("Computing kolmogorevs and execution distances")
		IdslGeneratorModelValidation.Compute_kolmogorevs_and_execution_distances(validityResults, mresults, path) // graphs are printed here as well
		
		IdslGeneratorPostProcessing.DSL_utilities_to_files(fsa, path, utilities)
		IdslGeneratorPostProcessing.DSL_utility_requirements_to_file(fsa, path, utilities)
		IdslGeneratorPostProcessing.DSL_validations_to_files(fsa, path, validityResults.validity_res)		
		
		IdslGeneratorPostProcessing.Create_tradeoff_graphs_for_each_pair_of_utilities(fsa, path, utilities)
		
		iDSLinstanceToDisc("validation")
		System.out.println("done")	
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("STOP post_processing")	
	}
	
	var static private Resource iDSLinstanceToDisc_resource
	var static private IFileSystemAccess iDSLinstanceToDisc_fsa
	var static private String iDSLinstanceToDisc_path
	var static private List<Service> service_list
	var static public  random = new Random
	
	def static ClearScreen(int numlines){ // Outputs "..." empty lines. Used to emulate a "Clear Screen"
		for(cnt:1..numlines)
			System.out.println("")
	}
	
	def static public ServiceToProcess(String service){
		for(s:service_list)
			if(service==s.name)
				return s.extprocess_id.name
		throw new Throwable("Service "+service+" not found in ServiceToProcess")
	}
	
	def static public void iDSLinstanceToDisc(String filenameExtension){
		if (IdslConfiguration.Lookup_value("write_DSL_instances_to_disk")=="true"){
			var OutputStream os = new ByteArrayOutputStream
			iDSLinstanceToDisc_resource.save(os, null)
			IdslGeneratorGlobalVariables.global_DSL_text=os.toString
			iDSLinstanceToDisc_fsa.generateFile(iDSLinstanceToDisc_path+"/DSL_instance/"+iDSLinstanceToDisc_resource.getURI().lastSegment+"-"+filenameExtension+".idsl-gen",
												os.toString)			
		}
	}
	
	def static void iDSLinstanceToDisc(String filenameExtension, Resource resource, IFileSystemAccess fsa, String path){
		if (IdslConfiguration.Lookup_value("write_DSL_instances_to_disk")=="true"){
			iDSLinstanceToDisc_resource=resource
			iDSLinstanceToDisc_fsa=fsa
			iDSLinstanceToDisc_path=path
			iDSLinstanceToDisc(filenameExtension)
		}
	}	
	
	def static boolean allTrue(List<Boolean> bools){ // boolean ALL quantor
		for(bool:bools)
			if(!bool)
				return false
		return true
	}
	
	def computeAggregatedMeasures(MeasurementSearches search, DesignSpaceModel dsm){ 
		// the search methods has to be brute force and no constraints are allowed, to ensure that all instances are computed for aggregated arftifacts.
		var boolean brute_force=false
		switch (search.ms.head){ MeasurementSearchBruteForce: brute_force=true }//false otherwise
		
		val boolean has_constraints  			 = !dsm.constraint.empty
		val boolean compute_aggregate_measures   = brute_force && !has_constraints
		System.out.println("brute_force:"+brute_force+", has_constraints:"+has_constraints+", compute_measures:"+compute_aggregate_measures)
		if(!compute_aggregate_measures)
			System.out.println("Warning: aggregated measures are not computed!")
		return compute_aggregate_measures
	}
	
	def booleanListToText(List<Boolean> bools)'''«FOR bool:bools»«IF bool»1«ELSE»0«ENDIF»,«ENDFOR»'''	
	
	def static MeasurementPTAModelChecking2 measurements_contain_PTAmodelchecking2 (List<Measurement> measurements){
		for(measurement:measurements)
			switch(measurement){ MeasurementPTAModelChecking2: return measurement }
		return null
	}
		
	def StudyGenerate (IFileSystemAccess fsa, String path, Study study, DesignSpaceModel dsm, List<Scenario> scenarios, List<Service> activities, 
					   List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, 
					   List<Measurement> measurements, MeasurementSearches search){			
		for (substudy:study.substudy) {
			// Reset the list of commands to perform
			IdslGeneratorGlobalVariables.global_contents_of_main_batch_file_reset
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_reset
			
			if(IdslConfiguration.Lookup_value("negative_exponential_distribution_arrivals_use_math")=="yes")
				System.out.println("Warning: negative_exponential_distribution_arrivals_use_math==yes")
			
			System.out.println("Creating design instances")
			IdslGeneratorDesignSpace.turnDesignSpaceModelsIntoInstances (substudy, dsm)
			System.out.println("Creating design instances... done")
			
			IdslGeneratorGlobalVariables.global_filenames_cdf_dsis = new ArrayList<String> // to store the CDF filenames of different design alternatives
			
			var dsi_constraint_contents = "" // to store the outcomes of the constraints on the DSM
			for (dsi:substudy.dspacem){  // Create artefacts that are independent of experiments, per DesignSpaceInstance that meets the constraints
				val dsi_constraint_content = PotentialDSIelementGenerate(fsa, path, substudy, scenarios, activities, epms,  mappings, resources,  measurements, dsm, dsi)
				dsi_constraint_contents = dsi_constraint_contents + dsi_constraint_content	
			}
			fsa.generateFile(path+"lop_and_loi.dat",IdslGeneratorGlobalVariables.lop_and_loi_file_contents)
			IdslGeneratorGlobalVariables.lop_and_loi_file_contents=""
			fsa.generateFile(path+"dsi_constraints.dat",dsi_constraint_contents)  // log about the outcomes of the constraints per DSI
			
			// AGGREGATE MEASURE: create CDFs with multiple design alternatives
			if(computeAggregatedMeasures(search,dsm)){ // are aggragates measures possible? 
				Collections.sort(IdslGeneratorGlobalVariables.global_filenames_cdf_dsis)
				if(IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.length>0){			
					for(cnt:(0..IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.length-1)) // remove the prefixed indices 
						IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.set(cnt,IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.get(cnt).substring(5))
				}
			}
			var scenario = scenarios.head // filterScenario(scenarios,substudy.scenario_id.head)
			val num_servreqs = scenario.ainstance.length
			val dsis = IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.length / num_servreqs
			
			if (IdslConfiguration.Lookup_value("Debug_mode")=="true") // Perform in debug mode
				System.out.println(num_servreqs+"\n"+IdslGeneratorGlobalVariables.global_filenames_cdf_dsis)				
			
			// AGGREGATE MEASURE
			// WARNING: Technically the code below should be executed when there is a simulation only. However, the code does not cause harm otherwise.
			if(computeAggregatedMeasures(search,dsm)){ // are aggragates measures possible? 
				for (cnt:(0..num_servreqs-1)){
					var activitymodel = scenario.ainstance.get(cnt).activity_id.head
					var extPath = path + "_SCN_" + substudy.scenario_id.head + "_aggregated/"
					var process_mapping_filename= extPath+"ProcessMapping_"+activitymodel.extprocess_id.name
					var datalegends = new ArrayList<String> // legends to show in the CDF graph
					
					for (ainstance:scenario.ainstance)
						IdslGeneratorGraphViz.createNonPerformanceGraphs(fsa, ainstance, extPath, dsm, null)
					
					for (cnt2:(0..IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.length)) 
						datalegends.add("alternative "+cnt2.toString)
								
					fsa.generateFile(process_mapping_filename+"-cdf.gnuplot", 
									 IdslGeneratorGNUplot.create_gnu_plot_cdf("CDF of ProcessMapping_"+activitymodel.extprocess_id.name, 
																			  IdslGeneratorGlobalVariables.global_filenames_cdf_dsis.subList(cnt*dsis,cnt*dsis+(dsis)), 
																			  datalegends, 
																			  process_mapping_filename+"-cdf."+IdslConfiguration.Lookup_value("Output_format_graphics")))
					IdslGeneratorGlobalVariables.global_contents_of_main_batch_file_add("gnuplot "+process_mapping_filename+"-cdf.gnuplot")
					IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("gnuplot "+process_mapping_filename+"-cdf.gnuplot","","All design instances")
				}
			}
					
		}
	} 
	
	def String PotentialDSIelementGenerate(IFileSystemAccess fsa, String path, SubStudy substudy, List<Scenario> scenarios, List<Service> services, 
					   List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, List<Measurement> measurements, 
					   DesignSpaceModel dsm, DesignSpaceModel dsi){ // a DSI that might have to be genereated (constraint dependent
		
		val List<Boolean> dsi_meets_constraints = IdslGeneratorDesignSpace.DSImeetsConstraints(dsi, dsm.constraint) // does DSI satisfy all constraints?
		val boolean alltrue = allTrue(dsi_meets_constraints)
		dsi_meets_constraints.add(alltrue)
								
		// NOT NEEDED ANYMORE: SELECTION HAPPENS EARLIER //if(alltrue && IdslConfiguration.Lookup_value("Design_space_display_constraints_information_only")=="false")		
		DSIelementGenerate(fsa, path, substudy, scenarios, services, epms,  mappings, resources,  measurements, dsm, dsi)
		
		return IdslGeneratorDesignSpace.DSMvalues(dsi)+" "+booleanListToText(dsi_meets_constraints)+"\n"
	}
	
	def DSIelementGenerate(IFileSystemAccess fsa, String path, SubStudy substudy, List<Scenario> scenarios, List<Service> services, 
					   List<ExtendedProcessModel> epms, List<Mapping> mappings, List<ResourceModel> resources, List<Measurement> measurements, 
					   DesignSpaceModel dsm, DesignSpaceModel dsi){
		var extPath = path + "_SCN_" + substudy.scenario_id.head + "_DSE_" + IdslGeneratorDesignSpace.DSMvalues(dsi) + "/"
	    var scenario = scenarios.head //filterScenario(scenarios,substudy.scenario_id.head) // WARNING: this eliminates support for multipe scenarios
		
		//System.out.println("Evaluating design instance "+IdslGeneratorDesignSpace.DSMvalues(dsi))
		
		IdslGeneratorGlobalVariables.global_dsm_values = IdslGeneratorDesignSpace.DSMvalues(dsi)

		// Create performance independent artefacts per service request
		if(IdslConfiguration.Lookup_value("Create_performance_independent_artefacts_per_service_request")=="true")
			for (ainstance:scenario.ainstance)
				IdslGeneratorGraphViz.createNonPerformanceGraphs(fsa, ainstance, extPath, dsm, dsi) 
		
		fsa.generateFile(extPath+IdslConfiguration.Lookup_value("bestcase_filename"), IdslGeneratorBestCase.computeStr(epms, services, dsi))
		
		if(IdslGeneratorGlobalVariables.ptamodelchecking2)  // a redundant bestcase
			fsa.generateFile(extPath+"ExpPTAModelChecking2/"+IdslConfiguration.Lookup_value("bestcase_filename"), IdslGeneratorBestCase.computeStr(epms, services, dsi))
		
		for (measure:measurements){
			switch(measure){	// boolean stopwatchEnabled, boolean utilizationEnabled, boolean throughputCalcEnabled
			    MeasurementSimulationINT:       IdslGeneratorPerformExperiment.performExperimentSimulation(measure.num_runs, measure.num_activityis, fsa, extPath, scenario, dsm, dsi, services, epms, mappings, resources, "", "int", measure.stopwatch_distribution)
				MeasurementSimulation: 			IdslGeneratorPerformExperiment.performExperimentSimulation(measure.num_runs, measure.num_activityis, fsa, extPath, scenario, dsm, dsi, services, epms, mappings, resources, "", "real", measure.stopwatch_distribution)
				MeasurementThroughput:	 		IdslGeneratorPerformExperiment.performExperimentThroughput(measure.num_activityis, fsa, extPath, scenario, dsm, dsi, services, epms, mappings, resources, "", "real", false)
				MeasurementTheoBounds: 			IdslGeneratorPerformExperiment.performExperimentTheoreticalBounds(fsa, extPath, scenario, dsm, dsi, services, epms, mappings, resources, "urgent", "int", false)	
				MeasurementPTAModelChecking:    IdslGeneratorPerformExperiment.performExperimentPTAModelChecking(measure, fsa, extPath, scenario, dsm, dsi, services, epms, mappings, resources, "urgent", "int")
				MeasurementPTAModelChecking2:   IdslGeneratorPerformExperiment.performExperimentPTAModelChecking2(measure, fsa, extPath, scenario, dsm, dsi, services, epms, mappings, resources, "urgent", "int")
				default: throw new Throwable("DSIelementGenerate: unimplemented measure")
			}
		}
		IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add(IdslGeneratorGlobalVariables.global_dsm_values,"","Compute utility function")//remove
		
		if(IdslConfiguration.Lookup_value("Create_gobat_and_goallbat")=="true")
			fsa.generateFile(extPath+"go.bat",IdslGeneratorGlobalVariables.global_contents_of_local_batch_file(IdslGeneratorDesignSpace.DSMvalues(dsi))+IdslConfiguration.Lookup_value("pause_in_batch_file"))
		
		if(IdslGeneratorGlobalVariables.ptamodelchecking2){
			fsa.generateFile(extPath+"loss_of_info_and_prec.dat",RetrieveMeasureOfLossOfInformationAndLossOfPrecision(epms,dsi))		
			for(epm:epms){
				var loi_value = avg(CollectAtoms_kmeans_clustering_score(epm.pmodel.head,dsi))
				var lop_value = RetrieveMeasureOfLossOfPrecision_only(epm.pmodel.head,dsi)
				
				if(IdslGeneratorDesignSpace.DSMparamToValue(dsi,"modeltimeunit").equals("1") ||
						IdslGeneratorDesignSpace.DSMparamToValue(dsi,"samplingmethod").equals("ecdf1024"))
					IdslGeneratorGlobalVariables.lop_and_loi_file_contents = IdslGeneratorGlobalVariables.lop_and_loi_file_contents+
							epms.head.name + " " + IdslGeneratorDesignSpace.DSMvalues(dsi) + " loi+lop: " + loi_value + " " + lop_value	+ "\r\n"		
			}
		}		
		IdslGeneratorGlobalVariables.global_contents_of_main_batch_file_add("call "+extPath+"go.bat")	
	}
	
	def static RetrieveMeasureOfLossOfInformationAndLossOfPrecision (List<ExtendedProcessModel> epm, DesignSpaceModel dsi){
		'''
		«FOR extprocess:epm»«RetrieveMeasureOfLossOfInformation(extprocess.pmodel.head,dsi)»
		«RetrieveMeasureOfLossOfPrecision(extprocess.pmodel.head,dsi)»
		«ENDFOR»
		'''
	}
	
	def static String RetrieveMeasureOfLossOfInformation (ProcessModel pm, DesignSpaceModel dsi){ // retrieve k-means values in the model and average them out
		'''
		RetrieveMeasureOfLossOfInformation for «IdslGeneratorDesignSpace.DSMvalues(dsi)» and process «pm.name»
		«IF IdslConfiguration.Lookup_value("show_inbetween_results_in_loss_of_precision_and_information_files")=="true"»
		K-means clustering score(s): «CollectAtoms_kmeans_clustering_score(pm,dsi)»
		«ENDIF»
		Average (normalized and squared) K-means clustering score: «avg(CollectAtoms_kmeans_clustering_score(pm,dsi))»
		'''
	}
	
	def static String RetrieveMeasureOfLossOfPrecision (ProcessModel pm, DesignSpaceModel dsi){ // retrieve atoms of the model and compute the loss of precision
		var atom_dsi          = CollectAtoms(pm,dsi).map[ atom | IdslGeneratorExpression.evalAExp(atom.taskload.head.load,dsi) ]
		var atom_dsi_mult     = CollectAtoms(pm,dsi).map[ atom | new Integer(IdslGeneratorDesignSpace.DSMparamToValue(dsi,"modeltimeunit"))*IdslGeneratorExpression.evalAExp(atom.taskload.head.load,dsi) ]
		var atom_dsi_mu1      = CollectAtoms(pm,dsi).map[ atom | IdslGeneratorExpression.evalAExp(atom.taskload.head.load,IdslGeneratorDesignSpace.change_modeltimeunit_to_1(dsi)) ]
		var atom_dsi_deltasqr = CollectAtoms(pm,dsi).map[ atom | (new Integer(IdslGeneratorDesignSpace.DSMparamToValue(dsi,"modeltimeunit"))*IdslGeneratorExpression.evalAExp(atom.taskload.head.load,dsi) - IdslGeneratorExpression.evalAExp(atom.taskload.head.load,IdslGeneratorDesignSpace.change_modeltimeunit_to_1(dsi))) *
																 (new Integer(IdslGeneratorDesignSpace.DSMparamToValue(dsi,"modeltimeunit"))*IdslGeneratorExpression.evalAExp(atom.taskload.head.load,dsi) - IdslGeneratorExpression.evalAExp(atom.taskload.head.load,IdslGeneratorDesignSpace.change_modeltimeunit_to_1(dsi))) ]
		var loss_of_precision = Math.sqrt(1.0 * sum_int(atom_dsi_deltasqr) / atom_dsi_deltasqr.length) // a la standard deviation  
		'''
		RetrieveMeasureOfLossOfPrecision for «IdslGeneratorDesignSpace.DSMvalues(dsi)» and process «pm.name»
		«IF IdslConfiguration.Lookup_value("show_inbetween_results_in_loss_of_precision_and_information_files")=="true"» 
		Atom values for DSI: «FOR atom:atom_dsi»«atom» «ENDFOR»
		Atom values for DSI (multiplied): «FOR atom:atom_dsi_mult»«atom» «ENDFOR»
		Atom values for DSI with model unit 1: «FOR atom:atom_dsi_mu1»«atom» «ENDFOR»
		Atom values delta squared: «FOR atom:atom_dsi_deltasqr»«atom» «ENDFOR»
		«ENDIF»
		Loss of precision: «loss_of_precision»
		'''
	}
	
	def static Double RetrieveMeasureOfLossOfPrecision_only (ProcessModel pm, DesignSpaceModel dsi){
		var atom_dsi          = CollectAtoms(pm,dsi).map[ atom | IdslGeneratorExpression.evalAExp(atom.taskload.head.load,dsi) ]
		var atom_dsi_mult     = CollectAtoms(pm,dsi).map[ atom | new Integer(IdslGeneratorDesignSpace.DSMparamToValue(dsi,"modeltimeunit"))*IdslGeneratorExpression.evalAExp(atom.taskload.head.load,dsi) ]
		var atom_dsi_mu1      = CollectAtoms(pm,dsi).map[ atom | IdslGeneratorExpression.evalAExp(atom.taskload.head.load,IdslGeneratorDesignSpace.change_modeltimeunit_to_1(dsi)) ]
		var atom_dsi_deltasqr = CollectAtoms(pm,dsi).map[ atom | (new Integer(IdslGeneratorDesignSpace.DSMparamToValue(dsi,"modeltimeunit"))*IdslGeneratorExpression.evalAExp(atom.taskload.head.load,dsi) - IdslGeneratorExpression.evalAExp(atom.taskload.head.load,IdslGeneratorDesignSpace.change_modeltimeunit_to_1(dsi))) *
																 (new Integer(IdslGeneratorDesignSpace.DSMparamToValue(dsi,"modeltimeunit"))*IdslGeneratorExpression.evalAExp(atom.taskload.head.load,dsi) - IdslGeneratorExpression.evalAExp(atom.taskload.head.load,IdslGeneratorDesignSpace.change_modeltimeunit_to_1(dsi))) ]
		var loss_of_precision = Math.sqrt(1.0 * sum_int(atom_dsi_deltasqr) / atom_dsi_deltasqr.length) // a la standard deviation
		return loss_of_precision													 
	}
	
	def static Double sum (List<Double> nums){
		var Double s=0.0
		for(i:nums)
			s=s+i
		return s
	}
	
	def static Integer sum_int (List<Integer> nums){
		var sum=sum(nums.map[i | i as double])
		return sum.intValue
	}
	
	def static Double avg (List<Double> nums){
		if(nums==null || nums.length==0)
			return -1.0
		else
			return sum(nums) / nums.length
	}
	
	def static List<AtomicProcessModel> CollectAtoms(ProcessModel pmodel, DesignSpaceModel dsi){
		var List<AtomicProcessModel> atoms = new ArrayList<AtomicProcessModel>
		switch(pmodel){
			ParProcessModel:    for (pm:pmodel.pmodel)  { atoms.addAll(CollectAtoms(pm,dsi)) }
			AltProcessModel:    for (pm:pmodel.pmodel)  { atoms.addAll(CollectAtoms(pm,dsi)) }
			SeqProcessModel:   	for (pm:pmodel.pmodel)  { atoms.addAll(CollectAtoms(pm,dsi)) }
			PaltProcessModel:   for (pm:pmodel.ppmodel) { atoms.addAll(CollectAtoms(pm.pmodel.head,dsi)) }
			AtomicProcessModel: atoms.add(pmodel)
			DesAltProcessModel: for (pm:pmodel.pmodel) 
										if(IdslGeneratorDesignSpace.loopUpDSEValue(pmodel.param.head, dsi).equals(pm.select.head))
											atoms.addAll(CollectAtoms(pm.pmodel.head,dsi))
			default:			throw new Throwable("CollectAtoms: ProcessModel kind not implemented")
		}
		return atoms
	}

	def static List<Double> CollectAtoms_kmeans_clustering_score(ProcessModel pmodel, DesignSpaceModel dsi){
		var List<Double> kmcs = new ArrayList<Double>
		if (pmodel.kmeans_clustering_score!=null && !pmodel.kmeans_clustering_score.empty)
			kmcs.add(new Double(pmodel.kmeans_clustering_score.head))
			
		switch(pmodel){
			AtomicProcessModel: {}
			ParProcessModel:    for (pm:pmodel.pmodel)  { kmcs.addAll(CollectAtoms_kmeans_clustering_score(pm,dsi)) }
			AltProcessModel:    for (pm:pmodel.pmodel)  { kmcs.addAll(CollectAtoms_kmeans_clustering_score(pm,dsi)) }
			SeqProcessModel:   	for (pm:pmodel.pmodel)  { kmcs.addAll(CollectAtoms_kmeans_clustering_score(pm,dsi)) }
			PaltProcessModel:   for (pm:pmodel.ppmodel) { kmcs.addAll(CollectAtoms_kmeans_clustering_score(pm.pmodel.head,dsi)) }
			DesAltProcessModel: for (pm:pmodel.pmodel) 
										if(IdslGeneratorDesignSpace.loopUpDSEValue(pmodel.param.head, dsi).equals(pm.select.head))
											kmcs.addAll(CollectAtoms_kmeans_clustering_score(pm.pmodel.head,dsi))
			MutexProcessModel:  throw new Throwable("CollectAtoms_kmeans_clustering_score: MutexProcessModel kind not implemented")
			default:			throw new Throwable("CollectAtoms_kmeans_clustering_score: ProcessModel kind not implemented")
		}
		return kmcs
	}	

	// functions that retrieve an object from a set, based on an ID
	def static filterResource (List<ResourceModel> resources, String resource_id) 				{ for (resource:resources) { if (resource.name==resource_id) { return resource } } return null } 
	def static filterExtProcess (List<ExtendedProcessModel> extprocesses, String eprocess_id) 	{ for (extproc:extprocesses) { if (extproc.name==eprocess_id) { return extproc } } return null }
	def static filterProcess (List<ProcessModel> processes, String process_id)					{ for (process:processes) {if (process.name==process_id) { return process } } return null }
	def static filterScenario (List<Scenario> scenarios, String scenario_id)					{ for (scen:scenarios) { if (scen.name.head==scenario_id) { return scen } } return null }	
	def static filterActivity (List<Service> activities, String activity_id)					{ for (act:activities) { if (act.name==activity_id) { return act } } return null }
	def static filterAcivityInstance (List<ServiceRequest> activityinstances, String act_id) 	{ for (ai:activityinstances) { if(ai.activity_id==act_id) {return ai} } return null }
	
	def static concatStrings (List<String> strings)												'''«FOR str:strings»«str»_«ENDFOR»'''
	def static concatStrings2 (List<String> strings)											{ var String ret="" ; for (str:strings){ ret.concat(" " + str) } ; return ret }
	def static concatStrings (Set<String> strings)												'''«FOR str:strings»«str»_«ENDFOR»'''
	def static concatStrings2 (Set<String> strings)												{ var String ret="" ; for (str:strings){ ret.concat(" " + str ) } ; return ret }
}

class fsa2 implements IFileSystemAccess { // replaces fsa, because fsa deletes files
	override deleteFile(String filename) {
		var File f = new File(filename) 
		f.delete
	}
	
	override generateFile(String filename, CharSequence contents){
		// make directory if not exists
		var File theDir1 = new File(pathOf(filename))
		if(!theDir1.exists)
			theDir1.mkdirs // make the directories
				
		// write contents to file
		var PrintWriter writer = new PrintWriter(filename, "UTF-8");
		writer.println(contents)
		writer.close
	}
	
	def generateFile(String filename, List<String> contents_list){ // each element of the list represents a line 
		var String contents = ""
		for (cnt:contents_list)
			contents=contents+"\n"+cnt
		generateFile(filename,contents)
	}
	
	override generateFile(String filename, String outputConfigurationName, CharSequence contents){
		generateFile(filename,contents)
	}
	
	def String pathOf(String filename){ // removes the filename from the file path, leaving the directory structure
		var File file = new File(filename)
		var String absolutePath = file.getAbsolutePath
		var String filePath = absolutePath.substring(0,absolutePath.lastIndexOf(File.separator))
		return filePath
	} 
}
