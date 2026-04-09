package org.idsl.language.generator

import java.util.List
import java.util.ArrayList

class IdslGeneratorLatencyFunctionToJitterAndEntropy {
	def static Pair<List<Double>,List<Double>> createJitterFunction (
		Pair<List<Double>,List<Double>> pmin, Pair<List<Double>,List<Double>> pmax){ 
			
		return null
	}
	
	
	def static int retrieveV (Pair<List<Double>,List<Double>> val_probs, double probability){
		for(int cnt:0..val_probs.value.length-1){ // for probability ...
			var current_prob=val_probs.value.get(cnt)
			if(probability<=current_prob){
				return val_probs.key.get(cnt).intValue
			}
		}
		throw new Throwable("retrieveV: no value found for given probability")
	}
	
	def static double retrieveP (Pair<List<Double>,List<Double>> val_probs, int value){
		var prev_double = 0.0 // to compute deltas between probabilities

		for(int cnt:0..val_probs.key.length-1){ // for value ...
			var current_value=val_probs.key.get(cnt)
			if(value==current_value){
				//prev_double=0.0
				return val_probs.value.get(cnt)-prev_double
			}
			prev_double=val_probs.value.get(cnt)
		}
		return 1.0-prev_double // the value is greater than the whole collection, return 1.0
	}
	
	def static Pair<Integer,Integer> delta_between_segments (Pair<Integer,Integer> s1, Pair<Integer,Integer> s2){
		var int result_min
		var int result_max
		if(s1.key>s2.key) // the segments are not sorted
			return delta_between_segments(s2,s1)
		if(s1.value>s2.key) // the segments overlap
			result_min = 0
		else
			result_min = s2.key - s1.value
		result_max = s2.value - s1.key
		return result_min -> result_max
	}
	
	def static void main(String[] args){
		var Pair<List<Double>,List<Double>> tmin = #[3.0, 5.0, 7.0, 8.0] -> #[0.0, 0.25, 0.55, 1.0] 
		var Pair<List<Double>,List<Double>> tmax = #[8.0, 9.0, 10.0]     -> #[0.0, 0.55, 1.0]
		
		for(cnt:0..10)
			System.out.println(cnt+" "+retrieveP(tmin,cnt))
		for(cnt:0..10)
			System.out.println(cnt+" "+retrieveP(tmax,cnt))
		
		for(double cnt:0..20)
			System.out.println(cnt/20+" "+retrieveV(tmin,cnt/20)+" "+retrieveV(tmax,cnt/20))
	}
}
