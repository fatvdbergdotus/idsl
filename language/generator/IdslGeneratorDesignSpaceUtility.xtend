package org.idsl.language.generator

import java.util.Collections
import java.util.List

class IdslGeneratorDesignSpaceUtility {

	def public static double aggregateSum (List<Double> doubles){
		var double sum=0
		for (dbl:doubles) sum=sum+dbl
		return sum
	}
	
	def public static int aggregateCount (List<Double> doubles){
		var int cnt=0
		for (_:doubles) cnt=cnt+1
		return cnt 
	}
	
	def public static double aggregateAverage (List<Double> doubles){
		return aggregateSum(doubles) / aggregateCount(doubles)
	}
	
	def public static aggregateMaximum (List<Double> doubles){
		Collections.sort(doubles)
		return doubles.get(doubles.length-1)
	}
	
	def public static aggregateMinimum (List<Double> doubles){
		Collections.sort(doubles)
		return doubles.get(0)
	}
	
	def public static aggregateMedian (List<Double> doubles){
		Collections.sort(doubles)
		if(doubles.length%2==1)
			return doubles.get(doubles.length/2)
		else
			return (doubles.get(doubles.length/2-1) + doubles.get(doubles.length/2)) / 2
	}
}