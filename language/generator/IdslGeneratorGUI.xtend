package org.idsl.language.generator

import java.awt.BorderLayout
import java.awt.FlowLayout
import java.awt.event.ActionEvent
import java.awt.event.ActionListener
import java.util.ArrayList
import java.util.List
import javax.swing.JButton
import javax.swing.JFrame
import javax.swing.JList
import javax.swing.JProgressBar
import javax.swing.JScrollPane
import javax.swing.JLabel
import javax.swing.DefaultBoundedRangeModel
import javax.swing.SwingUtilities
import org.eclipse.xtext.generator.IFileSystemAccess
import org.idsl.language.idsl.MeasurementResults
import org.eclipse.emf.ecore.resource.Resource
import javax.swing.ListSelectionModel

public class IdslGeneratorGUI extends JFrame implements ActionListener, Runnable {
	
	private static List<JFrame> opened_windows=new ArrayList<JFrame>

	var static IFileSystemAccess file_system
	var static MeasurementResults measurement_results
	var static Resource resource
	var static String path
	
	val static public all_design_instance_string = "All design instances"	
	var JList<String> jlist_dsi
	var JButton jbutton_compute = new JButton("Compute")
	var List<String> designInstances=new ArrayList<String>
	var JLabel jlabel_progress = new JLabel("")
	var DefaultBoundedRangeModel model = new DefaultBoundedRangeModel
	var JProgressBar jProgressBar_computation = new JProgressBar (model)
	
	def public static set_resource(Resource res) { resource=res }
	def public static set_filesystem(IFileSystemAccess fsa) { file_system=fsa }
	def public static set_measurements_results(MeasurementResults mr ) {measurement_results=mr }
	def public static set_path(String pathname) {path=pathname}
	
	//def public 
	
	def public start(String model_name) { // generates a default window to get started with
   		if(opened_windows.length>0) // if any other analyze windows opened, close them
   			for(ow:opened_windows)
   				ow.dispose
   				
   		opened_windows=new ArrayList<JFrame>
		opened_windows.add(this)
   		
   		this.setTitle("iDSL executer: "+model_name)
   		this.setSize(600, 400)
   		this.setLocationRelativeTo(null)
   		this.setVisible(true)
   		this.setLayout(new FlowLayout)
   		
		setup_JList(designInstances)
		setup_progressbar
		
		jbutton_compute.addActionListener(this)
		//this.add(new JLabel("kakakaak"), BorderLayout.WEST)
		
		this.add(jbutton_compute, BorderLayout.EAST)
		this.add(new JScrollPane(jlist_dsi), BorderLayout.SOUTH) 
		this.add(jProgressBar_computation, BorderLayout.WEST) 	
		this.add(jlabel_progress, BorderLayout.WEST) 
		    	
		this.pack 
    }
    
    def setup_JList(List<String> list){
    	list.add(all_design_instance_string)
    	jlist_dsi = new JList(list.toArray);
    	jlist_dsi.setSelectedIndex(0)
    	jlist_dsi.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION) // enable multiselect
    }
    
    def setup_progressbar(){
		jProgressBar_computation.setValue(0)
		jProgressBar_computation.setStringPainted(true)
		jProgressBar_computation.setMaximum(100)
    }
    
    def public addDesignInstance(String dsis) { 
    	designInstances.add(dsis)
    }
	
	def public perform_command(String command, String output, String dsi, String description){
		switch(description){ // Run console by default and special cases otherwise
			case "Measure timeouts":			System.out.println("warning: perform_command Measure timeouts skipped")
												//IdslGeneratorDesignSpaceMeasurements.readTimeouts(command, dsi+" "+output)
			case "Measure latencies": 			System.out.println("warning: perform_command Measure latencies skipped")
												//IdslGeneratorDesignSpaceMeasurements.readLatencies(command, dsi+" "+output)
			case "Measure utilizations":		System.out.println("warning: perform_command Measure utilizations skipped")
												//IdslGeneratorDesignSpaceMeasurements.readUtilizations(command, dsi+" "+output)
			case "Measure bounds":				IdslGeneratorDesignSpaceMeasurements.readTheobounds(command, dsi+" "+output)
			case "MODES simulation":			IdslGeneratorConsole.executeAndCheckForParsingError(command, output)				
			case "Model checking":	  			IdslGeneratorMODESBinarySearch.binarySearch(command, file_system)
			case "Compute utility function":	System.out.println("warning: perform_command Compute utility function skipped")
												//IdslGeneratorDesignSpaceMeasurements.computeUtilityFunctions(dsi, measurement_results)
			case "PTA Model checking":			IdslGeneratorPerformExperimentPTAModelCheck.PTAModelcheck(command,output /*which is the current DSI + SPACE + service*/)
			case "Dynamic PTA Model checking":  IdslGeneratorPerformExperimentPTAModelCheck.PTAModelcheckDynamic(command)
			case "PTA Model checking2":			IdslGeneratorPerformExperimentPTAModelCheck2.PTAModelcheck(command, output) // loop per service happens inside PTAModelcheck
			case "ComputeAverageLatencyAndPower": IdslGeneratorPerformExperimentSimulationLoadBalancer.extractAvgPowerAndLatencyWithCI(command,output)
			default:				  			IdslGeneratorConsole.execute(command, output)
		}
	}
	
	override actionPerformed(ActionEvent arg0) { // Execute the select Design Instance of choice
		var List<String> dsi_vals = jlist_dsi.selectedValuesList	// multi select
		var List<String> contents_of_local_batch_file				= IdslGeneratorGlobalVariables.selected_contents_of_local_batch_file(dsi_vals)
		var List<String> contents_of_local_batch_output_file		= IdslGeneratorGlobalVariables.selected_contents_of_local_batch_output_file(dsi_vals)
		var List<String> contents_of_local_batch_file_description	= IdslGeneratorGlobalVariables.selected_contents_of_local_batch_file_description(dsi_vals)
		var List<String> contents_of_local_batch_file_dsi			= IdslGeneratorGlobalVariables.selected_contents_of_local_batch_file_dsi(dsi_vals)

		
		//var String       dsi_val  = jlist_dsi.selectedValue   		// single select (depreciated)
		//var List<String> contents_of_local_batch_file				= IdslGeneratorGlobalVariables.selected_contents_of_local_batch_file(#[dsi_val])
		//var List<String> contents_of_local_batch_output_file		= IdslGeneratorGlobalVariables.selected_contents_of_local_batch_output_file(#[dsi_val])
		//var List<String> contents_of_local_batch_file_description	= IdslGeneratorGlobalVariables.selected_contents_of_local_batch_file_description(#[dsi_val])
		//var List<String> contents_of_local_batch_file_dsi			= IdslGeneratorGlobalVariables.selected_contents_of_local_batch_file_dsi(#[dsi_val])
		
		jProgressBar_computation.setMaximum(contents_of_local_batch_file.length-1)
		
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("START execute_batch_file")
		for(cnt:0..contents_of_local_batch_file.length-1){ //item by item command-line execution 
			var long starting_time = System.nanoTime // for measuring the time the task takes
			
			var command     = contents_of_local_batch_file.get(cnt)  
			var output 	    = contents_of_local_batch_output_file.get(cnt)
			var dsi		    = contents_of_local_batch_file_dsi.get(cnt)
			var description = contents_of_local_batch_file_description.get(cnt)
			
			perform_command(command, output, dsi, description)
			
			var long ending_time = System.nanoTime
			IdslGeneratorConsole.writeLineToFile(IdslConfiguration.Lookup_value("logfile_name"), contents_of_local_batch_file.get(cnt))
			IdslGeneratorConsole.writeLineToFile(IdslConfiguration.Lookup_value("logfile_name"), (ending_time-starting_time).toString)

			// UNDER CONSTRUCTION
			SwingUtilities.invokeLater(this) // calls run() in the UI thread 
		}
		/* stopwatch */ IdslConfiguration.writeTimeToTimestampFile("STOP execute_batch_file")
		
		//IdslGenerator.iDSLinstanceToDisc("results")
		
		// Post processing
		IdslGenerator.doGenerate_postprocessing(file_system, path, resource) // WARNING: may also be implemented as one of the steps above
		
		//System.out.println(IdslGeneratorGlobalVariables.file_outputfile_description_and_dsi_to_string(contents_of_local_batch_file, contents_of_local_batch_output_file, contents_of_local_batch_file_description))
	}
	
	override run() {
		jProgressBar_computation.setValue(5)
		jProgressBar_computation.repaint
	}
}