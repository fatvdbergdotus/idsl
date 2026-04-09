package org.idsl.language.generator

import java.util.Collections
import java.util.List
import org.idsl.language.idsl.AExpVal
import org.idsl.language.idsl.impl.IdslFactoryImpl
import org.idsl.language.idsl.MeasurementResults
import org.idsl.language.idsl.UExpParameterInt
import org.idsl.language.idsl.UtilityResult
import org.idsl.language.idsl.UExpParameterIntRange
import org.idsl.language.idsl.UExpParameterTrueIntRange
import org.idsl.language.idsl.UExp
import org.idsl.language.idsl.UExpExpr
import org.idsl.language.idsl.UExpMeasurement
import org.idsl.language.idsl.UExpAggregatedMeasurement
import org.idsl.language.idsl.UExpAggregateSum
import org.idsl.language.idsl.UExpAggregatMinkowskiDist
import org.idsl.language.idsl.UExpAggregateLConfInterval
import org.idsl.language.idsl.UExpAggregateUConfInterval
import org.idsl.language.idsl.UExpAggregateMinimum
import org.idsl.language.idsl.UExpAggregateMedian
import org.idsl.language.idsl.UExpAggregateCount
import org.idsl.language.idsl.UExpAggregateAverage
import org.idsl.language.idsl.UExpAggregateMaximum
import org.idsl.language.idsl.UExpAggregateFunction
import org.idsl.language.idsl.UExpFuncServiceRequest
import org.idsl.language.idsl.UExpFuncUpperBound
import org.idsl.language.idsl.UExpFuncLowerBound
import org.idsl.language.idsl.UExpFuncUtilization
import org.idsl.language.idsl.UExpFuncTimeouts
import org.idsl.language.idsl.UExpFuncTimeToProb
import org.idsl.language.idsl.UExpFuncProbToTime
import org.idsl.language.idsl.ComputedProbabilities
import java.util.ArrayList
import java.io.InputStream
import org.idsl.language.idsl.ComputedTimeouts
import org.idsl.language.idsl.ComputedResultLatency
import org.idsl.language.idsl.ComputedResultBounds
import org.idsl.language.idsl.ComputedResultUtilization
import org.idsl.language.idsl.UExpParameterString
import java.io.BufferedReader
import java.io.FileInputStream
import java.io.InputStreamReader
import java.nio.charset.Charset
import org.idsl.language.idsl.MinOrMax
import org.idsl.language.idsl.MinOrMax_min
import org.idsl.language.idsl.MinOrMax_max
import org.idsl.language.idsl.AExpDspace
import org.idsl.language.idsl.Utility
import org.idsl.language.idsl.UExpAggregatePercentBelow
import org.idsl.language.idsl.UExpAggregateValueBelow
import java.util.Collection
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.MultiplyResults

class IdslGeneratorDesignSpaceMeasurements {	
	def static computeUtilityFunctions(String dsi, MeasurementResults mr){
		for(Utility util:mr.utils){
			var UtilityResult struct_utility_result 	= IdslFactoryImpl::init.createUtilityResult
			struct_utility_result.dsm_values			= dsi 
			struct_utility_result.value 				= evalUExp(util.util_func, dsi, mr).toString
			
			if(!util.requirement.empty){ // utility has a requirement
				var double req = new Double(util.requirement.head.threshold_value.head) 
				if(new Double(struct_utility_result.value) >= req )
					struct_utility_result.meet_requirement.add("1")
				else
					struct_utility_result.meet_requirement.add("0")
			}
			util.util_result.add(struct_utility_result)
		}
	}
	
	def static contains(UExpParameterIntRange range, int value){
		switch(range){
			UExpParameterInt:			return value==range.int12	
			UExpParameterTrueIntRange:	return (range.int1<=value && value<=range.int2)
			default: throw new Throwable("UExpParameterIntRange not fully implemented")
		}
	}
	
	def static int range_low(UExpParameterIntRange range){
		switch(range){
			UExpParameterInt:			return range.int12	
			UExpParameterTrueIntRange:	return range.int1
			default: throw new Throwable("UExpParameterIntRange_low not fully implemented")
		}		
	}

	def static int range_high(UExpParameterIntRange range){
		switch(range){
			UExpParameterInt:			return range.int12	
			UExpParameterTrueIntRange:	return range.int2
			default: throw new Throwable("UExpParameterIntRange_high not fully implemented")
		}		
	}
	
	def static double evalUExp(UExp uexp, String dsi, MeasurementResults measurementresults){
		switch(uexp){
			UExpExpr: 					return evalOp(uexp.op.head, evalUExp(uexp.a1.head, dsi, measurementresults), evalUExp(uexp.a2.head, dsi, measurementresults))
			AExpVal: 					return uexp.value
			AExpDspace: 				return new Double(IdslGeneratorDesignSpace.DSIstring_param_value (dsi, uexp.param.head)) 
			UExpMeasurement: 			return evalUExpMeasurement(uexp, dsi, measurementresults).head
			UExpAggregatedMeasurement:	return evalUExpAggregatedMeasurement(uexp.aggrfunc.head, uexp.measure.head, dsi, measurementresults)
			default: 					throw new Throwable("UExp not defined for certain type")
		}
	}
	
	def static double evalUExpAggregatedMeasurement (UExpAggregateFunction aggr_function, UExpMeasurement measure, String dsi, MeasurementResults measurementresults ){
		var List<Double> results = evalUExpMeasurement(measure, dsi, measurementresults)
		
		switch(aggr_function){
			UExpAggregateSum:		    { var sum=0.0; for(r:results) sum=sum+r; return sum}
			UExpAggregateMaximum: 		return Collections.max(results)
			UExpAggregateAverage:		{ var sum=0.0; var cnt=0.0; for (r:results) {sum=sum+r; cnt=cnt+1} return sum/cnt}	
			UExpAggregateCount:			{ var cnt=0.0; for(r:results) cnt=cnt+1; return cnt}
			UExpAggregateMedian: 		throw new UnsupportedOperationException ("EvalUExpAggregatedMeasurement")	
			UExpAggregateMinimum: 		return Collections.min(results)
			UExpAggregateLConfInterval: throw new UnsupportedOperationException ("EvalUExpAggregatedMeasurement: UExpAggregateLConfInterval")
			UExpAggregateUConfInterval: throw new UnsupportedOperationException ("EvalUExpAggregatedMeasurement: UExpAggregateUConfInterval")
			UExpAggregatMinkowskiDist:  throw new UnsupportedOperationException ("EvalUExpAggregatedMeasurement: UExpAggregatMinkowskiDist")
			UExpAggregatePercentBelow:  { return results.filter[i | i.intValue >= aggr_function.value.int12].length / results.length }	
			UExpAggregateValueBelow:	return percentile_of_list(aggr_function.percentage.int12, results)
			default: 					throw new Throwable("EvalUExpAggregatedMeasurement: Unknown aggregation function")
		}
	}
	
	def static double percentile_of_list(Integer percentage, List<Double> _results){
		var intresults 			= _results.map[ i | i.intValue.toString ]
		var freqval_results		= new ArrayList<String>
		
		for(intresult:intresults){
			freqval_results.add("1")
			freqval_results.add(intresult)
		}
		var MVExpECDF ecdf 		= IdslGeneratorSyntacticSugarECDF.ECDF_from_freqval_array (freqval_results, #[])
		return IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf, 0.01*percentage, 1)	
	}
	
	def static List<Double> evalUExpMeasurement(UExpMeasurement uexp, String dsi, MeasurementResults measurementresults){		
		switch(uexp){
			UExpFuncServiceRequest: return readLatenciesFromDSL(IdslGenerator.ServiceToProcess(uexp.service.str), uexp.runs, uexp.requestno, dsi, measurementresults)
			UExpFuncUpperBound:		return #[ readTheoBoundsFromDSL(IdslGenerator.ServiceToProcess(uexp.service.str), dsi, measurementresults, true)  ]
			UExpFuncLowerBound:		return #[ readTheoBoundsFromDSL(IdslGenerator.ServiceToProcess(uexp.service.str), dsi, measurementresults, false) ]
			UExpFuncUtilization:    return readUtilizationsFromDSL(uexp.resource, uexp.runs, dsi, measurementresults)
			UExpFuncTimeouts:		return readTimeoutFromDSL(IdslGenerator.ServiceToProcess(uexp.service.str), uexp.runs, dsi, measurementresults)
			UExpFuncTimeToProb:		return readPTAProbabilitiesFromDSL(uexp.service.str, uexp.min_max, uexp.time.int12, measurementresults) 
			UExpFuncProbToTime:		return readPTAValuesFromDSL(uexp.service.str, uexp.min_max, uexp.percentage.int12, measurementresults)
			default:				throw new Throwable("evalUExpMeasurement: Unknown uexp type")
		}
	}	
	
	def static String min_max_to_String (MinOrMax minORmax) {
		switch(minORmax){
			MinOrMax_min: return "pmin"
			MinOrMax_max: return "pmax"
		}
	}
	
	// Functions that retrieve measurement results from the DSL to be used in the utility function
	def static List<Double> readPTAProbabilitiesFromDSL(String service, MinOrMax min_or_max, int time, MeasurementResults measurementresults){
		for(m:measurementresults.comp_results)
			switch(m) {
				ComputedProbabilities: 
									if(m.service.head==service && m.pmin_or_pmax.head.equals(min_max_to_String(min_or_max))){
										val index = indexInList_str(m.latenciesfrom0to100percent, time)
										if(min_max_to_String(min_or_max)=="pmax")
											return #[new Double(index.key)]
										else if (min_max_to_String(min_or_max)=="pmin")
											return #[new Double(index.key + index.value)]
		}}
		throw new Throwable ("readPTAProbabilitiesFromDSL: Service "+service+", time "+time+" and pmin/pmax "+min_max_to_String(min_or_max)+" triple not found")
	}
	
	def static List<Double> readPTAValuesFromDSL(String service, MinOrMax min_or_max, int percentage, MeasurementResults measurementresults){
		for(m:measurementresults.comp_results)
			switch(m) {ComputedProbabilities: {
				if(m.service.head==service && m.pmin_or_pmax.head.equals(min_or_max))
					return #[new Double(m.latenciesfrom0to100percent.get(percentage))]
				}
			}
		throw new Throwable ("readPTAValuesFromDSL: Service and pmin/pmax pair not found")
	}
	
	def static List<Double> readTimeoutFromDSL(String service, UExpParameterIntRange runs, String dsi, MeasurementResults measurementresults){
		var List<Double> double_list = new ArrayList<Double>
		for(m:measurementresults.comp_results)
			switch(m) {ComputedTimeouts: {
				if(m.service.head==service && contains(runs, m.run.head) && dsi==m.dsm_values.head)
					double_list.add(new Double(m.timeouts.head))
			}}
		return double_list
	}
	
	def static List<Double> readLatenciesFromDSL(String service, UExpParameterIntRange runs, UExpParameterIntRange requestno, String dsi, MeasurementResults measurementresults){
		var List<Double> double_list = new ArrayList<Double>
		for(m:measurementresults.comp_results)
			switch(m){ ComputedResultLatency: { 
				if (m.service.head==service && contains(runs,m.run.head) && dsi==m.dsm_values.head) 
					for(range_cnt:range_low(requestno)..range_high(requestno))			
						double_list.add(new Double(m.latencies.get(range_cnt-1)))
			}}
		return double_list
	}
	
	def static Double readTheoBoundsFromDSL(String service, String dsi, MeasurementResults measurementresults, boolean returnUpper/* either the upper or lower bound */){
		for(m:measurementresults.comp_results)
			switch(m){ ComputedResultBounds:
				if (m.service.head==service && dsi==m.dsm_values.head)	
					if (returnUpper) return new Double(m.upper_bound.head)
					else		     return new Double(m.lower_bound.head)
			}
		throw new Throwable("Cannot find requested value in readTheoBoundsFromDSL")
	}
	
	def static List<Double> readUtilizationsFromDSL(UExpParameterString resource, UExpParameterIntRange runs, String dsi, MeasurementResults measurementresults){
		var List<Double> double_list = new ArrayList<Double>
		for(m:measurementresults.comp_results)
			switch(m){ ComputedResultUtilization:
				if(m.resource.head==resource.str && contains(runs,m.run.head) && dsi==m.dsm_values.head) 
					double_list.add(new Double(m.utilization.head))
			}
		return double_list			
	}
	
	//def static double readTimeoutsFromDSL
	
	
	def static double evalOp(String op, double val1, double val2){
		if (op.toString=="+") 		return val1+val2
		else if (op.toString=="-") 	return val1-val2
		else if (op.toString=="*") 	return val1*val2
		else if (op.toString=="/") 	return val1/val2
	    throw new Throwable("Op not defined for certain type")
	}
	
	
	def static List<String> fileToList(String filename){ return fileToList(filename, -1) } // print all columns by default
	
	def static List<String> fileToList(String filename, int column){
			var List<String>   list		= new ArrayList<String> 
			var InputStream    fis 		= new FileInputStream(filename)
			var BufferedReader br 		= new BufferedReader(new InputStreamReader(fis, Charset.forName("UTF-8")));
			var String         line;
			
			while ((line = br.readLine) != null) // read the file line by line
			    if(column==-1) // return whole line
			    	list.add(line)
				else // return a given single column			    	
			    	list.add(line.split(" ").get(column))
			    	
			br.close
			return list
	}		

	//READ
	def static readTimeouts(String filename, String dsm_run_service){
		var dsm 		= dsm_run_service.split(" ").get(0)
		var run 		= dsm_run_service.split(" ").get(1)
		var service		= dsm_run_service.split(" ").get(2)
		var timeout 	= fileToList(filename, 2).head
		writeTimeouts(dsm, run, service, timeout)
	}

	//WRITE	TO DSL
	def static writeTimeouts(String dsm, String run, String service, String timeout){
		var cr_timeout = IdslFactoryImpl::init.createComputedTimeouts
		cr_timeout.dsm_values.add(dsm)
		cr_timeout.run.add(new Integer(run))
		cr_timeout.service.add(service)
		cr_timeout.timeouts.add(timeout)
		measurementResults.comp_results.add(cr_timeout)
	}

	//READ
	def static readLatencies(String filename, String dsm_run_service){
		var dsm 		= dsm_run_service.split(" ").get(0)
		var run 		= dsm_run_service.split(" ").get(1)
		var service		= dsm_run_service.split(" ").get(2)
		var latencies 	= fileToList(filename, 2)
		writeLatenciesToDSL(dsm, run, service, latencies)		
	}

	//WRITE	TO DSL	
	def static writeLatenciesToDSL(String dsm, String run, String service, List<String> latencies){
		var cr_latency = IdslFactoryImpl::init.createComputedResultLatency
		cr_latency.dsm_values.add(dsm)
		cr_latency.run.add(new Integer(run))
		cr_latency.service.add(service)
		cr_latency.latencies.addAll(latencies.map[i | multiply_result_for_design(dsm,i) ])
		measurementResults.comp_results.add(cr_latency)
	}

	//READ	
	def	static readUtilizations(String filename, String dsm_run_service){
		var dsm 		 = dsm_run_service.split(" ").get(0)
		var run 		 = dsm_run_service.split(" ").get(1)
		var resources    = fileToList(filename, 0)
		var utilizations = fileToList(filename, 2)
			
		for (cnt:(0..resources.length-1))
			writeUtilizationToDSL(dsm, run, resources.get(cnt), utilizations.get(cnt))
	}

	//WRITE	TO DSL	
	def static writeUtilizationToDSL(String dsm, String run, String resource, String utilization){
		var cr_utilization = IdslFactoryImpl::init.createComputedResultUtilization
		cr_utilization.dsm_values.add(dsm)
		cr_utilization.run.add(new Integer(run))
		cr_utilization.resource.add(resource.substring(21)) // cut off prefix "property_utilization_"
		cr_utilization.utilization.add(utilization)
		measurementResults.comp_results.add(cr_utilization)
	}

	//READ	
	def	static readTheobounds(String filename, String dsm_service){
		var dsm 	= dsm_service.split(" ").get(0)
		var service = dsm_service.split(" ").get(1)
		var lb 		= fileToList(filename+"-lb.out").head
		var ub 		= fileToList(filename+"-ub.out").head
		writeTheoBoundsToDSL(dsm, service, lb, ub)
	}

	//WRITE	TO DSL
	def static writeTheoBoundsToDSL(String dsm, String service, String lb, String ub){
		var cr_bounds = IdslFactoryImpl::init.createComputedResultBounds
		cr_bounds.dsm_values.add(dsm)
		cr_bounds.service.add(service)
		cr_bounds.lower_bound.add(multiply_result_for_design(dsm,lb))
		cr_bounds.upper_bound.add(multiply_result_for_design(dsm,ub))
		measurementResults.comp_results.add(cr_bounds)
	}
	
	//READ
	//def static readPTAProbabilities() // not needed. PTA model checking calls writePTAProbabilitiesToDSL!!!
	
	//WRITE TO DSL
	def static writePTAProbabilitiesToDSL (String dsm, String service, String pmin_or_pmax, 
											      Pair<List<Integer>,List<Double>> values_and_probabilities){ // overloading for not supplying whether to multiply
		return writePTAProbabilitiesToDSL (dsm,  service,  pmin_or_pmax, values_and_probabilities, false)
	}
	
	def static writePTAProbabilitiesToDSL (String dsm, String service, String pmin_or_pmax, 
														 Pair<List<Integer>,List<Double>> values_and_probabilities, boolean multiply_results){
		var List<String> latenciesfrom0to100percent = interpolate101percentages (pmin_or_pmax, values_and_probabilities)
		var probs = IdslFactoryImpl::init.createComputedProbabilities
		probs.dsm_values.add(dsm)
		probs.service.add(service)
		probs.pmin_or_pmax.add(pmin_or_pmax)
		if(multiply_results)
			probs.latenciesfrom0to100percent.addAll(latenciesfrom0to100percent.map [ i | multiply_result_for_design(dsm,i) ])
		else
			probs.latenciesfrom0to100percent.addAll(latenciesfrom0to100percent)
		
		measurementResults.comp_results.add(probs)
		
		var List<String> latencies = new ArrayList<String> // hardcopy
		latencies.addAll(probs.latenciesfrom0to100percent)
		return latencies
	}
	
	def static List<String> convertPTAProbabilitiesToListOfCDFValues (String pmin_or_pmax, Pair<List<Integer>,List<Double>> values_and_probabilities){
		var List<String> latenciesfrom0to100percent = interpolate101percentages (pmin_or_pmax, values_and_probabilities)
		return latenciesfrom0to100percent
	}
	
	def static List<String> interpolate101percentages (String pmin_or_pmax, Pair<List<Integer>,List<Double>> values_and_probabilities){
		// may be sorted in parallel since they describe a monotone function
		Collections.sort(values_and_probabilities.key)
		Collections.sort(values_and_probabilities.value)
		
		var List<String> percentages = new ArrayList<String>
		
		for(percent:0..100){
			var double p     = (percent as double) / 100.0
			if(percent==1) //special case
				p = 0.01
			val index 		 = indexInList (values_and_probabilities.value, p)
			
			if (pmin_or_pmax=="pmin")
				percentages.add((values_and_probabilities.key).get(index.key+index.value /* higher value to be safe */).toString)
			else // (pmin_or_pmax=="pmax")
				percentages.add((values_and_probabilities.key).get(index.key).toString)
		}
		return percentages
	} 
	
	def static Pair<Integer, Integer> indexInList_str (List<String> string_list, double dbl){ // overloading; for strings representing doubles
		return indexInList(string_list.map[i | new Double(i)], dbl)
	}	
	
	def static Pair<Integer, Integer> indexInList (List<Double> double_list, double dbl){
		// return the index order of dbl in list double_list. The integer is 1 when the value of db1 is between to values of double_list, 0 otherwise
		
		if(dbl<double_list.get(0)) // dbl is smaller than any value in double_list
			return 0 -> 0
		
		for(cnt:0..double_list.length-1){
			if(dbl < double_list.get(cnt))
				return (cnt-1) -> 1
			if(dbl == double_list.get(cnt))
				return cnt -> 0
		}		
		return double_list.length-1 -> 0 // dbl is greater than any value in double_list
	} 
	
	def static String multiply_result_for_design(String dsm, String value){
		for(multiplyResult:multiplyResults.multiplyresult){
			if(compare_mresult_dsm_values_and_dsm (multiplyResult.dsm_values.head,dsm)){ // match, this is the right multiplier
				System.out.println("Warning: multiplier is applied on "+dsm+", on value "+value)
				return (new Double(value)*multiplyResult.factor.head).toString
			}
		}
		return value // did not find a multiplier, multiplier is 1
	}
	
	def static boolean compare_mresult_dsm_values_and_dsm (String multiply_result_dsm, String dsm){
		if (IdslConfiguration.Lookup_value("multiply_results_dsm_comparison_method")=="whole_dsm"){
			return multiply_result_dsm==dsm //full comparison
		}
		else if (IdslConfiguration.Lookup_value("multiply_results_dsm_comparison_method")=="one_variable"){
			return dsm.contains(multiply_result_dsm) //one variable comparison
		}	
		else
			throw new Throwable("compare_mresult_dsm_values_and_dsm: given multiply_results_dsm_comparison_method not supported")
	}
	
	var public static MeasurementResults measurementResults
	var public static MultiplyResults multiplyResults
	
	def static void main(String[] args) {
		var List<Integer> x = new ArrayList<Integer>; x.add(5); x.add(8); x.add(12); x.add(112); x.add(2); x.add(27); x.add(29)  
		Collections.sort(x)
		System.out.println(x)
	}
}


