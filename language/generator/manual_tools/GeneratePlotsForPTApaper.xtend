package org.idsl.language.generator.manual_tools

import java.util.ArrayList
import java.util.List
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.generator.IdslGeneratorSyntacticSugarECDF

class GeneratePlotsForPTApaper {
	def static void main(String[] args) {
		//System.out.println(new Integer(" 7"))
		
		//plot_test
		plot_milliseconds_512
		//plot_bounds_512
		//plot_subset_512
		
		plot_milliseconds_1024
		//plot_bounds_1024	
		System.out.println("done")	
	}   
	
	def static plot_test(){
		var String fldr					= "P:\\cdfs_biplane\\"
		var String dsi_path				= "Y:\\simple2.idsl_15-3-2015a\\_SCN_sc_DSE_offset_15_\\"
		var List<MVExpECDF> ecdfs 		= new ArrayList<MVExpECDF>
		var List<String>    labels      = new ArrayList<String>
		
		labels.add("measurement")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], fldr+"010fps_0512_mono.cdf#SUM_bruto",""))
		labels.add("model checking (pmin)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"ExpPTAModelChecking\\modes_theo_bounds_p1-lb-pmin-cdf.out",""))
		labels.add("model checking (pmax)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"ExpPTAModelChecking\\modes_theo_bounds_p1-lb-pmax-cdf.out",""))
		labels.add("simulations")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"ExpSimulation_1_5\\run_1\\ProcessMapping_p1-latencies.out!2",""))
		
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(fldr+"plots\\plot_test.pdf", ecdfs, labels)		
	}
	
	def static plot_bounds_512(){
		var String fldr					= "P:\\cdfs_biplane\\"
		var String dsi_path				= "F:\\paper 2015 pta model checking\\idsl_experiments\\bounds.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_512_samplingmethod_ecdf1_\\ExpPTAModelChecking\\"
		var String dsi_path_simulation	= "F:\\paper 2015 pta model checking\\idsl_experiments\\bounds_simulation.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_512_\\ExpSimulation_1_100\\run_1\\"
		var List<MVExpECDF> ecdfs 		= new ArrayList<MVExpECDF>
		var List<String>    labels      = new ArrayList<String>
		
		labels.add("measurement")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], fldr+"010fps_mono_subset.cdf#sum_3processes_512",""))
		labels.add("model checking (pmin)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmin-cdf.out!0",""))
		labels.add("model checking (pmax)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmax-cdf.out!0",""))
		labels.add("simulation")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path_simulation+"ProcessMapping_Image_Processing-latencies.out!2",""))
		
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(fldr+"plot_bounds_512.pdf", ecdfs, labels)
	}
	
	def static plot_subset_512(){
		var String fldr					= "P:\\cdfs_biplane\\"
		var String dsi_path				= "F:\\paper 2015 pta model checking\\idsl_experiments\\regular_subset.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_512_\\ExpPTAModelChecking\\"
		var String dsi_path_simulation	= "F:\\paper 2015 pta model checking\\idsl_experiments\\regular_subset.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_512_\\ExpSimulation_1_100\\run_1\\"
		var List<MVExpECDF> ecdfs 		= new ArrayList<MVExpECDF>
		var List<String>    labels      = new ArrayList<String>	
		
		labels.add("measurement")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], fldr+"010fps_mono_subset.cdf#sum_2processes_512",""))
		labels.add("model checking (pmin)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmin-cdf.out!0",""))
		labels.add("model checking (pmax)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmax-cdf.out!0",""))
		labels.add("simulation")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path_simulation+"ProcessMapping_Image_Processing-latencies.out!2",""))
	
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(fldr+"plot_subset_512.pdf", ecdfs, labels)		
	}

	def static plot_milliseconds_512(){
		var String fldr					= "P:\\cdfs_biplane\\"
		
		// COPY THE FOLLOWING RESULTS TO F:
		var String dsi_path				= "F:\\paper 2015 pta model checking\\idsl_experiments\\milliseconds_512.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_512_\\ExpPTAModelChecking\\"
		var String dsi_path_simulation	= "F:\\paper 2015 pta model checking\\idsl_experiments\\milliseconds_simulation.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_512_\\ExpSimulation_1_100\\run_1\\"
		var List<MVExpECDF> ecdfs 		= new ArrayList<MVExpECDF>
		var List<String>    labels      = new ArrayList<String>	
		
		labels.add("measurement")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], fldr+"010fps_0512_mono.cdf#SUM_bruto",""))
		labels.add("model checking (pmin)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.multiply_ECDF(250,IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmin-cdf.out!0","")))
		labels.add("model checking (pmax)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.multiply_ECDF(250,IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmax-cdf.out!0","")))
		labels.add("simulation")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path_simulation+"ProcessMapping_Image_Processing-latencies.out!2",""))
	
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(fldr+"plot_milliseconds_0512.pdf", ecdfs, labels)		
	}

	def static plot_bounds_1024(){
		var String fldr					= "P:\\cdfs_biplane\\"
		var String dsi_path				= "F:\\paper 2015 pta model checking\\idsl_experiments\\bounds.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_1024_samplingmethod_ecdf1_\\ExpPTAModelChecking\\"
		var String dsi_path_simulation	= "F:\\paper 2015 pta model checking\\idsl_experiments\\bounds_simulation.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_1024_\\ExpSimulation_1_100\\run_1\\"
		var List<MVExpECDF> ecdfs 		= new ArrayList<MVExpECDF>
		var List<String>    labels      = new ArrayList<String>	
		
		labels.add("measurement")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], fldr+"010fps_mono_subset.cdf#sum_3processes_1024",""))
		labels.add("model checking (pmin)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmin-cdf.out!0",""))
		labels.add("model checking (pmax)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmax-cdf.out!0",""))
		labels.add("simulation")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file (#[], dsi_path_simulation+"ProcessMapping_Image_Processing-latencies.out!2",""))
	
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(fldr+"plot_bounds_1024.pdf", ecdfs, labels)		
	}
	
	def static plot_milliseconds_1024(){
		var String fldr					= "P:\\cdfs_biplane\\"
		var String dsi_path				= "F:\\paper 2015 pta model checking\\idsl_experiments\\milliseconds.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_1024_\\ExpPTAModelChecking\\"
		var String dsi_path_simulation	= "F:\\paper 2015 pta model checking\\idsl_experiments\\milliseconds_simulation.idsl_EXPERIMENT\\_SCN_BiPlane_Image_Processing_run_DSE_resolution_1024_\\ExpSimulation_1_100\\run_1\\"
		var List<MVExpECDF> ecdfs 		= new ArrayList<MVExpECDF>
		var List<String>    labels      = new ArrayList<String>	
		
		labels.add("measurement")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], fldr+"010fps_1024_mono.cdf#SUM_bruto",""))
		labels.add("model checking (pmin)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.multiply_ECDF(800,IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmin-cdf.out!0","")))
		labels.add("model checking (pmax)")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.multiply_ECDF(800,IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path+"modes_theo_bounds_Image_Processing-lb-pmax-cdf.out!0","")))
		labels.add("simulation")
		ecdfs.add(IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file(#[], dsi_path_simulation+"ProcessMapping_Image_Processing-latencies.out!2",""))
	
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(fldr+"plot_milliseconds_1024.pdf", ecdfs, labels)		
	}
}	