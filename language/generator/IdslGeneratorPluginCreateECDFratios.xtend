package org.idsl.language.generator

import java.util.ArrayList
import java.util.List
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.ValidityResult
import org.idsl.language.idsl.impl.IdslFactoryImpl
import java.io.File

class IdslGeneratorPluginCreateECDFratios {	
	var static frame_rate_default 				= "010"
	var static frame_rate_default_aggregate		= "010" // a different frame-rate for the aggregated runs
	var static target 							= IdslConfiguration.Lookup_value("cdf_ratios_filename") // P:\\cdfs_biplane\\ratio 
	
	var static base_cdf_filename 				= base_path+"fluoroAcqOnly_"+frame_rate_default+"fps_0512\\Measurements.gannt.cdf"
	var static r1024_cdf_filename				= base_path+"fluoroAcqOnly_"+frame_rate_default+"fps_1024\\Measurements.gannt.cdf"
	var static r2048_cdf_filename				= base_path+"fluoroAcqOnly_"+frame_rate_default+"fps_2048\\Measurements.gannt.cdf"
	
	var static biplane_cdf_filename   		    = biplane_path+"fluoroAcqOnly_"+frame_rate_default+"fps_0512\\Measurements.gannt.cdf"
	var static target_cdf_filename				= biplane_path+"fluoroAcqOnly_"+frame_rate_default+"fps_1024\\Measurements.gannt.cdf"
	
	def static base_path() 			    { return base_path("1") } 
	def static base_path(String run)    { return "P:\\TestPerformance_runmono"+run+"\\" }	
	def static biplane_path() 		    { return biplane_path("1") }
	def static biplane_path(String run) { return "P:\\TestPerformance_Xres4_Intel_Run0"+run+"\\" }
	
	// paths for aggregated 005fps eCDFs
	def static aggregate_path(String resolution, String mode, String function) { // resolution in {0512,1024,2048}, mode in {mono,bi}
		if (!(resolution=="0512" || resolution=="1024" || resolution=="2048"))
			throw new UnsupportedOperationException("aggregate_path: resolution out of range")
		if (!(mode=="mono" || mode=="bi"))
			throw new UnsupportedOperationException("aggregate_path: mode out of range")
				
		return "P:\\TestPerformance_aggregation\\"+frame_rate_default_aggregate+"fps_"+resolution+"_"+mode+".cdf#"+function
	}
	def static aggregate_target()       { return  IdslConfiguration.Lookup_value("cdf_ratios_filename") + "_aggregate" } // P:\\cdfs_biplane\\ratio_aggregate}  
	def static aggregate_base()			{ return  aggregate_path("0512","mono","SUM_bruto") }
	def static aggregate_base_no_func()	{ return  aggregate_path("0512","mono","") } // function to be added later
	def static aggregate_1024()			{ return  aggregate_path("1024","mono","") } // function to be added later
	def static aggregate_2048()			{ return  aggregate_path("2048","mono","") } // function to be added later
	def static aggregate_biplane()		{ return  aggregate_path("0512","bi","") }   // function to be added later
	def static aggregate_target_dsi()   { return  aggregate_path("1024","bi","1Felix") } // the target DSI to be predicted in the graphs
	
	def static void compute_eCDF_ratios (){ // Create all the needed CDF ratios
		compute_eCDF_ratios(false, true, true) // no debugging and running everything, by default
	}
	
	def static void compute_eCDF_ratios (boolean debug_mode, boolean evaluate_single, boolean evaluate_aggregated){
		if(evaluate_single)
			compute_eCDF_ratios_single_run(debug_mode)
		if(evaluate_aggregated)
			compute_eCDF_ratios_aggregated_runs(debug_mode)
	}
	
	def static void compute_eCDF_ratios_aggregated_runs (boolean debug_mode){ //aggregate_target
		var File f = new File(aggregate_target)
		if(f.exists)     throw new Throwable("compute_eCDF_ratios_aggregated_runs: ratio file already exists")	
		if (debug_mode)  throw new UnsupportedOperationException("compute_eCDF_ratios_aggregated_runs: Debug facility not yet supported")
		
		// ID ratio
		val int multiplier = new Integer(IdslConfiguration.Lookup_value("ecdf_quotient_multiplier"))
		//var List<Integer> values= new ArrayList<Integer>;values.add(multiplier);values.add(multiplier)
		var List<Integer> values= #[multiplier,multiplier]
		var ecdf_id = IdslGeneratorSyntacticSugarECDF.create_eCDF_from_values(values)
		IdslGeneratorSyntacticSugarECDF.write_ECDF_to_file(aggregate_target+"#id", ecdf_id)
		
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Basic",	   		aggregate_base,	aggregate_target+"#FREEK")// for testing purposes
		
		// Target divided by base. To validate prediction (product of 3 dimension ratios)
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_target_dsi,						aggregate_base,	aggregate_target+"#target_base")
		
		//  Dimension: function (does not reveal any Philips information) 
		/*IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Basic",	   			aggregate_base,	aggregate_target+"#p_basic")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Compose",  			aggregate_base, aggregate_target+"#p_comp1")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Decompose",			aggregate_base,	aggregate_target+"#p_decomp1")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Felix",				aggregate_base,	aggregate_target+"#p_space_nr")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1McTemp",			aggregate_base,	aggregate_target+"#p_temp_nr")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Reorientation",		aggregate_base,	aggregate_target+"#p_pre_proc")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"2Compose",			aggregate_base,	aggregate_target+"#p_comp2")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"2Decompose",			aggregate_base,	aggregate_target+"#p_decomp2")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"2Unique",			aggregate_base,	aggregate_target+"#p_refine1")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"3Compose",			aggregate_base,	aggregate_target+"#p_comp3")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"3Decompose",			aggregate_base,	aggregate_target+"#p_decomp3")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"3Unique",			aggregate_base,	aggregate_target+"#p_refine2")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"PADDING",			aggregate_base,	aggregate_target+"#p_padding")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"SUM_netto",			aggregate_base,	aggregate_target+"#SUM_netto")*/

		// backup in original terms, in case called differently
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Basic",	   			aggregate_base,	aggregate_target+"#1Basic")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Compose",  			aggregate_base, aggregate_target+"#1Compose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Decompose",			aggregate_base,	aggregate_target+"#1Decompose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Felix",				aggregate_base,	aggregate_target+"#1Felix")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1McTemp",			aggregate_base,	aggregate_target+"#1McTemp")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"1Reorientation",		aggregate_base,	aggregate_target+"#1Reorientation")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"2Compose",			aggregate_base,	aggregate_target+"#2Compose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"2Decompose",			aggregate_base,	aggregate_target+"#2Decompose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"2Unique",			aggregate_base,	aggregate_target+"#2Unique")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"3Compose",			aggregate_base,	aggregate_target+"#3Compose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"3Decompose",			aggregate_base,	aggregate_target+"#3Decompose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"3Unique",			aggregate_base,	aggregate_target+"#3Unique")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"PADDING",			aggregate_base,	aggregate_target+"#PADDING")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_base_no_func+"SUM_netto",			aggregate_base,	aggregate_target+"#SUM_netto")

		// Dimension resolution: 512,1024,2048
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_1024+"SUM_bruto",	   				aggregate_base,	aggregate_target+"#res_1024")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_2048+"SUM_bruto",	 	  			aggregate_base,	aggregate_target+"#res_2048")
		
		// Dimension mode: monoplane, biplane
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(aggregate_biplane+"SUM_bruto",				aggregate_base,	aggregate_target+"#mode_biplane")
		
		System.out.println("Generating aggregated ratios: done!")					
	}
	
	def static void compute_eCDF_ratios_single_run (boolean debug_mode){ // Create all the needed CDF ratios for single run based eCDFs
		var File f = new File(target)
		if(f.exists)     throw new Throwable("compute_eCDF_ratios_aggregated_runs: ratio file already exists")
		if (debug_mode)  throw new UnsupportedOperationException("compute_eCDF_ratios_single_run: Debug facility not yet supported")
		
		// ID ratio
		val int multiplier = new Integer(IdslConfiguration.Lookup_value("ecdf_quotient_multiplier"))
		//var List<Integer> values= new ArrayList<Integer>;values.add(multiplier);values.add(multiplier)
		var List<Integer> values= #[multiplier,multiplier]
		var ecdf_id = IdslGeneratorSyntacticSugarECDF.create_eCDF_from_values(values)
		IdslGeneratorSyntacticSugarECDF.write_ECDF_to_file(target+"#id", ecdf_id)
		
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Basic",	   		base_cdf_filename+"#SUM_bruto",	target+"#FREEK")// for testing purposes
		
		// Target divided by base. To validate prediction (product of 3 dimension ratios)
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(target_cdf_filename+"#1Felix",		base_cdf_filename+"#SUM_bruto",	target+"#target_base")
		
		//  Dimension: function (does not reveal any Philips information) 
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Basic",	   		base_cdf_filename+"#SUM_bruto",	target+"#p_basic")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Compose",  		base_cdf_filename+"#SUM_bruto", target+"#p_comp1")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Decompose",		base_cdf_filename+"#SUM_bruto",	target+"#p_decomp1")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Felix",			base_cdf_filename+"#SUM_bruto",	target+"#p_space_nr")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1McTemp",		base_cdf_filename+"#SUM_bruto",	target+"#p_temp_nr")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Reorientation",	base_cdf_filename+"#SUM_bruto",	target+"#p_pre_proc")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#2Compose",		base_cdf_filename+"#SUM_bruto",	target+"#p_comp2")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#2Decompose",		base_cdf_filename+"#SUM_bruto",	target+"#p_decomp2")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#2Unique",		base_cdf_filename+"#SUM_bruto",	target+"#p_refine1")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#3Compose",		base_cdf_filename+"#SUM_bruto",	target+"#p_comp3")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#3Decompose",		base_cdf_filename+"#SUM_bruto",	target+"#p_decomp3")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#3Unique",		base_cdf_filename+"#SUM_bruto",	target+"#p_refine2")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#PADDING",		base_cdf_filename+"#SUM_bruto",	target+"#p_padding")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#SUM_netto",		base_cdf_filename+"#SUM_bruto",	target+"#SUM_netto")

		// backup in original terms, in case called differently
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Basic",	   		base_cdf_filename+"#SUM_bruto",	target+"#1Basic")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Compose",  		base_cdf_filename+"#SUM_bruto", target+"#1Compose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Decompose",		base_cdf_filename+"#SUM_bruto",	target+"#1Decompose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Felix",			base_cdf_filename+"#SUM_bruto",	target+"#1Felix")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1McTemp",		base_cdf_filename+"#SUM_bruto",	target+"#1McTemp")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#1Reorientation",	base_cdf_filename+"#SUM_bruto",	target+"#1Reorientation")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#2Compose",		base_cdf_filename+"#SUM_bruto",	target+"#2Compose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#2Decompose",		base_cdf_filename+"#SUM_bruto",	target+"#2Decompose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#2Unique",		base_cdf_filename+"#SUM_bruto",	target+"#2Unique")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#3Compose",		base_cdf_filename+"#SUM_bruto",	target+"#3Compose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#3Decompose",		base_cdf_filename+"#SUM_bruto",	target+"#3Decompose")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#3Unique",		base_cdf_filename+"#SUM_bruto",	target+"#3Unique")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#PADDING",		base_cdf_filename+"#SUM_bruto",	target+"#PADDING")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(base_cdf_filename+"#SUM_netto",		base_cdf_filename+"#SUM_bruto",	target+"#SUM_netto")

		// Dimension resolution: 512,1024,2048
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(r1024_cdf_filename+"#SUM_bruto",	   	base_cdf_filename+"#SUM_bruto",	target+"#res_1024")
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(r2048_cdf_filename+"#SUM_bruto",	   	base_cdf_filename+"#SUM_bruto",	target+"#res_2048")
		
		// Dimension mode: monoplane, biplane
		IdslGeneratorSyntacticSugarECDF.compute_eCDF_ratio(biplane_cdf_filename+"#SUM_bruto",	base_cdf_filename+"#SUM_bruto",	target+"#mode_biplane")
		
		System.out.println("Generating ratios: done!")
	}
	
	def static void produce_vCDFs(){
		var vcdf_output_path        = "P:\\vcdf\\"
		
		var List<MVExpECDF> ecdfs = new ArrayList<MVExpECDF>
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], base_cdf_filename+"#SUM_netto",null)) // null==no_ratio
		
		var MVExpECDF product = IdslGeneratorSyntacticSugarECDF.multiply_eCDFs(ecdfs)
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file( vcdf_output_path+"abc", product)
	}
	
	def static MVExpECDF create_vcdf(int mono_biplane, int resolution, int function){ // compose a vcdf (=product of ratio and base), based on a DSI
	 	var String mono_biplane_filename
	 	var String resolution_filename
	 	var String function_filename
	 	
	 	switch(mono_biplane){
			case 0: mono_biplane_filename = target+"#id" //default: mono
			case 1: mono_biplane_filename = target+"#id"
			case 2: mono_biplane_filename = target+"#mode_biplane" //default: mono
			default: throw new Throwable("create_vcdf: illegal mono_biplane parameter") 		
	 	}
	 	
	 	switch(resolution){
			case 0:	 resolution_filename = target+"#id" //default: 512
			case 1:	 resolution_filename = target+"#id"
			case 2:  resolution_filename = target+"#res_1024"
			case 3:  resolution_filename = target+"#res_2048" //default: 512
			default: throw new Throwable("create_vcdf: illegal resolution parameter")	 		
	 	}
	 	
	 	switch(function){
	 		case 0:  function_filename=target+"#id" //default:SUM_bruto
			case 1:  function_filename=target+"#1Basic"
			case 2:  function_filename=target+"#1Compose"
			case 3:  function_filename=target+"#1Decompose"
			case 4:  function_filename=target+"#1Felix"
			case 5:  function_filename=target+"#1McTemp"
			case 6:  function_filename=target+"#1Reorientation"
			case 7:  function_filename=target+"#2Compose"
			case 8:  function_filename=target+"#2Decompose"
			case 9:  function_filename=target+"#2Unique"
			case 10: function_filename=target+"#3Compose"	
			case 11: function_filename=target+"#3Decompose"
			case 12: function_filename=target+"#3Unique"	
			case 13: function_filename=target+"#PADDING" 
			case 14: function_filename=target+"#SUM_netto"
			case 15: function_filename=target+"#id" //default:SUM_bruto
			default: throw new Throwable("create_vcdf: illegal function parameter")
				 		
			/*case 0:  function_filename = target+"#id" //default:SUM_bruto
			case 1:  function_filename = target+"#p_basic"
			case 2:  function_filename = target+"#p_comp1"
			case 3:  function_filename = target+"#p_space_nr"
			case 4:  function_filename = target+"#p_temp_nr"
			case 5:  function_filename = target+"#p_pre_proc"
			case 6:  function_filename = target+"#p_comp2"
			case 7:  function_filename = target+"#p_decomp2"
			case 8:  function_filename = target+"#p_refine1"
			case 9:  function_filename = target+"#p_comp3"
			case 10: function_filename = target+"#p_decomp3"
			case 11: function_filename = target+"#p_refine2"
			case 12: function_filename = target+"#p_padding"	
			case 13: function_filename = target+"#SUM_netto"
			case 14: function_filename = target+"#id"	 //default:SUM_bruto	*/
			//default: throw new Throwable("create_vcdf: illegal function parameter")	 		
	 	}
	 	
	 	var List<MVExpECDF> ecdfs = new ArrayList<MVExpECDF>
	 	ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], "P:\\TestPerformance_runmono1\\fluoroAcqOnly_"+frame_rate_default+"fps_0512\\Measurements.gannt.cdf#SUM_bruto",null)) // null==no_ratio
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], mono_biplane_filename,"ratio"))
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], resolution_filename,"ratio"))
	 	ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], function_filename,"ratio"))
	 	
	 	var MVExpECDF product = IdslGeneratorSyntacticSugarECDF.multiply_eCDFs(ecdfs)
	 	//System.out.println("vcdf---\n"+IdslGeneratorSyntacticSugarECDF.eCDF_to_string(product))
	 	return product
	}
	
	
	def static String generate_ecdf_filename(int mono_biplane, int resolution, int function){ // default resolution=30
		generate_ecdf_filename(mono_biplane, -1, resolution, function) // framerate=-1 -> take global frame-rate
	}
	
	def static String generate_ecdf_filename(int mono_biplane, int framerate, int resolution, int function){ // composes a ecdf filename, based on a DSI
		// example filename: "P:\\TestPerformance_runmono1\\fluoroAcqOnly_030fps_0512\\Measurements.gannt.cdf"
		// a parameter value of 0 refers to the default value
		var String fn // filename
		switch(mono_biplane){
			case 0: fn = "P:\\TestPerformance_runmono1\\" // default
			case 1: fn = "P:\\TestPerformance_runmono1\\"
			case 2: fn = "P:\\TestPerformance_Xres4_Intel_Run01\\"
			default: throw new Throwable("generate_ecdf_filename: illegal mono_biplane parameter")
		}
		fn=fn+"fluoroAcqOnly_"
		switch(framerate){
			case -1: fn=fn+frame_rate_default // default, when no framerate chosen
			case 0:	 fn=fn+"005" // default
			case 1:  fn=fn+"005"
			case 2:  fn=fn+"010" 
			case 3:  fn=fn+"015"
			case 4:  fn=fn+"030"
			case 5:  fn=fn+"060"
			case 6:  fn=fn+"120"
			case 7:  fn=fn+"240"
			default: throw new Throwable("generate_ecdf_filename: illegal framerate parameter")
		}
		fn=fn+"fps_"
		switch(resolution){			
			case 0:	 fn=fn+"0512" // default
			case 1:	 fn=fn+"0512"
			case 2:  fn=fn+"1024"
			case 3:  fn=fn+"2048"
			default: throw new Throwable("generate_ecdf_filename: illegal resolution parameter")
		}
		fn=fn+"\\Measurements.gannt.cdf"
		switch(function){
			case 0:  fn=fn+"#SUM_bruto" // default : sum bruto
			case 1:  fn=fn+"#1Basic"
			case 2:  fn=fn+"#1Compose"
			case 3:  fn=fn+"#1Decompose"
			case 4:  fn=fn+"#1Felix"
			case 5:  fn=fn+"#1McTemp"
			case 6:  fn=fn+"#1Reorientation"
			case 7:  fn=fn+"#2Compose"
			case 8:  fn=fn+"#2Decompose"
			case 9:  fn=fn+"#2Unique"
			case 10: fn=fn+"#3Compose"	
			case 11: fn=fn+"#3Decompose"
			case 12: fn=fn+"#3Unique"	
			case 13: fn=fn+"#PADDING" 
			case 14: fn=fn+"#SUM_bruto"
			case 15: fn=fn+"#SUM_bruto" // default: sum bruto
			default: throw new Throwable("generate_ecdf_filename: illegal function parameter")
		}
		return fn
	}

	def static List<ValidityResult> create_validation_list_with_dsi_and_ecdf (){
		var List<ValidityResult> vresults = new ArrayList<ValidityResult>
		for(mode:1..2)
			for(resolution:1..3){
				var ValidityResult vresult = IdslFactoryImpl::init.createValidityResult
				var dsm_value      = "resolution_"+resolution+"_mode_"+mode+"_framerate_"+"15"+"_numinstances_"+"1"+"_"
				var ecdf_filename  = generate_ecdf_filename(mode, 3, resolution, -1)
				var ecdf		   = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file (#[], ecdf_filename, null)
				
				vresult.dsm_values.add(dsm_value) 
				vresult.ecdf.add(ecdf)
				System.out.print(dsm_value+",")
				System.out.println(ecdf_filename)
			}
		return vresults
		/* (resolution{"512" "1024" "2048"})(mode{"monoplane" "biplane"})(framerate{"15"})(numinstances{"1"/}) */
	}
	
	def static void create_a_vcdf_and_ecdf_per_dsi(){ create_a_vcdf_and_ecdf_per_dsi(true,true,true) }
	
	def static void create_a_vcdf_and_ecdf_per_dsi(boolean create_ecdfs, boolean create_vcdfs, boolean combi_cdfs){
		for(mono_biplane:0..2) // 0..2
		 	for(resolution:0..3) // 0..3
		  		for(function:0..15){ //0..15
					var ecdf       = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(mono_biplane,resolution,function),null)
					var vcdf       = create_vcdf(mono_biplane,resolution,function)
					var dsi_string = mono_biplane.toString+"_"+resolution.toString+"_"+function.toString
					val both_cdfs  = #[ecdf, vcdf]
					var legends    = #["ecdf","vcdf"]
					var graph_path = IdslConfiguration.Lookup_value("cdf_graph_path") // e.g., "P:\\cdfs_biplane\\graphs\\"

					System.out.println("XXXX "+IdslGeneratorSyntacticSugarECDF.eCDF_to_string(ecdf)) // DEBUG ONLY

					if(create_ecdfs) 
						IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+dsi_string+"_ecdf",ecdf)
					if(create_vcdfs) 
						IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+dsi_string+"_vcdf",vcdf)
					if(combi_cdfs)
						IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+dsi_string+"_combi",both_cdfs,legends)
						
					System.out.println("graph(s) for DSI "+dsi_string+" plotted.")
				}		
	}

	def static void create_ratio_graphs_for_valuetools(String graph_path){
		create_ratio_graphs_for_valuetools(graph_path, true, true) // evaluate everything, by default
	}
	
	def static void create_ratio_graphs_for_valuetools (String graph_path, boolean evaluate_single, boolean evaluate_aggregated){
		if (evaluate_single)
			create_ratio_graphs_for_valuetools_single_run(graph_path)
		if (evaluate_aggregated)
			create_ratio_graphs_for_valuetools_aggregated(graph_path)
	}

	def static void create_ratio_graphs_for_valuetools_aggregated(String graph_path){ // prints the base eCDF and all eCDFs that only differ in one dimension from it 
		System.out.println("start: printing aggregated load graphs")
		
		// load graphs for 005fps aggregated
		var MVExpECDF aggr_base         = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_path("0512","mono","SUM_netto"),null)
		var MVExpECDF aggr_biplane      = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_path("0512","bi","SUM_netto"),null)
		var MVExpECDF aggr_1024         = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_path("1024","mono","SUM_netto"),null)
		var MVExpECDF aggr_2048         = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_path("2048","mono","SUM_netto"),null)
		var MVExpECDF aggr_temp         = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_path("0512","mono","1McTemp"),null)
		var MVExpECDF aggr_spatial      = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_path("0512","mono","1Felix"),null)
		var MVExpECDF aggr_bi_1024		= IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_path("1024","bi","SUM_bruto"),null)
		var MVExpECDF aggr_bi_2048		= IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_path("2048","bi","SUM_bruto"),null)
		
		val List<MVExpECDF> cdfs_no2048 = #[aggr_base,  aggr_biplane, aggr_1024, aggr_2048, aggr_temp, aggr_spatial, aggr_bi_1024, aggr_bi_2048]	
		val List<String> legends_no2048 = #["dsi_base","(sum_512_biplane)", "(sum_1024_mono)", "(sum_2048_mono)","(f_temp,512,mono)","(f_spatial,512,mono)","(sum_1024_bi)","(sum_2048_bi)"]

		val List<MVExpECDF> cdfs_bimono_only = #[aggr_base,aggr_biplane]
		val List<String> legends_bimono_only = #["(sum_512_mono)","(sum_512_biplane)"]
		// bimono_only
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"aggregated_graph_bimono_only",cdfs_bimono_only,legends_bimono_only,"time(ms)","Cumulative probability P","1000")

		//IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"graph",cdfs,legends,"time(\u03BCs)","Cumulative probability","1000")
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"aggregated_graph_without_2048_new",cdfs_no2048,legends_no2048,"time(ms)","Cumulative probability P","1000")
		System.out.println("done: printing aggregated load graphs")

		// print ratio graph
		var MVExpECDF rat_base		    = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_target+"#id", "ratio") 
		var MVExpECDF rat_mod_biplane   = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_target+"#mode_biplane", "ratio")
		var MVExpECDF rat_res_1024      = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_target+"#res_1024", "ratio") 
		var MVExpECDF rat_res_2028      = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_target+"#res_2048", "ratio")
		var MVExpECDF rat_pro_temp      = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_target+"#1McTemp", "ratio") 
		var MVExpECDF rat_pro_spatial   = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_target+"#1Felix", "ratio") 
		var MVExpECDF rat_target_base   = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], aggregate_target+"#target_base", "ratio")
				
		// Compute product of 3 ratios
		var List<MVExpECDF> ratio_cdfs_no2048_without_product = #[rat_mod_biplane, rat_res_1024, rat_pro_spatial]
		var MVExpECDF product = IdslGeneratorSyntacticSugarECDF.multiply_eCDFs(ratio_cdfs_no2048_without_product, 10000, 6)
		product.is_ratio="ratio"
		
		var List<MVExpECDF> ratio_cdfs_no2048= #[rat_mod_biplane, rat_res_1024, rat_pro_spatial, product, rat_target_base]
		
		// TEMPORARY EMPTY FOR NOW
		//var List<String> ratio_legends_no2048 = #["","","","",""]		
		//FOR INSERTING LEGENDS
		var List<String> ratio_legends_no2048 = #["(sum_512_biplane)", "(sum_1024_mono)","(f_1,512,mono)", "product", "target_base"]

		//IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"ratio_graph",ratio_cdfs,ratio_legends,"relative load","Cumulative probability","1000000")
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"aggregated_ratio_graph_without_2048",ratio_cdfs_no2048,ratio_legends_no2048,"relative execution time","Cumulative probability","1000000")
		System.out.println("done: printing aggregated ratio graphs")
	}
	
	
	def static void create_ratio_graphs_for_valuetools_single_run(String graph_path){ // prints the base eCDF and all eCDFs that only differ in one dimension from it 
		System.out.println("start: printing load graphs")
		
		// print load graphs
		var MVExpECDF base		        = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(0, 0, 0),null) // parameters: mode, resolution, function
		var MVExpECDF mod_biplane       = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(2, 0, 0),null)
		var MVExpECDF res_1024          = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(0, 2, 0),null) 
		var MVExpECDF res_2028          = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(0, 3, 0),null)
		var MVExpECDF pro_temp          = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(0, 0, 5),null) 
		var MVExpECDF pro_spatial       = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(0, 0, 4),null)
		var MVExpECDF bi_1024			= IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(2, 2, 0),null)
		var MVExpECDF bi_2048			= IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], generate_ecdf_filename(2, 3, 0),null)		
 	
		//val List<MVExpECDF> cdfs        = #[base, mod_biplane, res_1024, res_2028, pro_temp, pro_spatial]	
		//val List<String> legends        = #["base","m_biplane","rs_1024","rs_2048","f_temp","f_spatial"]
		val List<MVExpECDF> cdfs_no2048 = #[base,  mod_biplane, res_1024, res_2028, pro_temp, pro_spatial, bi_1024, bi_2048]	
		val List<String> legends_no2048 = #["dsi_base","(sum_512_biplane)", "(sum_1024_mono)", "res_2048", "(f_temp,512,mono)","(f_spatial,512,mono)","(sum,1024,bi)","(sum,2048,bi)"]

		val List<MVExpECDF> cdfs_bimono_only = #[base /*,mod_biplane*/]
		val List<String> legends_bimono_only = #[/*"",*/""]
		// bimono_only
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"graph_bimono_only",cdfs_bimono_only,legends_bimono_only,"time(\u03BCs)","Cumulative probability P","1000")

		//IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"graph",cdfs,legends,"time(\u03BCs)","Cumulative probability","1000")
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"graph_without_2048_new",cdfs_no2048,legends_no2048,"time(\u03BCs)","Cumulative probability P","1000")
		System.out.println("done: printing load graphs")

		// print ratio graph
		var MVExpECDF rat_base		    = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], target+"#id", "ratio") 
		var MVExpECDF rat_mod_biplane   = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], target+"#mode_biplane", "ratio")
		var MVExpECDF rat_res_1024      = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], target+"#res_1024", "ratio") 
		var MVExpECDF rat_res_2028      = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], target+"#res_2048", "ratio")
		var MVExpECDF rat_pro_temp      = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], target+"#p_temp_nr", "ratio") 
		var MVExpECDF rat_pro_spatial   = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], target+"#p_space_nr", "ratio") 
		var MVExpECDF rat_target_base   = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], target+"#target_base", "ratio")
		
		//var List<MVExpECDF> ratio_cdfs  = #[rat_base, rat_mod_biplane, rat_res_1024, rat_res_2028, rat_pro_temp, rat_pro_spatial]	
		//var List<String> ratio_legends  = #["base","m_biplane","rs_1024","rs_2048","f_temp","f_spatial"]
		
		//original ones:
		//var List<MVExpECDF> ratio_cdfs_no2048 = #[rat_base, rat_mod_biplane, rat_res_1024, /*rat_res_2028,*/ rat_pro_temp, rat_pro_spatial]	
		//var List<String> ratio_legends_no2048 = #["dsi_base","(sum_512_biplane)", "(sum_1024_mono)",/* "res_2048",*/"(f_temp,512,mono)","(f_spatial,512,mono)"]
		
		
		// Compute product of 3 ratios
		var List<MVExpECDF> ratio_cdfs_no2048_without_product = #[rat_mod_biplane, rat_res_1024, rat_pro_spatial]
		var MVExpECDF product = IdslGeneratorSyntacticSugarECDF.multiply_eCDFs(ratio_cdfs_no2048_without_product, 10000, 6)
		product.is_ratio="ratio"
		
		var List<MVExpECDF> ratio_cdfs_no2048= #[rat_mod_biplane, rat_res_1024, rat_pro_spatial, product, rat_target_base]
		
		// TEMPORARY EMPTY FOR NOW
		var List<String> ratio_legends_no2048 = #["","","","",""]		
		//FOR INSERTING LEGENDS
		//var List<String> ratio_legends_no2048 = #["(sum_512_biplane)", "(sum_1024_mono)","(f_1,512,mono)", "product"]

		//IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"ratio_graph",ratio_cdfs,ratio_legends,"relative load","Cumulative probability","1000000")
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(graph_path+"ratio_graph_without_2048",ratio_cdfs_no2048,ratio_legends_no2048,"relative execution time","Cumulative probability","1000000")
		System.out.println("done: printing ratio graphs")
	}
	
	def static void remove_eCDF_ratios(){ // deletes the two ratio files
		var File f1 = new File(IdslConfiguration.Lookup_value("cdf_ratios_filename") + "_aggregate")
		if(f1.delete)
			System.out.println("Deleted "+f1.name)
		var File f2 = new File(IdslConfiguration.Lookup_value("cdf_ratios_filename"))
		if(f2.delete)
			System.out.println("Deleted "+f2.name)
	}

	def static void main(String[] args) {
		/*var List<String> filenames = new ArrayList<String>
		filenames.add("d:\\cdfs#product1")
		filenames.add("d:\\cdfs#product2")
		filenames.add("d:\\cdfs#product3")
		filenames.add("d:\\cdfs#product4")
		multiply_eCDFs_from_file (filenames)*/
		
		for(frames_per_second:#["010"]){   // create graphs for frame-rate   // ,"010","015"
			System.out.println("Case "+frames_per_second)
			frame_rate_default_aggregate = frames_per_second
			remove_eCDF_ratios ()
			compute_eCDF_ratios (false, false, true)
			//create_ratio_graphs_for_valuetools( "P:\\cdfs_biplane\\valuetools\\"+frame_rate_default_aggregate+"_", false, true )
		}
		
		
		//frame_rate_default 			= "010" // overrides default 
		//frame_rate_default_aggregate	= "005" // overrides default
		
			
		//remove_eCDF_ratios () // removes the ratios files
		
		// compute_eCDF_ratios (true) // divide several eCDFs by the base eCDF AND show intermediate results
	    //compute_eCDF_ratios (false, false, true) // divide several eCDFs by the base eCDF
		
		//produce_vCDFs 		// multiply the base with ratios, to reach virtual CDFs for a certain DSI
		//create_a_vcdf_and_ecdf_per_dsi(true,true,true)
		//create_a_vcdf_and_ecdf_per_dsi(false,false,true)
		//create_a_vcdf_and_ecdf_per_dsi(true,false,false)
		
		//create_ratio_graphs_for_valuetools( "P:\\cdfs_biplane\\valuetools\\"+frame_rate_default_aggregate+"_", false, true )
		//create_validation_list_with_dsi_and_ecdf
		

	}
}
