package org.idsl.language.generator

import org.idsl.language.idsl.MVExpECDF
import org.idsl.language.idsl.impl.IdslFactoryImpl
import org.idsl.language.idsl.MVExpECDFfromfile
import org.idsl.language.idsl.FreqValue
import org.idsl.language.idsl.FreqValue
import org.idsl.language.idsl.MVExpECDFProduct
import org.idsl.language.idsl.MVExpECDFbasedonDSI
import java.util.List
import org.idsl.language.idsl.MVExpECDFabstract
import java.util.ArrayList

class IdslGeneratorDeepCopy {	
	def static MVExpECDF deepcopy (MVExpECDF mvexpECDF){ // only works with freqval CDFs and DSIfromFile
		//MVExpECDF:						'eCDF ' (freqval+=FreqValue+) | MVExpECDFfromfile | MVExpECDFbasedonDSI | MVExpECDFabstract | MVExpECDFProduct ;
			//FreqValue:						'(' freq+=INT? ':'? value+=INT ')'; // No frequency means frequency=1
		//MVExpECDFidentity:				{MVExpECDFidentity} 'eCDF identity';
		//MVExpECDFfromfile:				'eCDF from file' filename=STRING ;
		//MVExpECDFbasedonDSI:				'select' 'dspace' '(' param+=ID ')' '{' ecdfs+=MVExpECDF+ '}'; // Selects an element from ecdfs, based on the current DSI
		//MVExpECDFProduct:					'product' '{' ecdfs+=MVExpECDF+ '}'; // A list of CDFs, whose product needs to be determined
		//MVExpECDFabstract:				'eCDF call' abstract_cdf=[AbstractCDF|ID] ;
		
		switch(mvexpECDF){
			MVExpECDFProduct:  				return deepcopy_MVExpECDFProduct (mvexpECDF)
			MVExpECDFbasedonDSI:			return deepcopy_MVExpECDFbasedonDSI (mvexpECDF)
			MVExpECDFabstract:				return IdslGeneatorCreateAtomMVExpReplacement.retrieve_MVExpECDFabstract(mvexpECDF)
			MVExpECDFfromfile: 				return IdslGeneratorSyntacticSugarECDF.read_ECDF_from_file (mvexpECDF.num_samples, mvexpECDF.filename, mvexpECDF.is_ratio) // convert to FreqVal right away
		}

		var mvexpECDF_copy = IdslFactoryImpl::init.createMVExpECDF 
		for(freqval:mvexpECDF.freqval)
			mvexpECDF_copy.freqval.add(deepcopy(freqval))
			
		mvexpECDF_copy.is_ratio=mvexpECDF.is_ratio

		return mvexpECDF_copy
	}
	
	def static MVExpECDFProduct deepcopy_MVExpECDFProduct (MVExpECDFProduct eCDFProduct){
		var eCDFProduct_copy = IdslFactoryImpl::init.createMVExpECDFProduct
		for (ecdf:eCDFProduct.ecdfs)
			eCDFProduct_copy.ecdfs.add(deepcopy(ecdf))
		return eCDFProduct_copy
	}
	
	def static MVExpECDFbasedonDSI deepcopy_MVExpECDFbasedonDSI (MVExpECDFbasedonDSI eCDFbasedonDSI){
		var eCDFbasedonDSI_copy = IdslFactoryImpl::init.createMVExpECDFbasedonDSI
		eCDFbasedonDSI_copy.param.add(eCDFbasedonDSI.param.head)
		for(sel_ecdf:eCDFbasedonDSI.select_ecdfs){
			var selectECDF = IdslFactoryImpl::init.createSelectECDF
			selectECDF.select.add(sel_ecdf.select.head)
			selectECDF.ecdf.add(deepcopy(sel_ecdf.ecdf.head))
			eCDFbasedonDSI_copy.select_ecdfs.add(selectECDF)
		}
		return eCDFbasedonDSI_copy
	}	
	
	def static FreqValue deepcopy (FreqValue freqval){
		var freqval_copy = IdslFactoryImpl::init.createFreqValue
		freqval_copy.freq.addAll(freqval.freq)
		freqval_copy.value.addAll(freqval.value)
		return freqval_copy
	}
}
