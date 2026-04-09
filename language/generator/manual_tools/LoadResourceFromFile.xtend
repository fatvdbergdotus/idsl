package org.idsl.language.generator.manual_tools

import org.idsl.language.IdslStandaloneSetup
import com.google.inject.Injector
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.common.util.URI
import org.idsl.language.idsl.Model
import org.eclipse.xtext.resource.XtextResource
import org.idsl.language.idsl.Service
import java.io.File

class LoadResourceFromFile {
	def static void main(String[] args) {
		new org.eclipse.emf.mwe.utils.StandaloneSetup().setPlatformUri("../");
		var x = new IdslStandaloneSetup()
		var Injector injector = x.createInjectorAndDoEMFRegistration
		var XtextResourceSet resourceSet = injector.getInstance(XtextResourceSet);
		resourceSet.addLoadOption(XtextResource.OPTION_RESOLVE_ALL, Boolean.TRUE);
		
		var fileURI = URI.createFileURI("F:\\eclipse\\workspace\\iDSL-instance\\iDSL specifications\\jozef\\milliseconds_512.idsl")
		
		var Resource resource = resourceSet.getResource(fileURI, true);
		var service_list = resource.allContents.toIterable.filter(typeof(Service)).toList
		
		for(Service serv:service_list)
			System.out.println(serv)
	}
}