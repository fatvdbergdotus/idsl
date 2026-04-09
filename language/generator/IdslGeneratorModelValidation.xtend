package org.idsl.language.generator

import org.idsl.language.idsl.ValidityResults
import org.idsl.language.idsl.ComputedResultLatency
import org.idsl.language.idsl.MeasurementResults
import org.idsl.language.idsl.ValidityResult
import org.idsl.language.idsl.impl.IdslFactoryImpl
import org.idsl.language.idsl.MVExpECDF
import java.util.List
import java.util.ArrayList
import org.eclipse.internal.xtend.util.Pair

class IdslGeneratorModelValidation {
	def public static Compute_kolmogorevs_and_execution_distances(ValidityResults val_results, MeasurementResults cresults, String path){  // compute distances between eCDF, for each one in validityResults
		System.out.println("Compute_kolmogorevs_and_execution_distances")
		for(val_result:val_results.validity_res){ /// look up the corresponding measurement, and determine the kolmogorov and time distance. 
			for(cresult:cresults.comp_results)
				switch(cresult){ // only consider latencies
					ComputedResultLatency: if (val_result.dsm_values.head.equals(cresult.dsm_values.head) && val_result.service.head.equals( cresult.service.head)) // they match
												Compute_kolmogorevs_and_execution_distance(val_result, cresult, path) // compute the distance measures
				}
		}
	}
	
	def public static remove_decimals_of_String_numbers (List<String> string_numbers){ // Removes after the . decimals for a list of numbers
		var List<String> numbers = new ArrayList<String>
		for(string_number:string_numbers){
			var int    number 		= Double.parseDouble(string_number).intValue
			var String new_number	= number.toString
			numbers.add(new_number)
		}		
		return numbers
	}
	
	def public static Compute_kolmogorevs_and_execution_distance(ValidityResult val_result, ComputedResultLatency cresult_latency, String path){
		var validity_path = path + "validities/" 
		
		var MVExpECDF ecdf1_pre = val_result.ecdf.head
		var MVExpECDF ecdf1     = IdslGeneratorSyntacticSugar.inject_abstract_product_fromfile_eCDFs( ecdf1_pre )
		
		var numbers = remove_decimals_of_String_numbers ( cresult_latency.latencies )
		var MVExpECDF ecdf2_pre = IdslGeneratorSyntacticSugarECDF.ECDF_from_list_of_strings ( numbers, #[]  )
		var MVExpECDF ecdf2     = IdslGeneratorSyntacticSugar.inject_abstract_product_fromfile_eCDFs( ecdf2_pre )
		
		var Pair<Double,Double> kolmogorov 		= Kolmogorov_distance (ecdf1, ecdf2)
		var Pair<Double,Double> execution_dist  = Execution_distance (ecdf1, ecdf2) 

		//System.out.println("Kolmogorov" + " " + val_result.dsm_values.head.toString + " " + kolmogorov)
		//System.out.println("Exec_dist" + " " + val_result.dsm_values.head.toString + " " + execution_dist)
		
		var validity_values = IdslFactoryImpl::init.createValidityValues
		validity_values.run.add(cresult_latency.run.head)
		validity_values.kolmogorov.add(kolmogorov.first.toString)
		validity_values.forvalue.add(kolmogorov.second.toString)
		validity_values.exec.add(execution_dist.first.toString)
		validity_values.forprobability.add(execution_dist.second.toString)
		val_result.validity_values.add(validity_values) // add the newly computed distance values
		
		val both_cdfs  = #[ecdf1, ecdf2]
		var legends    = #["validator","result"]
		IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file(validity_path+"graphic_"+val_result.dsm_values+val_result.service,both_cdfs,legends)
	}
	
	def static Pair<Double,Double> Execution_distance (MVExpECDF ecdf1, MVExpECDF ecdf2){ // Horizontal version of the Kolmogorov distance
		return Execution_distance (ecdf1, ecdf2, true)
	}
	
	def static Pair<Double,Double> Execution_distance (MVExpECDF ecdf1, MVExpECDF ecdf2, boolean interpolation){ // Horizontal version of the Kolmogorov distance
		val int grannularity     = new Integer((IdslConfiguration.Lookup_value("execution_distance_grannularity")))
		val double normalize     = (IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf1, 0.5) + IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf2, 0.5)) / 2 // average of medians

		// the values of the pair to be returned
		var double max_delta_val = 0 // the highest value distant for a given probability
		var double for_pvalue    = 0 // the p-value at which "max_delta_val" was obtained
		
		for(cnt:0..grannularity){
			val p 			= 1.0 * cnt/grannularity
			val delta_val   = Math.abs(IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf1, p) - IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf2, p))
			
			if(delta_val>max_delta_val){ // update needed
				max_delta_val	= Math.max(max_delta_val, delta_val)
				for_pvalue		= p
			}
			
			System.out.println("------") // DEBUG only
			System.out.println(IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf1, p) + " " + IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf2, p)) 
			System.out.println(p + " " + delta_val)
		}
		var ed = max_delta_val / normalize
		
		return new Pair(ed, for_pvalue)
	}
	
	def static public Pair<Double,Double> Kolmogorov_distance (MVExpECDF ecdf1, MVExpECDF ecdf2){
		return Kolmogorov_distance (ecdf1, ecdf2, IdslConfiguration.Lookup_value("kolmogorov_interpolation")=="true")
	}
	
	def static public Pair<Double,Double> Kolmogorov_distance (MVExpECDF ecdf1, MVExpECDF ecdf2, boolean interpolation){
		// Determine the minimum and maximum value to consider for the computation
		val int min_value    = Math.min(ecdf1.freqval.head.value.head, ecdf2.freqval.head.value.head)
		val int max_value    = Math.max(ecdf1.freqval.last.value.head, ecdf2.freqval.last.value.head)
		val int range        = max_value - min_value
		val int grannularity = new Integer(IdslConfiguration.Lookup_value("kolmogorov_grannularity"))
		
		// the values of the pair to be returned
		var double max_delta_p = 0 // the highest probability distance value found so far
		var double for_val     = 0 // the value for which "delta_p" was obtained
		
		for(cnt:0..grannularity){ // browse through the eCDFs, looking for the biggest delta
			val int value 		= min_value + ( 1.0 * range * cnt / grannularity ) as int // determine the value to check
			
			val double p_ecdf1 = IdslGeneratorSyntacticSugarECDF.eCDF_value_to_probability(ecdf1, value, interpolation)
			val double p_ecdf2 = IdslGeneratorSyntacticSugarECDF.eCDF_value_to_probability(ecdf2, value, interpolation)
			val double delta_p = Math.abs ( p_ecdf1 - p_ecdf2 )
			
			if(delta_p>max_delta_p){ // update needed
				max_delta_p = delta_p 
				for_val		= value
			}

			System.out.println("------") // DEBUG only
			System.out.println(p_ecdf1+" "+p_ecdf2+" "+value + " " + delta_p)
		}
		return new Pair(max_delta_p, for_val)
	}
	
}
		