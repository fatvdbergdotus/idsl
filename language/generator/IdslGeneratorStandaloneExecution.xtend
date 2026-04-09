package org.idsl.language.generator


import org.idsl.language.IdslStandaloneSetup
import com.google.inject.Injector
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.common.util.URI
import org.idsl.language.idsl.Model
import org.eclipse.xtext.resource.XtextResource
import org.idsl.language.idsl.Service
import java.io.File
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.MeasurementSearches
import org.idsl.language.idsl.Scenario
import org.idsl.language.idsl.Study
import org.idsl.language.idsl.ExtendedProcessModel
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.Measurement
import org.idsl.language.idsl.MeasurementResults
import org.idsl.language.idsl.MultiplyResults

public class IdslGeneratorStandaloneExecution {
	def static public Resource idsl2model(String filename){
		new org.eclipse.emf.mwe.utils.StandaloneSetup().setPlatformUri("../")
		var x = new IdslStandaloneSetup()
		var Injector injector = x.createInjectorAndDoEMFRegistration
		var XtextResourceSet resourceSet = injector.getInstance(XtextResourceSet)
		resourceSet.addLoadOption(XtextResource.OPTION_RESOLVE_ALL, Boolean.TRUE)
		var fileURI = URI.createFileURI(filename)
		var Resource resource = resourceSet.getResource(fileURI, true)
		return resource
	}
	
	def static void main(String[] args) {
		var resource = idsl2model("F:\\simple.idsl")

		var dsm = resource.allContents.toIterable.filter(typeof(DesignSpaceModel)).head // currently first one DesignSpaceModel, others DesignSpaceInstanceS  
		var searches =resource.allContents.toIterable.filter(typeof(MeasurementSearches)).toList
		var scenarios = resource.allContents.toIterable.filter(typeof(Scenario)).toList
		var studies = resource.allContents.toIterable.filter(typeof(Study)).toList
		var extprocesses = resource.allContents.toIterable.filter(typeof(ExtendedProcessModel)).toList
		var resourcemodels = resource.allContents.toIterable.filter(typeof(ResourceModel)).toList
		var mappings = resource.allContents.toIterable.filter(typeof(Mapping)).toList	
		var experiments = resource.allContents.toIterable.filter(typeof(Measurement)).toList // Experiments are global
		var service_list = resource.allContents.toIterable.filter(typeof(Service)).toList
		var mresults = resource.allContents.toIterable.filter(typeof(MeasurementResults)).head
		var multresults = resource.allContents.toIterable.filter(typeof(MultiplyResults)).head
		
		System.out.println(IdslGeneratorBestCase.computeStr(extprocesses,service_list,dsm))
	}

}