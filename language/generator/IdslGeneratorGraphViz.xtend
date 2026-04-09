package org.idsl.language.generator

import java.util.LinkedHashSet
import org.eclipse.xtext.generator.IFileSystemAccess
import org.idsl.language.idsl.AbstractionProcessModel
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.AtomicProcessModel
import org.idsl.language.idsl.AtomicResourceTree
import org.idsl.language.idsl.CompoundResourceTree
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.MutexProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.ResourceTree
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.ServiceRequest
import org.idsl.language.idsl.DesAltProcessModel
import org.idsl.language.idsl.DesignSpaceModel
import java.util.List
import org.idsl.language.idsl.LoadBalancerConfiguration
import org.idsl.language.idsl.LoadBalancerProcessModel

class IdslGeneratorGraphViz {
 	public static def PrintPlaceholderLatency(String name, boolean visible) '''«IF visible»\lxxxproperty_latency_«name»xxx«ENDIF»'''// _10 is temporary hack (must be: activity nr selection)	
 	public static def PrintPlaceholderUtil(String name, boolean visible) '''«IF visible»\lxxxproperty_utilization_«name»xxx«ENDIF»''' // xxx enables unique identification (see .AWK file)	

	public static def GraphTitle(String title)'''«IF IdslConfiguration.Lookup_value("Graph_titles")=="true"»
		labelloc="t";
		label="«title»";«ENDIF»'''

	public static def ResourceToGraph(String title, ResourceModel rmodel)'''
		graph G{node [style=rounded shape=box];
		«FOR conn:rmodel.resconn»"«conn.resource_from.replace("_","\\l")»"--"«conn.resource_to.replace("_","\\l")»";«ENDFOR»
		«FOR rtree:rmodel.restree»«ResourceTreeToGraph(rtree)»«ENDFOR»
		«GraphTitle(title)»}'''
	
	public static def ResourceTreeToGraph(ResourceTree rt){ 
		switch(rt){
			AtomicResourceTree: '''"«rt.name.replace("_","\\l")»" '''
			CompoundResourceTree: '''
			subgraph cluster_«rt.name» { label = "«rt.name.replace("_","\\l")»" 
				«FOR subtree:rt.rtree»«ResourceTreeToGraph(subtree)»«ENDFOR»
			}'''
		}	
	}

	public static def ExtProcessToGraph(String title, ExtendedProcessModel extprocess, DesignSpaceModel dsm, DesignSpaceModel dsi){
		IdslGeneratorGlobalVariables.global_processes_to_print=new LinkedHashSet<String>()
		'''digraph G{node [style=rounded shape=box];«ProcessToGraph(extprocess.pmodel.head, dsm, dsi)»
		«FOR gl:IdslGeneratorGlobalVariables.global_processes_to_print»«FOR spm:extprocess.spm»
		«IF IdslGeneratorGlobalVariables.global_processes_to_print.contains(spm.name)»«ProcessToGraph(spm.pmodel.head, dsm, dsi)»«ENDIF»
		«ENDFOR»«ENDFOR»
		«GraphTitle(title)»}'''
	}

	public static def ProcessToGraph(ProcessModel pmodel, DesignSpaceModel dsm, DesignSpaceModel dsi){
		 switch (pmodel){ AbstractionProcessModel: IdslGeneratorGlobalVariables.global_processes_to_print.add(pmodel.name) }
		 
		 switch (pmodel){
					AtomicProcessModel:			return ""				     // does not need code, since its parent will list its name
					AbstractionProcessModel:	return ""					 // does not need code, since its parent will list its name				
					AltProcessModel:'''
						«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»"->"«p.name.replace("_","\\l")»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»alt«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
						«FOR p:pmodel.pmodel»«ProcessToGraph(p, dsm, dsi)»«ENDFOR»
						'''
					PaltProcessModel:'''
						«var cnt=1»«FOR p:pmodel.ppmodel»"«pmodel.name.replace("_","\\l")»"->"«p.pmodel.head.name.replace("_","\\l")»" [label = " «IF cnt==1 || cnt==pmodel.ppmodel.length»palt«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
						«FOR p:pmodel.ppmodel»«ProcessToGraph(p.pmodel.head, dsm, dsi)»«ENDFOR»
						'''
					ParProcessModel:'''
						«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»"->"«p.name.replace("_","\\l")»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»par«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
						«FOR p:pmodel.pmodel»«ProcessToGraph(p, dsm, dsi)»«ENDFOR»
						'''
					SeqProcessModel:'''
						«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»"->"«p.name.replace("_","\\l")»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»seq«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
						«FOR p:pmodel.pmodel»«ProcessToGraph(p, dsm, dsi)»«ENDFOR»
						'''
					MutexProcessModel:'''
						«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»"->"«p.name.replace("_","\\l")»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»mutex«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
						«FOR p:pmodel.pmodel»«ProcessToGraph(p, dsm, dsi)»«ENDFOR»
						'''	
					DesAltProcessModel:'''
						«IF dsi==null»«/* Display everything */»
							«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»"->"«p.pmodel.head.name.replace("_","\\l")»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»desalt«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
							«FOR p:pmodel.pmodel»«ProcessToGraph(p.pmodel.head, dsm, dsi)»«ENDFOR»
						«ELSE»«/* Display the one defined in the DSI */»
							«var index=IdslGeneratorDesignSpace.lookupValuePositionDSM(pmodel.param.head, dsi, pmodel.pmodel)»
							«var chosenProcess=pmodel.pmodel.get(index).pmodel.head»
							"«pmodel.name.replace("_","\\l")»"->"«chosenProcess.name.replace("_","\\l")»" [label = "desalt"];
							«ProcessToGraph(chosenProcess, dsm, dsi)»
						«ENDIF»
						'''	
					LoadBalancerProcessModel:'''ERROR: ProcessMappingToGraph: LoadBalancerProcessModel not supported!'''					
		 }				
	}    // ORGINALLY: lookupValuePositionDSM (String param, DesignSpaceModel dsm, DesignSpaceModel dsi)

	public static def ExtProcessMappingToGraph(String title, ExtendedProcessModel extprocess, Mapping mapping, boolean showPlaceholders, DesignSpaceModel dsm, DesignSpaceModel dsi){
		IdslGeneratorGlobalVariables.global_processes_to_print=new LinkedHashSet<String>() // for abstract processes
		IdslGeneratorGlobalVariables.global_resources_to_print=new LinkedHashSet<Pair<String,LoadBalancerConfiguration>> // to prrealresources and their init exactly once
		'''digraph G{node [style=rounded shape=box];«ProcessMappingToGraph(extprocess.pmodel.head, mapping, showPlaceholders, dsm, dsi)»
		«FOR gl:IdslGeneratorGlobalVariables.global_processes_to_print»«FOR spm:extprocess.spm»
			«IF IdslGeneratorGlobalVariables.global_processes_to_print.contains(spm.name.head)»
			"«spm.name.head.replace("_","\\l")»«PrintPlaceholderLatency(spm.name.head, showPlaceholders)»"->"«spm.pmodel.head.name.replace("_","\\l")»«PrintPlaceholderLatency(spm.pmodel.head.name, showPlaceholders)»" [label = " call" ];
			«ProcessMappingToGraph(spm.pmodel.head, mapping, showPlaceholders, dsm, dsi)»«ENDIF»
		«ENDFOR»«ENDFOR»
			subgraph cluster_resources { label = "resources" «FOR res:IdslGeneratorGlobalVariables.global_resources_to_print» "«res.key.replace("_","\\l")»«PrintPlaceholderUtil(res.key,showPlaceholders)»" «ENDFOR»}
			«GraphTitle(title)»}'''
	}
	
	
	public static def ProcessMappingToGraph(ProcessModel pmodel, Mapping mapping, boolean showPlaceholders, DesignSpaceModel dsm, DesignSpaceModel dsi){
		 for (a:mapping.prassignment){
		 	if(pmodel.name==a.process){ // detected the process/mapping boundary
		 		IdslGeneratorGlobalVariables.global_resources_to_print.add(a.resource->null)
		 		return '''"«pmodel.name.replace("_","\\l")»«PrintPlaceholderLatency(pmodel.name, showPlaceholders)»"->"«a.resource.replace("_","\\l")»«PrintPlaceholderUtil(a.resource,showPlaceholders)»"
		 				'''
		 	}
		 }
		 switch (pmodel){ AbstractionProcessModel: IdslGeneratorGlobalVariables.global_processes_to_print.add(pmodel.name) }
		 	 
		 switch (pmodel){
				AtomicProcessModel:			return ""										// does not need code, since its parent will list its name
				AbstractionProcessModel:	return ""								 		// does not need code, since its parent will list its name
					AltProcessModel:'''
					«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»«PrintPlaceholderLatency(pmodel.name, showPlaceholders)»"->"«p.name.replace("_","\\l")»«PrintPlaceholderLatency(p.name, showPlaceholders)»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»alt«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
					«FOR p:pmodel.pmodel»«ProcessMappingToGraph(p,mapping, showPlaceholders, dsm, dsi)»«ENDFOR»
					'''
				PaltProcessModel:'''
					«var cnt=1»«FOR p:pmodel.ppmodel»"«pmodel.name.replace("_","\\l")»«PrintPlaceholderLatency(pmodel.name, showPlaceholders)»"->"«p.pmodel.head.name.replace("_","\\l")»«PrintPlaceholderLatency(p.pmodel.head.name, showPlaceholders)»" [label = " «IF cnt==1 || cnt==pmodel.ppmodel.length»palt«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
					«FOR p:pmodel.ppmodel»«ProcessMappingToGraph(p.pmodel.head,mapping, showPlaceholders, dsm, dsi)»«ENDFOR»
					'''
				ParProcessModel:'''
					«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»«PrintPlaceholderLatency(pmodel.name, showPlaceholders)»"->"«p.name.replace("_","\\l")»«PrintPlaceholderLatency(p.name, showPlaceholders)»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»par«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
					«FOR p:pmodel.pmodel»«ProcessMappingToGraph(p,mapping, showPlaceholders, dsm, dsi)»«ENDFOR»
					'''
				SeqProcessModel:'''
					«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»«PrintPlaceholderLatency(pmodel.name, showPlaceholders)»"->"«p.name.replace("_","\\l")»«PrintPlaceholderLatency(p.name, showPlaceholders)»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»seq«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
					«FOR p:pmodel.pmodel»«ProcessMappingToGraph(p,mapping, showPlaceholders, dsm, dsi)»«ENDFOR»					
					'''
				MutexProcessModel:''' 
					«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»«PrintPlaceholderLatency(pmodel.name, showPlaceholders)»"->"«p.name.replace("_","\\l")»«PrintPlaceholderLatency(p.name, showPlaceholders)»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»mutex«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
					«FOR p:pmodel.pmodel»«ProcessMappingToGraph(p,mapping, showPlaceholders, dsm, dsi)»«ENDFOR»
					'''	
				DesAltProcessModel:'''				
					«IF dsi==null»
						«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»«PrintPlaceholderLatency(pmodel.name, showPlaceholders)»"->"«p.pmodel.head.name.replace("_","\\l")»«PrintPlaceholderLatency(p.pmodel.head.name, showPlaceholders)»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»desalt«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
						«FOR p:pmodel.pmodel»«ProcessMappingToGraph(p.pmodel.head,mapping, showPlaceholders, dsm, dsi)»«ENDFOR»
					«ELSE»
						«var index=IdslGeneratorDesignSpace.lookupValuePositionDSM(pmodel.param.head, dsi, pmodel.pmodel)»
						«var chosenProcess=pmodel.pmodel.get(index).pmodel.head»
						"«pmodel.name.replace("_","\\l")»«PrintPlaceholderLatency(pmodel.name, showPlaceholders)»"->"«chosenProcess.name.replace("_","\\l")»" [label = "desalt"];
						«ProcessMappingToGraph(chosenProcess, mapping, showPlaceholders, dsm, dsi)»
					«ENDIF»'''
					//	«IF dsi==null»
					//		«var cnt=1»«FOR p:pmodel.pmodel»"«pmodel.name.replace("_","\\l")»"->"«p.name.replace("_","\\l")»" [label = " «IF cnt==1 || cnt==pmodel.pmodel.length»desalt«ENDIF»"];«(cnt=cnt+1).toString.substring(0,0)»«ENDFOR»
					//		«FOR p:pmodel.pmodel»«ProcessToGraph(p, dsm, dsi)»«ENDFOR»
				LoadBalancerProcessModel:'''ERROR: ProcessMappingToGraph: LoadBalancerProcessModel not supported!'''
		 }	
	}
	
	public static def createNonPerformanceGraphs(IFileSystemAccess fsa, ServiceRequest ainstance, String extPath, DesignSpaceModel dsm, DesignSpaceModel dsi){
		var activitymodel = ainstance.activity_id.head
		var extprocess = activitymodel.extprocess_id
		var resource = activitymodel.resource_id
		var mapping = activitymodel.mapping
		
		if (IdslConfiguration.Lookup_value("evaluate_createNonPerformanceGraphs")=="true"){
			var extprocess_filename=extPath+"graphviz/Process_"+activitymodel.extprocess_id.name+".Graphviz"
			fsa.generateFile(extprocess_filename, IdslGeneratorGraphViz.ExtProcessToGraph("Process overview of Process_"+activitymodel.extprocess_id.name, extprocess, dsm, dsi))
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("dot.exe "+extprocess_filename+" -T"+IdslConfiguration.Lookup_value("Output_format_graphics")+" -o"+extPath+"graphviz/Process_"+activitymodel.extprocess_id.name+"."+IdslConfiguration.Lookup_value("Output_format_graphics"), "", "GraphViz non-performance")
			
			var resource_filename=extPath+"graphviz/Resource_"+activitymodel.extprocess_id.name+".Graphviz"
			fsa.generateFile(resource_filename, IdslGeneratorGraphViz.ResourceToGraph("Resource overview of Resource_"+activitymodel.extprocess_id.name, resource))
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("dot.exe "+resource_filename+" -T"+IdslConfiguration.Lookup_value("Output_format_graphics")+" -o"+extPath+"graphviz/Resource_"+activitymodel.extprocess_id.name+"."+IdslConfiguration.Lookup_value("Output_format_graphics"), "", "GraphViz non-performance")
			
			var process_mapping_filename=extPath+"graphviz/ProcessMapping_"+activitymodel.extprocess_id.name+".Graphviz"
			fsa.generateFile(process_mapping_filename, IdslGeneratorGraphViz.ExtProcessMappingToGraph("Process and mapping overview of ProcessMapping_"+activitymodel.extprocess_id.name, extprocess, mapping.head, false, dsm, dsi))
			IdslGeneratorGlobalVariables.global_contents_of_local_batch_file_add("dot.exe "+process_mapping_filename+" -T"+IdslConfiguration.Lookup_value("Output_format_graphics")+" -o"+extPath+"graphviz/ProcessMapping_"+activitymodel.extprocess_id.name+"."+IdslConfiguration.Lookup_value("Output_format_graphics"), "", "GraphViz non-performance")			
		}
	}
}