package org.idsl.language.generator.manual_tools

import java.util.List
import java.util.ArrayList
import org.idsl.language.generator.IdslConfiguration
import org.idsl.language.idsl.impl.IdslFactoryImpl
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.MVExpExponential

class TestExponential {
	def static void main(String[] args) {
		System.out.println("start")
		System.out.println(flatten(exponentialDistribution("0.3")))
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

	def static List<Pair<Integer,Integer>> exponentialDistribution (String rate_string){
		var int multiplier = new Integer(IdslConfiguration.Lookup_value("negative_exponential_distribution_multiplier"))
		return exponentialDistribution (rate_string,multiplier)
	}

	// a higher multiplier leads to more precision but also to a more complex PALT construct	
	def static List<Pair<Integer,Integer>> exponentialDistribution (String rate_string, int multiplier){  
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
	
	def static String flatten (List<Pair<Integer,Integer>> list_pair){
		var String str = ""
		for(pair:list_pair){
			str = str + "\n" + pair.key.toString + " - " + pair.value.toString
		}
		return str
	}
}