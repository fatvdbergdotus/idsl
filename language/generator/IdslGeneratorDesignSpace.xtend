package org.idsl.language.generator

import java.util.ArrayList
import java.util.Collections
import java.util.HashSet
import java.util.List
import java.util.Set
import org.idsl.language.idsl.AExp
import org.idsl.language.idsl.AExpDspace
import org.idsl.language.idsl.AExpExpr
import org.idsl.language.idsl.AbstractionProcessModel
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.AtomicProcessModel
import org.idsl.language.idsl.CompoundResourceTree
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.DesignSpaceParam
import org.idsl.language.idsl.Exp
import org.idsl.language.idsl.MutexProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.ResourceModel
import org.idsl.language.idsl.ResourceTree
import org.idsl.language.idsl.Scenario
import org.idsl.language.idsl.SeqParProcessModel
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.ServiceRequest
import org.idsl.language.idsl.SubStudy
import org.idsl.language.idsl.impl.IdslFactoryImpl
import org.idsl.language.idsl.TimeSchedule
import org.idsl.language.idsl.Mapping
import org.idsl.language.idsl.Model
import org.idsl.language.idsl.DesAltProcessModel
import org.idsl.language.idsl.TaskLoad
import org.idsl.language.idsl.MVExpECDFbasedonDSI
import org.idsl.language.idsl.MVExpECDFProduct
import org.idsl.language.idsl.SelectProcessModel
import org.idsl.language.idsl.BExpconstraint
import org.idsl.language.idsl.BExpTrue
import org.idsl.language.idsl.BExpFalse
import org.idsl.language.idsl.BExpCmpString
import org.idsl.language.idsl.BExpDspace
import org.idsl.language.idsl.BExpString
import org.idsl.language.idsl.BExpValue
import org.idsl.language.idsl.BExpBi
import org.idsl.language.idsl.BExp
import org.idsl.language.idsl.BExpNeg
import org.idsl.language.idsl.BExpArithmetic
import org.idsl.language.idsl.TimeScheduleLatencyJitter
import org.idsl.language.idsl.TimeScheduleFixedIntervals
import org.idsl.language.idsl.TimeScheduleExp
import org.idsl.language.idsl.TimeScheduleCDF

class IdslGeneratorDesignSpace {
	def static String DSMvalues (DesignSpaceModel dsm)    '''«FOR dsparam:dsm.dsparam»«dsparam.variable.head»_«dsparam.value.head»_«ENDFOR»'''
	 
	def static String DSIstring_param_value (String DSIstring, String paramstring) {
		var var_vals = DSIstring.split("_")
		for (cnt:(0..var_vals.length).filter[i | i % 2 == 0])
			if (var_vals.get(cnt)==paramstring)
				return var_vals.get(cnt+1)
		throw new Throwable(DSIstring+" does not contain variable "+paramstring)
	}
	
	def static String DSMparamToValue (DesignSpaceModel dsm, String param){ // looks up a belonging value for a given design space parameter
		for(dsparam:dsm.dsparam)
			if (dsparam.variable.head==param)
					return dsparam.value.head
		throw new Throwable ("Param "+param+" not found in the design space")
	}

	def static DesignSpaceModel dsm_copy (DesignSpaceModel dsm_original) { // makes a hardcopy of a DesignSpaceModel
		var dsm_copy = IdslFactoryImpl::init.createDesignSpaceModel
		dsm_copy.constraint.addAll(dsm_original.constraint) // constraints are soft-copied
		
		for(param:dsm_original.dsparam){
			var dsparam=IdslFactoryImpl::init.createDesignSpaceParam
			dsparam.variable.addAll(param.variable)
			dsparam.value.addAll(param.value)
			dsm_copy.dsparam.add(dsparam)
		}
		return dsm_copy
	}
	
	def static DesignSpaceModel change_modeltimeunit_to_1 (DesignSpaceModel _dsi){
		var dsi = dsm_copy(_dsi)
		for(param:dsi.dsparam)
			if(param.variable.head.equals("modeltimeunit"))
				param.value.set(0,"1")
		return dsi
	}
	
	def static List<Boolean> DSImeetsConstraints(DesignSpaceModel dsi, List<BExpconstraint> constraints){ // does the DSI meet all constraints?
		var List<Boolean> constraintResult = new ArrayList<Boolean>
		for(constraint:constraints) // check the DSI for all constraints
			constraintResult.add(evalBExp(dsi,constraint))		
		return constraintResult
	}

	def static boolean evalBExp (DesignSpaceModel dsi, BExpconstraint bexpconstraint){ return evalBExp(dsi, bexpconstraint.bexp.head) }
	
	def static boolean evalBExp (DesignSpaceModel dsi, BExp bexp){
		switch(bexp){
			BExpTrue: 			return true
			BExpFalse:			return false
			BExpCmpString:		return evalBExp(dsi, bexp)
			BExpBi:				return evalBExp(dsi, bexp)
			BExpNeg:			return !evalBExp(dsi, bexp)
		}
		throw new Throwable ("Invalid evalBExp expression")
	}
	
	def static boolean evalBExp (DesignSpaceModel dsi, BExpCmpString b){
		val op = b.bcmpop.head // the connecting operator
		if(op=="=")  return new Integer(evalBExpValue(dsi,b.bexpds_left.head)) == new Integer(evalBExpValue(dsi,b.bexpds_right.head))
		if(op==">")  return new Integer(evalBExpValue(dsi,b.bexpds_left.head)) >  new Integer(evalBExpValue(dsi,b.bexpds_right.head))
		if(op=="<")  return new Integer(evalBExpValue(dsi,b.bexpds_left.head)) <  new Integer(evalBExpValue(dsi,b.bexpds_right.head))
		if(op=="eq") return     evalBExpValue(dsi,b.bexpds_left.head) 	       == evalBExpValue(dsi,b.bexpds_right.head)
		throw new Throwable ("Operator "+op+" is not valid")
	}
	
	def static boolean evalBExp (DesignSpaceModel dsi, BExpBi b){
		val op = b.bop.head // the connecting operator
		if(op=="&&") return evalBExp(dsi, b.bexp_left.head) && evalBExp(dsi, b.bexp_right.head)
		if(op=="||")  return evalBExp(dsi, b.bexp_left.head) || evalBExp(dsi, b.bexp_right.head)
		if(op=="->")  return !evalBExp(dsi, b.bexp_left.head) || evalBExp(dsi, b.bexp_right.head)
		if(op=="<->")  return (evalBExp(dsi, b.bexp_left.head) && evalBExp(dsi, b.bexp_right.head)) ||
							  (!evalBExp(dsi, b.bexp_left.head) && !evalBExp(dsi, b.bexp_right.head))
		throw new Throwable ("Operator "+op+" is not valid")
	}
	
	def static String evalBExpValue (DesignSpaceModel dsi, BExpValue b){
		switch(b){
			BExpString: 		return b.value.head
			BExpDspace:			return DSMparamToValue(dsi, b.param.head)
			BExpArithmetic:		return evalBExpArithmetic(dsi,b)
		}
	}
	
	def static String evalBExpArithmetic(DesignSpaceModel dsi, BExpArithmetic b){
		val op         = b.baop.head
		val bleft_int  = new Integer(evalBExpValue(dsi, b.bval_left.head))
		val bright_int = new Integer(evalBExpValue(dsi, b.bval_right.head))
		
		if(op=="+") return (bleft_int+bright_int).toString
		if(op=="-") return (bleft_int-bright_int).toString
		if(op=="*") return (bleft_int*bright_int).toString
		if(op=="/") return (bleft_int/bright_int).toString
	}
	
	
	def static List<Set<String>> valuesPerColumnCSVfile (String filename){
		var csvFile     = openCSVfile (filename).tail // omit titles
		var num_columns = csvFile.get(0).length
		var listSets    = new ArrayList<Set<String>>
		
		for(cnt:0..num_columns-1){
			var set = new HashSet<String>
			for(csvLine:csvFile)
				set.add(csvLine.get(cnt))
			
			listSets.add(set)
		}
		return listSets
	}
	
	def static ResolveWhiteListDSM(DesignSpaceModel dsm){
		var dsparams = createDesignSpaceCSVfile(dsm.bexpwhitelist.head.filename)
		dsm.dsparam.addAll(dsparams)
		
		// constraint
		var bexpcon = IdslFactoryImpl::init.createBExpconstraint
		bexpcon.bexp.add(makeConstraintForWhitelist(dsm.bexpwhitelist.head.filename))
		dsm.constraint.add(bexpcon)
		
		//remove whitelist
		dsm.bexpwhitelist.clear
	}
	
	def static BExp or_kwantor (List<BExp> bexps){
		if(bexps.empty) //base case
			return IdslFactoryImpl::init.createBExpFalse
			
		var or = IdslFactoryImpl::init.createBExpBi
		or.bexp_left.add(bexps.head)
		or.bop.add("||")
		or.bexp_right.add(or_kwantor(bexps.tail.toList))		
		return or
	}
	
	def static BExp and_kwantor (List<BExp> bexps){
		if(bexps.empty) //base case
			return IdslFactoryImpl::init.createBExpTrue
			
		var or = IdslFactoryImpl::init.createBExpBi
		or.bexp_left.add(bexps.head)
		or.bop.add("&&")
		or.bexp_right.add(and_kwantor(bexps.tail.toList))		
		return or
	}
	/*BExpconstraint: 'constraint'  bexp+=BExp ;
	BExp: BExpTrue | BExpFalse | BExpCmpString |  BExpBi | BExpNeg;  
		BExpTrue : { BExpTrue} 'true';
		BExpFalse : { BExpFalse} 'false';
		BExpValue: BExpString | BExpDspace | BExpArithmetic ;// values, which turn into boolean expresison via comparisons
			BExpString:		value += STRING;
			BExpDspace:		'dspace' '(' param+=ID ')' ;
			BExpArithmetic: ('[' bval_left+=BExpValue baop+=BAOp bval_right+=BExpValue ']');
				BAOp: 			'+' | '-' | '*' | '/';
		// value comparison operations
		BExpCmpString: '(' bexpds_left+=BExpValue  bcmpop+=BCmpOp  bexpds_right+=BExpValue ')' ; 
			BCmpOp: '=' | '<' | '>' | 'eq';
		// composite boolean operations (AND, OR, implication, equivalence negation)
		BExpBi:			'(' bexp_left += BExp  bop+=BOp  bexp_right += BExp ')';
		BExpNeg:		'neg' '(' bexp += BExp ')' ;
			BOp:        	'||' | '->' | '<->' | '&&' ;*/

	def static BExp makeConstraintForCSVline (List<String> header, List<String> line){
		var List<BExp>	BExpPerDSvariable = new ArrayList<BExp>
		
		for(cnt:0..header.length-1){
			var variable = IdslFactoryImpl::init.createBExpDspace
			variable.param.add(header.get(cnt))
			
			var value = IdslFactoryImpl::init.createBExpString
			value.value.add(line.get(cnt))
			
			var cmp = IdslFactoryImpl::init.createBExpCmpString
			cmp.bexpds_left.add(variable)
			cmp.bexpds_right.add(value)
			cmp.bcmpop.add("eq")
		}
		return and_kwantor(BExpPerDSvariable)
	}
	
	def static BExp makeConstraintForWhitelist(String filename) { // to implement: based on the CSV, make one big constraint
		var List<String>       csvHeader   = openCSVfile (filename).head.toList
		var List<List<String>> csvFile     = openCSVfile (filename).tail.toList
		var List<BExp>         BExpPerLine = new ArrayList<BExp>
		
		for(csvLine:csvFile){ // make a boolean expression for each CSV line
			BExpPerLine.add(makeConstraintForCSVline(csvHeader, csvLine))
		}
		return or_kwantor(BExpPerLine)
	}
	
	def static List<DesignSpaceParam> createDesignSpaceCSVfile ( String filename ){
		var List<DesignSpaceParam> dsparams        = new ArrayList<DesignSpaceParam>
		var List<String>           csvHeader       = openCSVfile (filename).head
		var List<Set<String>>      csvValuesColumn = valuesPerColumnCSVfile (filename)
		
		for(cnt:0..csvValuesColumn.length-1){ // add design variables, one by one
			var dsparam = IdslFactoryImpl::init.createDesignSpaceParam
			dsparam.variable.add(csvHeader.get(cnt))
			dsparam.value.addAll(csvValuesColumn.get(cnt))
			dsparams.add(dsparam)
		}
		return dsparams
	}
	
	def static List<List<String>> openCSVfile (String filename){
		var List<List<String>> ret       = new ArrayList<List<String>>
		var List<String>       fileList  = IdslGeneratorSyntacticSugarECDF.fileToList(filename)
		var List<Integer>      num_lines = new ArrayList<Integer> // to check if all lines have the same length
		
		for(fileLine:fileList){ // read a line of the CSV file
			var List<String> ret_line = new ArrayList<String>
			var parts                 = fileLine.split(",")
			
			for(part:parts){ // remove unwanted chars
				part.replace("(","_")
				part.replace(")","_")
				part.replace(" ","_")
			}
			
			ret_line.addAll(parts)
			ret.add(ret_line)
			num_lines.add(ret_line.length) // to check if all lines have the same length
		}
		
		if (allEqual(num_lines))
			return ret
		else
			throw new Throwable("The lines in the CSV file are not of equal length") 
	}
	
	def static boolean allEqual (List<Integer> numbers){
		for(cnt:0..numbers.length-2)
			if(numbers.get(cnt)!=numbers.get(cnt+1)) // found a difference
				return false
		return true
	}
	
	def static int lookupValuePositionDSM (String param, DesignSpaceModel dsm, DesignSpaceModel dsi){ // looks up the index in the DSM for a certain DSI value
		if(param=="no_choice") // virtual parameter with one option
			return 0
		
		for(param_dsm:dsm.dsparam) // match dsm and dsi parameter to param
			if(param_dsm.variable.head==param) // found the param in the DSM
				for(param_dsi:dsi.dsparam)
					if(param_dsi.variable.head==param) // found the param in the DSI
						for(cnt:0..param_dsm.value.length-1)
							if(param_dsm.value.get(cnt)==param_dsi.value.head)
								return cnt
								
		throw new Throwable ("lookupValuePositionDSM: Parameter "+param+" not found in the DesignSpace")
	}
	
	def static int lookupValuePositionDSM (String param, DesignSpaceModel dsi, List<SelectProcessModel> sel_pms) { // looks up the index in the DSM for a lookup_value
		if(param=="no_choice") // virtual parameter with one option
			return 0	
			
		//if(param=="samplingmethod") // high level design space variable.. not accesible.
		//	return 0	
		
		/* DEBUG: PRINTS THE DESIGN SPACE
		for(param_dsi:dsi.dsparam){
			System.out.println("param:"+param_dsi)
			for (cnt:0..sel_pms.length-1){
				System.out.print("v:"+sel_pms.get(cnt).select.head)
			}
			System.out.println("")
		}*/
		
		for(param_dsi:dsi.dsparam)
			if(param_dsi.variable.head==param){ // found the param in the DSM
				var value=param_dsi.value.head
				for (cnt:0..sel_pms.length-1){
					if(sel_pms.get(cnt).select.head==value) // value found, return the index
						return cnt
				}
				throw new Throwable ("lookupValuePositionDSM: Parameter "+param+" and/or value "+value+" not found in the DesignSpace")
			}		
		throw new Throwable ("lookupValuePositionDSM: Parameter "+param+" and/or requested value not found in the DesignSpace")
	}
	
	def static int DSM_number_of_entries_for_param (DesignSpaceModel dsm, String param){
		for(dsparam:dsm.dsparam)
			if (param==dsparam.variable.head) // found variable
				return dsparam.value.length
		return -1 // param not found
		//throw new Throwable("Design Space does not contain parameter "+param)
	}
	
	def static turnDesignSpaceModelsIntoInstances (SubStudy substudy, DesignSpaceModel dsm){
		// Add a number of DSIs to the substudy for each DSIS, represented as DesignSpaceModels
		var List<DesignSpaceModel> dsi_list=new ArrayList<DesignSpaceModel>
		for (dsis:substudy.dspacem) {
			dsi_list.addAll(designSpaceModelDeriveInstances(dsm))
			//MyDslGeneratorDesignSpace.addDSIStoModelAsSeperateDSIs (dsis, substudy)
		}
		substudy.dspacem.removeAll()
		substudy.dspacem.addAll(dsi_list)
		if (substudy.dspacem.length==0)
			substudy.dspacem.add(IdslFactoryImpl::init.createDesignSpaceModel) /* add an empty DesignSpaceModel in case of an empty list */ 
	}
	
	def static Set<String> DesignSpaceVariablesUsed (Scenario scenario){
		var Set<String> dsvars=new HashSet()
		for (servReq:scenario.ainstance) 
			dsvars.addAll(DesignSpaceVariablesUsed(servReq))
		return dsvars
	}
	
	def static Set<String> DesignSpaceVariablesUsed (ProcessModel pm){  // TO IMPLEMENT
		var Set<String> dsvars=new HashSet
		switch(pm){ // add taskload dspaces
			AbstractionProcessModel:		if(pm.taskload.length>0) dsvars.addAll(DesignSpaceVariablesUsed(pm.taskload.head.load))
			AtomicProcessModel:				if(pm.taskload.length>0) dsvars.addAll(DesignSpaceVariablesUsed(pm.taskload.head.load))
 			ParProcessModel:				if(pm.taskload.length>0) dsvars.addAll(DesignSpaceVariablesUsed(pm.taskload.head.load))
			AltProcessModel:				if(pm.taskload.length>0) dsvars.addAll(DesignSpaceVariablesUsed(pm.taskload.head.load))
			SeqProcessModel:				if(pm.taskload.length>0) dsvars.addAll(DesignSpaceVariablesUsed(pm.taskload.head.load))
			PaltProcessModel:				if(pm.taskload.length>0) dsvars.addAll(DesignSpaceVariablesUsed(pm.taskload.head.load))
			MutexProcessModel:				if(pm.taskload.length>0) dsvars.addAll(DesignSpaceVariablesUsed(pm.taskload.head.load))
			SeqParProcessModel:				if(pm.taskload.length>0) dsvars.addAll(DesignSpaceVariablesUsed(pm.taskload.head.load))
			DesAltProcessModel:				dsvars.add(pm.param.head)
 		}
 		
		switch(pm){ // add recursive dspaces
 	  		ParProcessModel:				for(pms:pm.pmodel) { dsvars.addAll(DesignSpaceVariablesUsed(pms)) }
			AltProcessModel:				for(pms:pm.pmodel) { dsvars.addAll(DesignSpaceVariablesUsed(pms)) }
			SeqProcessModel:				for(pms:pm.pmodel) { dsvars.addAll(DesignSpaceVariablesUsed(pms)) }
			PaltProcessModel:				for(pms:pm.ppmodel) { dsvars.addAll(DesignSpaceVariablesUsed(pms.pmodel.head)) } 
			MutexProcessModel:				for(pms:pm.pmodel) { dsvars.addAll(DesignSpaceVariablesUsed(pms)) }
			SeqParProcessModel:				for(pms:pm.pmodel) { dsvars.addAll(DesignSpaceVariablesUsed(pms)) } 
			DesAltProcessModel:				for(pms:pm.pmodel) { dsvars.addAll(DesignSpaceVariablesUsed(pms.pmodel.head)) } 
		}
		return dsvars
	}
	
	def static Set<String> DesignSpaceVariablesCovered (DesignSpaceModel ds){  
		var Set<String> dsvars=new HashSet()
		for(dv:ds.dsparam)
			dsvars.add(dv.variable.head)
		return dsvars
	}
			
	def static Set<String> DesignSpaceVariablesUsed (ResourceModel rm){  // TO IMPLEMENT
		var Set<String> dsvars=new HashSet()
		if(rm.restree.head.taskrate.length>0) { dsvars.addAll(DesignSpaceVariablesUsed(rm.restree.head.taskrate.head.rate)) }
		switch(rm.restree.head){
				CompoundResourceTree: 		dsvars.addAll(DesignSpaceVariablesUsed(rm.restree.head)) 
		}
		return dsvars
	}
	
	def static Set<String> DesignSpaceVariablesUsed (ResourceTree rt){	
		var Set<String> dsvars=new HashSet()
		if(rt.taskrate.length>0) { dsvars.addAll(DesignSpaceVariablesUsed(rt.taskrate.head.rate)) }
		switch(rt){
			CompoundResourceTree: for (srt:rt.rtree){ dsvars.addAll(DesignSpaceVariablesUsed(srt)) }
		}
		return dsvars
	}
	
	def static Set<String> DesignSpaceVariablesUsed (ServiceRequest sr){
		var Set<String> dsvars=new HashSet()
		dsvars.addAll(DesignSpaceVariablesUsed(sr.time.head))
		
		dsvars.addAll(DesignSpaceVariablesUsed(sr.activity_id.head.extprocess_id.pmodel.head))
		for(spm:sr.activity_id.head.extprocess_id.spm){
			dsvars.addAll(DesignSpaceVariablesUsed(spm.pmodel.head))
		}
		dsvars.addAll(DesignSpaceVariablesUsed(sr.activity_id.head.resource_id))
		dsvars.addAll(DesignSpaceVariablesUsed(sr.activity_id.head.mapping.head))
		return dsvars
	}
	
	def static Set<String> DesignSpaceVariablesUsed (Mapping mapping){
		var Set<String> dsvars=new HashSet()
		for(rsp:mapping.rspolicy)
			dsvars.addAll(DesignSpaceVariablesUsed(rsp.timeslice.time))
		return dsvars
	}
	
	def static Set<String> DesignSpaceVariablesUsed_fi (TimeScheduleFixedIntervals ts){
		var Set<String> dsvars=new HashSet()
		dsvars.addAll(DesignSpaceVariablesUsed(ts.interval))
		dsvars.addAll(DesignSpaceVariablesUsed(ts.num_instances))
		dsvars.addAll(DesignSpaceVariablesUsed(ts.frequency))
		dsvars.addAll(DesignSpaceVariablesUsed(ts.start))
		return dsvars
	}

	def static Set<String> DesignSpaceVariablesUsed_lj (TimeScheduleLatencyJitter ts){
		var Set<String> dsvars=new HashSet()
		dsvars.addAll(DesignSpaceVariablesUsed(ts.period))
		dsvars.addAll(DesignSpaceVariablesUsed(ts.jitter))
		dsvars.addAll(DesignSpaceVariablesUsed(ts.num_instances))
		return dsvars
	}

	def static Set<String> DesignSpaceVariablesUsed (TimeSchedule ts){
		switch(ts){
			TimeScheduleFixedIntervals: return DesignSpaceVariablesUsed_fi(ts)
			TimeScheduleLatencyJitter:  return DesignSpaceVariablesUsed_lj(ts)
			TimeScheduleExp:		    { var Set<String> dsvars=new HashSet(); dsvars.addAll(DesignSpaceVariablesUsed(ts.num_instances)); return dsvars }
			TimeScheduleCDF:			{ var Set<String> dsvars=new HashSet(); dsvars.addAll(DesignSpaceVariablesUsed(ts.num_instances)); return dsvars }
			default:					throw new Throwable("DesignSpaceVariablesUsed: TimeSchedule not supported!")
		}	
	}
	
	def static Set<String> DesignSpaceVariablesUsed (AExp aexp){
		var Set<String> dsvars=new HashSet()
		switch(aexp){
			AExpDspace: 	dsvars.add(aexp.param.head)       
			AExpExpr:		{ dsvars.addAll(DesignSpaceVariablesUsed(aexp.a1.head))
							  dsvars.addAll(DesignSpaceVariablesUsed(aexp.a2.head)) }
		}							 
		return dsvars
	}
	
	def static Set<String> DesignSpaceVariablesUsed (Exp exp){
		var Set<String> dsvars=new HashSet()
		switch(exp){ 
			AExp: 					dsvars.addAll(DesignSpaceVariablesUsed (exp))
			MVExpECDFbasedonDSI: 	dsvars.add(exp.param.head)
			MVExpECDFProduct: 		for(ecdf:exp.ecdfs) { dsvars.addAll(DesignSpaceVariablesUsed(ecdf)) }
		}							 
		return dsvars
	}
	
	def static String loopUpDSEValue (String param, DesignSpaceModel dsi){
		for (v:dsi.dsparam){ 
			if (v.variable.head==param){ 
				return v.value.head
			}
		} // return the first value. There should be only 1 value, since the designspacemodel have been composed before here.
		throw new Throwable("DSE variable "+param+" not found")
	}
	
	def static List<DesignSpaceModel> designSpaceModelDeriveInstances(DesignSpaceModel dsm){
		var List<DesignSpaceModel> dsis=new ArrayList()
		var int totalCounter = 0
		var int selectedCounter = 0
		
		for (v:(1..DesignSpaceModelSize(dsm)-1)){
			totalCounter = totalCounter + 1
			if (totalCounter%100000==0) // progress
				System.out.print(".")
			
			var dsi = designSpaceModeltoInstance(dsm,v)
			val List<Boolean> dsi_meets_constraints = IdslGeneratorDesignSpace.DSImeetsConstraints(dsi, dsm.constraint) // does DSI satisfy all constraints?
			val boolean alltrue = IdslGenerator.allTrue(dsi_meets_constraints)
								
			if(alltrue && IdslConfiguration.Lookup_value("Design_space_display_constraints_information_only")=="false")	{
				dsis.add(dsi)
				selectedCounter = selectedCounter + 1
			}
		}
		System.out.println("Selected "+(selectedCounter+1)+" ("+(100*(selectedCounter+1))/(totalCounter+1) +"%) out of a total of "+(totalCounter+1)+" designs.")
		return dsis
	}
	
	def static int DesignSpaceModelSize (DesignSpaceModel dsm){
		var int size=1
		for(v:dsm.dsparam) size=size*v.value.length // for each param, multiply by its number of elements
		System.out.println("max. "+size+" DSIs")
		return size
	}
	
	def static DesignSpaceModel designSpaceModeltoInstance(DesignSpaceModel dsm, int instance_num){
		var num_params=dsm.dsparam.length
		var budget=instance_num
		var int multiplier=1

		// create a lookup table used to budget items		
		var List<Integer> lookup = new ArrayList<Integer>
		for(v:dsm.dsparam){
			var int count=v.value.length
			for (cnt:(0..count-1)){
				lookup.add(cnt*multiplier)
			}
			multiplier=multiplier*count
		}
		
		// go through the dimensions and select the right element for each
		var int lookup_cnt = lookup.length()-1
		var List<Integer> dim_elems = new ArrayList<Integer>
		
		for(param_nr:(num_params-1..0)){
			for (param_value:(dsm.dsparam.get(param_nr).value.length-1..0)){
				if (budget>=lookup.get(lookup_cnt)) { 
					budget=budget-lookup.get(lookup_cnt)
					dim_elems.add(param_value)
				}
				lookup_cnt=lookup_cnt-1
			}
		}
		
		// remove redudant zeros and reverse the order of dim_elems	
		for (cnt:(0..dim_elems.length()-1))
		{
				if (dim_elems.get(cnt)!=null && dim_elems.get(cnt)>0 && dim_elems.get(cnt+1)==0){ 
					dim_elems.set(cnt+1, null) // mark redudant zeros
				} 
		}
		dim_elems.removeAll(Collections.singleton(null)) // removes null values
		Collections.reverse(dim_elems)
		
		// construct a DesignSpaceModel
		val DesignSpaceModel dsm_return = IdslFactoryImpl::init.createDesignSpaceModel
		var counter=0
		
		for(el:dim_elems){
			val DesignSpaceParam dsm_param = IdslFactoryImpl::init.createDesignSpaceParam
			
			dsm_param.variable.add ( dsm.dsparam.get(counter).variable.head ) // add variable name
			dsm_param.value.add    ( dsm.dsparam.get(counter).value.get(el) ) // add one variable value
			
			dsm_return.dsparam.add 
			(dsm_param
			) 								  // add variable/value pair to dsm
			counter=counter+1
		}
		return dsm_return
	}
	
	def static void main(String[] args) {
		var dsparams1 = createDesignSpaceCSVfile("F:\\paper2015c philips\\casestudy\\merged.csv")
		
		//var listSets1 = valuesPerColumnCSVfile("F:\\paper2015c philips\\casestudy\\Performance tastes2_derived.csv")
		
		//var CSVfile1 =  openCSVfile("F:\\paper2015c philips\\casestudy\\Performance tastes2_derived.csv")
		//var CSVfile2 =  openCSVfile("F:\\paper2015c philips\\casestudy\\PRSModeTable_data_only.csv")
		System.out.println("done")
	}
	
}