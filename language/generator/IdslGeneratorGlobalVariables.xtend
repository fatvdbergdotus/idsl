package org.idsl.language.generator

import java.util.ArrayList
import java.util.List
import java.util.Set
import org.idsl.language.idsl.ProcessResource
import org.idsl.language.idsl.LoadBalancerConfiguration

class IdslGeneratorGlobalVariables {	
	public static var String    lop_and_loi_file_contents = ""  // the lop and loi contents to be stored in a file
	public static var boolean   ptamodelchecking2 			// is the ptamodelchecking2 measure used in the model? (-> nondeterministic segments for atoms
	
	public static int global_random_counter=0
	public static int global_noname_counter=0
	public static Set<String> global_processes_to_print
	public static Set<Pair<String,LoadBalancerConfiguration>> global_resources_to_print // 2nd parameter indicates that is an energy resource that can be switched off.
	public static Set<ProcessResource> global_processresources_to_print
	public static List<String> global_filenames_cdf_dsis
	public static String global_dsm_values
	public static String global_DSL_text // DSL instance text
	public static boolean add_global_counter_to_modest_code = false // process "global_time" is needed for load balancing to keep track of time.
	
	// ******************************************************************************************************************************************************************	
	// Variable for the Main batch file contents
	private static List<String> contents_of_main_batch_file = new ArrayList<String>
	private static List<String> contents_of_main_batch_output_file = new ArrayList<String>
	private static List<String> contents_of_main_batch_file_description = new ArrayList<String>
	private static List<String> contents_of_main_batch_file_dsi = new ArrayList<String>
	
	def public static global_contents_of_main_batch_file_add(String str, String output_str, String descr){ 
		contents_of_main_batch_file.add(str)
		contents_of_main_batch_output_file.add(output_str)
		contents_of_main_batch_file_description.add(descr)
		contents_of_main_batch_file_dsi.add(global_dsm_values)
		return ""
	}
	
	def public static global_contents_of_main_batch_file_add(String str){ 
		global_contents_of_main_batch_file_add(str, "", "unnamed")
	}
	
	def public static global_contents_of_main_batch_file_reset(){ 
		contents_of_main_batch_file=new ArrayList<String> 
		contents_of_main_batch_output_file=new ArrayList<String> 
		contents_of_main_batch_file_description=new ArrayList<String> 
		contents_of_main_batch_file_dsi=new ArrayList<String> 
		return ""
	}
	
	def public static global_contents_of_main_batch_file(){ 
		return string_array_to_string(contents_of_main_batch_file)
	}

	// ******************************************************************************************************************************************************************
	// Variable for the Local batch file contents
	private static List<String> contents_of_local_batch_file = new ArrayList<String>
	private static List<String> contents_of_local_batch_output_file = new ArrayList<String>
	private static List<String> contents_of_local_batch_file_description = new ArrayList<String>
	private static List<String> contents_of_local_batch_file_dsi = new ArrayList<String>
	
	def public static global_contents_of_local_batch_file_add(String str, String output_str, String descr){ 
		contents_of_local_batch_file.add(str)
		contents_of_local_batch_output_file.add(output_str)
		contents_of_local_batch_file_description.add(descr)
		contents_of_local_batch_file_dsi.add(global_dsm_values)
		return ""
	}
	// TEMPORARILY DISABLED TO ENFORCE CALLS WITH OUTPUT AND DESCRIPTION	
	//def public static global_contents_of_local_batch_file_add(String str){ global_contents_of_local_batch_file_add(str, "", "unnamed") }
	def public static global_contents_of_local_batch_file_reset(){ 
		contents_of_local_batch_file=new ArrayList<String>
		contents_of_local_batch_output_file=new ArrayList<String>
		contents_of_local_batch_file_description=new ArrayList<String>
		contents_of_local_batch_file_dsi=new ArrayList<String>
		return ""
	}
	//def public static global_contents_of_local_batch_file(){ return string_array_to_string(contents_of_local_batch_file) }
	def public static global_contents_of_local_batch_file(){ 
		return file_outputfile_description_and_dsi_to_string( contents_of_local_batch_file, contents_of_local_batch_output_file, 
															  contents_of_local_batch_file_description, contents_of_local_batch_file_dsi )
	}
	
	def public static global_contents_of_local_batch_file(String filter_dsi){ 
		return file_outputfile_description_and_dsi_to_string( contents_of_local_batch_file, contents_of_local_batch_output_file, 
															  contents_of_local_batch_file_description, contents_of_local_batch_file_dsi, filter_dsi)
	}	
	
	def public static List<String> selected_contents_of_local_batch_file(List<String> dsi_string){
		var List<String> ret_val = new ArrayList<String>
		for(cnt:(0..contents_of_local_batch_file_dsi.length-1))
			if(dsi_string.contains(IdslGeneratorGUI.all_design_instance_string) || dsi_string.contains(contents_of_local_batch_file_dsi.get(cnt)))
				ret_val.add(contents_of_local_batch_file.get(cnt))
		return ret_val	
	}
	
	def public static List<String> selected_contents_of_local_batch_output_file(List<String> dsi_string){
		var List<String> ret_val =new ArrayList<String>
		for(cnt:(0..contents_of_local_batch_file_dsi.length-1))
			if(dsi_string.contains(IdslGeneratorGUI.all_design_instance_string) || dsi_string.contains(contents_of_local_batch_file_dsi.get(cnt)))
				ret_val.add(contents_of_local_batch_output_file.get(cnt))
		return ret_val	
	}
	
	def public static List<String> selected_contents_of_local_batch_file_description(List<String> dsi_string){
		var List<String> ret_val = new ArrayList<String>
		for(cnt:(0..contents_of_local_batch_file_dsi.length-1))
			if(dsi_string.contains(IdslGeneratorGUI.all_design_instance_string) || dsi_string.contains(contents_of_local_batch_file_dsi.get(cnt)))
				ret_val.add(contents_of_local_batch_file_description.get(cnt))
		return ret_val	
	}
	
	def public static List<String> selected_contents_of_local_batch_file_dsi(List<String> dsi_string){
		var List<String> ret_val = new ArrayList<String>
		for(cnt:(0..contents_of_local_batch_file_dsi.length-1))
			if(dsi_string.contains(IdslGeneratorGUI.all_design_instance_string) || dsi_string.contains(contents_of_local_batch_file_dsi.get(cnt)))
				ret_val.add(contents_of_local_batch_file_dsi.get(cnt))
		return ret_val		
	} 
	
	// ******************************************************************************************************************************************************************	
	// Variables for the Main MODEST process	
	private static List<String> main_modest_class_to_print = new ArrayList<String>
	private static List<String> main_modest_class_to_print_description = new ArrayList<String>
	
	def public static global_main_modest_class_to_print_add(String str, String descr){ 
		main_modest_class_to_print.add(str)
		main_modest_class_to_print_description.add(descr)
		return ""
	}
	
	def public static global_main_modest_class_to_print_add(String str){ global_main_modest_class_to_print_add(str, "unnamed") }
	def public static global_main_modest_class_to_print_reset(){ main_modest_class_to_print=new ArrayList<String>; return "" }
	def public static global_main_modest_class_to_print(){ return string_array_to_string(main_modest_class_to_print) }	
	
	// Concatenates a list of Strings into one String
	def public static string_array_to_string(List<String> strings)'''
		«FOR str:strings»«str»
		«ENDFOR»'''
	 
	// ******************************************************************************************************************************************************************	
	def public static file_outputfile_description_and_dsi_to_string (List<String> file, List<String> output_file, List<String> descr, List<String> dsi, String dsi_filter)'''
		«FOR cnt:(0..file.length-1)»«IF dsi_filter==null /* exploits lazy evaluation */|| dsi_filter.toString == dsi.get(cnt).toString»
			«IF dsi!=null»rem dsi: 			«dsi.get(cnt)»«ENDIF»
			rem description:	«descr.get(cnt)»
			«file.get(cnt)»    «IF output_file.get(cnt)!=""»>    «output_file.get(cnt)»«ENDIF»
			
		«ENDIF»«ENDFOR»
	'''
	
	def public static file_outputfile_description_and_dsi_to_string (List<String> file, List<String> output_file, List<String> descr){
		file_outputfile_description_and_dsi_to_string (file, output_file, descr, null)
	}
	
	def public static file_outputfile_description_and_dsi_to_string (List<String> file, List<String> output_file, List<String> descr, List<String> dsi){
		file_outputfile_description_and_dsi_to_string (file, output_file, descr, dsi, null)
	}
}