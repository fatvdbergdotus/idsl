package org.idsl.language.generator

import java.io.BufferedReader
import java.io.FileInputStream
import java.io.InputStream
import java.io.InputStreamReader
import java.nio.charset.Charset
import org.eclipse.xtext.generator.IFileSystemAccess
import java.io.OutputStream
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.io.BufferedWriter
import java.util.List
import java.util.ArrayList
import java.io.File
import java.util.concurrent.TimeUnit

class IdslGeneratorConsole {
		//try{
		//		var Runtime r=Runtime.runtime
		//		// var Process p=r.exec("cmd /c dir C:\\")
		//		var Process p=r.exec("cmd /c C:\\temp\\fred.bat") 
		//		p.waitFor(); 
        //         
        //        var BufferedReader reader=new BufferedReader(new InputStreamReader(p.getInputStream())); 
        //        var String line;
        //         
        //        while((line = reader.readLine()) != null) 
        //        { System.out.println(line); } 
		//}
		//catch(Exception e){ System.out.println("Done"); }
		
		// Pause for post-processing
		//System.out.println("Press run go-all.bat first now.")
		//System.out.println("Press any key to continue after go-all.bat has finished...")
		//var BufferedReader stdin = new BufferedReader(new InputStreamReader(System.in)); 
		//stdin.readLine();
		
		var static public IFileSystemAccess file_system
		
		def static public writeLineToFile (String filename, String line){
			var lines=new ArrayList<String>
			lines.add(line)
			writeLineToFile(filename,lines)
		}
		
		def static public writeLineToFile (String filename, List<String> lines){
			var OutputStream   fos = new FileOutputStream(filename, true)
			var BufferedWriter bw = new BufferedWriter(new OutputStreamWriter(fos, Charset.forName("UTF-8")))
			
			for(l:lines) bw.write(l+"\n") // write line by line to file
			bw.close	
		}
		
		def static void executeBatch (String batchfile){ // executes a batch file line by line
			var InputStream    fis = new FileInputStream(batchfile)
			var BufferedReader br = new BufferedReader(new InputStreamReader(fis, Charset.forName("UTF-8")))
			var String         line;
			
			while ((line = br.readLine) != null) // execute the batch file line by line
			    execute(line,"")

			br.close
		}

		def public static String executeAndCheckForParsingError (String command, String output_filename, int num_retries){
			var File file = new File(output_filename) // delete the previously created outputfile
			file.delete

			// The next attempt
			execute(command,output_filename)
			val firstLine = IdslGeneratorMODESBinarySearch.readOneLineFromFile(output_filename)
			
			if (firstLine==null || firstLine.contains(": error:")){ // ERROR found. Act accordingly
				System.out.println("Warning: Maybe modest output file not found.") // Modest does not return anything
				if(num_retries==0)
					throw new Throwable("Modest file "+output_filename+" results into an error: "+firstLine) // last try and still error result
				else{	
					System.out.println("Warning: Modest file "+output_filename+" results into an error: "+firstLine+", retries left: "+num_retries.toString)
					return executeAndCheckForParsingError(command, output_filename, num_retries-1) // error result, but more attempts left
				}
			}
			//everything is fine here
			return firstLine
		}

		def public static String executeAndCheckForParsingError (String command, String output_filename){
			execute(command,output_filename)
			val firstLine = IdslGeneratorMODESBinarySearch.readOneLineFromFile(output_filename)
		
			if (firstLine==null || firstLine=="" || firstLine.contains(": error:")){ // ERROR found. Act accordingly.
				var int num_retries = new Integer(IdslConfiguration.Lookup_value("execution_retry_runs"))
				executeAndCheckForParsingError(command, output_filename, num_retries)
			}
			return firstLine
		}
		
		def private static BufferedReader getOutput(Process p) {
		    return new BufferedReader(new InputStreamReader(p.getInputStream))
		}
		
		def private static BufferedReader getError(Process p) {
		    return new BufferedReader(new InputStreamReader(p.getErrorStream))
		}
		
		def public static void execute(String command, String output_filename){
			if (command.length>3 && command.substring(command.length-4)==".bat"){ //batch file: execute command by command 
				executeBatch(command)
				return
			}			
			
			var String fileout = ""
			if(output_filename!=null && output_filename!=""){
				fileout = " > " + output_filename 
				System.out.println(command+" > "+output_filename) 			//DEBUG
			}
			else
				System.out.println(command+"   "+output_filename) 			//DEBUG
				
			if (IdslConfiguration.Lookup_value("java_execution_engine")=="process"){ // use process as engine
				var Runtime r=Runtime.runtime
				var Process p=r.exec ("C:\\Windows\\System32\\cmd.exe /c "+command + fileout, null, new File("f:\\inpath\\"))
				p.waitFor
				
				// for outputting the process
				var BufferedReader output = getOutput(p)
				var BufferedReader error = getError(p)
				var String line
				while ((line = output.readLine()) != null) 
    				System.out.println(line);
				while ((line = error.readLine()) != null) 
				 	System.out.println(line);

				
				System.out.println("exitvalue: " + p.exitValue)		
			} else { // use processbuilder as engine
				var ProcessBuilder builder = new ProcessBuilder("cmd", "/c", command, fileout)
		        //builder.redirectErrorStream(true)
		        var Process p = builder.start
		        //p.waitFor
		        if(!p.waitFor(3, TimeUnit.SECONDS))
		        	p.destroy
		        	
		        var BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream))
		        var String line;
				while ((line = r.readLine) != null) 
	            	System.out.println(line)
	            
	            System.out.println("exitvalue: " + p.exitValue)			
            }
		}
		
		def public static execute(String command) { 
			execute(command, "")
		} // executions without output
		
		def public static boolean /* succesful exit? */ execute_with_timeout(String command, int timeout_seconds){
			var ProcessBuilder builder = new ProcessBuilder("cmd", "/c", command)
	        var Process p = builder.start

			if(!p.waitFor(timeout_seconds, TimeUnit.SECONDS)) {
   			 	System.out.println("timeout!")
   			 	// p.destroyForcibly // does not work!
				var ProcessBuilder kill_builder = new ProcessBuilder("taskkill", "/f", "/im", "mcsta.exe") // warning: kills all mcsta.exe's
	        	var Process p_kill = kill_builder.start
	        	p_kill.waitFor
   				return false // time is up, execution failed 	
   			}
	        	
	        var BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream))
	        var String line;
			while ((line = r.readLine) != null) 
            	System.out.println(line)
            
            System.out.println("exitvalue: " + p.exitValue)
            return true // succesfully terminated	
		}
		
		def public static void execute(IFileSystemAccess fsa, String command, String output_filename){
			file_system=fsa // the fsa only needs to be initialized once and will be remembered forever
			execute(command, output_filename)
		}
		
		def public static set_filesystem(IFileSystemAccess fsa) { file_system=fsa }
		
		def static void main(String[] args) {
			//var Process p = Runtime.getRuntime.exec("cmd /c \"modes -?>>C:\\temp\\abcdef\"")
            //var BufferedReader in = new BufferedReader( new InputStreamReader(p.getInputStream))
            //var String line = null;
            //while ((line = in.readLine()) != null) {
            //    System.out.println(line);
            //}
            //p.waitFor
			//System.out.println("exitvalue: " + p.exitValue)	
			

			
			//execute("modes -?", "")
			//execute("gawk.exe", "C:\\temp\\67")
			
			//execute("modes", "C:\\temp\\68"
			//execute("F:\\inpath\\gawk.exe", "")
			
			//execute("f:\\inpath\\modes.exe -?", "")
		}
}
