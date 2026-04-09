package org.idsl.language.generator

import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.OutputStreamWriter
import java.math.BigInteger
import java.nio.charset.Charset
import java.util.ArrayList
import java.util.Collections
import java.util.Comparator
import java.util.List
import java.util.Random
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.MVExpECDFabstract
import org.idsl.language.idsl.MVExpECDFbasedonDSI
import org.idsl.language.idsl.impl.IdslFactoryImpl

class IdslGeneratorSyntacticSugarECDF {
	/*def static void main(String[] args) {
		var MVExpECDF ecdf1 = create_random_eCDF(100,10)
		var MVExpECDF ecdf2 = create_random_eCDF(100,10)
		
		System.out.println(eCDF_to_string(ecdf1))
		System.out.println("---")
		System.out.println(eCDF_to_string(ecdf2))
		System.out.println("---")
		System.out.println(eCDF_to_string(sort_and_clean_ecdf(multiply_eCDFs(ecdf1,ecdf2),0)))
	}*/
	
	def static List<MVExpECDFbasedonDSI> convert_ECDFs_to_ECDFs_dsi(List<MVExpECDF> ecdfs){
		var List<MVExpECDFbasedonDSI> dsi_cdfs  = new ArrayList<MVExpECDFbasedonDSI>
		var List<MVExpECDF> ecdfs_copy 			= new ArrayList<MVExpECDF>
		ecdfs_copy.addAll(ecdfs)
		var size=ecdfs_copy.length-1
		
		for(cnt:0..size){
			var ecdf_copy=ecdfs_copy.get(cnt)
			switch(ecdf_copy){
				MVExpECDFbasedonDSI: dsi_cdfs.add(ecdf_copy)	
				MVExpECDF:			 dsi_cdfs.add( wrap_ECDF_into_ECDFdsi(ecdf_copy) )	
			}
		}
		
		//System.out.println("XXdsi_cdfs1: "+ dsi_cdfs.get(0).param.head) // TEMPORARY
		//System.out.println("XXdsi_cdfs2: "+ dsi_cdfs.get(1).param.head)	// TEMPORARY	
		//System.out.println("XXdsi_cdfs3: "+ dsi_cdfs.get(2).param.head) // TEMPORARY
		
		return dsi_cdfs
	}
	
	def static MVExpECDFbasedonDSI wrap_ECDF_into_ECDFdsi(MVExpECDF ecdf){
		var dsi_cdf = IdslFactoryImpl::init.createMVExpECDFbasedonDSI
		var select_ecd = IdslFactoryImpl::init.createSelectECDF
		select_ecd.select.add("")
		select_ecd.ecdf.add(ecdf)
		
		dsi_cdf.param.add("no_choice")
		dsi_cdf.select_ecdfs.add(select_ecd)
		return dsi_cdf
	}
	
	def static MVExpECDF lookup_eCDF_call (MVExpECDFabstract aeCDF){
		return aeCDF.abstract_cdf.load.head
	}	
	
	// Traditional eCDF multiplication: take the crossproduct of the eCDFs and take the product of each one of them
	/*def static MVExpECDF multiply_eCDFs(MVExpECDF ecdf1, MVExpECDF ecdf2){
		var ret_ecdf = IdslFactoryImpl::init.createMVExpECDF
		
		if(ecdf1.freqval==null || ecdf2.freqval==null ) throw new Throwable("Error multiply_eCDFs: one of the eCDFs is empty")
		
		for(freq_val1:ecdf1.freqval)
			for(freq_val2:ecdf2.freqval){
				var freq_val = IdslFactoryImpl::init.createFreqValue
				freq_val.freq.add(freq_val1.freq.head * freq_val2.freq.head)
				freq_val.value.add(freq_val1.value.head * freq_val2.value.head)
				ret_ecdf.freqval.add(freq_val)				
			}
		return ret_ecdf
	}*/

	def static int num_values_in_eCDF(MVExpECDF ecdf){ // derives the number of samples in an eCDF
		var counter=0
		for(freqval:ecdf.freqval)
			counter=counter+freqval.freq.head
		return counter
	}
	
	def static int retrieve_value_in_eCDF(MVExpECDF ecdf, int index){
		if(index==0)
			throw new Throwable("Index may not be 0 in retrieve_value_in_eCDF")

		var counter=0
		for(freqval:ecdf.freqval){
			counter=counter+freqval.freq.head
			if(counter>=index)
				return freqval.value.head
		}
		throw new Throwable("Index ("+index+") out of bounds in retrieve_value_in_eCDF")	
	}

	def static double draw_sample_eCDF(MVExpECDF ecdf){
		 draw_sample_eCDF(ecdf, new Integer(IdslConfiguration.Lookup_value("default_ecdf_sampling_method"))) 
	}
	
	def static double draw_sample_eCDF(MVExpECDF ecdf, int none_interpolation_arithmicmean_median){
		var Double p = IdslGenerator.random.nextDouble // sample between 0.0 and 1.0
		return draw_sample_eCDF(ecdf, p, none_interpolation_arithmicmean_median)
	}

	def static double draw_sample_eCDF(MVExpECDF ecdf, double p_inclusive){
		return draw_sample_eCDF(ecdf, p_inclusive, new Integer(IdslConfiguration.Lookup_value("default_ecdf_sampling_method")))
	}
	
	def static double draw_sample_eCDF(MVExpECDF ecdf, double p_inclusive, int none_interpolation_arithmicmean_median){
		var p=p_inclusive
		if(p==1) 
			p=0.999999999 // probability 1 is not permitted

		var MVExpECDF ecdf2 
		if (is_ratio_eCDF(ecdf)) // sort when not of type ratio
			ecdf2 = ecdf
		else
			ecdf2 = sort_and_clean_ecdf(ecdf, -1) // Orders and minimizes the eCDF without losing data
		
		var int size = num_values_in_eCDF(ecdf2)			// The number of values in the eCDF
		var int index = (size*p) as int +1      			// The position in the eCDF needed
		var int index_prime = ((size-1)*p) as int +1   		// for segments (interpolation)
		var modulus=((size-1)*p) % 1
		
		//System.out.println ("*** "+index_prime+" "+modulus) FOR DEBUGGING PURPOSES ONLY!!!
		
		switch(none_interpolation_arithmicmean_median){
			case 0:  return retrieve_value_in_eCDF(ecdf2,index) as double
			case 1:  return ( ((1-modulus) * retrieve_value_in_eCDF(ecdf2,index_prime)) + 
			          ((modulus) * retrieve_value_in_eCDF(ecdf2,index_prime+1)) ) 
			case 2:  return arithmicmean_of_ecdf(ecdf)
			case 3:  return draw_sample_eCDF(ecdf,0.5) // draw median value
			default: throw new Throwable("draw_sample_eCDF: invalid none_interpolation_arithmicmean_median selection")
		}	 
	}
	
	def public static double arithmicmean_of_ecdf(MVExpECDF ecdf){
			var int sum = 0 
			var int cnt = 0
			
			for(freqval:ecdf.freqval){
				sum = sum + freqval.freq.head * freqval.value.head
				cnt = cnt + freqval.freq.head
			}
			
			if(cnt==0)
				throw new Throwable("arithmicmean_of_ecdf: input eCDF is empty")
			
			var arithmicmean=sum/cnt
			return arithmicmean
	}
	
	def public static String draw_samples_eCDF_to_string(MVExpECDF ecdf){ // draws evenly distributed samples from the eCDF and writes them to screen
		return draw_samples_eCDF_to_string(ecdf, new Integer(IdslConfiguration.Lookup_value("default_ecdf_sampling_method")))
	}
	
	def public static String draw_samples_eCDF_to_string(MVExpECDF ecdf, int none_interpolation_arithmicmean_median){
		var ret_str = ""
		
		val int granularity = new Integer(IdslConfiguration.Lookup_value("ecdf_grannularity"))
		for(cnt:0..granularity){ // the number of samples to take
			var double p = (1.0 * cnt) / (1.0 * granularity)
			var sample = draw_sample_eCDF(ecdf,p,none_interpolation_arithmicmean_median)
			ret_str = ret_str + "\n" + p.toString + "-" + sample.toString
		}
		return ret_str
	}

	def public static MVExpECDF compute_eCDF_ratio ( String dividend_filename, String divisor_filename){ // quotient of eCDFs, result returned as MVExpECDF
		var MVExpECDF dividend_cdf  = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file (#[],dividend_filename, null) // building blocks of ratios are not ratios
		var MVExpECDF dividend_cdf2 = sort_and_clean_ecdf(dividend_cdf)
		var MVExpECDF divisor_cdf   = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file (#[],divisor_filename, null)
		var MVExpECDF divisor_cdf2  = sort_and_clean_ecdf(divisor_cdf)
		
		var MVExpECDF quotient = IdslGeneratorSyntacticSugarECDF.divide_eCDFs(dividend_cdf2, divisor_cdf2)
		quotient.is_ratio="ratio"
		return quotient		
	}

	def public static void compute_eCDF_ratio ( String dividend_filename, String divisor_filename, String ratio_name ){ // quotient of eCDFs, result written to disc
		var MVExpECDF quotient = compute_eCDF_ratio( dividend_filename, divisor_filename )
		write_ECDF_to_file(ratio_name,quotient)
	}
	
	def public static MVExpECDF divide_eCDFs(MVExpECDF divisor, MVExpECDF dividend){
		val int granularity = new Integer(IdslConfiguration.Lookup_value("ecdf_quotient_grannularity"))
		return divide_eCDFs(divisor,dividend,granularity)
	}

	def public static MVExpECDF divide_eCDFs(MVExpECDF divisor, MVExpECDF dividend, int grannularity){
		val int multiplier = new Integer(IdslConfiguration.Lookup_value("ecdf_quotient_multiplier"))
		var ret_ecdf = IdslFactoryImpl::init.createMVExpECDF
		
		for(cnt:0..grannularity){
			var freq_val = IdslFactoryImpl::init.createFreqValue
			var double p = (1.0 * cnt) / (1.0 * grannularity)
			var ecdf1_sample = draw_sample_eCDF(divisor, p)
			var ecdf2_sample = draw_sample_eCDF(dividend, p)
			var ecdf_quotient = ((multiplier * ecdf1_sample) / ecdf2_sample) as int
			
			freq_val.freq.add(1)
			freq_val.value.add(ecdf_quotient as int)
			ret_ecdf.freqval.add(freq_val)
		}	
		
		ret_ecdf.is_ratio="ratio" // enable the ratio flag
		return ret_ecdf
	}
	
	/*def static MVExpECDF multiply_eCDFs(MVExpECDF ecdf1, MVExpECDF ecdf2){
		val int granularity = new Integer(IdslConfiguration.Lookup_value("ecdf_product_grannularity"))
		return multiply_eCDFs(ecdf1,ecdf2,granularity)
	}	
	
	def static MVExpECDF multiply_eCDFs(MVExpECDF ecdf1, MVExpECDF ecdf2, int grannularity){ // grannularity: the number of horizontal "cuts" to make in the eCDFs
		var ret_ecdf = IdslFactoryImpl::init.createMVExpECDF
		for(cnt:0..grannularity){
			var freq_val = IdslFactoryImpl::init.createFreqValue
			var double p = (1.0 * cnt) / (1.0 * grannularity)
			var ecdf1_sample = draw_sample_eCDF(ecdf1, p)
			var ecdf2_sample = draw_sample_eCDF(ecdf2, p)
			var ecdf_product = ecdf1_sample * ecdf2_sample
			
			freq_val.freq.add(1)
			freq_val.value.add(ecdf_product as int)
			ret_ecdf.freqval.add(freq_val)
		}
		throw new Throwable("Please use multiply_eCDFs for a list of ecdfs instead")
		//return sort_and_clean_ecdf(ret_ecdf, -1)
	}*/
	
	def static MVExpECDF multiply_eCDFs(List<MVExpECDF> ecdfs){
		val int granularity = new Integer(IdslConfiguration.Lookup_value("ecdf_product_grannularity"))
		return multiply_eCDFs(ecdfs,granularity)
	}
	
	def static MVExpECDF multiply_eCDFs(List<MVExpECDF> ecdfs, int grannularity){
		multiply_eCDFs(ecdfs, grannularity, new Integer(IdslConfiguration.Lookup_value("multiply_eCDFs_multiplier")))
	}
		
	def static MVExpECDF multiply_eCDFs(List<MVExpECDF> ecdfs, int grannularity, int global_divisor_exponent){
		var double_multiplier	= new Integer(IdslConfiguration.Lookup_value("double_multiplier")) // e.g., 100
		var ret_ecdf        	= IdslFactoryImpl::init.createMVExpECDF
		var ecdf_divisor    	= new Integer(IdslConfiguration.Lookup_value("ecdf_quotient_multiplier")) 
		// var divisor = Math.pow(new Integer(IdslConfiguration.Lookup_value("ecdf_quotient_multiplier")),num_ratio_ecdfs(ecdfs)) 
		
		if(global_divisor_exponent<-20 && global_divisor_exponent>20) // probably the meaning of the parameter is misiterpreted
			throw new Throwable("multiply_eCDFs: parameter global_divisor_exponent is used for absolute values greater than")
		
		for(cnt:0..grannularity){
			var freq_val = IdslFactoryImpl::init.createFreqValue
			var double p = (1.0 * cnt) / (1.0 * grannularity)
			var List<Integer> dividends = new ArrayList<Integer>
			var List<Integer> divisors  = new ArrayList<Integer>
			
			if (global_divisor_exponent>0)
				for(cnt_exp:1..global_divisor_exponent) // global_divisor_exponent is positive -> powers of 10 to multiply by
					dividends.add(10) // input of this function

			if (global_divisor_exponent<0)
				for(cnt_exp:1..-global_divisor_exponent) // global_divisor_exponent is negatieve -> powers of 10 to divide by
					divisors.add(10) // input of this function
			
			for(ecdf:ecdfs){ // draw a sample from each ecdf
				dividends.add((draw_sample_eCDF(ecdf, p)*double_multiplier) as int)
				divisors.add(double_multiplier)
				
				if(is_ratio_eCDF(ecdf))
					divisors.add(ecdf_divisor)
			}
			var int ecdf_product = multiply_fractions(dividends, divisors)
						
			freq_val.freq.add(1)
			freq_val.value.add(ecdf_product)
			ret_ecdf.freqval.add(freq_val)			
		}
		return ret_ecdf
	}
	
	def static int num_ratio_ecdfs (List<MVExpECDF> ecdfs){
		var num_ratios=0
		for(ecdf:ecdfs)
			if(is_ratio_eCDF(ecdf))
				num_ratios=num_ratios+1
		return num_ratios
	}
	
	def static MVExpECDF sort_and_clean_ecdf_lossless(MVExpECDF ecdf){
		sort_and_clean_ecdf(ecdf, -1)
	}
	
	def static MVExpECDF sort_and_clean_ecdf(MVExpECDF ecdf){
		sort_and_clean_ecdf(ecdf, new Integer(IdslConfiguration.Lookup_value("number_of_remaning_CDF_entries_after_operations"))) // 0 indicates that the number of entries remains intact
	}
	
	def static boolean is_ratio_eCDF (MVExpECDF ecdf){
		return (ecdf.is_ratio!=null)
	}
	
	def static MVExpECDF sort_and_clean_ecdf(MVExpECDF ecdf, int num_entries){ // sort a cdf on the value attribute, remove duplicate values and limit the number of entries
		if(is_ratio_eCDF(ecdf) || ecdf.freqval==null || ecdf.freqval.length<3 ) // order must be preserved
			return ecdf
				
		var List<Integer> value_lst1 = new ArrayList<Integer>
		
		for(freq_val:ecdf.freqval) // each entry
			for(cnt:(1..freq_val.freq.head)) // freq times the value
				value_lst1.add(freq_val.value.head) // the actual value
		
		var List<Integer> value_lst2 = new ArrayList<Integer>
		if(num_entries>0 && num_entries<value_lst1.length){ 	// the number of desired entries is limiting the eCDF size
			val interval = value_lst1.length / num_entries
			for(cnt:(0..value_lst1.length-1))
				if (cnt%interval==0)
					value_lst2.add(value_lst1.get(cnt))
		} else { 												// simply copy the list
			for(value:value_lst1)
				value_lst2.add(value)
		}
		
		return aggregate_similar_values(value_lst2.map[i|i.toString])
		/*Collections.sort(value_lst2)
		
		var int last_value = -1 								// to detect and aggregate similar values 
		var int current_freq = 1
		for(value:value_lst2){
			if (value.intValue==last_value) // aggregate
				current_freq = current_freq +1
			else {
				if (last_value!=-1){ // ignore the first entry
					var freq_val = IdslFactoryImpl::init.createFreqValue
					freq_val.freq.add(current_freq)
					freq_val.value.add(last_value)
					ret_ecdf.freqval.add(freq_val)
					current_freq = 1
				}
			}	
			last_value=value	
		}	
		// add the last entry, since it goes unnoticed in the preceeding FOR loop
		var freq_val = IdslFactoryImpl::init.createFreqValue
		freq_val.freq.add(current_freq)
		freq_val.value.add(last_value)
		ret_ecdf.freqval.add(freq_val)
			
		return ret_ecdf*/
	}	
	
	def static MVExpECDF aggregate_similar_values(List<String> _values){
		var ret_ecdf = IdslFactoryImpl::init.createMVExpECDF
		var int last_value = -1 								// to detect and aggregate similar values 
		var int current_freq = 1
		
		var List<String> values = new ArrayList<String>
		values.addAll(_values)			
		Collections.sort(values)
		
		for(Integer value:values.map[i|new Integer(i)]){
			if (value==last_value) // aggregate
				current_freq = current_freq +1
			else {
				if (last_value!=-1){ // ignore the first entry
					var freq_val = IdslFactoryImpl::init.createFreqValue
					freq_val.freq.add(current_freq)
					freq_val.value.add(last_value)
					ret_ecdf.freqval.add(freq_val)
					current_freq = 1
				}
			}	
			last_value=value	
		}	
		// add the last entry, since it goes unnoticed in the preceeding FOR loop
		var freq_val = IdslFactoryImpl::init.createFreqValue
		freq_val.freq.add(current_freq)
		freq_val.value.add(last_value)
		ret_ecdf.freqval.add(freq_val)
			
		return ret_ecdf		
	}
	
	def static MVExpECDF create_random_eCDF(int number_of_items){ // by default integers in range [0:100] are returned
		return create_random_eCDF(number_of_items, 100)
	}
	
	def static MVExpECDF create_random_eCDF(int number_of_items, int max_integer_value){
		var ret_ecdf = IdslFactoryImpl::init.createMVExpECDF
		var random = new Random
		
		for(cnt:(1..number_of_items)){ // one interation for each item to add
			var freq_val = IdslFactoryImpl::init.createFreqValue
			freq_val.freq.add(1)
			freq_val.value.add(random.nextInt(max_integer_value))
			ret_ecdf.freqval.add(freq_val)
		}
		
		return ret_ecdf
	}
	
	def static MVExpECDF create_eCDF_from_values(List<Integer> values){ // Generates a MVExpECDF based on a list of integer values
		var ret_ecdf = IdslFactoryImpl::init.createMVExpECDF
		
		for(value:values){
			var freq_val = IdslFactoryImpl::init.createFreqValue
			freq_val.freq.add(1)
			freq_val.value.add(value)
			ret_ecdf.freqval.add(freq_val)
		}
		return ret_ecdf		
	}
	
	def static CharSequence is_eCDF_ratio (MVExpECDF ecdf)'''«IF is_ratio_eCDF(ecdf)»ratio«ELSE»no_ratio«ENDIF»'''
		
	def static eCDF_to_string(MVExpECDF ecdf){
		var ret_str = is_eCDF_ratio(ecdf) // displays whether the eCDF is of kind ratio or not
		//var ret_str=""
		
		for(freq_val:ecdf.freqval)
			ret_str = ret_str + "\n(" + freq_val.freq + ":" + freq_val.value + ")" 
		return ret_str
	}
	
	def static MVExpECDF read_ECDF_from_file(List<Integer> num_samples, String raw_filename, String anchor, String is_ratio){
		// Check whether the filename requires a directoryname to be added
		var filename = raw_filename
		if(!filename.contains("\\"))  //no pathname found, add it
			filename=(IdslConfiguration.Lookup_value("cdf_file_path"))+filename
		
		var List<String> file_contents = fileToList (filename)
		var List<String> values = new ArrayList<String>
		
		for(line:file_contents){ // search for anchor
			var split_line = line.split(" ")
			if(split_line.length>0 && anchor.equals(split_line.get(0))) // right line found
				for(number:split_line.tail)
					if (number!="")
						values.add(number)
		}
		
		if(values.empty)
			throw new Throwable("read_ECDF_from_file: filename "+filename+"#"+anchor+" does not yield results.")
		
		var MVExpECDF ret_ecdf = ECDF_from_freqval_array(values, num_samples)
		ret_ecdf.is_ratio=is_ratio
		return ret_ecdf
	}

	def static MVExpECDF read_ECDF_from_file(List<Integer> num_samples, String raw_filename, String is_ratio){ 
		var List<String> file_contents
		
		var filename = raw_filename
		if(!filename.contains("\\"))  //no pathname found, add it
			filename=(IdslConfiguration.Lookup_value("cdf_file_path"))+filename	
		
		// Check whether the filename contains an anchor "#" or column "?".
		var parts=filename.split("#")
		if (parts.length>1) // # detected
			return read_ECDF_from_file(num_samples, parts.get(0), parts.get(1),is_ratio)
		
		parts = filename.split("!")
		if (parts.length>1) // ! detected
			file_contents = interleave_with_ones(fileToList (parts.get(0), new Integer(parts.get(1)))) // return column number
		else // no "!" or "#" detected
			file_contents = fileToList (filename) // only one column
		
		var MVExpECDF ret_ecdf = ECDF_from_freqval_array(file_contents, num_samples)
		ret_ecdf.is_ratio=is_ratio
		return ret_ecdf
	}
	
	def static list_copy_suffle_subset(List<String> _str_list, int num_samples){ // used to take a random subset of a list
		var boolean truly_random = (IdslConfiguration.Lookup_value("shuffle_measurements_randomly"))=="true"
		if (num_samples<0) // num_samples out of range
			throw new Throwable("list_copy_suffle_subset_and_sort: num_samples<0")
		
		var List<String> str_list = new ArrayList<String>
		str_list.addAll(_str_list) 							// copy
		
		if(truly_random)
			Collections.shuffle(str_list)					// shuffle (randomly)
		else
			Collections.shuffle(str_list, new Random(14))	// shuffle (reproducible)
		
		if(num_samples<str_list.length)
			str_list=str_list.subList(0,num_samples)		// subset
		return str_list
	}
	
	def static List<String> interleave_with_ones (List<String> _values){ // interleave with ones representing frequencies
		var values = _values.filter[ i | i != ""].toList // ignore empty lines
		Collections.sort(values, new MyComparator_String_Numerically)
		var List<String> ret = new ArrayList<String>
		for (value:values){
			ret.add("1")
			ret.add(value)
		}
		return ret
	}
	
	def static MVExpECDF ECDF_from_freqval_array (List<String> _freqvalues, List<Integer> num_samples){
		// freqvalues: an alternating list of frequencies and values.
		var ret_ecdf 			   = IdslFactoryImpl::init.createMVExpECDF
		var List<String> values    = new ArrayList<String>					// when subset of num_samples is taken
		
		if(_freqvalues.empty)
			throw new Throwable("ECDF_from_freqval_array: The input freqvalues is empty")
		
		var freqvalues=_freqvalues.toList.filter[i | i != ""].map[ i | new Double(i).intValue.toString ] // omit empty lines and convert to integer 
			
		for(cnt:(0..(freqvalues.length/2)-1)){
			var freq_val = IdslFactoryImpl::init.createFreqValue
			freq_val.freq.add(new Integer(freqvalues.get(cnt*2).trim))
			freq_val.value.add(new Integer(freqvalues.get(cnt*2+1).trim))
			ret_ecdf.freqval.add(freq_val)
			
			if(!num_samples.empty)
				for(x:1..freq_val.freq.head)
					values.add(freq_val.value.head.toString)		
		}
		if(num_samples.empty) // no post-processing needed
			return ret_ecdf
		
		values=list_copy_suffle_subset(values, num_samples.head)
		return aggregate_similar_values(values)
	}

	def static MVExpECDF ECDF_from_list_of_strings (List<String> values, List<Integer> num_samples){
		var List<String> freqvalues =  new ArrayList<String>
		for(value:values){
			freqvalues.add("1")
			freqvalues.add(value)
		}
		return ECDF_from_freqval_array (freqvalues, num_samples)
	}
	
	def static listlist_int_to_double (List<List<Integer>> llint){
		var List<List<Double>> lldouble = new ArrayList<List<Double>>
		for(lint:llint){
			var List<Double> ldouble = new ArrayList<Double>
			for(in:lint)
				ldouble.add(in as double)	
			lldouble.add(ldouble)
		}
		return lldouble
	}
	
	
	def static write_valueprobs_GNUplot_graph_to_file(String filename, List<List<Integer>> values_list, List<List<Double>> probs_list){ //based on write_ECDF_GNUplot_graph_to_file(String filename, List<MVExpECDF> ecdfs)
		write_valueprobs_GNUplot_graph_to_file("",  filename,  values_list, probs_list)
	}
	
	def static write_valueprobs_GNUplot_graph_to_file(String graph_title, String filename, List<List<Integer>> values_list, List<List<Double>> probs_list){
		write_valueprobs_GNUplot_graph_to_file_double(graph_title, filename, listlist_int_to_double(values_list), probs_list)
	}
	
	def static write_valueprobs_GNUplot_graph_to_file_double(String graph_title, String filename, List<List<Double>> values_list, List<List<Double>> probs_list){ //based on write_ECDF_GNUplot_graph_to_file(String filename, List<MVExpECDF> ecdfs)
		write_valueprobs_GNUplot_graph_to_file_double(graph_title, filename, values_list, probs_list, new ArrayList<List<Double>>, new ArrayList<List<Double>> ) // overloading
	}
	
	def static write_valueprobs_GNUplot_graph_to_file_double(String graph_title, String filename, List<List<Double>> values_list, List<List<Double>> probs_list, List<List<Double>> values_list_circle, List<List<Double>> probs_list_circle){ //based on write_ECDF_GNUplot_graph_to_file(String filename, List<MVExpECDF> ecdfs)
		//assertion: value_list.length == probs_list.length
		var random_part				= ((Math.random*10000000.0).longValue.toString)	 		// to avoid duplicate filenames
		var filepath 	    		= IdslConfiguration.Lookup_value("temporary_working_directory")+"temp_cdf_files_"+random_part+"_"
		var filepaths_lines   		= new ArrayList<String>
		var filepaths_circles 		= new ArrayList<String>	
		var plotsymbols       		= (IdslConfiguration.Lookup_value("gnuplot_plot_symbols").equals("true"))
		var List<String> legends 	= new ArrayList<String>
		
		for(cnt:1..values_list.length){
			filepaths_lines.add(filepath+cnt.toString+".out")	
			legends.add("") // an empty legend by default
		}

		for(cnt:1..values_list_circle.length)
			filepaths_circles.add(filepath+cnt.toString+"_circles.out")

		// write .gnuplot file to disk
		var file_contents   = IdslGeneratorGNUplot.create_gnu_plot_cdf(
								graph_title, filepaths_lines, filepaths_circles, legends, 
								filename+"."+IdslConfiguration.Lookup_value("Output_format_graphics"), 
								""/*xlabel*/, "" /*ylabel*/, "1" /*xdivisor*/, plotsymbols)		
		listToFile(filepath+".gnuplot",file_contents.toString)		
		
		// writes the data to disk to be read by GNUplot
		values_list_and_probs_list_to_file(filepaths_lines,   values_list, 		  probs_list)
		values_list_and_probs_list_to_file(filepaths_circles, values_list_circle, probs_list_circle)

		IdslGeneratorConsole.execute ("gnuplot "+filepath+".gnuplot") // run the GNUplot script
		// var file = new File(filepath+".gnuplot"); file.delete // delete it
	}
	
	def static public void values_list_and_probs_list_to_file(List<String> filepaths, List<List<Double>> values_list, List<List<Double>> probs_list){
		for(cnt:1..values_list.length) // write eCDFs to file  
			listToFile(filepaths.get(cnt-1), value_probability_string(values_list.get(cnt-1), probs_list.get(cnt-1)))	
	}

	def static String value_probability_string(List<Double> values, List<Double> probs){
		var ret_str		= ""
		for(cnt:1..values.length) // for each freqval
			ret_str = ret_str + values.get(cnt-1).toString + " " + probs.get(cnt-1).toString + "\n"
		return ret_str
	}	
	
	def static String value_probability_string_int(List<Integer> values, List<Double> probs){ //overloading: boolean is not used as parameter.
		var ret_str		= ""
		for(cnt:1..values.length) // for each freqval
			ret_str = ret_str + values.get(cnt-1).toString + " " + probs.get(cnt-1).toString + "\n"
		return ret_str
	}	
	
	def static MVExpECDF multiply_ECDF (int multiplier, MVExpECDF ecdf){ // multiplies the values of an MVExpECDF with factor "multiplier"
		var ecdf_ret = IdslFactoryImpl::init.createMVExpECDF
		for(freqval:ecdf.freqval){
			var freqval_ret = IdslFactoryImpl::init.createFreqValue
			freqval_ret.freq.add(freqval.freq.head)
			freqval_ret.value.add(freqval.value.head * multiplier)
			ecdf_ret.freqval.add(freqval_ret)
		}
		return ecdf_ret
	}
	
	def static write_ECDF_GNUplot_graph_to_file(String filename, List<MVExpECDF> ecdfs){
		var List<String> legends = new ArrayList<String>
		for(cnt:1..ecdfs.length)
			legends.add("") // an empty legend by default
		write_ECDF_GNUplot_graph_to_file(filename,ecdfs,legends)
	}
	
	def static write_ECDF_GNUplot_graph_to_file(String filename, MVExpECDF ecdf){ // Create a GNUPLOT graph without a legend
		write_ECDF_GNUplot_graph_to_file(filename,ecdf,"")
	}
	
	def static write_ECDF_GNUplot_graph_to_file(String filename, List<MVExpECDF> ecdfs, List<String> legends){
		write_ECDF_GNUplot_graph_to_file(filename, ecdfs, legends, "Time", "Cumulative probability", "1")
	}
	
	def static write_ECDF_GNUplot_graph_to_file(List<String> ecdf_filenames, List<String> legends, String filename, String xlabel, String ylabel, String xdivisor){
		var List<MVExpECDF> ecdfs = new ArrayList<MVExpECDF>
		for (ecdf_filename:ecdf_filenames) // read the MVExpECDFs to plot from file
			ecdfs.add(read_ECDF_from_file(#[],ecdf_filename,""))
			
		write_ECDF_GNUplot_graph_to_file(filename, ecdfs, legends, xlabel, ylabel, xdivisor)
	}
	
	def static write_ECDF_GNUplot_graph_to_file(String filename, List<MVExpECDF> ecdfs, List<String> legends, String xlabel, String ylabel, String xdivisor){
		var random_part		= ((Math.random*10000000.0).longValue.toString)	 		// to avoid duplicate filenames
		var filepath 	    = IdslConfiguration.Lookup_value("temporary_working_directory")+"temp_cdf_files_"+random_part+"_"
		var filepaths       = new ArrayList<String>
		var plotsymbols     = (IdslConfiguration.Lookup_value("gnuplot_plot_symbols").equals("true"))
		
		for(cnt:1..ecdfs.length)
			filepaths.add(filepath+cnt.toString+".out")
		
		var file_contents   = IdslGeneratorGNUplot.create_gnu_plot_cdf(
								"", filepaths, legends, filename+"."+IdslConfiguration.Lookup_value("Output_format_graphics"), xlabel, ylabel, xdivisor, plotsymbols)		
		
		listToFile(filepath+".gnuplot",file_contents.toString)
		
		for(cnt:1..ecdfs.length) // write eCDFs to file 
			listToFile(filepaths.get(cnt-1),ecdf_to_value_probability_string(ecdfs.get(cnt-1)))

		IdslGeneratorConsole.execute ("gnuplot "+filepath+".gnuplot") // run the GNUplot script
		//IdslGeneratorConsole.execute ("gnuplot "+filepath+".gnuplot", filepath+".output") // run the GNUplot script & store the output. DEBUG only

		//delete the temporary files
		//var file = new File(filepath+".gnuplot"); file.delete
		/*for(fp:filepaths){
			file = new File(fp)file.delete
		}*/ //DEBUG: does not delete when commented
	}	
	
	def static write_ECDF_GNUplot_graph_to_file(String filename, MVExpECDF ecdf, String legend){ // creates a graphical representation of a CDF via GNUplot
		var random_part		= ((Math.random*10000000.0).longValue.toString)	 		// to avoid duplicate filenames
		var filepath 	    = IdslConfiguration.Lookup_value("temporary_working_directory")+"temp_cdf_files_"+random_part+"_"
		var file_contents   = IdslGeneratorGNUplot.create_gnu_plot_cdf(
								"no_title", filepath+".out", legend, filename+"."+IdslConfiguration.Lookup_value("Output_format_graphics"))

		listToFile(filepath+".gnuplot",file_contents.toString)
		listToFile(filepath+".out"	  ,ecdf_to_value_probability_string(ecdf))
		
		IdslGeneratorConsole.execute ("gnuplot "+filepath+".gnuplot") // run the GNUplot script
		
		//delete the two temporary files
		var file = new File(filepath+".gnuplot"); file.delete
		file = new File(filepath+".out"); file.delete
	}
	
	def static String ecdf_to_value_probability_string (MVExpECDF ecdf){ // create a file from a eCDF that can be used at input for GNUplot
		var ecdf2		= sort_and_clean_ecdf(ecdf) 
		val cdf_entries = num_values_in_eCDF(ecdf2)
		
		System.out.println(eCDF_to_string(ecdf2))
		
		if(IdslConfiguration.Lookup_value("gnuplot_printing_method").equals("interpolation")) //staircase
			return ecdf_to_value_probability_string_interpolation(ecdf2,cdf_entries)
		else if (IdslConfiguration.Lookup_value("gnuplot_printing_method").equals("staircase"))
			return ecdf_to_value_probability_string_staircase(ecdf2,cdf_entries)
		
		throw new Throwable (IdslConfiguration.Lookup_value("gnuplot_printing_method")+" not implemented for gnuplot_printing_method")
	}
	
	def static String ecdf_to_value_probability_string_interpolation (MVExpECDF ecdf, int cdf_entries){
		var counter=0
		var ret_str		= ""
		for(freqval:ecdf.freqval) // for each freqval
			for(cnt:1..freqval.freq.head){ // and corresponding values
				ret_str = ret_str+freqval.value.head.toString+" "+((1.0*counter)/(1.0*(cdf_entries-1))).toString+"\n"
				counter=counter+1
			}		
		return ret_str
	}
	
	def static String ecdf_to_value_probability_string_staircase (MVExpECDF ecdf, int cdf_entries){
		var counter = 0
		var ret_str = ""
		for(freqval:ecdf.freqval) // for each freqval
			for(cnt:1..freqval.freq.head){ // and corresponding values
				ret_str = ret_str+freqval.value.head.toString+" "+((1.0*counter)/(1.0*(cdf_entries-1))).toString+"\n"
				ret_str = ret_str+freqval.value.head.toString+" "+((1.0*(counter+1))/(1.0*(cdf_entries-1))).toString+"\n"
				counter=counter+1
			}		
		return ret_str
	}
	
	def static write_ECDF_to_file(String filename, MVExpECDF ecdf){ // writes a CDF to a file as a set of freqvals 
		var str = ""
		for(freqval:ecdf.freqval)
			str = str + " " + freqval.freq.head.toString + " " + freqval.value.head.toString 
		
		listToFile(filename, str)
	}
	
	def static void listToFile(String filename, String line){
		var List<String> lines = new ArrayList<String>
		lines.add(line)
		listToFile(filename, lines)
	}
	
	def static void listToFile(String filename, List<String> lines){ // appends a number of lines to a file
		var parts=filename.split("#") // see if the filename contains an anchor with the CDF name
		var OutputStream fis 		= new FileOutputStream(parts.get(0), true)
		var BufferedWriter bw 		= new BufferedWriter(new OutputStreamWriter(fis, Charset.forName("UTF-8")))		
		
		var anchor=""
		if (parts.length>1)
			anchor=parts.get(1)+" "
		
		for(line:lines) // write contents to disk
			bw.append(anchor+line+"\n")
		bw.close			
	}
	
	def static List<String> fileToList(String filename){ return fileToList(filename, -1) } // print all columns by default
	
	def static List<String> fileToList(String filename, int column){
		// Return empty list when the file does not exists
		var File file = new File(filename)
		if(!file.exists){ 
			System.out.println("Warning: trying to read non-existing file "+filename)
			return new ArrayList<String>
		}
	
		var List<String>   list		= new ArrayList<String> 
		var InputStream    fis 		= new FileInputStream(filename)
		var BufferedReader br 		= new BufferedReader(new InputStreamReader(fis, Charset.forName("UTF-8")))
		var String         line
		
		while ((line = br.readLine) != null) // read the file line by line
		    if(column==-1) // return whole line
		    	list.add(line)
			else // return a given single column			    	
		    	list.add(line.split(" ").get(column))
		    	
		br.close
		return list
	}
	
	def static int multiply_fractions(List<Integer> dividends, List<Integer> divisors){ // multiplies a number of ratios with little loss of precision
		var BigInteger dividends_product = BigInteger.valueOf(1)		
		var BigInteger divisors_product  = BigInteger.valueOf(1)
		
		for(dividend:dividends)
			dividends_product = dividends_product.multiply(BigInteger.valueOf(dividend))		
		for(divisor:divisors)
			divisors_product = divisors_product.multiply(BigInteger.valueOf(divisor))
		
		var BigInteger[] result_remainder = dividends_product.divideAndRemainder(divisors_product)
		
		var BigInteger remainderTimesTwo = result_remainder.get(1).multiply(BigInteger.valueOf(2))	
		var BigInteger result            = result_remainder.get(0)
		
		if(remainderTimesTwo.compareTo(divisors_product)>0) // round up
			return result.intValue + 1
		else
			return result.intValue	
	}
	
	def static double eCDF_value_to_probability (MVExpECDF ecdf, int sample_value){ // to be used to perform one step in the Kolmogorov distance computation
		return eCDF_value_to_probability (ecdf, sample_value, true) // DEFAULT: interpolation
	}
	
	def static double eCDF_value_to_probability (MVExpECDF ecdf, int sample_value, boolean interpolation){ // to be used to perform one step in the Kolmogorov distance computation
		//System.out.println(ecdf.freqval.toString)
		//System.out.println(values.toString)
		var int counter_smaller_values = 0
		
		// converts the freqvals of the eCDF into a list of values
		var List<Integer> values = new ArrayList<Integer>
		for (freqval:ecdf.freqval) // per freqval
			for(cnt:1..freqval.freq.head) // frequency
				values.add(freqval.value.head) // add the value
		Collections.sort(values)

		// if the sample_value is out of range, the probablity can be return right away
		if(sample_value<=values.head)
			return 0.0 // value is smaller than any value in the eCDF
		if(sample_value>=values.last)
			return 1.0 // value is larger than any value in the eCDF
				
		// determine the rank of the sample_value in terms of the eCDF
		for(value:values)
			if(sample_value>value)
				counter_smaller_values = counter_smaller_values + 1
		
		var double interpolate = 0.5 // in case of no interpolation 
		if(interpolation)
			interpolate = (1.0 * (sample_value - values.get(counter_smaller_values-1))) / 
						  (1.0 * (values.get(counter_smaller_values) - values.get(counter_smaller_values-1))) 
		
		// return the value with a "p in [0:1]" check
		val double return_value = 1.0 * ( counter_smaller_values + interpolate ) / values.length 
		if (return_value<0.0 || return_value>1.0)
			throw new Throwable("eCDF_value_to_probability: computed value not in range [0:1]: "+return_value.toString)
		return return_value  
	}
	
	def static void write_ecdf_to_out_file(MVExpECDF ecdf, String out_filename){ // Writes an eCDF to an CDF outfile, with value/probability pairs
		listToFile(out_filename ,ecdf_to_value_probability_string(ecdf))
	}	
	
	def static void test_sampling_method(){
		/*var ecdf1  = sort_and_clean_ecdf( create_random_eCDF(5, 50) )
		var ecdf2  = sort_and_clean_ecdf( create_random_eCDF(5, 50) )
		
		val kolmo = Kolmogorov_distance(ecdf1,ecdf2)
		System.out.println("Max (kolmo): "+kolmo)
		
		val exec_distance = Execution_distance(ecdf1,ecdf2)
		System.out.println("Max (exec): "+exec_distance)*/
		
		// test whether a sampling method works
		var ecdf3  = ECDF_from_list_of_strings(#["1","2","3","4","5","6","7","8","9"],#[])
		var ecdf4  = ECDF_from_list_of_strings(#["2","3","4","5","6","7","1000","1000","1000"],#[])
		for(p:0..100){
			System.out.println((0.01*p)+" "+draw_sample_eCDF(ecdf3, 0.01*p)+" & "+(0.01*p)+" "+draw_sample_eCDF(ecdf4, 0.01*p))
			System.out.println()
		}
		var kolmo = IdslGeneratorModelValidation.Kolmogorov_distance(ecdf3,ecdf4)
		System.out.println("kolmo")
		System.out.println(kolmo.first)
		System.out.println(kolmo.second)
		
		//for(value:-1..51)
		//	System.out.println(value.toString+" "+eCDF_value_to_probability(ecdf,value) )
	}
	
	def static void main(String[] args){
		//test_sampling_method()
		//System.out.println("555"=="555")
		// converts the model validation measuremetns to .out to plot in gnuplot 
		/*var MVExpECDF ecdf1 = read_ECDF_from_file("P:\\TestPerformance_aggregation\\010fps_0512_mono.cdf#SUM_brto_sorted","")
		var MVExpECDF ecdf2 = read_ECDF_from_file("P:\\TestPerformance_aggregation\\010fps_1024_mono.cdf#SUM_brto_sorted","")
		var MVExpECDF ecdf3 = read_ECDF_from_file("P:\\TestPerformance_aggregation\\010fps_2048_mono.cdf#SUM_brto_sorted","")
		var MVExpECDF ecdf4 = read_ECDF_from_file("P:\\TestPerformance_aggregation\\010fps_0512_bi.cdf#SUM_brto_sorted","")
		var MVExpECDF ecdf5 = read_ECDF_from_file("P:\\TestPerformance_aggregation\\010fps_1024_bi.cdf#SUM_brto_sorted","")
		var MVExpECDF ecdf6 = read_ECDF_from_file("P:\\TestPerformance_aggregation\\010fps_2048_bi.cdf#SUM_brto_sorted","")
		
		write_ecdf_to_out_file(ecdf1,"z:\\ecdf_0512_mono.out")
		write_ecdf_to_out_file(ecdf2,"z:\\ecdf_1028_mono.out")
		write_ecdf_to_out_file(ecdf3,"z:\\ecdf_2048_mono.out")
		write_ecdf_to_out_file(ecdf4,"z:\\ecdf_0512_bi.out")
		write_ecdf_to_out_file(ecdf5,"z:\\ecdf_1024_bi.out")
		write_ecdf_to_out_file(ecdf6,"z:\\ecdf_2048_bi.out")*/
		
		for(x:0..20)
			System.out.println(list_copy_suffle_subset(#[1,3,6,8,12,16,17,19].map[i|i.toString],1))
		
	}
}

public class MyComparator_String_Numerically implements Comparator<String> {
	override int compare(String s1, String s2) {
			System.out.println("sort")
			var int val1 = new Double(s1.trim).intValue
			var int val2 = new Double(s2.trim).intValue
			var int dif = val1-val2
			return dif
	}
}

public class MyComparator_String_Numerically_reverse implements Comparator<String> {
	override int compare(String s1, String s2) {
			System.out.println("sort")
			var int val1 = new Double(s1.trim).intValue
			var int val2 = new Double(s2.trim).intValue
			var int dif = val2-val1
			return dif
	}
}
	