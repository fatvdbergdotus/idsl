package org.idsl.language.generator

import java.util.ArrayList
import java.util.Collections
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.emf.ecore.resource.Resource
import org.idsl.language.idsl.AbstractionProcessModel
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.AtomicProcessModel
import org.idsl.language.idsl.CompoundResourceTree
import org.idsl.language.idsl.DesAltProcessModel
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.DesignSpaceParam
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.MVExp
import org.idsl.language.idsl.MVExpCoDomain
import org.idsl.language.idsl.MVExpDiscreteNondet
import org.idsl.language.idsl.MVExpDiscreteUniform
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.MVExpECDFProduct
import org.idsl.language.idsl.MVExpECDFabstract
import org.idsl.language.idsl.MVExpECDFbasedonDSI
import org.idsl.language.idsl.MVExpECDFfromfile
import org.idsl.language.idsl.MVExpNondet
import org.idsl.language.idsl.MVExpUniform
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.MeasurementResults
import org.idsl.language.idsl.MeasurementSearches
import org.idsl.language.idsl.MutexProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.ResourceTree
import org.idsl.language.idsl.SelectProcessModel
import org.idsl.language.idsl.SeqParProcessModel
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.SyncFrequencyAlways
import org.idsl.language.idsl.SyncFrequencyOnce
import org.idsl.language.idsl.SyncFrequencySometimes
import org.idsl.language.idsl.impl.IdslFactoryImpl

import static org.idsl.language.generator.IdslGeneratorGlobalVariables.*
import org.idsl.language.idsl.AExp
import org.idsl.language.idsl.Exp
import org.idsl.language.idsl.AExpExpr
import org.idsl.language.idsl.AExpVal
import org.idsl.language.idsl.TaskLoad
import org.idsl.language.idsl.Scenario
import org.idsl.language.idsl.TimeSchedule
import org.idsl.language.idsl.MultiplyResults
import org.idsl.language.idsl.Measurement
import org.idsl.language.idsl.RepeatProcessModel
import org.idsl.language.idsl.FreqValue
import org.idsl.language.idsl.AExpDspace
import org.idsl.language.idsl.TimeScheduleFixedIntervals
import org.idsl.language.idsl.TimeScheduleLatencyJitter
import org.idsl.language.idsl.MVExpExponential
import org.idsl.language.idsl.LoadBalancerProcessModel

class IdslGeneratorSyntacticSugar {
	def static ApplySyntacticSugar(		DesignSpaceModel dsm, List<Measurement> experiments,
										List<MeasurementSearches> searches, List<ExtendedProcessModel> extprocesses, List<ResourceModel> resourcemodels, 
								   		List<Mapping> mappings, Resource resource, List<Scenario> scenarios, MeasurementResults mresults){

		// SYNTACTIC SUGAR CONVERSION
		if(!dsm.bexpwhitelist.empty)
			IdslGeneratorDesignSpace.ResolveWhiteListDSM(dsm)
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step0-white_list_to_dsm_and_constraint") // step 2
		// ************************************************************************************************************************

		ReplaceCostFunctionsByUtilityFunctions(mresults)
		SelectBruteForceSearchWhenNotDefined(searches) // brute search by default
		ImplementDefaultSchedulingRoutineForUndefined(mappings) // scheduling
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step1-costtoutility_search_and_scheduling") // step 3
		// ************************************************************************************************************************
		
		//for (abstr_CDF:resource.allContents.toIterable.filter(typeof(MVExpECDFabstract)).toList)
		//	abstr_CDF=abstr_CDF.abstract_cdf.load.head
		
		for (extprocess:extprocesses) {
			ResolveRepeatProcesses(extprocess.pmodel.head)
		}
		
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step1a-replace-repeat-processes-by-processes") // step 4
		// ************************************************************************************************************************		
		
		for (extprocess:extprocesses) {
			ResolveSeqPars(extprocess.pmodel.head)
			//ResolveAtomProcWithMVExp(extprocess.pmodel.head) // done in an earlier stage? 		
			ResolveAtomProcWithMVExp(extprocess.pmodel.head)
			//System.out.println(IdslGeneratorDebugging.PrintProcessTree(extprocess.pmodel.head))
			//extprocess.aload.removeAll() // deletes all abstract CDFs, since they should have been copied by now
		}
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step2-seqpars_and_mvexps") // step 5
		
		// ************************************************************************************************************************
		
		// REQUIRES IMPLEMENTATION
		//for (extprocess:extprocesses)	
			//RemoveDesAltProcessesNoChoice(extprocess.pmodel.head)	//ERROR: not implemented yet		
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step3-desalt-no_choice-elimination") // step 6
		// ************************************************************************************************************************
		IdslGeneratorGlobalVariables.global_noname_counter=0
		for (extprocess:extprocesses) { // rename unnamed parts from processes to "noname_xxx"
			LabelNoNamesProcess(extprocess.pmodel.head)
			for (spm:extprocess.spm) 
				LabelNoNamesProcess(spm.pmodel.head) 
		}
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step4-unnamed_processes") // step 7
		// ************************************************************************************************************************
		
		if(IdslConfiguration.Lookup_value("enable_model_time_unit")=="true" ||
			IdslGenerator.measurements_contain_PTAmodelchecking2(experiments)!=null ){ // divide all times by the unit
			for (scenario:scenarios)
				DivideAtomsByTimeUnit(scenario)
			
			for (extprocess:extprocesses) { // multiply atom loads by time unit
				DivideAtomsByTimeUnit(extprocess.pmodel.head)
				for (spm:extprocess.spm) 
					DivideAtomsByTimeUnit(spm.pmodel.head) 
			}
		}
		
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step4a-introduce_desalts_in_process_for_timeunit") // step 8
		// ************************************************************************************************************************		
				
		for (resmodel:resourcemodels) 
			LabelNoNamesResourceTree(resmodel.restree.head)  // renames unnamed parts from resources to "noname_xxx"
			
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step5-unnamed_resources")	 // step 9	
		// ************************************************************************************************************************
		
		System.out.println("Found lb_names: "+IdslGeneratorPerformExperiment.load_balancers_in_extprocesses(extprocesses))
		
		for(lb_name_numpolicies:IdslGeneratorPerformExperiment.load_balancers_in_extprocesses(extprocesses))
			AddLoadBalancerPolicyToTheDesignSpaceModel(dsm, lb_name_numpolicies.key, lb_name_numpolicies.value)
		
		IdslGenerator.iDSLinstanceToDisc("syntacticsugar-step6-policies-for-loadbalancers-in-processes") // step 10		
		// ************************************************************************************************************************			
					
	}
	
	def static ReplaceCostFunctionsByUtilityFunctions(MeasurementResults mresults){
		for(cost:mresults.costs){ // create a utility equivalent
			var util	  = IdslFactoryImpl::init.createUtility
			var util_expr = IdslFactoryImpl::init.createUExpExpr
			var uval	  = IdslFactoryImpl::init.createAExpVal
			uval.value = 0 
			
			// utility = 0 - cost 
			util_expr.a1.add(uval)
			util_expr.op.add("-")
			util_expr.a2.add(cost.util_func)
			
			if(!cost.requirement.empty){ // copy the (inversed) requirement additionally
				var req   = IdslFactoryImpl::init.createUtilityCostRequirement
				var thold = cost.requirement.head.threshold_value.head
				
				req.threshold_value.add((1.0-new Double(thold)).toString)
				util.requirement.add(req)
			}
			
			util.name=cost.name
			util.util_func=util_expr
	
			mresults.utils.add(util)
		}
		mresults.costs.clear // delete all cost functions, they have been replaced by utility ones
	}
	
	def static SelectBruteForceSearchWhenNotDefined(List<MeasurementSearches> searches){
		if(searches.head.ms.empty){
			var brute_force = IdslFactoryImpl::init.createMeasurementSearchBruteForce // when not defined: brute force is the default search method
			searches.head.ms.add(brute_force)
		}	
	}
	
	// Sets scheduling defaults for undefined resources: Non-deterministic order, medium priority and non-preemption
	def static ImplementDefaultSchedulingRoutineForUndefined(List <Mapping> mappings){
		for (mapping:mappings){
			// set undefined priorities to medium
			for(pr:mapping.prassignment)
				if(pr.plevel.head==null) pr.plevel.add(IdslFactoryImpl::init.createPriorityLevelMedium) 
			// set undefined time slices to -1 (meaning non-preemption)
			for(rs:mapping.rspolicy){
				if(rs.timeslice==null)
				 	rs.setTimeslice(IdslFactoryImpl::init.createTimeSlice)
				if(rs.timeslice.time==null)
					rs.timeslice.setTime(IdslGeneratorExpression.AExpMinusOne)
			}
			// add a policy and time slice for unlisted resources
			for(res:ResourceNamesPerMapping(mapping)){
				if (!RSPolicyContainsResource(mapping, res)){
					var new_rsp = IdslFactoryImpl::init.createResourceSchedulingPolicy	
					new_rsp.setResource(res)
					new_rsp.setPolicy(IdslFactoryImpl::init.createSchedulingPolicyNonDet)
					new_rsp.setTimeslice(IdslFactoryImpl::init.createTimeSlice)
					new_rsp.timeslice.setTime(IdslGeneratorExpression.AExpMinusOne)
					mapping.rspolicy.add(new_rsp)
				}
			}
		}
	}
	
	//def static RemoveDesAltProcessesNoChoice(ProcessModel pmodel){
		// OUT OF ORDER: Please add the cases for DesAltProcessModel and PaltProcessModel, and implement the RemoveDesAltProcessesNoChoice_parent_child function
		
		/*var List<ProcessModel> 			pmodels  = new ArrayList<ProcessModel>
		var List<DesAltProcessModel>	pdesalts = new ArrayList<DesAltProcessModel>
		
		switch(pmodel){ // first do the recursion and a lower, then detect desalts
			ParProcessModel:   	for (pm:pmodel.pmodel)  { RemoveDesAltProcessesNoChoice(pm)
														  switch(pm){ DesAltProcessModel: { pmodels.add(pmodel); pdesalts.add(pm) } } }
			AltProcessModel:   	for (pm:pmodel.pmodel)  { RemoveDesAltProcessesNoChoice(pm)
														  switch(pm){ DesAltProcessModel: { pmodels.add(pmodel); pdesalts.add(pm) } } }
			SeqProcessModel:   	for (pm:pmodel.pmodel)  { RemoveDesAltProcessesNoChoice(pm) 
														  switch(pm){ DesAltProcessModel: { pmodels.add(pmodel); pdesalts.add(pm) } } }
			MutexProcessModel: 	for (pm:pmodel.pmodel)  { RemoveDesAltProcessesNoChoice(pm) 
														  switch(pm){ DesAltProcessModel: { pmodels.add(pmodel); pdesalts.add(pm) } } }
			DesAltProcessModel: for (pm:pmodel.pmodel)  { RemoveDesAltProcessesNoChoice(pm.pmodel.head)
														  switch(pm.pmodel.head) { DesAltProcessModel: { pmodels.add(pmodel); pdesalts.add(pm.pmodel) } } }
			
			PaltProcessModel:  	for (pm:pmodel.ppmodel) { RemoveDesAltProcessesNoChoice(pm.pmodel.head) }			
		}
		//for(cnt:1..pmodels.length)
		//	RemoveDesAltProcessesNoChoice_parent_child(pmodels.get(cnt), pdesalts.get(cnt))		
	}*/
	/*def static RemoveDesAltProcessesNoChoice_parent_child(ProcessModel pmodel, DesAltProcessModel desalt){
		if(desalt.pmodel.length==1) // remove the desalt, since there is "no choice"
			var replace_pm = desalt.pmodel.head.pmodel.head			
			replace_pmodel_in_pmodel_by_pmodel( pmodel, desalt, replace_pm )
		}
	}
	def static replace_pmodel_in_pmodel_by_pmodel(ProcessModel parent_pm, DesAltProcessModel toreplace_pm, ProcessModel replaceby_pm ){
	}*/
	
	def static RSPolicyContainsResource (Mapping mapping, String res){
		for(rsp:mapping.rspolicy)  
			if(rsp.resource==res) 
				return true  
		return false
	}
	
	def static ResourceNamesPerMapping (Mapping mapping){
		var Set<String> res_names = new HashSet<String>
		for(pr:mapping.prassignment)
			res_names.add(pr.resource)
		return res_names
	}
	
	def static DivideAtomsByTimeUnit(Scenario scenario){
		for(sreq:scenario.ainstance){
			DivideAtomsByTimeUnit(sreq.time.head)
		}
	}
	
	def static DivideAtomsByTimeUnit(TimeSchedule ts){
		switch(ts){
			TimeScheduleLatencyJitter:  DivideAtomsByTimeUnit_lj(ts)
			TimeScheduleFixedIntervals: DivideAtomsByTimeUnit_fi(ts)
			default:					throw new Throwable("DivideAtomsByTimeUnit: ts type not supported!")
		}
	}
	
	def static DivideAtomsByTimeUnit_lj(TimeScheduleLatencyJitter ts){
		var AExp old_period   = ts.period
		var AExp old_jitter   = ts.jitter
		
		var AExp period    	  = DivideAtomsByTimeUnit(old_period) 
		var AExp jitter       = DivideAtomsByTimeUnit(old_jitter)
		
		ts.period             = period
		ts.jitter             = jitter
	}
	
	def static DivideAtomsByTimeUnit_fi(TimeScheduleFixedIntervals ts){
		var AExp old_start    = ts.start
		var AExp old_interval = ts.interval
		
		var AExp start    	  = DivideAtomsByTimeUnit(old_start) 
		var AExp interval     = DivideAtomsByTimeUnit(old_interval)
		
		ts.start              = start
		ts.interval           = interval
	}
	
	def static DivideAtomsByTimeUnit(ProcessModel pmodel){
		switch(pmodel){
			AtomicProcessModel:  DivideAtomsByTimeUnit(pmodel) // to add the time unit to the load
			ParProcessModel:   	 for (pm:pmodel.pmodel)  { DivideAtomsByTimeUnit(pm) }
			AltProcessModel:   	 for (pm:pmodel.pmodel)  { DivideAtomsByTimeUnit(pm) }
			SeqProcessModel:   	 for (pm:pmodel.pmodel)  { DivideAtomsByTimeUnit(pm) }
			PaltProcessModel:  	 for (pm:pmodel.ppmodel) { DivideAtomsByTimeUnit(pm.pmodel.head) }
			MutexProcessModel: 	 for (pm:pmodel.pmodel)  { DivideAtomsByTimeUnit(pm) }
			DesAltProcessModel:  for (pm:pmodel.pmodel)  { DivideAtomsByTimeUnit(pm.pmodel.head) }
		}		
	}

	def static DivideAtomsByTimeUnit(AtomicProcessModel atomic_pmodel){
		// this function divides the taskload(s) of an atomic process by the time unit
		var Exp  old_load = atomic_pmodel.taskload.head.load
		var Exp  new_load = DivideAtomsByTimeUnit(old_load)
		atomic_pmodel.taskload.head.load = new_load
	
		if(!atomic_pmodel.taskload_nondet.empty){ // update the second taskload as well
			var Exp  old_load2 = atomic_pmodel.taskload_nondet.head.load
			var Exp  new_load2 = DivideAtomsByTimeUnit(old_load2)
			atomic_pmodel.taskload_nondet.head.load = new_load2
		}
	}
	
	def static AExp DivideAtomsByTimeUnit(Exp old_loadE){
		// corrected load = (old_load / dspace(timeunit)) + (1/2) = (old_load+dspace(timeunit)/2) / dspace(timeunit)
		var AExp old_load
		switch(old_loadE){
			AExp:    old_load = old_loadE // copy the reference
			default: throw new Throwable("Function MultiplyAtomsByTimeUnit only support AExp loads")
		}		

		var dspace_load= IdslFactoryImpl::init.createAExpDspace
		dspace_load.param.add("modeltimeunit")	

		// create 1/2
		var AExpVal numerator = IdslFactoryImpl::init.createAExpVal
		numerator.value = 1
		var AExpVal denumerator = IdslFactoryImpl::init.createAExpVal
		denumerator.value = 2
		var AExpExpr half       = IdslFactoryImpl::init.createAExpExpr
		half.a1.add(numerator)
		half.op.add("/")
		half.a2.add(denumerator)
	
		// create old_load + ( dspace(timeunit)/2 )
		var AExpExpr old_load_div_dspace = IdslFactoryImpl::init.createAExpExpr // to enable rounding
		old_load_div_dspace.a1.add(old_load)
		old_load_div_dspace.op.add("/")
		old_load_div_dspace.a2.add(dspace_load)	

		// create (old_load+dspace(timeunit)/2)    /     dspace(timeunit)
		var new_load =   IdslFactoryImpl::init.createAExpExpr
		new_load.a1.add(old_load_div_dspace)
		new_load.op.add("+")
		new_load.a2.add(half)	
	 
	 	//return old_load
		return new_load
	}
	
	def static TaskLoad one_layer_clone (TaskLoad tl){
		var tl_clone = IdslFactoryImpl::init.createTaskLoad
		//tl_clone.load = one_layer_clone(tl.load) 
		return tl_clone
	}
	
	
	
	def static AExpVal one_layer_clone (AExpVal exp){ var e=IdslFactoryImpl::init.createAExpVal; e.value=exp.value; return e }
	def static AExpDspace one_layer_clone (AExpDspace exp) { var e=IdslFactoryImpl::init.createAExpDspace; e.param.addAll(exp.param); return e }
	//		AExpExpr:       { var e=IdslFactoryImpl::init.createAExpExpr; e.a1.add(one_layer_clone(exp.a1.head)); return e }
	//		default: throw new Throwable("one_layer_clone: Exp type not supported")
	//	}
	//}
	
	def static ProcessModel one_layer_clone (ProcessModel pm){ //clones the top layer of a process model so that its reference address is different
		switch(pm){
			AtomicProcessModel: { var p = IdslFactoryImpl::init.createAtomicProcessModel
								  p.name=pm.name
								  if (pm.taskload!=null) p.taskload.addAll(pm.taskload)
								  if (pm.taskload_nondet!=null) p.taskload.addAll(pm.taskload_nondet)
								  return p
			}
			ParProcessModel:   	{ var p = IdslFactoryImpl::init.createParProcessModel
								  p.name=pm.name
								  p.pmodel.addAll(pm.pmodel.map[x|one_layer_clone(x)])
								  if (pm.taskload!=null) p.taskload.addAll(pm.taskload)
								  return p
			}
			AltProcessModel:   	{ var p = IdslFactoryImpl::init.createAltProcessModel
								  p.name=pm.name
								  p.pmodel.addAll(pm.pmodel.map[x|one_layer_clone(x)])
								  if (pm.taskload!=null) p.taskload.addAll(pm.taskload)
								  return p
			}   	
			SeqProcessModel:   	{ var p = IdslFactoryImpl::init.createSeqProcessModel
								  p.name=pm.name
								  p.pmodel.addAll(pm.pmodel.map[x|one_layer_clone(x)])
								  if (pm.taskload!=null) p.taskload.addAll(pm.taskload)
								  return p
			}   	
			MutexProcessModel:  { var p = IdslFactoryImpl::init.createSeqProcessModel
								  p.name=pm.name
								  p.pmodel.addAll(pm.pmodel.map[x|one_layer_clone(x)])
								  if (pm.taskload!=null) p.taskload.addAll(pm.taskload)
								  return p
			} 	
/*			DesAltProcessModel: { var p = IdslFactoryImpl::init.createDesAltProcessModel
								  p.name=pm.name
								  p.pmodel.addAll(pm.pmodel)
								  p.param.addAll(pm.param)
								  if (pm.taskload!=null) p.taskload.addAll(pm.taskload)
								  return p
			} 	 
			PaltProcessModel:   { var p = IdslFactoryImpl::init.createPaltProcessModel
								  p.name=pm.name
								  p.ppmodel.addAll(pm.ppmodel)
								  if (pm.taskload!=null) p.taskload.addAll(pm.taskload)
								  return p
			}*/ 				
			//RepeatProcessModel: 
			default:			throw new Throwable ("one_layer_clone: High level process not supported")
		}
	}
	
	def static ResolveRepeatProcesses(ProcessModel pmodel){
		switch(pmodel){
			ParProcessModel:   	for (cnt:0..pmodel.pmodel.length-1)  { ResolveRepeatProcesses(pmodel, pmodel.pmodel.get(cnt), cnt) }
			AltProcessModel:   	for (cnt:0..pmodel.pmodel.length-1)  { ResolveRepeatProcesses(pmodel, pmodel.pmodel.get(cnt), cnt) }
			SeqProcessModel:   	for (cnt:0..pmodel.pmodel.length-1)  { ResolveRepeatProcesses(pmodel, pmodel.pmodel.get(cnt), cnt) }
			MutexProcessModel: 	for (cnt:0..pmodel.pmodel.length-1)  { ResolveRepeatProcesses(pmodel, pmodel.pmodel.get(cnt), cnt) }
			// the harder cases
			DesAltProcessModel: for (cnt:0..pmodel.pmodel.length-1)  { ResolveRepeatProcesses(pmodel, pmodel.pmodel.get(cnt).pmodel.head, cnt) }
			PaltProcessModel:  	for (cnt:0..pmodel.ppmodel.length-1) { ResolveRepeatProcesses(pmodel, pmodel.ppmodel.get(cnt).pmodel.head, cnt) }			
			RepeatProcessModel: throw new Throwable ("ResolveRepeatProcesses: High level process cannot be of type RepeatProcessModel!")
		}	
	}
	
	def static ResolveRepeatProcesses(ProcessModel parent, ProcessModel child, int child_index){ // create replacement for repeat and inserts it into the parent
		System.out.println("ResolveRepeatProcesses")
		switch(child){
			RepeatProcessModel: { 
				var new_child = ResolveRepeatProcessSingle(child) // replace repeat by palts and sequences
				switch(parent){
					ParProcessModel:   	parent.pmodel.set(child_index, new_child)
					AltProcessModel:   	parent.pmodel.set(child_index, new_child)
					SeqProcessModel:   	parent.pmodel.set(child_index, new_child)
					MutexProcessModel: 	parent.pmodel.set(child_index, new_child)
					// the harder cases					
					DesAltProcessModel: parent.pmodel.get(child_index).pmodel.set(0, new_child)
					PaltProcessModel:  	parent.ppmodel.get(child_index).pmodel.set(0, new_child)
					RepeatProcessModel: throw new Throwable ("ResolveRepeatProcesses: illegal subtype of RepeatProcessModel!")						
				}
			} 
		}
	}
	
	def static PaltProcessModel ResolveRepeatProcessSingle (RepeatProcessModel rpm){ // turns the repeat process into an alt
		var palt_pm 				 = IdslFactoryImpl::init.createPaltProcessModel
		var List<FreqValue> freqvals = rpm.freqval
		
		for(freqval:freqvals){
			var rpm_process		     = one_layer_clone(rpm.pmodel.head)
			var prob_proc			 = IdslFactoryImpl::init.createProbProcess
			prob_proc.prob.add(freqval.freq.head)
			prob_proc.pmodel.add(ResolveRepeatProcessSequence(rpm_process,freqval.value.head))
			palt_pm.ppmodel.add(prob_proc)
		}
		return palt_pm
	}
	
	def static SeqProcessModel ResolveRepeatProcessSequence (ProcessModel pm, int repetitions){ // creates a repeating sequence of one process model
		var seq_pm  = IdslFactoryImpl::init.createSeqProcessModel
		seq_pm.name=pm.name
		for(cnt:1..5){ //repetitions
			var pm_copy = one_layer_clone(pm)
			seq_pm.pmodel.add(pm_copy)
		}
		return seq_pm
	}
	
	def static void LabelNoNamesProcess(ProcessModel pmodel){
		IdslGeneratorGlobalVariables.global_noname_counter=IdslGeneratorGlobalVariables.global_noname_counter+1
		if (pmodel.name==null || pmodel.name=="no_name") 
			pmodel.name="noname_"+IdslGeneratorGlobalVariables.global_noname_counter.toString
			
		switch(pmodel){
			ParProcessModel:   	for (pm:pmodel.pmodel)  { LabelNoNamesProcess(pm) }
			AltProcessModel:   	for (pm:pmodel.pmodel)  { LabelNoNamesProcess(pm) }
			SeqProcessModel:   	for (pm:pmodel.pmodel)  { LabelNoNamesProcess(pm) }
			PaltProcessModel:  	for (pm:pmodel.ppmodel) { LabelNoNamesProcess(pm.pmodel.head) }
			MutexProcessModel: 	for (pm:pmodel.pmodel)  { LabelNoNamesProcess(pm) }
			DesAltProcessModel: for (pm:pmodel.pmodel)  { LabelNoNamesProcess(pm.pmodel.head) }
		}
	}
	
	def static void LabelNoNamesResourceTree(ResourceTree rtree){
		IdslGeneratorGlobalVariables.global_noname_counter=IdslGeneratorGlobalVariables.global_noname_counter+1
		if (rtree.name==null || rtree.name=="no_name") 
			rtree.name="noname_"+IdslGeneratorGlobalVariables.global_noname_counter.toString
			
		switch(rtree){ 
			CompoundResourceTree: for(rt:rtree.rtree) { LabelNoNamesResourceTree(rt) }
		}
	}
	
	def static boolean isAtomProcWithMVExp (ProcessModel pmodel){
		switch(pmodel){
			AtomicProcessModel:   switch(pmodel.taskload.head.load) { MVExp:   return true 
																      default: return false } 
			default: return false
		}	
	}
	
	private static List<List<ProcessModel>> global_pm_parents 	// the parent processes of the process that needs editing
	private static List<ProcessModel> global_pm_children 		// the process that needs editing
	
	def static CollectAtomProcsWithMVExp(ProcessModel pmodel){
		switch(pmodel){
			AbstractionProcessModel: 	return null // Implement this to enable MVExp in abstraction processes
			ParProcessModel:     		for (pm:pmodel.pmodel)  { CollectAtomProcsWithMVExp(pm) ; 			 if (isAtomProcWithMVExp(pm)) 			  { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } }
			AltProcessModel:    		for (pm:pmodel.pmodel)  { CollectAtomProcsWithMVExp(pm); 			 if (isAtomProcWithMVExp(pm)) 		      { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } }
			SeqProcessModel:   			for (pm:pmodel.pmodel)  { CollectAtomProcsWithMVExp(pm); 			 if (isAtomProcWithMVExp(pm)) 			  { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } } 
			PaltProcessModel:   		for (pm:pmodel.ppmodel) { CollectAtomProcsWithMVExp(pm.pmodel.head); if (isAtomProcWithMVExp(pm.pmodel.head)) { global_pm_parents.add(pm.pmodel); global_pm_children.add(pm.pmodel.head) } } 
			MutexProcessModel:  		for (pm:pmodel.pmodel)  { CollectAtomProcsWithMVExp(pm); 			 if (isAtomProcWithMVExp(pm)) 		      { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } } 
			AtomicProcessModel: 		return null
			DesAltProcessModel: 		return null // YET TO IMPLEMENT!!!!
			LoadBalancerProcessModel: 	return null // only contains atoms
			default:					throw new Throwable("ProcessModel kind not implemented for ResolveAtomProcsWithMVExp")
		}
	}	
	
	def static isSeqPar(ProcessModel pm){ switch(pm) 		{ SeqParProcessModel: return true default: return false} }
	def static isExponential(ProcessModel pm){ switch(pm)   { MVExpExponential: return true default: return false} }

	def static FindExponentials(ProcessModel pmodel){
		switch(pmodel){
			AbstractionProcessModel: return null // Implement this to enable SeqPars in abstraction processes
			ParProcessModel:    for (pm:pmodel.pmodel)  { FindExponentials(pm) ; 	         if (isExponential(pm)) 			  { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } }
			AltProcessModel:    for (pm:pmodel.pmodel)  { FindExponentials(pm); 			 if (isExponential(pm)) 		      { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } }
			SeqProcessModel:   	for (pm:pmodel.pmodel)  { FindExponentials(pm); 			 if (isExponential(pm)) 			  { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } } 
			PaltProcessModel:   for (pm:pmodel.ppmodel) { FindExponentials(pm.pmodel.head);  if (isExponential(pm.pmodel.head))   { global_pm_parents.add(pm.pmodel); global_pm_children.add(pm.pmodel.head) } } 
			MutexProcessModel:  for (pm:pmodel.pmodel)  { FindExponentials(pm); 			 if (isExponential(pm)) 		      { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } } 
			AtomicProcessModel: return null
			SeqParProcessModel: for (pm:pmodel.pmodel)  { FindExponentials(pm); 			 if (isExponential(pm)) 		      { global_pm_parents.add(list_parProcessModel__processModel(pmodel.pmodel)); global_pm_children.add(pm) } }
								//return null // what about seqpars that contain a seqpar???
			DesAltProcessModel: return null // YET TO IMPLEMENT!!!!
			default:			throw new Throwable("ProcessModel kind not implemented for ResolveAtomProcsWithMVExp")
		}			
	}
	
	def static FindSeqPars(ProcessModel pmodel){
		switch(pmodel){
			AbstractionProcessModel: return null // Implement this to enable SeqPars in abstraction processes
			ParProcessModel:    		for (pm:pmodel.pmodel)  { FindSeqPars(pm) ; 	     if (isSeqPar(pm)) 			  { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } }
			AltProcessModel:    		for (pm:pmodel.pmodel)  { FindSeqPars(pm); 			 if (isSeqPar(pm)) 		      { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } }
			SeqProcessModel:   			for (pm:pmodel.pmodel)  { FindSeqPars(pm); 			 if (isSeqPar(pm)) 			  { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } } 
			PaltProcessModel:   		for (pm:pmodel.ppmodel) { FindSeqPars(pm.pmodel.head); if (isSeqPar(pm.pmodel.head)) { global_pm_parents.add(pm.pmodel); global_pm_children.add(pm.pmodel.head) } } 
			MutexProcessModel:  		for (pm:pmodel.pmodel)  { FindSeqPars(pm); 			 if (isSeqPar(pm)) 		      { global_pm_parents.add(pmodel.pmodel); global_pm_children.add(pm) } } 
			AtomicProcessModel: 		return null
			SeqParProcessModel:			for (pm:pmodel.pmodel)  { FindSeqPars(pm); 			 if (isSeqPar(pm)) 		      { global_pm_parents.add(list_parProcessModel__processModel(pmodel.pmodel)); global_pm_children.add(pm) } }
										//return null // what about seqpars that contain a seqpar???
			DesAltProcessModel: 		return null // YET TO IMPLEMENT!!!!
			LoadBalancerProcessModel: 	return null // only contains atoms
			default:					throw new Throwable("ProcessModel kind not implemented for ResolveAtomProcsWithMVExp")
		}			
	}
	
	def static list_parProcessModel__processModel(List<ParProcessModel> ppm_list){
		var List<ProcessModel> pm_list = new ArrayList<ProcessModel>
		pm_list.addAll(ppm_list)
		return pm_list
	}
	
	def static ResolveExponentials(ProcessModel pmodel){
		global_pm_parents=new ArrayList<List<ProcessModel>>
		global_pm_children=new ArrayList<ProcessModel>		
		
		FindExponentials(pmodel)
		
		if (global_pm_parents.length==0) { return null } // no exponentials found
		
		for(cnt:(0..global_pm_parents.length-1)){
			var pm_parent = global_pm_parents.get(cnt)
			var pm_child  = global_pm_children.get(cnt)
			val index 	  = pm_parent.indexOf(pm_child)
			
			var ProcessModel pm_to_add = CreateSeqParReplacement(pm_child)
			
			pm_parent.add(index,pm_to_add)
			pm_parent.remove(index+1) // remove the original process
		}			
	}
	
	
	def static ResolveSeqPars(ProcessModel pmodel){
		global_pm_parents=new ArrayList<List<ProcessModel>>
		global_pm_children=new ArrayList<ProcessModel>
		
		FindSeqPars(pmodel)
		
		if (global_pm_parents.length==0) { return null } // no seqpars found
		
		for(cnt:(0..global_pm_parents.length-1)){
			var pm_parent = global_pm_parents.get(cnt)
			var pm_child  = global_pm_children.get(cnt)
			val index 	  = pm_parent.indexOf(pm_child)
			
			var ProcessModel pm_to_add = CreateSeqParReplacement(pm_child)
			
			pm_parent.add(index,pm_to_add)
			pm_parent.remove(index+1) // remove the original process
		}		
	}
	
	def static ResolveAtomProcWithMVExp(ProcessModel pmodel){
		global_pm_parents=new ArrayList<List<ProcessModel>>
		global_pm_children=new ArrayList<ProcessModel>
		
		CollectAtomProcsWithMVExp(pmodel) // collect atom processes with MVExp, recursively
		
		if (global_pm_parents.length==0) { return null } // no MVEExp processes found 
		
		for(cnt:(0..global_pm_parents.length-1)){
			var pm_parent = global_pm_parents.get(cnt)
			var pm_child  = global_pm_children.get(cnt)
			val index 	  = pm_parent.indexOf(pm_child)
			
			var ProcessModel pm_to_add = CreateAtomMVExpReplacement(pm_child)
			
			pm_parent.add(index,pm_to_add)
			pm_parent.remove(index+1) // remove the original process
		}
	}
	
	def static List<Integer> value_list (MVExpECDFfromfile load){
		var MVExpECDF new_load = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file (load.num_samples, load.filename, "")
		return value_list (new_load)			
	}
	
	def static List<Integer> value_list (MVExpECDF load){
		var List<Integer> values = new ArrayList<Integer>
		for(freqval:load.freqval)
			for(cnt:1..freqval.freq.head)
				values.add(freqval.value.head)
		return values
	}
	
	def static List<Integer> value_list (MVExpCoDomain load){
		return load.value
	}
	
	def static int arithmetic_mean (List<Integer> values){ // Determines the arithmetic mean of a list of numbers
		var sum = 0
		for(value:values)
			sum = sum + value
		var cnt = values.length
		return sum/cnt
	}
	
	def static int median (List<Integer> values){ // Determines the median a list of numbers
		Collections.sort(values)
		var size=values.length
		
		if(size==1)
			return values.head
		else if(size%2==0)
			return values.get(size/2)
		else
			return (values.get(size/2) + values.get(size/2+1)) / 2
	}
	
	def static ProcessModel CreateAtomMVExpReplacement(ProcessModel apmodel){
		var load = apmodel.taskload.head.load
		var MVExp new_load
		
		System.out.println(apmodel.name)
		System.out.println(load)
		switch(load){ //MVExpECDFfromfile
					  MVExpECDF: new_load = IdslGeneratorSyntacticSugarECDF.sort_and_clean_ecdf_lossless( inject_abstract_product_fromfile_eCDFs(load) )
					  MVExp:	 new_load = load
					  default: 	 throw new Throwable("CreateAtomMVExpReplacement does not support non-MVExpECDF constructs")
		}
		
		// "regular" sampling
		var ProcessModel regular_pm
		switch(new_load){
			// to add: averages and means (sampling_method) for non-eCDF constructs
			MVExpCoDomain:					return	     IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVEexReplacement_MVExpRange(apmodel, new_load)
			MVExpUniform: 					return 		 IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpUniform(apmodel, new_load)
			MVExpDiscreteUniform: 			return 		 IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpDiscreteUniform(apmodel, new_load)
			MVExpNondet: 					return 		 IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpNondet(apmodel, new_load)	
			MVExpDiscreteNondet: 			return 		 IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpDiscreteNondet(apmodel, new_load)	
			
			// CDF constructs
			MVExpECDFabstract:				return 		 IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpECDFabstract(apmodel,new_load)
			MVExpECDFbasedonDSI:			return		 IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpECDFbasedonDSI(apmodel,new_load)
			MVExpECDFProduct:				return		 IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpECDF(apmodel, new_load)
			MVExpECDF: 						regular_pm = IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpECDF(apmodel, new_load)
			MVExpExponential:				return       IdslGeneatorCreateAtomMVExpReplacement.CreateAtomMVExpReplacement_MVExpECDF(apmodel, exponential_to_ecdf(new_load))			
			//MVExpECDFfromfile:			throw new Throwable("No support for MVExpECDFfromfile in CreateAtomMVExpReplacement (should have been evaluated earlier in this function")
			
			default: 						throw new Throwable("No support for AtomicProcess in CreateAtomMVExpReplacement")
		}
		
		switch(new_load){
			MVExpECDF:
			if(ptamodelchecking2) // in case of model checking 2, create non-determinstic atoms
				return create_desalt_sampling_method(regular_pm, new_load)
			else
				return regular_pm
			MVExp:     throw new Throwable("MVExp should have been resolved a few lines up. Something went wrong.")
			default:   throw new Throwable("MVExp should have been resolved a few lines up. Something went wrong.")		
		}
	}
	
	def static MVExpECDF exponential_to_ecdf (MVExpExponential load){
		var ret_ecdf    = IdslFactoryImpl::init.createMVExpECDF
		var rate_string = load.value
		var values      = exponentialDistribution (rate_string, load.prec)
		for(value:values){
			var freq_val = IdslFactoryImpl::init.createFreqValue
			freq_val.freq.add(value.key)
			freq_val.value.add(value.value)
			ret_ecdf.freqval.add(freq_val)
		}
		return ret_ecdf
	}

	def static List<Pair<Integer,Integer>> exponentialDistribution (String rate_string){
		var int multiplier = new Integer(IdslConfiguration.Lookup_value("negative_exponential_distribution_multiplier"))
		return exponentialDistribution (rate_string,multiplier)
	}
	
	// a higher multiplier leads to more precision but also to a more complex PALT construct	
	def static List<Pair<Integer,Integer>> exponentialDistribution (String rate_string, int multiplier){  
		if(multiplier==0)
			return exponentialDistribution(rate_string) // use the default rate when not defined
		
		var        ret   = new ArrayList<Pair<Integer,Integer>>
		var int    time  = 0
		var int    freq = 1
		var double rate  = Double.valueOf(rate_string) 
		
		while(freq>0){
			freq = (multiplier*Math.exp(-time*rate)) as int
			ret.add(freq -> time)
			time=time+1
		}
		return ret
	}
	
	/*def List<Integer> MVExpECDFtoValues(MVExpECDF mvexpecdf){ // transforms a MVExpECDF into a list of values
		var List<Integer> values = new ArrayList<Integer>
		for(fv:mvexpecdf.freqval)
			for(cnt:1..fv.freq.head)
				values.add(fv.value.head)
		return values
	}*/
	
	// chops a list into non-view sublists of length L
	def static List<List<Integer>> chopped(List<Integer> list, int part_size) {
	    var List<List<Integer>> parts = new ArrayList<List<Integer>>
	    val int N = list.size();
	    for(cnt:(0..N).filter[ i | i % part_size == 0])
	        if(cnt<Math.min(N, cnt + part_size)) // do not add empty lists
	        	parts.add(new ArrayList<Integer>(list.subList(cnt, Math.min(N, cnt + part_size))))
    	return parts;
	}
	
	def static List<Integer> SubsetOfValues (List<Integer> values, int num_values){
		//var List<List<Integer> values_partition = Lists.parti	
		
		var List<Integer> subset_values = new ArrayList<Integer>
		if(num_values==1){ // special case
			subset_values.add(median(values))
			return subset_values
		}
		
		for(cnt:0..(num_values-2)){
			val double elem = (1.0*cnt) / (1.0*(num_values-1)) * (values.length-1)
			val int elem1= (elem) as int
			val int elem2= (elem+1) as int
			val double value= ((1-elem%1)*values.get(elem1))+((elem%1)*values.get(elem2))
			//System.out.println(elem+" "+num_values) 
			subset_values.add(value as int)
		}
		subset_values.add(values.get(values.length-1)) // manually add the last one to prevent an array out of bounds
		return subset_values
	}
	
	def static PaltProcessModel create_probablistic_process_model (String name, List<Integer> values, int num_values){ // from values to a probablistic process
		var palt_proc 	  = IdslFactoryImpl::init.createPaltProcessModel
		var val_subset    = SubsetOfValues(values,num_values)
		
		for(value:val_subset){
			var atom_proc = IdslFactoryImpl::init.createAtomicProcessModel
			var taskload = IdslFactoryImpl::init.createTaskLoad
			var aexp 	  = IdslFactoryImpl::init.createAExpVal		
			
			System.out.println("create_probablistic_process_model name: "+name)
			aexp.value=value
			taskload.load=aexp
			atom_proc.taskload.add(taskload)
			atom_proc.name=name
				
			var prob_proc = IdslFactoryImpl::init.createProbProcess
			prob_proc.prob.add(1)	
			prob_proc.pmodel.add(atom_proc)
			
			palt_proc.ppmodel.add(prob_proc)		
		}
		palt_proc.name=name+"_subset"
		return palt_proc
	}
	
	def static AtomicProcessModel createAtomicProcessModel(String name, int taskload1, int taskload2){
			var atom_proc  = IdslFactoryImpl::init.createAtomicProcessModel
			var _taskload1 = IdslFactoryImpl::init.createTaskLoad
			var _taskload2 = IdslFactoryImpl::init.createTaskLoad
			var aexp1 	   = IdslFactoryImpl::init.createAExpVal
			var aexp2      = IdslFactoryImpl::init.createAExpVal		
			
			aexp1.value = taskload1
			aexp2.value = taskload2
			_taskload1.load = aexp1
			_taskload2.load = aexp2
			atom_proc.name=name
			atom_proc.taskload.add(_taskload1)
			atom_proc.taskload_nondet.add(_taskload2)
			
			return atom_proc		
	}
	
	def static ProcessModel create_non_deterministic_time_process (String name, List<Integer> values, int num_segments, boolean kmeans){
		var int num_iterations  				 = new Integer(IdslConfiguration.Lookup_value("number_iterations_kmeans"))
		var int max_number_iterations_in_kmeans  = new Integer(IdslConfiguration.Lookup_value("max_number_iterations_in_kmeans"))
		return create_non_deterministic_time_process(name, values, num_segments, kmeans, num_iterations, max_number_iterations_in_kmeans)
	}
	
	def static ProcessModel create_non_deterministic_time_process (String name, List<Integer> values, int num_segments, boolean kmeans,
															       int num_iterations, int max_number_iterations_in_kmeans){ // introduce non-deterministic time
		var palt_proc 	  		= IdslFactoryImpl::init.createPaltProcessModel
		var segment_edges 		= SubsetOfValues(values,num_segments+1) 
		val num_needed_segments = Math.min(num_segments,values.length) // if segments>num_values, no simplification is needed.

		// cluster the values in "num_segments" clusters	
		var Pair<Double,List<List<Integer>>> cluster_score_and_value_parts
		if(kmeans) // k-means clustering
			cluster_score_and_value_parts = IdslGeneratorKmeans.iterative_k_means_clustering (values, num_segments, num_iterations, max_number_iterations_in_kmeans) // segments determined by k-means clustering
		else // equally sized clusters
			throw new Throwable("create_non_deterministic_time_process: equally sized clusters disabled")
			//value_parts = chopped(values,(values.length/num_needed_segments)+1)	// segments of equal with
		
		for(value_part:cluster_score_and_value_parts.value){
			val taskload1 = value_part.head
			val taskload2 = value_part.last
			//System.out.println ("Debug "+name+" "+taskload1+" "+taskload2)
			var atom_proc = createAtomicProcessModel(name, taskload1, taskload2)
			
			var prob_proc = IdslFactoryImpl::init.createProbProcess
			prob_proc.prob.add(value_part.length)	
			prob_proc.pmodel.add(atom_proc)
			
			palt_proc.ppmodel.add(prob_proc)
		}		
		palt_proc.name=name+"_nondettime"
		palt_proc.kmeans_clustering_score.add((Math.sqrt(cluster_score_and_value_parts.key/values.length)).toString) // write the NORMALIZED cluster value to the model
		//palt_proc.kmeans_clustering_score.add((cluster_score_and_value_parts.key).toString) // TEST ONLY!!
		return palt_proc
	}
	
	def static void AddLoadBalancerPolicyToTheDesignSpaceModel (DesignSpaceModel dsm, String lb_name, int num_policies){
		System.out.println("Adding load balancer policy "+lb_name+" to the DesignSpace") // DEBUG
		var DesignSpaceParam dsp = IdslFactoryImpl::init.createDesignSpaceParam
		dsp.variable.add("lb_policy_"+lb_name)
		
		for(cnt:0..num_policies-1)
			dsp.value.add(cnt.toString)
		
		dsm.dsparam.add(dsp)
	}
	
	// Add the sampling method to the DesignSpaceModel when configuration "enable_dsi_sampling_method" is enabled
	def static void AddSamplingMethodToDesignSpaceModel (DesignSpaceModel dsm,  String value, boolean add_constraint){
		var num_segments = new Integer(IdslConfiguration.Lookup_value("number_of_simplified_models_with_nondeterministic_segments"))
		AddSamplingMethodToDesignSpaceModel (dsm, value, add_constraint, num_segments)
	}
	
	def static void AddSamplingMethodToDesignSpaceModel (DesignSpaceModel dsm,  String value, boolean add_constraint, int num_segments ){
		System.out.println("Adding samplingmethod to the DesignSpace") // DEBUG
		var DesignSpaceParam dsp = IdslFactoryImpl::init.createDesignSpaceParam
		dsp.variable.add("samplingmethod")
		if(value!=null)
			dsp.value.add(value)

		for(int power2:0..num_segments)
			dsp.value.add("ecdf"+Math.pow(2,power2) as int)
		
		dsm.dsparam.add(dsp)
		//add_constraint_to_limit_dimension_to_one_value(dsm, "samplingmethod", "ecdf"+Math.pow(2,0) as int) // first element of the dimension
		//add_constraint_to_enforce_sampling_method_regular(dsm)
	}
	
	def static void AddModelTimeUnitToDesignSpaceModelAndMultiplyValues (DesignSpaceModel dsm, MultiplyResults mresults, boolean add_constraint){
		var timeunits = new Integer(IdslConfiguration.Lookup_value("number_of_simplified_models_with_modeltimeunits"))
		AddModelTimeUnitToDesignSpaceModelAndMultiplyValues (dsm, mresults, add_constraint, timeunits)
	}
	
	// Add the time unit to the DesignSpaceModel when configuration "enable_model_time_unit" is enabled
	def static void AddModelTimeUnitToDesignSpaceModelAndMultiplyValues (DesignSpaceModel dsm, MultiplyResults mresults, boolean add_constraint, int timeunits){
		// modify DSM
		var DesignSpaceParam dsp = IdslFactoryImpl::init.createDesignSpaceParam
		dsp.variable.add("modeltimeunit")

		for(int power2:0..timeunits)
			dsp.value.add(""+Math.pow(2,power2) as int)
		
		dsm.dsparam.add(dsp)
		//add_constraint_to_limit_dimension_to_one_value(dsm, "modeltimeunit", ""+Math.pow(2,0) as int) // first element of the dimension

		// modify mresults
		for(int power2:0..timeunits){
			var mresult = IdslFactoryImpl::init.createMultiplyResult
			mresult.dsm_values.add("modeltimeunit_"+Math.pow(2,power2) as int+"_")
			mresult.factor.add(Math.pow(2,power2) as int)
			mresults.multiplyresult.add(mresult)
		}		
	}
	
	def static void add_constraint_to_limit_dimension_to_one_value (DesignSpaceModel dsm, String dimension, String value){	
		System.out.println("Constraining DSM dimension "+dimension+" to value "+value)
		
		var constraint_dspace_regular		  = IdslFactoryImpl::init.createBExpconstraint
		var dspace_is_value	 				  = IdslFactoryImpl::init.createBExpCmpString
		var dspace_dimension 			  	  = IdslFactoryImpl::init.createBExpDspace
		var regular_string				      = IdslFactoryImpl::init.createBExpString
		dspace_dimension.param.add(dimension)
		
		regular_string.value.add(value)
		dspace_is_value.bexpds_left.add(dspace_dimension)
		dspace_is_value.bcmpop.add("eq")
		dspace_is_value.bexpds_right.add(regular_string)
		
		constraint_dspace_regular.bexp.add(dspace_is_value)
		dsm.constraint.add(constraint_dspace_regular)		
	}	
	
	def static void add_constraint_to_enforce_sampling_method_regular (DesignSpaceModel dsm){	//add a constraint "dspace(sampling_methods) eq regular" to enforce the regular sampling method
		var constraint_dspace_regular		  = IdslFactoryImpl::init.createBExpconstraint
		var dspace_sampling_method_is_regular = IdslFactoryImpl::init.createBExpCmpString
		var dspace_sampling_method 			  = IdslFactoryImpl::init.createBExpDspace
		var regular_string				      = IdslFactoryImpl::init.createBExpString
		dspace_sampling_method.param.add("samplingmethod")
		
		regular_string.value.add("regular")
		dspace_sampling_method_is_regular.bexpds_left.add(dspace_sampling_method)
		dspace_sampling_method_is_regular.bcmpop.add("eq")
		dspace_sampling_method_is_regular.bexpds_right.add(regular_string)
		
		constraint_dspace_regular.bexp.add(dspace_sampling_method_is_regular)
		dsm.constraint.add(constraint_dspace_regular)		
	}
	
	def static ProcessModel create_desalt_sampling_method (ProcessModel regular, MVExpECDF load){
		//if(IdslConfiguration.Lookup_value("enable_dsi_sampling_method")=="false")
		//	return regular // only the regular sampling method is used and no "sampling method" reference is made

		var values = value_list (load)
		var name   = regular.name
		
		switch(regular){ // take the name of a palt branch in case of a paltprocessmodel to get rid of the extension, e.g., "_cdf"
			PaltProcessModel: name = regular.ppmodel.head.pmodel.head.name
		}

		var SelectProcessModel regular_select = IdslFactoryImpl::init.createSelectProcessModel
		regular_select.select.add("regular")
		regular_select.pmodel.add(regular)

		/*var ProcessModel ecdf_100 = create_probablistic_process_model(name, values, 100 )
		var SelectProcessModel ecdf_100_select = IdslFactoryImpl::init.createSelectProcessModel
		ecdf_100_select.select.add("ecdf_100")
		ecdf_100_select.pmodel.add(ecdf_100)*/

		var DesAltProcessModel sampling_method_pm = IdslFactoryImpl::init.createDesAltProcessModel
		sampling_method_pm.param.add("samplingmethod")
		sampling_method_pm.pmodel.add(regular_select)
	
		for(int power2:0..new Integer(IdslConfiguration.Lookup_value("number_of_simplified_models_with_nondeterministic_segments")))
			sampling_method_pm.pmodel.add(create_non_deterministic_select_process_model(name,values,Math.pow(2,power2) as int,regular))

		return sampling_method_pm		
	}
	
	def static SelectProcessModel create_non_deterministic_select_process_model (String process_name, List<Integer> values, int segments, ProcessModel regular){
		val boolean kmeans 		 = true // kmeans clustering method to obtain "reasonable" clusters
		var ProcessModel ecdf_pm = create_non_deterministic_time_process(process_name, values, segments, kmeans)
		var SelectProcessModel ecdf_select_pm = IdslFactoryImpl::init.createSelectProcessModel
		ecdf_select_pm.select.add("ecdf"+segments.toString)
		ecdf_select_pm.pmodel.add(ecdf_pm)	
		return ecdf_select_pm	
	}
	
	def static MVExpECDF inject_abstract_product_fromfile_eCDFs (MVExpECDF load){
		switch(load){
			MVExpECDFProduct:  { var List<MVExpECDF> new_ecdfs = new ArrayList<MVExpECDF>
								 for(ecdf:load.ecdfs) 
								 	new_ecdfs.add ( inject_abstract_product_fromfile_eCDFs (ecdf) )
								 load.ecdfs.clear
								 load.ecdfs.addAll(new_ecdfs)	
							   }
			MVExpECDFfromfile: return IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file (load.num_samples, load.filename, load.is_ratio)							   
			MVExpECDFabstract: return IdslGeneatorCreateAtomMVExpReplacement.retrieve_MVExpECDFabstract (load)
		}
		return load
	}	
	
	def static MVExpECDF replace_exponentialDistributionCDF (MVExpExponential mv_exponential){
		var ret_ecdf    = IdslFactoryImpl::init.createMVExpECDF
		var rate_string = mv_exponential.value
		var values      = exponentialDistribution (rate_string)
		for(value:values){
			var freq_val = IdslFactoryImpl::init.createFreqValue
			freq_val.freq.add(value.key)
			freq_val.value.add(value.value)
			ret_ecdf.freqval.add(freq_val)
		}
		return ret_ecdf
	}

	def static ProcessModel CreateSeqParReplacement (ProcessModel pmodel){
		var SeqParProcessModel spmodel
		switch (pmodel){SeqParProcessModel: spmodel=pmodel default: throw new Throwable("CreateSeqParReplacement only handles SeqPars")}
		var syncf = spmodel.sf
		switch (syncf){
			SyncFrequencyOnce:		return CreateSeqParReplacement_SyncFrequencyOnce(spmodel)
			SyncFrequencyAlways: 	return CreateSeqParReplacement_SyncFrequencyAlways(spmodel)
			SyncFrequencySometimes: return CreateSeqParReplacement_SyncFrequencySometimes(spmodel, syncf)
			default:				throw new Throwable("SyncFrequency of SeqPar not defined")			
		}
	}
	
	def static ProcessModel CreateSeqParReplacement_SyncFrequencyAlways(SeqParProcessModel spmodel){
		var pm_return=IdslFactoryImpl::init.createSeqProcessModel
		pm_return.name=spmodel.name
		pm_return.pmodel.addAll(spmodel.pmodel)
		return pm_return
	}
	
	def static ProcessModel CreateSeqParReplacement_SyncFrequencyOnce(SeqParProcessModel spmodel){
		var pm_return=IdslFactoryImpl::init.createParProcessModel
		pm_return.name=spmodel.name
		for(cnt:(0..spmodel.pmodel.head.pmodel.length-1)){ // enumerate over size of first PAR
			var pm_seq=IdslFactoryImpl::init.createSeqProcessModel
			if (spmodel.name==null) pm_seq.name="par"+cnt else pm_seq.name=spmodel.name+"_par"+cnt
			
			for(par_pm:spmodel.pmodel){
				pm_seq.pmodel.add(par_pm.pmodel.get(0))
			}
			pm_return.pmodel.add(pm_seq)
		}
		return pm_return
	}
	
	// UNDER CONSTRUCTION -- UNDER CONSTRUCTION -- UNDER CONSTRUCTION -- UNDER CONSTRUCTION -- UNDER CONSTRUCTION //
	def static ProcessModel CreateSeqParReplacement_SyncFrequencySometimes(SeqParProcessModel spmodel, SyncFrequencySometimes sf){
		var pm_return=IdslFactoryImpl::init.createSeqProcessModel
		var List<Integer> sync_afters = sf.turn
		pm_return.name=spmodel.name
		
		var List<List<ParProcessModel>> ppm_list2 = new ArrayList<List<ParProcessModel>> // create a partition of synced processes
		var previous_sa=0
		for(sa:sync_afters){
			var List<ParProcessModel> ppm_list = new ArrayList<ParProcessModel>
			ppm_list.addAll(spmodel.pmodel.subList(previous_sa,sa))
			ppm_list2.add(ppm_list)
			previous_sa=sa
		}
		
		// TO-DO create a sequence of SEQPAR processes here that sync once 
		
		//System.out.println(ppm_list2.toString)
	/*	for (par:spmodel.pmodel){
			var SeqParProcessModel seqpar=IdslFactoryImpl::init.createSeqParProcessModel
			//seqpar.pmodel.add(par)
			pm_return.pmodel.add(CreateSeqParReplacement_SyncFrequencyOnce(seqpar))
		} */
		return pm_return
	}
	
	// Creates a  AtomicProcessModel with a given name and fixed load value
	def static AtomicProcessModel CreateAtomMV_with_load (String process_name, int value){ 
		var pm_taskload = IdslFactoryImpl::init.createTaskLoad
		var exp_val=IdslFactoryImpl::init.createAExpVal 
		var aprocess=IdslFactoryImpl::init.createAtomicProcessModel
		
		exp_val.setValue(value)
		pm_taskload.setLoad(exp_val)
		aprocess.name=process_name
		aprocess.taskload.add(pm_taskload)
		
		return aprocess
	}
	
	def static ProcessModel buildDESALTtree_from_product_of_dsis(List<MVExpECDFbasedonDSI> dsi_cdfs, String atom_names){
		var List<MVExpECDF> ecdfs_so_far =            new ArrayList<MVExpECDF>
		var List<MVExpECDFbasedonDSI> dsi_cdfs_copy = new ArrayList<MVExpECDFbasedonDSI>
		dsi_cdfs_copy.addAll(dsi_cdfs) // hardcopy
		
		System.out.println("dsi_cdfs_length: "+dsi_cdfs_copy.length) // TEMPORARY
		
		buildDESALTtree_from_product_of_dsis(dsi_cdfs, ecdfs_so_far, 0, atom_names)
	}
	
	def static ProcessModel CreateProcessWithNameAndLoad(String name, int load_value){
		var atom     = IdslFactoryImpl::init.createAtomicProcessModel
		var taskload = IdslFactoryImpl::init.createTaskLoad
		var expval   = IdslFactoryImpl::init.createAExpVal	
		
		expval.value  = load_value
		taskload.load = expval
		atom.name     = name
		atom.taskload.add(taskload)
		
		return atom
	}
	
	def static ProcessModel buildDESALTtree_from_product_of_dsis(List<MVExpECDFbasedonDSI> dsi_cdfs, List<MVExpECDF> ecdfs_so_far, int index, String atom_names){
		if(index==dsi_cdfs.length) { // base case. TOADD: implement product of ecdfs_so_far
			var atom = IdslFactoryImpl::init.createAtomicProcessModel
			var load = IdslFactoryImpl::init.createTaskLoad
			var load_ecdfs = IdslFactoryImpl::init.createMVExpECDFProduct
			
			for(ecdf:ecdfs_so_far){
				//System.out.println("ecdfs_for_loop: "+ecdf.freqval.toString)
				var ecdf_copy=IdslGeneratorDeepCopy.deepcopy(ecdf)
				load_ecdfs.ecdfs.add(ecdf_copy)
			} 
			
			var MVExpECDF load_ecdfs_eval = IdslGeneratorSyntacticSugarECDF.multiply_eCDFs(load_ecdfs.ecdfs)
		
			load.load = load_ecdfs_eval   // evaluate product
			//load.load = load_ecdfs	  // do not evaluate product
			atom.name=atom_names
			atom.taskload.add(load)
			 
			//return atom
			
			var ProcessModel mean = CreateProcessWithNameAndLoad(atom_names, arithmetic_mean (value_list(load_ecdfs_eval)))
			var ProcessModel median = CreateProcessWithNameAndLoad(atom_names, median(value_list(load_ecdfs_eval)))
			//var ProcessModel regular = CreateAtomMVExpReplacement(atom) 
			var regular = IdslGeneatorCreateAtomMVExpReplacement.
				CreateAtomMVExpReplacement_MVExpECDF(atom, load_ecdfs_eval /*atom.taskload.head.load as MVExpECDF*/)

			return create_desalt_sampling_method(regular, load_ecdfs_eval)
		}
		
		var MVExpECDFbasedonDSI dsi_cdf = dsi_cdfs.get(index) // (index)
		//System.out.println("index: "+index) // TEMPORARY
		var param=dsi_cdf.param.head
		var size=dsi_cdf.select_ecdfs.length
		
		//System.out.println("size: "+size) // TEMPORARY
		//System.out.println("param: "+param) // TEMPORARY
		
		var desalt = IdslFactoryImpl::init.createDesAltProcessModel
		desalt.name="no_name"
		desalt.param.add(param)
		
		for(cnt:0..size-1){
			//desalt.pmodel.add(buildDESALTtree(params.tail.toList, num_options.tail.toList))	
			var new_ecdfs_so_far=new ArrayList<MVExpECDF>
			new_ecdfs_so_far.addAll(ecdfs_so_far)			// copy the old list
			new_ecdfs_so_far.add(dsi_cdf.select_ecdfs.get(cnt).ecdf.head) // and add the new one
			//System.out.println("Add_cdf_to_so_far: "+dsi_cdf.ecdfs.get(cnt).freqval.toString) // TEMPORARY
			
			//System.out.println("index + cnt: "+index.toString+" "+cnt.toString) // TEMPORARY
			var List<MVExpECDFbasedonDSI> dsi_cdfs_copy = new ArrayList<MVExpECDFbasedonDSI>
			dsi_cdfs_copy.addAll(dsi_cdfs) // hardcopy
			
			var select_pm = IdslFactoryImpl::init.createSelectProcessModel
			select_pm.select.add( dsi_cdf.select_ecdfs.get(cnt).select.head )
			//select_pm.select.add( param+"xxx"+cnt)
			select_pm.pmodel.add( buildDESALTtree_from_product_of_dsis(dsi_cdfs_copy, new_ecdfs_so_far, index+1, atom_names) )
			desalt.pmodel.add(select_pm)
		}
		return desalt
	}
	
	def static add_empty_frequencies(List<MVExpECDF> ecdfs){
		for(ecdf:ecdfs)
			add_empty_frequencies(ecdf)
	}
	
	def static add_empty_frequencies(MVExpECDF ecdf){
		for(freqval:ecdf.freqval)
			if(freqval.freq.length==0)
				freqval.freq.add(1) // no frequency given, implies 1
	}
	
	def static void main(String[] args) {
		//val values = #[1,8,14,14,18,19,20,56,78,104,145,145,160,170]
		//val granularity = 4
		//System.out.println(SubsetOfValues(values,10))	
		//var x = chopped(values,7)
		//System.out.println(x)
		//for(cnt:(0..values.length-1).filter[i | i %(values.length/(granularity-1)) == 0])
		//	System.out.println(values.get(cnt))
		
		var p   = IdslFactoryImpl::init.createAtomicProcessModel
		var tl  = IdslFactoryImpl::init.createTaskLoad
		var e   = IdslFactoryImpl::init.createAExpVal
		
		p.name     = "abc"
		e.value    = 100
		tl.load    = e
		p.taskload.add(tl)
		
		var p2   = IdslFactoryImpl::init.createAtomicProcessModel
		var tl2  = IdslFactoryImpl::init.createTaskLoad
		var e2   = IdslFactoryImpl::init.createAExpVal
		
		p2.name     = "abc"
		e2.value    = 200
		tl2.load    = e2
		p2.taskload.add(tl2)		
		
		var seq_pm  = IdslFactoryImpl::init.createSeqProcessModel
		for(cnt:1..5){ //repetitions
			seq_pm.pmodel.add(p)
			seq_pm.pmodel.add(p2)
			seq_pm.pmodel.add(p)
			seq_pm.pmodel.add(p2)			
		}
		
		var List<ProcessModel> ps = new ArrayList<ProcessModel>
		ps.add(p)
		ps.add(p2)
		ps.add(p)
		ps.add(p2)

	}
	
}