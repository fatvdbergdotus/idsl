package org.idsl.language.generator

import java.util.List
import java.util.ArrayList

class IdslGeneratorStatistics {
	def static sum(List<Double> numbers){
        var double sum = 0
        for (nr:numbers) { sum = sum + nr }
        return sum;
    }
	
	def static double mean(List<Double> numbers){
        return sum(numbers) / (numbers.length * 1.0);
    }
    
    def static median(List<Integer> numbers){
        var middle_index = numbers.size()/2;
 		if (numbers.size() % 2 == 1) { return numbers.get(middle_index) } else {
           return (numbers.get(middle_index-1) + numbers.get(middle_index)) / 2.0 }
    }
    
    def static sd(List<Double> numbers){
        var double sum = 0;
        var double mean = mean(numbers);
 
        for (nr:numbers) { sum = sum + (nr - mean)*(nr - mean) }
        return Math.sqrt( sum / ( numbers.size() - 1 ) ); // sample
    }
	
	def static List<Double> lower_and_upper_bound(List<Double> numbers, int column){
		var List<Double> bounds = new ArrayList<Double>
		var double mean = mean(numbers)
		var n = numbers.length
		var range = studentt(n-1,column) * sd(numbers) / Math.sqrt(n)

		bounds.addAll({mean-range},{mean+range}) // the lower and upper bound
		return bounds
	}
	
	def static Pair<Double,Double> lower_and_upper_bound_pair(List<Double> numbers, int column){
		var double mean = mean(numbers)
		var n = numbers.length
		var range = studentt(n-1,column) * sd(numbers) / Math.sqrt(n)
		return (mean-range) -> (mean+range) // the lower and upper bound
	}
		
	def static test_sd_and_bounds(){ // Test function for the Standard Deviation and bounds.
		var List<Double> numbers = new ArrayList<Double>
		numbers.addAll(8.0)
		numbers.add(7.0)
		numbers.add(6.0)
		numbers.add(7.0)
		numbers.add(8.0)
		numbers.add(6.0)
		numbers.add(54.0)
		numbers.add(6.0)
		numbers.add(7.0)
		numbers.add(756.0)	
		System.out.println("stdev: "+sd(numbers))		
		System.out.println("bounds (90): "+lower_and_upper_bound(numbers,twosided_column(90.0)))					
		System.out.println("bounds (99): "+lower_and_upper_bound(numbers,twosided_column(99.0)))
		System.out.println("bounds (99.9): "+lower_and_upper_bound(numbers,twosided_column(99.9)))
	}	
		
	def static studentt (int degrees_of_freedom, int column) { // returns to student-t value that can be used to compute confidence intervals
		//Usage example:
		//System.out.println(MyDslGeneratorStatistics.studentt(12,MyDslGeneratorStatistics.onesided_column(85.0)))
		//System.out.println(MyDslGeneratorStatistics.studentt(12,MyDslGeneratorStatistics.twosided_column(99.5)))
		var List<Double> values = new ArrayList<Double>
		switch(degrees_of_freedom){
			case 1: values.addAll({1.0},{1.376},{1.963},{3.078},{6.314},{12.71},{31.82},{63.66},{127.3},{318.3},{636.6})
			case 2: values.addAll({0.816},{1.061},{1.386},{1.886},{2.92},{4.303},{6.965},{9.925},{14.09},{22.33},{31.6})
			case 3: values.addAll({0.765},{0.978},{1.25},{1.638},{2.353},{3.182},{4.541},{5.841},{7.453},{10.21},{12.92})
			case 4: values.addAll({0.741},{0.941},{1.19},{1.533},{2.132},{2.776},{3.747},{4.604},{5.598},{7.173},{8.61})
			case 5: values.addAll({0.727},{0.92},{1.156},{1.476},{2.015},{2.571},{3.365},{4.032},{4.773},{5.893},{6.869})
			case 6: values.addAll({0.718},{0.906},{1.134},{1.44},{1.943},{2.447},{3.143},{3.707},{4.317},{5.208},{5.959})
			case 7: values.addAll({0.711},{0.896},{1.119},{1.415},{1.895},{2.365},{2.998},{3.499},{4.029},{4.785},{5.408})
			case 8: values.addAll({0.706},{0.889},{1.108},{1.397},{1.86},{2.306},{2.896},{3.355},{3.833},{4.501},{5.041})
			case 9: values.addAll({0.703},{0.883},{1.1},{1.383},{1.833},{2.262},{2.821},{3.25},{3.69},{4.297},{4.781})
			case 10: values.addAll({0.7},{0.879},{1.093},{1.372},{1.812},{2.228},{2.764},{3.169},{3.581},{4.144},{4.587})
			case 11: values.addAll({0.697},{0.876},{1.088},{1.363},{1.796},{2.201},{2.718},{3.106},{3.497},{4.025},{4.437})
			case 12: values.addAll({0.695},{0.873},{1.083},{1.356},{1.782},{2.179},{2.681},{3.055},{3.428},{3.93},{4.318})
			case 13: values.addAll({0.694},{0.87},{1.079},{1.35},{1.771},{2.16},{2.65},{3.012},{3.372},{3.852},{4.221})
			case 14: values.addAll({0.692},{0.868},{1.076},{1.345},{1.761},{2.145},{2.624},{2.977},{3.326},{3.787},{4.14})
			case 15: values.addAll({0.691},{0.866},{1.074},{1.341},{1.753},{2.131},{2.602},{2.947},{3.286},{3.733},{4.073})
			case 16: values.addAll({0.69},{0.865},{1.071},{1.337},{1.746},{2.12},{2.583},{2.921},{3.252},{3.686},{4.015})
			case 17: values.addAll({0.689},{0.863},{1.069},{1.333},{1.74},{2.11},{2.567},{2.898},{3.222},{3.646},{3.965})
			case 18: values.addAll({0.688},{0.862},{1.067},{1.33},{1.734},{2.101},{2.552},{2.878},{3.197},{3.61},{3.922})
			case 19: values.addAll({0.688},{0.861},{1.066},{1.328},{1.729},{2.093},{2.539},{2.861},{3.174},{3.579},{3.883})
			case 20: values.addAll({0.687},{0.86},{1.064},{1.325},{1.725},{2.086},{2.528},{2.845},{3.153},{3.552},{3.85})
			case 21: values.addAll({0.686},{0.859},{1.063},{1.323},{1.721},{2.08},{2.518},{2.831},{3.135},{3.527},{3.819})
			case 22: values.addAll({0.686},{0.858},{1.061},{1.321},{1.717},{2.074},{2.508},{2.819},{3.119},{3.505},{3.792})
			case 23: values.addAll({0.685},{0.858},{1.06},{1.319},{1.714},{2.069},{2.5},{2.807},{3.104},{3.485},{3.767})
			case 24: values.addAll({0.685},{0.857},{1.059},{1.318},{1.711},{2.064},{2.492},{2.797},{3.091},{3.467},{3.745})
			case 25: values.addAll({0.684},{0.856},{1.058},{1.316},{1.708},{2.06},{2.485},{2.787},{3.078},{3.45},{3.725})
			case 26: values.addAll({0.684},{0.856},{1.058},{1.315},{1.706},{2.056},{2.479},{2.779},{3.067},{3.435},{3.707})
			case 27: values.addAll({0.684},{0.855},{1.057},{1.314},{1.703},{2.052},{2.473},{2.771},{3.057},{3.421},{3.69})
			case 28: values.addAll({0.683},{0.855},{1.056},{1.313},{1.701},{2.048},{2.467},{2.763},{3.047},{3.408},{3.674})
			case 29: values.addAll({0.683},{0.854},{1.055},{1.311},{1.699},{2.045},{2.462},{2.756},{3.038},{3.396},{3.659})
			case 30: values.addAll({0.683},{0.854},{1.055},{1.31},{1.697},{2.042},{2.457},{2.75},{3.03},{3.385},{3.646})
			case 40: values.addAll({0.681},{0.851},{1.05},{1.303},{1.684},{2.021},{2.423},{2.704},{2.971},{3.307},{3.551})
			case 50: values.addAll({0.679},{0.849},{1.047},{1.299},{1.676},{2.009},{2.403},{2.678},{2.937},{3.261},{3.496})
			case 60: values.addAll({0.679},{0.848},{1.045},{1.296},{1.671},{2.0},{2.39},{2.66},{2.915},{3.232},{3.46})
			case 80: values.addAll({0.678},{0.846},{1.043},{1.292},{1.664},{1.99},{2.374},{2.639},{2.887},{3.195},{3.416})
			case 100: values.addAll({0.677},{0.845},{1.042},{1.29},{1.66},{1.984},{2.364},{2.626},{2.871},{3.174},{3.39})
			case 120: values.addAll({0.677},{0.845},{1.041},{1.289},{1.658},{1.98},{2.358},{2.617},{2.86},{3.16},{3.373})
			case -1: values.addAll({0.674},{0.842},{1.036},{1.282},{1.645},{1.96},{2.326},{2.576},{2.807},{3.09},{3.291})
			default: values.addAll({0.674},{0.842},{1.036},{1.282},{1.645},{1.96},{2.326},{2.576},{2.807},{3.09},{3.291})
			//default: throw new Throwable("Illegal number degrees of freedom")
		}
		return values.get(column-1)
	}
	
	def static onesided_column ( double range ){ // converts a range into a column to insert in the studentt function
		switch(range){  case 75.0: return 1	case 80.0: return 2	case 85.0: return 3 case 90.0: return 4 case 95.0: return 5 case 97.5: return 6
						case 99.0: return 7 case 99.5: return 8 case 99.75: return 9 case 99.9: return 10 case 99.95: return 11 }
	}
	
	def static twosided_column (double range){ // converts a range into a column to insert in the studentt function
		switch(range){  case 50.0: return 1	case 60.0: return 2	case 70.0: return 3 case 80.0: return 4 case 90.0: return 5 case 95.5: return 6
						case 98.0: return 7 case 99.0: return 8 case 99.5: return 9 case 99.8: return 10 case 99.9: return 11 }
	}	
	
}

