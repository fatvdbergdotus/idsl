package org.idsl.language.generator

import java.util.ArrayList
import java.util.List
import java.util.Random
import java.util.Collections
import java.util.Comparator
import java.util.Set
import java.util.HashSet

class IdslGeneratorKmeans {
	def static List<Double> pick_n_values_randomly (List<Integer> values, int num_values){
		var List<Integer> subset = new ArrayList<Integer>
		val random = new Random
		random.setSeed(System.nanoTime)
		for(cnt:1..num_values){
			var int random_value 
			do 
				random_value = values.get(random.nextInt(values.length-1))
			while(subset.contains(random_value))
			subset.add(random_value)	
		}
		Collections.sort(subset)
		var List<Double> subset_double =  subset.map[ doubleValue]
		//System.out.println("subset_double: "+subset_double)
		return  subset_double
	}
	
	def static int indexOfClosestValues (List<Double> cluster_values, int value_to_match){
		var int index=0
		var double delta=Math.abs(value_to_match-cluster_values.get(0))
		for(cnt:1..cluster_values.length-1)
			if(Math.abs(value_to_match-cluster_values.get(cnt))<delta){ // found a better cluster for the value_to_match
				index=cnt
				delta=value_to_match-cluster_values.get(cnt)
			}	
		return index
	}
	
	def static List<Integer> k_means_clustering(List<Integer> values, int num_segments){
		var int max_number_iterations_in_kmeans  = new Integer(IdslConfiguration.Lookup_value("max_number_iterations_in_kmeans"))
		return k_means_clustering(values, num_segments, max_number_iterations_in_kmeans)
	}
	
	def static List<Integer> k_means_clustering(List<Integer> values, int num_segments, int max_iterations){ // returns a cluster number for each value
		//1+2+3. Pick number of clusters (k). Make k points (they're going to be the centroids). Randomize all these points location 
		var List<Double> clusters = pick_n_values_randomly (values, num_segments)
		return k_means_clustering(values, num_segments, clusters, max_iterations)
	}
	
	def static List<Integer> k_means_clustering(List<Integer> values, int num_segments, List<Double> clusters, int max_iterations){ // returns a cluster number for each value
		var List<Integer>		cluster_assignment 	   = new ArrayList<Integer>
		var List<Integer>		cluster_assignment_new = new ArrayList<Integer>
		
		System.out.print(" "+max_iterations.toString)
		
		//4+5. Calculate Euclidean distance from each point to all centroids. Assign 'membership' of each point to the nearest centroid	
		for(value:values)
			cluster_assignment.add(indexOfClosestValues(clusters,value)) 
	
		var new_clusters = new ArrayList<Double> 
		//6. Establish the new centroids by averageing locations of all points belonging to a given cluster
		for(ccnt:0..num_segments-1){ // per cluster: determine the prototype value
			var double sum=0
			var double cnt=0
			for(acnt:0..cluster_assignment.length-1) // per value: go through the cluster assignment
				if(cluster_assignment.get(acnt)==ccnt){
					sum=sum+values.get(acnt)
					cnt=cnt+1.0
				}
			var double prototype = sum / cnt
			new_clusters.add(prototype)
		}
		for(value:values)
			cluster_assignment_new.add(indexOfClosestValues(new_clusters,value)) 
		
		//7. Goto 4 Until convergence is achieved, or changes made are irrelevant.		
		if(cluster_assignment_new.equals(cluster_assignment)  || max_iterations==0 ) // convergence OR reached maximum iterations
			return cluster_assignment_new
		else
			return k_means_clustering(values, num_segments, new_clusters, max_iterations-1)
	}
	
	def static double value_clustering(List<Integer> values, int num_segments, List<Integer> assignments){ // sum of squared distances between value and belonging cluster
		var double score=0
		var List<Double> cluster_means = new ArrayList<Double>
		
		// compute cluster means
		for(cluster_no:0..num_segments-1){ // for each cluster
			var int sum=0
			var int count=0
			for(val_cnt:0..values.length-1)
				if(assignments.get(val_cnt)==cluster_no){ // value is in the right cluster
					sum=sum+values.get(val_cnt)
					count=count+1	
				}
			cluster_means.add(sum as double / count as double)
		}
		//System.out.println("MEANS: "+cluster_means)
		
		// compute sum of squared distances between elements and belonging cluster means 
		for(value_number:0..values.length-1){
			var double current_cluster_mean = cluster_means.get(assignments.get(value_number))  
			var double squared_delta		= (values.get(value_number) - current_cluster_mean) * (values.get(value_number) - current_cluster_mean)
			score=score + squared_delta
			// System.out.println(squared_delta) // debug only!!
		}
		return Math.sqrt(score/values.length)
	}
	
	def static List<Integer> returnDistinctValues ( List<Integer> values){
		var Set<Integer> set = new HashSet<Integer>
		for(value:values)
			set.add(value)
		return set.toList
	}
	
	def static int countFrequencyValueInValues ( int value, List<Integer> values){ // how often does value occur in values?
		var int counter=0
		for(v:values)
			if (v==value)
				counter=counter+1
		return counter
	}
	
	def static List<List<Integer>> returnListsOfDistinctValues ( List<Integer> values){
		var List<List<Integer>> ret          = new ArrayList<List<Integer>>  
		var List<Integer>       distinctVals = returnDistinctValues(values)
		for (distinctVal:distinctVals){
		//for (distinctVal:values){ // should be values to consider the weights
			var List<Integer> wrapped_value = new ArrayList<Integer>
			for(cnt:1..countFrequencyValueInValues(distinctVal, values))
				wrapped_value.add(distinctVal)	
			ret.add(wrapped_value)
		}
		return ret
	}
	
	def static int numberOfDistinctValues (List<Integer> values) {
		var count_distincts=1
		for(cnt:0..values.length-2)
			if (values.get(cnt)!=values.get(cnt+1)) // another distinct value
				count_distincts=count_distincts+1
		return count_distincts
	}
	
	def static Pair<Double,List<List<Integer>>> iterative_k_means_clustering (List<Integer> _values, int _num_segments){
		var int num_iterations  				 = new Integer(IdslConfiguration.Lookup_value("number_iterations_kmeans"))
		var int max_number_iterations_in_kmeans  = new Integer(IdslConfiguration.Lookup_value("max_number_iterations_in_kmeans"))
		return iterative_k_means_clustering (_values, _num_segments, num_iterations, max_number_iterations_in_kmeans)
	}
	
	def static Pair<Double,List<List<Integer>>> iterative_k_means_clustering (
								List<Integer> _values, int _num_segments, int num_iterations, int max_number_iterations_in_kmeans){ // performs N iterations of "k_means_clustering" and picks the best result
		System.out.println ("Executing k-means clustering for "+_num_segments+" segments...")
		
		var List<Integer> values=new ArrayList<Integer>
		for(value:_values)
			values.add(value)
		Collections.sort(values)
		
		var int num_segments=_num_segments
		
		if (_num_segments==1){ // only one possible solution
			var single_cluster_assignment = new ArrayList<Integer>
			for(value:values)
				single_cluster_assignment.add(0)
			return value_clustering(values, num_segments, single_cluster_assignment) -> #[values]
			
		}
		else if (_num_segments>=numberOfDistinctValues(values)){ // more segments than unique values
			return 0.0 -> returnListsOfDistinctValues(values)
		}
		
		var List<Pair<Double,List<Integer>>> objective_scores_and_cluster_assignments = new ArrayList<Pair<Double,List<Integer>>>  
		
		for(cnt:1..num_iterations){
			System.out.println("")
			System.out.print("  K-means iteration "+cnt.toString+":  ")
			var List<Integer> cluster_assignment 		  = k_means_clustering(values, num_segments, max_number_iterations_in_kmeans)
			var double        objective_score       	  = value_clustering(values, num_segments, cluster_assignment)
			objective_scores_and_cluster_assignments.add(objective_score -> cluster_assignment)
		}
		System.out.println("")
		
		Collections.sort(objective_scores_and_cluster_assignments, new MyComparator_Objective_scores_and_Cluster_assignments) // best (lowest value) result .head of list
		var Pair<Double,List<Integer>> score_assignments = objective_scores_and_cluster_assignments.head  // best cluster score + assignment
													
		
		// make a partition adhering to the assignment
		var List<List<Integer>> partition = new ArrayList<List<Integer>>
		for (cnt:0..num_segments-1) // add a partition for each segment
			partition.add(new ArrayList<Integer>)
		
		for (cnt:0..values.length-1){
			var assignment = score_assignments.value.get(cnt)
			var value      = values.get(cnt)
			partition.get(assignment).add(value)
		}
		return score_assignments.key -> partition
	}
	
	def static List<Integer> list_of_random_values (int length){ // generates a list of "length" integers
		var List<Integer> list = new ArrayList<Integer>
		var random = new Random
		for(cnt:1..length)
			list.add(random.nextInt(100000))
		return list
	}

	def static void main(String[] args) {
		//var List<Integer>		 values 		= #[1,1,2,3,3,3,3,3,3,3,3,3,3,3,4,5,6,7,8,11,16,18,19,26,29,30,40,60,67,68,69,74,76,77,80,85,89,100,200,200]
		//var List<Integer> values			    = list_of_random_values(10000)
		//var partition = iterative_k_means_clustering(values,50)
		//System.out.println(partition.toString)
		var values = #[1,6,6,6,6,16,18]
		var num_segments=1
		var assignment= #[0,0,0,0,0,0,0]
		System.out.println(value_clustering(values,num_segments,assignment))
	}

}

// Compares objective_scores for sorting cluster_assignments
public class MyComparator_Objective_scores_and_Cluster_assignments implements Comparator<Pair<Double,List<Integer>>> {
	override int compare(Pair<Double,List<Integer>> oc1, Pair<Double,List<Integer>> oc2) {
			return (100000*oc1.key) as int-(100000*oc2.key) as int
	}
}