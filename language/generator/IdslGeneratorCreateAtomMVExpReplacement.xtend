package org.idsl.language.generator

import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.impl.IdslFactoryImpl
import org.idsl.language.idsl.MVExpNondet
import org.idsl.language.idsl.MVExpDiscreteNondet
import org.idsl.language.idsl.MVExpUniform
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.MVExpDiscreteUniform
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.MVExpECDFfromfile
import org.idsl.language.idsl.MVExpECDFabstract
import org.idsl.language.idsl.MVExpECDFbasedonDSI
import org.idsl.language.idsl.SelectProcessModel
import org.idsl.language.idsl.MVExpECDFProduct
import java.util.ArrayList
import java.util.List
import org.idsl.language.idsl.MVExpCoDomain

class IdslGeneatorCreateAtomMVExpReplacement {
	def static ProcessModel CreateAtomMVEexReplacement_MVExpRange(ProcessModel apmodel, MVExpCoDomain load){
		var pm_return=IdslFactoryImpl::init.createAltProcessModel
		var values=load.value

		pm_return.name = apmodel.name+"_Range"		
		for(value:values){
			var pm_subalt=IdslFactoryImpl::init.createAtomicProcessModel
			var pm_subload=IdslFactoryImpl::init.createAExpVal
			var pm_taskload = IdslFactoryImpl::init.createTaskLoad
			
			pm_subload.value=value
			pm_taskload.load=pm_subload
			pm_subalt.name=apmodel.name
			pm_subalt.taskload.add(pm_taskload)
			pm_return.pmodel.add(pm_subalt)
		}
		return pm_return
	}
	
	def static ProcessModel CreateAtomMVExpReplacement_MVExpNondet(ProcessModel apmodel, MVExpNondet load){
		var pm_return=IdslFactoryImpl::init.createAltProcessModel
		val lbound = load.min
		val ubound = load.max		
		
		pm_return.name = apmodel.name+"_Nondet"
		for(cnt:(lbound..ubound)){ // create ALT branches with increasing taskload, one by one
			var pm_subalt=IdslFactoryImpl::init.createAtomicProcessModel
			var pm_subload=IdslFactoryImpl::init.createAExpExpr
			var pm_taskload = IdslFactoryImpl::init.createTaskLoad
			
			pm_subalt.name=apmodel.name
			// Create AExp in 3 steps
			var exp_a1=IdslFactoryImpl::init.createAExpVal // a1
			exp_a1.setValue(cnt)
			pm_subload.a1.add(exp_a1)
			var exp_a2=IdslFactoryImpl::init.createAExpMiniform // a2
			pm_subload.a2.add(exp_a2)
			pm_subload.op.add("+") // op			
			
			pm_taskload.load=pm_subload
			pm_subalt.taskload.add(pm_taskload)
			pm_return.pmodel.add(pm_subalt)
		}		
		
		return pm_return
	}
	
	def static ProcessModel CreateAtomMVExpReplacement_MVExpDiscreteNondet(ProcessModel apmodel, MVExpDiscreteNondet load){
		var pm_return=IdslFactoryImpl::init.createAltProcessModel
		val lbound = load.min
		val ubound = load.max		
		
		pm_return.name = apmodel.name+"_DiscreteNondet"
		for(cnt:(lbound..ubound)){ // create ALT branches with increasing taskload, one by one
			var pm_subalt=IdslFactoryImpl::init.createAtomicProcessModel
			var pm_subload=IdslFactoryImpl::init.createAExpVal
			var pm_taskload = IdslFactoryImpl::init.createTaskLoad
			
			pm_subalt.name=apmodel.name
			pm_subload.value=cnt
			pm_taskload.load=pm_subload
			pm_subalt.taskload.add(pm_taskload)
			pm_return.pmodel.add(pm_subalt)
		}		
		return pm_return
	}
	
	def static ProcessModel CreateAtomMVExpReplacement_MVExpUniform(ProcessModel apmodel, MVExpUniform load){
		var pm_return=IdslFactoryImpl::init.createPaltProcessModel
		val lbound = load.min
		val ubound = load.max

		pm_return.name = apmodel.name+"_Uniform"
		for(cnt:(lbound..ubound)){ // create PALT branches with increasing taskload, one by one
			var pm_subpalt=IdslFactoryImpl::init.createAtomicProcessModel
			var pm_subload=IdslFactoryImpl::init.createAExpExpr
			var pm_taskload = IdslFactoryImpl::init.createTaskLoad
			var pm_probproc = IdslFactoryImpl::init.createProbProcess
			
			pm_subpalt.name=apmodel.name
			// Create AExp in 3 steps
			var exp_a1=IdslFactoryImpl::init.createAExpVal // a1
			exp_a1.setValue(cnt)
			pm_subload.a1.add(exp_a1)
			var exp_a2=IdslFactoryImpl::init.createAExpMiniform // a2
			pm_subload.a2.add(exp_a2)
			pm_subload.op.add("+") // op
			
			pm_taskload.load=pm_subload
			pm_subpalt.taskload.add(pm_taskload)
			pm_probproc.prob.add(1)
			pm_probproc.pmodel.add(pm_subpalt)
			
			pm_return.ppmodel.add(pm_probproc)
		}
		return pm_return
	}
	
	def static PaltProcessModel CreateAtomMVExpReplacement_MVExpDiscreteUniform(ProcessModel apmodel, MVExpDiscreteUniform load){
		var pm_return=IdslFactoryImpl::init.createPaltProcessModel
		val lbound = load.min
		val ubound = load.max

		pm_return.name = apmodel.name+"_DiscreteUniform"
		for(cnt:(lbound..ubound)){ // create PALT branches with increasing taskload, one by one
			var pm_subpalt=IdslFactoryImpl::init.createAtomicProcessModel
			var pm_subload=IdslFactoryImpl::init.createAExpVal
			var pm_taskload = IdslFactoryImpl::init.createTaskLoad
			var pm_probproc = IdslFactoryImpl::init.createProbProcess
			
			pm_subpalt.name=apmodel.name
			pm_subload.value=cnt
			pm_taskload.load=pm_subload
			pm_subpalt.taskload.add(pm_taskload)
			pm_probproc.prob.add(1)
			pm_probproc.pmodel.add(pm_subpalt)
			
			pm_return.ppmodel.add(pm_probproc)
		}
		return pm_return
	}
	
	def static ProcessModel CreateAtomMVExpReplacement_MVExpECDF(ProcessModel apmodel, MVExpECDF load1){
		var load = IdslGeneratorSyntacticSugarECDF.sort_and_clean_ecdf_lossless(load1)
		
		var pm_return=IdslFactoryImpl::init.createPaltProcessModel
		
		pm_return.name = apmodel.name+"_eCDF"
		for(elem:(load.freqval)){
			var pm_subpalt = IdslFactoryImpl::init.createAtomicProcessModel
			var pm_subload = IdslFactoryImpl::init.createAExpVal
			var pm_taskload = IdslFactoryImpl::init.createTaskLoad
			var pm_probproc = IdslFactoryImpl::init.createProbProcess

			pm_subpalt.name=apmodel.name
			pm_subload.value=elem.value.head
			pm_taskload.load=pm_subload
			pm_subpalt.taskload.add(pm_taskload)
			if(elem.freq.length==0)	{pm_probproc.prob.add(1)} else {pm_probproc.prob.add(elem.freq.head)}
			pm_probproc.pmodel.add(pm_subpalt)
			
			pm_return.ppmodel.add(pm_probproc)
		}	
		return pm_return
	}
	
	def static ProcessModel CreateAtomMVExpReplacement_MVExpECDFfromfile(ProcessModel apmodel, MVExpECDFfromfile load){
		var MVExpECDF nonfile_cdf 			= IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file (load.num_samples, load.filename, load.is_ratio)
		var MVExpECDF nonfile_cdf_copy		= IdslGeneratorDeepCopy.deepcopy(nonfile_cdf) // deepcopy
		return CreateAtomMVExpReplacement_MVExpECDF(apmodel,nonfile_cdf_copy)
	} 
	
	def static ProcessModel CreateAtomMVExpReplacement_MVExpECDFabstract(ProcessModel apmodel, MVExpECDFabstract load){
		//var MVExpECDF nonabstract_cdf 			= IdslGeneratorSyntacticSugarECDF.lookup_eCDF_call(load)
		//var MVExpECDF nonabstract_cdf_copy		= IdslGeneratorDeepCopy.deepcopy(nonabstract_cdf) // deepcopy
		//WARNING: NEXT LINE REPLACES ABOVE TWO
		var MVExpECDF nonabstract_cdf_copy =  retrieve_MVExpECDFabstract (load)
		//return CreateAtomMVExpReplacement_MVExpECDF(apmodel,nonabstract_cdf_copy)
		var new_load =  IdslFactoryImpl::init.createTaskLoad
		new_load.load = nonabstract_cdf_copy
		apmodel.taskload.clear
		apmodel.taskload.add(new_load)
		return IdslGeneratorSyntacticSugar.CreateAtomMVExpReplacement(apmodel)
	}
	
	
	// TO DO: SEE IF THE FUNCTION WORKS IN CONTEXT OF CreateAtomMVExpReplacement_MVExpECDFabstract (ABOVE)
	// TO DO: IMPLEMENT THIS FUNCTION RECURSIVELY IN THE PRODUCT
	// TO DO: MAKE SURE THAT ADDED THINGS IN THE PRODUCT RECEIVE THIS TREATMENT AGAIN TOO
	def static MVExpECDF retrieve_MVExpECDFabstract (MVExpECDFabstract load){
		var MVExpECDF nonabstract_cdf 			= IdslGeneratorSyntacticSugarECDF.lookup_eCDF_call(load)
		var MVExpECDF nonabstract_cdf_copy		= IdslGeneratorDeepCopy.deepcopy(nonabstract_cdf) // deepcopy		
		return nonabstract_cdf_copy
	}
	
	def static ProcessModel CreateAtomMVExpReplacement_MVExpECDFbasedonDSI(ProcessModel apmodel, MVExpECDFbasedonDSI load){
		var pm_return =  IdslFactoryImpl::init.createDesAltProcessModel
		pm_return.name = apmodel.name+"_eCDFbasedonDSI"
		pm_return.param.add(load.param.head)
				
		for(sel_ecdf:load.select_ecdfs){ // Convert all eCDFs into PALTs, with an overarching DesAltProcessModel
			var MVExpECDF ecdf_copy
			var SelectProcessModel select_cdf = IdslFactoryImpl::init.createSelectProcessModel
			var select= sel_ecdf.select.head  
			var ecdf=   sel_ecdf.ecdf.head

			switch (ecdf){
				MVExpECDFfromfile:   ecdf_copy=IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(ecdf.num_samples, ecdf.filename, "ratio")
				MVExpECDFbasedonDSI: throw new Throwable("CreateAtomMVExpReplacement_MVExpECDFbasedonDSI: nested MVExpECDFbasedonDSIs not supported") 
				MVExpECDF:			 { ecdf_copy=ecdf }
				default: 			 throw new Throwable("CreateAtomMVExpReplacement_MVExpECDFbasedonDSI: nested type <UNKNOWN> not supported") 
			}
			IdslGeneratorSyntacticSugar.add_empty_frequencies(ecdf_copy)
			
			var pm_alt = CreateAtomMVExpReplacement_MVExpECDF(apmodel,ecdf_copy)
			pm_alt.name = apmodel.name  // override the given name	
			
			select_cdf.select.add(select)
			select_cdf.pmodel.add(pm_alt)
			pm_return.pmodel.add(select_cdf)
		}
		return pm_return
	}

	def static ProcessModel CreateAtomMVExpReplacement_MVExpECDF(ProcessModel apmodel, MVExpECDFProduct load){		
		var List<MVExpECDF> ecdf_list = 			new ArrayList<MVExpECDF>
		var List<MVExpECDF> product_product =		new ArrayList<MVExpECDF> // to store nested products
		
		for(ecdf:load.ecdfs){ // turn eCDF file ones in regular eCDFs. They are not process models and therefore skipped earlier
			switch(ecdf){
				MVExpECDFfromfile: 		ecdf_list.add( IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(ecdf.num_samples, ecdf.filename, "ratio") )
				MVExpECDFbasedonDSI:	return CreateAtomMVExpReplacement_MVExpECDF_product_with_dsis(apmodel, load) // special case: product with DSIs
				MVExpECDFProduct:		product_product.addAll( ecdf.ecdfs ) // lifting the products to a higher level
				MVExpECDFabstract:		ecdf_list.add( retrieve_MVExpECDFabstract (ecdf) )
				default:		   		ecdf_list.add( ecdf )
			}
		}

		for(ecdf:product_product){ // All eCDFs that are nested in two levels of products
			switch(ecdf){
				MVExpECDFfromfile: 		ecdf_list.add( IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(ecdf.num_samples, ecdf.filename, "ratio") )
				MVExpECDFbasedonDSI:    {	ecdf_list.addAll(product_product)
											return CreateAtomMVExpReplacement_MVExpECDF_product_with_dsis(apmodel, ecdf_list) // special case: product with DSIs
									 	}
				MVExpECDFabstract:		ecdf_list.add( retrieve_MVExpECDFabstract (ecdf) )
				default:		   		ecdf_list.add( ecdf )
			}
		}		
		
		for(ecdf:ecdf_list) // fill in value 1 as DEFAULT
			IdslGeneratorSyntacticSugar.add_empty_frequencies(ecdf)
		
		var MVExpECDF product_cdf = IdslGeneratorSyntacticSugarECDF.multiply_eCDFs(ecdf_list)
		var ProcessModel mean     = IdslGeneratorSyntacticSugar.CreateProcessWithNameAndLoad(
			apmodel.name, IdslGeneratorSyntacticSugar.arithmetic_mean (IdslGeneratorSyntacticSugar.value_list(product_cdf))
		)
		var ProcessModel median   = IdslGeneratorSyntacticSugar.CreateProcessWithNameAndLoad(
			apmodel.name, IdslGeneratorSyntacticSugar.median(IdslGeneratorSyntacticSugar.value_list(product_cdf))
		)
		var ProcessModel regular  = CreateAtomMVExpReplacement_MVExpECDF(apmodel,product_cdf)	
		
		if(IdslGeneratorGlobalVariables.ptamodelchecking2)
			return IdslGeneratorSyntacticSugar.create_desalt_sampling_method(regular, product_cdf)
		else
			return CreateAtomMVExpReplacement_MVExpECDF(apmodel,product_cdf)		
	}
	
	def static CreateAtomMVExpReplacement_MVExpECDF_product_with_dsis(ProcessModel apmodel, MVExpECDFProduct load){
		// A product CDF containing dspaces. Convert it into a DESALT of eCDFs (which are computed products)
		var List<MVExpECDFbasedonDSI> dsi_cdfs		= IdslGeneratorSyntacticSugarECDF.convert_ECDFs_to_ECDFs_dsi(load.ecdfs)
		var ProcessModel process_tree				= IdslGeneratorSyntacticSugar.buildDESALTtree_from_product_of_dsis(dsi_cdfs, apmodel.name)
		process_tree.name=apmodel.name+"_dsiproduct"
		return process_tree
	}
	
	def static CreateAtomMVExpReplacement_MVExpECDF_product_with_dsis(ProcessModel pmodel, List<MVExpECDF> ecdfs){ //overloading
		var MVExpECDFProduct ecdf_product = IdslFactoryImpl::init.createMVExpECDFProduct
		ecdf_product.ecdfs.addAll(ecdfs)
		CreateAtomMVExpReplacement_MVExpECDF_product_with_dsis(pmodel, ecdf_product)
	}
}