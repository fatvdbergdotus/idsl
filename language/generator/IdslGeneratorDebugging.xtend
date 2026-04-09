package org.idsl.language.generator

import org.idsl.language.idsl.AbstractionProcessModel
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.AtomicProcessModel
import org.idsl.language.idsl.MutexProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.Mapping
import java.util.List
import org.idsl.language.idsl.ProcessResource
import org.idsl.language.idsl.ResourceSchedulingPolicy
import java.io.IOException
import java.io.FileOutputStream
import java.io.ObjectOutputStream
import org.idsl.language.idsl.Model
import java.io.Serializable
import com.google.inject.Injector
import com.google.inject.Guice
import org.eclipse.xtext.parsetree.reconstr.Serializer
import org.eclipse.emf.ecore.EObject
import org.idsl.language.idsl.DesAltProcessModel
import org.idsl.language.idsl.DesAltProcessModel

class IdslGeneratorDebugging {
	static def spaces(int num){'''«FOR x:(1..num)» «ENDFOR»'''}
	static def newline(){return "\n" }
	
	static def PrintProcessTree(ProcessModel pmodel){  // main call, without indent
		if (IdslConfiguration.Lookup_value("Debug_mode")=="true") return PrintProcessTree(pmodel, 0) else return ""
	}
	
	static def PrintProcessTree(ProcessModel pmodel, int indent){
	  switch (pmodel){
			AtomicProcessModel:		 '''«spaces(indent)»Atom "«pmodel.name»"«newline»'''	
			AbstractionProcessModel: '''«spaces(indent)»Call "«pmodel.name»"«newline»'''								
			AltProcessModel:		 '''«spaces(indent)»Alt "«pmodel.name»"«newline»«FOR p:pmodel.pmodel»«PrintProcessTree(p, indent+3)»«ENDFOR»'''
			PaltProcessModel:		 '''«spaces(indent)»Palt "«pmodel.name»"«newline»«FOR p:pmodel.ppmodel»«PrintProcessTree(p.pmodel.head, indent+3)»«ENDFOR»'''
			ParProcessModel:		 '''«spaces(indent)»Par "«pmodel.name»"«newline»«FOR p:pmodel.pmodel»«PrintProcessTree(p, indent+3)»«ENDFOR»'''
			SeqProcessModel:		 '''«spaces(indent)»Seq "«pmodel.name»"«newline»«FOR p:pmodel.pmodel»«PrintProcessTree(p, indent+3)»«ENDFOR»'''
			MutexProcessModel:		 '''«spaces(indent)»Mutex "«pmodel.name»"«newline»«FOR p:pmodel.pmodel»«PrintProcessTree(p, indent+3)»«ENDFOR»'''
			DesAltProcessModel:		 '''WARNING: PrintProcessTree does not have an implementation for DesAltProcessModel (yet)'''	
	  }	
	} 
	
	static def MappingToTree(Mapping mapping){'''
		=== Process Resources ===
		«FOR pr:mapping.prassignment»«MappingToTree(pr, 3)»
		«ENDFOR»
		=== Resource Policies ===
		«FOR rsp:mapping.rspolicy»«MappingToTree(rsp, 3)»
		«ENDFOR»
	'''}

	static def MappingsToTree(List<Mapping> mappings){'''«IF IdslConfiguration.Lookup_value("Debug_mode")=="true"»«FOR mapping:mappings»«MappingToTree(mapping)»«ENDFOR»«ENDIF»'''}
	static def MappingToTree(ProcessResource pr, int indent){'''«spaces(indent)»[ «pr.process» : «pr.plevel.head» : «pr.resource» ]'''}
	static def MappingToTree(ResourceSchedulingPolicy rsp, int indent){'''«spaces(indent)»[ «rsp.resource» : «rsp.policy» : «rsp.timeslice.time» ]'''}
	
	static def serializeObject(EObject serial, String filename){
		try
	    {	 
	    	// TESTING
	    	 //var 	Injector injector = Guice.createInjector(new  my.dsl.MyDslRuntimeModule());  
			 //var	Serializer serializer = injector.getInstance(Serializer.class);  
			 //var	String s = serializer.serialize(serial);  

	         var FileOutputStream fileOut = new FileOutputStream(filename)
	         var ObjectOutputStream out = new ObjectOutputStream(fileOut)
	         out.writeObject(serial)
	         out.close()
	         fileOut.close();
	    }
	    catch(IOException i) { i.printStackTrace() }
	}
}
