package org.idsl.language.generator

import java.io.InputStream
import java.io.BufferedReader
import java.io.FileInputStream
import java.io.InputStreamReader
import java.nio.charset.Charset
import java.io.File
import org.eclipse.xtext.generator.IFileSystemAccess

class IdslGeneratorMODESBinarySearch {
	def static minimum(int value1, int value2){ if (value1<=value2) return value1 else return value2 }
	
	def static int binarySearch(String modestFilename, int lowerbound, int upperbound, boolean isLowerboundSearch, String computationTrace){

		if (Math.abs(lowerbound-upperbound)<=1) // range small enough to be returned as final answer
			if (isLowerboundSearch) 
				return minimum(lowerbound,upperbound)
			else
				return 0-minimum(0-lowerbound,0-upperbound) // maximum
			
		val valueToCheck = (upperbound+lowerbound)/2
		val result 		 = executeModelChecking (modestFilename, valueToCheck )
		
		var updatedComputationTrace=computationTrace+"\n range ["+lowerbound.toString+":"+upperbound.toString+"] result "+result.toString
		System.out.println(updatedComputationTrace)
		if ( (result=="0" && isLowerboundSearch) || (result!="0" && !isLowerboundSearch) ) // continue with upper range
			return binarySearch(modestFilename, valueToCheck, upperbound, isLowerboundSearch, updatedComputationTrace)
		else // otherwise, continue with lower range 
			return binarySearch(modestFilename, lowerbound, valueToCheck, isLowerboundSearch, updatedComputationTrace)		
	}
	
	def static int binarySearch(String modestFilename, int lowerbound, int upperbound, boolean isLowerboundSearch){
		return binarySearch(modestFilename, lowerbound, upperbound, isLowerboundSearch, "")
	}
	
	def static void binarySearch(String modestPrefixFilename, IFileSystemAccess fsa){
		val lb = binarySearch(modestPrefixFilename+"-lb.modest",0,new Integer(IdslConfiguration.Lookup_value("model_checking_interval_size")),true,"")
		val ub = binarySearch(modestPrefixFilename+"-ub.modest",0,new Integer(IdslConfiguration.Lookup_value("model_checking_interval_size")),false,"")
		fsa.generateFile(modestPrefixFilename+"-lb.out",lb.toString) // overwrite
		fsa.generateFile(modestPrefixFilename+"-ub.out",ub.toString) // overwrite
	}
	
	def static String executeModelChecking (String modestFilename, int valueToCheck){
		val mc = IdslConfiguration.Lookup_value("mctau_or_mc") 
		val command = mc+" "+modestFilename+" -E \"VAL="+valueToCheck+"\" | find \"Result:\" | gawk \"{print $2}\" > "+modestFilename+".temp"
		IdslGeneratorConsole.executeAndCheckForParsingError(command, "")
		
		val result = readOneLineFromFile(modestFilename+".temp")
		var File file = new File(modestFilename+".temp")
		file.delete
		
		return result
	}
	
	def static readOneLineFromFile(String filename){
		var InputStream    fis = new FileInputStream(filename)
		var BufferedReader br = new BufferedReader(new InputStreamReader(fis, Charset.forName("UTF-8")));
		var String         line = br.readLine;

		br.close
		return line
	}
}