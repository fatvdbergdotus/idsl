package org.idsl.language.generator.manual_tools

import java.util.List
import java.util.ArrayList
import java.io.FileInputStream
import java.io.InputStream
import java.io.BufferedReader
import java.io.InputStreamReader
import java.nio.charset.Charset
import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.impl.IdslFactoryImpl
import java.util.Random
import java.util.Collections
import java.math.BigInteger
import org.idsl.language.generator.IdslGeneratorSyntacticSugarECDF
import org.idsl.language.generator.IdslGeneratorDesignSpaceUtility
import java.io.File

class Test {
	def dirs(){
		var File theDir1 = new File("C:\\temp\\ddd\\eee\\fff")
		theDir1.mkdirs
		theDir1.delete
		
		var File theDir2 = new File("C:/temp/sss/rrr/aaa")
		theDir2.mkdirs
		theDir2.delete
		
		theDir1.exists
	}
	
	def static pathOf(){ // removes the filename from the file path, leaving the directory structure
		var File file = new File("C:\\abcfolder\\textfile.txt");
		var String absolutePath = file.getAbsolutePath();
		var String filePath = absolutePath.substring(0,absolutePath.lastIndexOf(File.separator));
		System.out.println(filePath)
	} 
	
	
	def static String modes_to_processname(String modes){
		return modes.split("/").last.substring(18) // pick the part after the last / + remove "modes_theo_bounds_"
	}
	
	def static String modes_to_mainstudyfoldername(String modes){
		return modes.split("/").get(0) + "/" + modes.split("/").get(1) + "/"
	}
	
	def static void main(String[] args) {
		
		System.out.println(true)
		System.out.println(false)
		
		//var x = "y:\\pta2_outputY:\\paper_compute.idsl_10-8-2015_biplane_e\\_SCN_BiPlane_Image_Processing_run_DSE_offset_0_samplingmethod_ecdf1_modeltimeun"
		//System.out.println(x.replace("Y:\\","\\").replace("i","ii"))
		
		//var y = "y:\\pta2_outputY:\\paper_compute.idsl_10-8-2015_biplane_g\\_SCN_BiPlane_Image_Processing_run_DSE_offset_0_samplingmethod_ecdf1_modeltimeunit_1_\\ExpPTAModelChecking2\\modes_theo_bounds_Lateral_Image_Processing_dynamic_mc.html"
		//System.out.println(y.replace("\\","_").replace("Y:\\","\\"))
		//pathOf
		
		//var z ="Y:/paper_compute.idsl_13-8-2015_try10/_SCN_BiPlane_Image_Processing_run_DSE_offset_0_samplingmethod_ecdf8_modeltimeunit_128_/ExpPTAModelChecking2/modes_theo_bounds_Lateral_Image_Processing"
		//System.out.println(modes_to_processname(z))
		//System.out.println(modes_to_mainstudyfoldername(z))
		//System.out.println((Math.random*10000000.0).longValue.toString)		
		
		//dirs
		
		/*var toSplit = "aaa.bbbb.ccc"
		var List<String> splitted=toSplit.split(".")
		System.out.println("par1 "+splitted.get(0))
		System.out.println("par2 "+splitted.get(1))
		System.out.println("par3 "+splitted.get(2))*/
	}	
		
		
		
		//test_replacement_in_a_list
		
		
		//var ecdf_combined = IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file("D:\\football", "abc", null)
		//System.out.println(eCDF_to_string(ecdf_combined))
		
		
		
		/*var path1="C:\\xxx"
		var path2="rrrrrrr"
		System.out.println(path1.contains("\\"))
		System.out.println(path2.contains("\\"))*/
		
		
		/*var List<Integer> a = #[10321410,6,13,18]
		var List<Integer> b = #[50,621,131,182]
		var result = IdslGeneratorSyntacticSugarECDF.multiply_fractions(a,b)
		System.out.println(result)*/
		
		//IdslGeneratorSyntacticSugarECDF.write_ECDF_GNUplot_graph_to_file("d:\\abc",create_random_eCDF(10,100))

		//open_and_display_file_using_path("D:\\file_to_display\\abc.txt")
		//test_sampling_from_ecdf
		//test_multiplying_ecdfs
		
		// double_integer_computations

		
		/*var int x=1
		for(cnt:1..20){
			System.out.println(x.toString)
			//x=x*1.4
		}*/
		
		/*var lijstje = new ArrayList<Integer>
		lijstje.add(1)
		lijstje.add(2)
		System.out.println(lijstje.get(0))*/
		
		/*var MVExpECDF ecdf1 = create_random_eCDF(100,5)
		var MVExpECDF ecdf2 = create_random_eCDF(100,5)
		
		System.out.println(eCDF_to_string(ecdf1))
		System.out.println("---")
		System.out.println(eCDF_to_string(ecdf2))
		System.out.println("---")
		System.out.println(eCDF_to_string(sort_and_clean_ecdf(multiply_eCDFs(ecdf1,ecdf2),20)))*/
		
		//testDesignSpaceUtilityAggregateFunctions
		//IdslGeneratorConsole.execute("dir","d:\\dir.txt")
		//test_string_substring
		//use_IdslGeneratorDesignSpaceMeasurements
		//splitter ("param1 pppp2 qqqq3")
		//printFile("d:\\xxx.abc")
		//System.out.println("property_utilization_CPU".substring(21))
		
		//var List<String> lijsje = new ArrayList<String>
		//System.out.println(lijsje.head)
		
		
		//parse_filename("pietje#bel")
		//parse_filename("jajajajajjaja")
		
		//read_ECDF_from_file("d:xxxx.cdf", "1Basic")
		
		//System.out.print(template_test)
	
		
	def static test_replacement_in_a_list(){
		var List<String> names = new ArrayList<String>
		names.add("john")
		names.add("peter")
		names.add("carl")
		names.add("fred")
		names.add("lily")
		names.add("erik")
		
		var String toReplace   = "fred"
		var String replaceBy   = "annie"
		
		var int lookupIndex
		//for(cnt:0..names.length-1)
		//	if(names.get(cnt)==toReplace)
		//		lookupIndex = cnt
		//lookupIndex = names.indexOf(toReplace)
		
		//System.out.println(lookupIndex) // return: 3
		//names.add(lookupIndex,replaceBy)
		//names.remove(lookupIndex+1)
		//names.set(lookupIndex,replaceBy)
		names.set(names.indexOf(toReplace),replaceBy)
		
		System.out.println(names.toString) //returns: [john, peter, carl, annie, lily, erik]
	}
	
	def static open_and_display_file_using_path(String filename){
		var List<String> file_contents = IdslGeneratorSyntacticSugarECDF.fileToList(filename)
		for(line:file_contents)
			System.out.println(line)
	}
	
	
	def static template_test()'''xxx'''

	def static double_integer_computations(){
		var int size=60
		var double p=0.53
		
		var int index = (size*p) as int       // The position in the eCDF needed
		var double modulus = (size*p)-index   // [0,1) For interpolation, e.g., 0: 100% index, 0.5: 50% index, 50% (index+1)
		
		System.out.println((size*p)+" -- "+index+" -- "+modulus)
		System.out.println(index+"*"+modulus)
		System.out.println((index+1)+"*"+(1-modulus))
	}

	def static MVExpECDF read_ECDF_from_file(String filename, String anchor){
		var List<String> file_contents = IdslGeneratorSyntacticSugarECDF.fileToList (filename)
		var List<String> values = new ArrayList<String>
		
		for(line:file_contents){
			var split_line = line.split(" ")
			if(split_line.length>0 && anchor==split_line.get(0)){ // right line found
				for(number:split_line.tail)
					if (number!="")
						values.add(number)
			}
		}
		System.out.println(values.toString)
		return null // To be implemented
	}
	
	def static parse_filename(String filename){
		var parts=filename.split("#")
		System.out.println(parts.get(0))
	}
	
	
	def static printFile(String batchfile){ // executes a batch file line by line
			var InputStream    fis = new FileInputStream(batchfile)
			var BufferedReader br = new BufferedReader(new InputStreamReader(fis, Charset.forName("UTF-8")));
			var String         line;
			
			while ((line = br.readLine) != null) // execute the batch file line by line
			    System.out.println(line)

			br.close
			return ""
	}
	
	
	def static splitter (String toSplit){
		var List<String> splitted=toSplit.split(" ")
		System.out.println("par1 "+splitted.get(0))
		System.out.println("par2 "+splitted.get(1))
		System.out.println("par3 "+splitted.get(2))
	}
	
	
	def static test_string_substring(){
		var String test_string = "abracadabra.bat"
		System.out.println(test_string.substring(test_string.length-4))
		readFile("d:freek.bat")		
	}
	
	def static testDesignSpaceUtilityAggregateFunctions () {
	  	var List<Double> db=new ArrayList<Double>
		db.add(3.0)
		db.add(5.0)
		db.add(6.0)
		//db.add(7.0)
		db.add(7.0)
		db.add(1118.0)
		
		System.out.println(IdslGeneratorDesignSpaceUtility.aggregateSum(db))
		System.out.println(IdslGeneratorDesignSpaceUtility.aggregateCount(db))
		System.out.println(IdslGeneratorDesignSpaceUtility.aggregateAverage(db))
		System.out.println(IdslGeneratorDesignSpaceUtility.aggregateMaximum(db))
		System.out.println(IdslGeneratorDesignSpaceUtility.aggregateMinimum(db))
		System.out.println(IdslGeneratorDesignSpaceUtility.aggregateMedian(db))
	}
	
	def static readFile(String filename){
			var InputStream    fis = new FileInputStream(filename)
			var BufferedReader br = new BufferedReader(new InputStreamReader(fis, Charset.forName("UTF-8")));
			var String         line;
			
			while ((line = br.readLine) != null) 
			   	System.out.println(line)

			br.close
	}
	
	/*def static MVExpECDF multiply_eCDFs(MVExpECDF ecdf1, MVExpECDF ecdf2){
		var ret_ecdf = IdslFactoryImpl::init.createMVExpECDF
		
		for(freq_val1:ecdf1.freqval)
			for(freq_val2:ecdf2.freqval){
				var freq_val = IdslFactoryImpl::init.createFreqValue
				freq_val.freq.add(freq_val1.freq.head * freq_val2.freq.head)
				freq_val.value.add(freq_val1.value.head * freq_val2.value.head)
				ret_ecdf.freqval.add(freq_val)				
			}
		return ret_ecdf
	}*/
	
	def static MVExpECDF sort_and_clean_ecdf(MVExpECDF ecdf){
		sort_and_clean_ecdf(ecdf, -1) // -1 indicates that the number of entries remains intact
	}
	
	def static MVExpECDF sort_and_clean_ecdf(MVExpECDF ecdf, int num_entries){ // sort a cdf on the value attribute, remove duplicate values and limit the number of entries
		var ret_ecdf = IdslFactoryImpl::init.createMVExpECDF
		var List<Integer> value_lst1 = new ArrayList<Integer>
		
		for(freq_val:ecdf.freqval) // each entry
			for(cnt:(1..freq_val.freq.head)) // freq times the value
				value_lst1.add(freq_val.value.head) // the actual value
		
		var List<Integer> value_lst2 = new ArrayList<Integer>
		if(num_entries>0 && num_entries<value_lst1.length){ 	// the number of desired entries is limited
			val interval = value_lst1.length / num_entries
			for(cnt:(0..value_lst1.length-1))
				if (cnt%interval==0)
					value_lst2.add(value_lst1.get(cnt))
		} else { 												// simply copy the list
			for(value:value_lst1)
				value_lst2.add(value)
		}
		
		Collections.sort(value_lst2)
		
		var int last_value = -1 								// to detect and aggregate similar values 
		var int current_freq = 1
		for(value:value_lst2){
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
	
	def static eCDF_to_string(MVExpECDF ecdf){
		var ret_str = ""
		for(freq_val:ecdf.freqval)
			ret_str = ret_str + "\n(" + freq_val.freq + ":" + freq_val.value + ")" 
		return ret_str
	}
	
	/*def static test_multiplying_ecdfs(){
		var MVExpECDF ecdf1        		 = IdslGeneratorSyntacticSugarECDF.create_random_eCDF(5)
		var MVExpECDF ecdf1_clean		 = sort_and_clean_ecdf(ecdf1)
		var MVExpECDF ecdf2        		 = IdslGeneratorSyntacticSugarECDF.create_random_eCDF(5)
		var MVExpECDF ecdf2_clean		 = sort_and_clean_ecdf(ecdf2)
		var MVExpECDF ecdf_product 		 = IdslGeneratorSyntacticSugarECDF.multiply_eCDFs(ecdf1_clean,ecdf2_clean,10000)
		var MVExpECDF ecdf_product_clean = sort_and_clean_ecdf(ecdf_product)
		
		// *****************************************************************************************************		
		System.out.println("---- eCDF 1 ----")		
		System.out.println(IdslGeneratorSyntacticSugarECDF.eCDF_to_string(ecdf1_clean))		

		// *****************************************************************************************************		
		System.out.println("---- eCDF 2 ----")		
		System.out.println(IdslGeneratorSyntacticSugarECDF.eCDF_to_string(ecdf2_clean))	
		
		// *****************************************************************************************************		
		System.out.println("---- eCDF product ----")		
		System.out.println(IdslGeneratorSyntacticSugarECDF.eCDF_to_string(ecdf_product_clean))
	}*/
	
	def static test_sampling_from_ecdf(){
		var MVExpECDF ecdf        = IdslGeneratorSyntacticSugarECDF.create_random_eCDF(20)
		var MVExpECDF ecdf_clean  = IdslGeneratorSyntacticSugarECDF.sort_and_clean_ecdf(ecdf)

		// *****************************************************************************************************		
		System.out.println("---- eCDF ----")
		System.out.println(IdslGeneratorSyntacticSugarECDF.eCDF_to_string(ecdf_clean))

		// *****************************************************************************************************		
		System.out.println("---- samples ----")
		var List<Integer> values1 = new ArrayList<Integer>
		for(cnt:1..2000){
			val double sample = IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf_clean,1) // interpolation
			//System.out.println(IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf_clean))
			values1.add(sample as int)
		}
		var ecdf_val1 = IdslGeneratorSyntacticSugarECDF.create_eCDF_from_values(values1)
		var ecdf_val1_clean = sort_and_clean_ecdf(ecdf_val1)
		System.out.println(IdslGeneratorSyntacticSugarECDF.eCDF_to_string(ecdf_val1_clean))
		
		// *****************************************************************************************************
		System.out.println("---- samples (with interpolation) ----")
		var List<Integer> values2 = new ArrayList<Integer>	
		for(cnt:1..2000){
			val double sample = IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf_clean)
			//System.out.println(IdslGeneratorSyntacticSugarECDF.draw_sample_eCDF(ecdf_clean,true))
			values2.add(sample as int)
		}
		var ecdf_val2 = IdslGeneratorSyntacticSugarECDF.create_eCDF_from_values(values2)
		var ecdf_val2_clean = sort_and_clean_ecdf(ecdf_val2)
		System.out.println(IdslGeneratorSyntacticSugarECDF.eCDF_to_string(ecdf_val2_clean))		
	}

}