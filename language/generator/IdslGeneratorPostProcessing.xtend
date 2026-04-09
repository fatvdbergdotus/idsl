package org.idsl.language.generator

import org.idsl.language.idsl.Utility
import java.util.List
import org.eclipse.xtext.generator.IFileSystemAccess
import org.idsl.language.idsl.UtilityResult
import java.util.ArrayList
import java.util.Collections
import java.util.Comparator
import org.idsl.language.idsl.ValidityResults
import org.idsl.language.idsl.ValidityResult
import org.idsl.language.idsl.ValidityValues
import org.eclipse.emf.common.util.ECollections
import org.eclipse.emf.common.util.EList
import java.io.PrintWriter
import java.io.File

class IdslGeneratorPostProcessing {
	
	def static public DSL_utility_requirements_to_file(IFileSystemAccess fsa, String path, List<Utility> utilities){
		var List<List<String>> util_reqs = new ArrayList<List<String>> // To store for each design, what utility function requirements it meets
		if(utilities.empty) // in case of no utilities, done!
			return
		
		var List<String> dsis			 = utilities.head.util_result.map[ i | i.dsm_values ] // retrieves the names of the dsis
		
		for(dsi:dsis){ // initiate a list for each dsi
			var dsi_entry=new ArrayList<String>
			dsi_entry.add(dsi)
			util_reqs.add(dsi_entry)
		}
		
		for(utility:utilities){ // add the requirements results per utility and DSI
			if(!utility.util_result.empty){
				var counter=0
				for(req:utility.util_result.map[ i | i.meet_requirement]){	
					util_reqs.get(counter).add(req.head)				
					counter=counter+1
				}
			}
		}
		fsa.generateFile(path+"/utility_constraints.dat", print_dsi_utilreq_values(util_reqs))
	}
	
	def static Create_tradeoff_graphs_for_each_pair_of_utilities (IFileSystemAccess fsa, String path, List<Utility> utilities){
		new File(path+"/tradeoff_graphs").mkdir
		for(util1:utilities)
			for(util2:utilities)
				if(util1.name!=util2.name){ // only pairs of different utitilities allowed
					var x_values   = util1.util_result.map[ i | new Double(i.value) ]
					var y_values   = util2.util_result.map[ i | new Double(i.value) ]
					var labels	   = util1.util_result.map[ i | i.dsm_values ]
					var title      = "Trade-off between "+util1.name+" and "+util2.name
					var outputfile = path+"tradeoff_graphs/"+util1.name+"_"+util2.name+".pdf"
					
					trade_off_graph_to_file (x_values, y_values, labels, title, outputfile)
				}
	}
	
	def static print_dsi_utilreq_values(List<List<String>> util_reqs)
	'''«FOR util_req:util_reqs»«FOR dsireq:util_req»«dsireq» «ENDFOR»«for_all_requirements(util_req.tail.toList)»
	«ENDFOR»
	'''
	
	def static for_all_requirements(List<String> reqs){
		for(req:reqs)
			if(req=="0") // one requirement not met
				return "0"		
		return "1" // all requirements are met
	}
		
	def static public DSL_utilities_to_files(IFileSystemAccess fsa, String path, List<Utility> utilities){
		var util_path = path + "/utilities/"
		for(utility:utilities)
			fsa.generateFile(util_path+utility.name, print_util_values(utility.util_result))
	}
	
	def static print_util_values(EList<UtilityResult> uresults){ 
		ECollections.sort(uresults, new MyComparator_UtilityResult)
		'''«FOR uresult:uresults»«uresult.dsm_values» «uresult.value»
		«ENDFOR»'''
	}
		
	def static public DSL_validations_to_files(IFileSystemAccess fsa, String path, List<ValidityResult> validities){
		var validity_path = path + "/validities/" 
		for(validity:validities)
			fsa.generateFile(validity_path+"validity_"+validity.dsm_values.head+"_"+validity.service.head, print_validity_values(validity.validity_values))
	}
	
	def static print_validity_values(EList<ValidityValues> validity_values){ // for printing validities for one DSM+service combination
		ECollections.sort(validity_values, new MyComparator_ValidityValues)
		'''run, kolmogorov, for_value, execution_ratio, for_probability
		«FOR validity_value:validity_values»«validity_value.run.head» «validity_value.kolmogorov.head» «validity_value.forvalue.head» «validity_value.exec.head» «validity_value.forprobability.head»
		«ENDFOR»'''
	}
	
	def static validations_to_graphs(IFileSystemAccess fsa, String path, List<ValidityResult> validities){ // creates Graphs of the validity functions
		// Graphs are printed at IdslGeneratorModelValidation.Compute_kolmogorevs_and_execution_distance
		var validity_path = path + "/validities/" 
		for(validity:validities){
			var validity_eCDF = validity.ecdf.head
			var validty_graph_path = validity_path+"graph_"+validity.dsm_values+validity.service
			IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(validty_graph_path, validity_eCDF)
		}
	}	

	def static trade_off_graph_to_file (List<Double> x_values, List<Double> y_values, List<String> labels, String title, String outputfile_pdf){
		var random_part				= ((Math.random*10000000.0).longValue.toString)	 		// to avoid duplicate filenames
		var filepath 	    		= IdslConfiguration.Lookup_value("temporary_working_directory")+"temp_cdf_files_"+random_part+".gnuplot"
		
		var	PrintWriter out = new PrintWriter(filepath)
		out.println(IdslGeneratorGNUplot.create_gnuplot_tradeoff_graph(title, x_values, y_values, labels, outputfile_pdf))
		out.close
		
		IdslGeneratorConsole.execute ("gnuplot "+filepath)
	}

	def static test_create_tradeoff_graph(){
		var List<Double> x_values = #[-237813.96725,-367159.925000001,-574542.4920000015,-650734.2077500012,
									  -250411.19224999993,-389870.4977500009,-696793.0022500015,-839824.0930000003]
		var List<Double> y_values = #[-25.0,-6.0,-6.0,-6.0,-25.0,-8.0,-8.0,-8.0]
		var labels   = #["(sum, 2048, mono, 0)","(sum, 2048, mono,1)","(sum, 2048, mono,2)","(sum, 2048, mono,3)",
						 "(sum, 2048, bi, 0)","(sum, 2048, bi, 1)","(sum, 2048, bi, 2)","(sum, 2048, bi, 3)"]
		
		var	PrintWriter out = new PrintWriter("F:/valuetools/trade-off/idsl_generated.gnuplot")
		out.println(IdslGeneratorGNUplot.create_gnuplot_tradeoff_graph("Trade-off graph",x_values,y_values,labels,"F:/valuetools/trade-off/idsl_generated222.pdf"))
		out.close
		
		IdslGeneratorConsole.execute ("gnuplot F:/valuetools/trade-off/idsl_generated.gnuplot")
	}

	def static void main(String[] args) {
		test_create_tradeoff_graph
	}
	
	
	//IdslGeneratorDesignSpace.def static String DSMvalues (DesignSpaceModel dsm)    '''«FOR dsparam:dsm.dsparam»«dsparam.variable.head»_«dsparam.value.head»_«ENDFOR»'''
}	
		
// Compares UtilityResult for sorting
public class MyComparator_UtilityResult implements Comparator<UtilityResult> {
	override int compare(UtilityResult ur1, UtilityResult ur2) {
			var double_val =  new Double(ur1.value) - new Double(ur2.value)
			return -double_val.intValue // - for descending sort
	}
}

// Compares ValidityValues for sorting
public class MyComparator_ValidityValues implements Comparator<ValidityValues> {
	override int compare(ValidityValues vv1, ValidityValues vv2) {
			var double_val =  new Double(vv1.exec.head) - new Double(vv2.exec.head)
			return -double_val.intValue // - for descending sort
	}
}
