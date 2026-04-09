package org.idsl.language.generator

import org.idsl.language.idsl.ExtendedProcessModel
import java.util.List
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.ProcessModel
import org.idsl.language.idsl.AtomicProcessModel
import org.idsl.language.idsl.Exp
import org.idsl.language.idsl.AExpVal
import org.idsl.language.idsl.AExpDspace
import org.idsl.language.idsl.AExpExpr
import org.idsl.language.idsl.ParProcessModel
import org.idsl.language.idsl.AltProcessModel
import org.idsl.language.idsl.SeqProcessModel
import org.idsl.language.idsl.PaltProcessModel
import org.idsl.language.idsl.MutexProcessModel
import java.util.ArrayList
import org.idsl.language.idsl.DesAltProcessModel
import org.idsl.language.idsl.Service
import org.idsl.language.idsl.LoadBalancerProcessModel

public class IdslGeneratorBestCase {
	def static public String computeStr(List<ExtendedProcessModel> epms, List<Service> services, DesignSpaceModel dsi){ // String representation of compute
		// Following functions return:  process -> ( value -> equation )
		var pmins_out_best  = IdslGeneratorBestCase.compute(epms,dsi,true,true)
		var pmaxs_out_best  = IdslGeneratorBestCase.compute(epms,dsi,false,true)
		var pmins_out_worst = IdslGeneratorBestCase.compute(epms,dsi,true,false)
		var pmaxs_out_worst = IdslGeneratorBestCase.compute(epms,dsi,false,false)
		'''«FOR pmin_out:pmins_out_best»«FOR service:process_to_services(pmin_out.key, services)»best pmin «service» «pmin_out.key» «pmin_out.value.key» «pmin_out.value.value»
		«ENDFOR»«ENDFOR»
«FOR pmax_out:pmaxs_out_best»«FOR service:process_to_services(pmax_out.key, services)»best pmax «service» «pmax_out.key» «pmax_out.value.key» «pmax_out.value.value»
«ENDFOR»«ENDFOR»
«FOR pmin_out:pmins_out_worst»«FOR service:process_to_services(pmin_out.key, services)»worst pmin «service» «pmin_out.key» «pmin_out.value.key» «pmin_out.value.value»
		«ENDFOR»«ENDFOR»
«FOR pmax_out:pmaxs_out_worst»«FOR service:process_to_services(pmax_out.key, services)»worst pmax «service» «pmax_out.key» «pmax_out.value.key» «pmax_out.value.value»
«ENDFOR»«ENDFOR»'''		
	}
	
	def static public List<String> process_to_services(String process, List<Service> services){ // returns all services that use a given process
		var List<String> ret = new ArrayList<String>
		for(service:services){
			if(service.extprocess_id.name.equals(process))
				ret.add(service.name)
		}
		return ret
	}
	
	def static public List<Pair<String,Pair<Integer,String>>> compute(List<ExtendedProcessModel> epms, DesignSpaceModel dsi, boolean pmin_pmax, boolean best_or_worst){ // true=pmin
		// returns for each extended process model: its name, best-case load (INT), equation for best-case load (STRING)
		var List<Pair<String,Pair<Integer,String>>> ret = new ArrayList<Pair<String,Pair<Integer,String>>>
		for(epm:epms){
			var pm      = epm.pmodel.head
			var int_str = compute(pm, dsi, pmin_pmax, best_or_worst)
			ret.add(epm.name -> int_str)
		}
		return ret
	}
	
	// returns the evaluted value + a string containing the equation
	def static public Pair<Integer,String> compute(ProcessModel pm, DesignSpaceModel dsi, boolean pmin_pmax /* true=pmin */, boolean best_or_worst /* true=best */){ 
		switch(pm){
			AtomicProcessModel:			return compute_taskload(pm, dsi, pmin_pmax, best_or_worst) 
			ParProcessModel:			return compute_max(pm.pmodel,dsi,pmin_pmax, best_or_worst)	 
			AltProcessModel:			if(best_or_worst) 
											return compute_min(pm.pmodel,dsi,pmin_pmax, best_or_worst)
										else
											return compute_max(pm.pmodel,dsi,pmin_pmax, best_or_worst)
			SeqProcessModel:			return compute_sum(pm.pmodel,dsi,pmin_pmax, best_or_worst)
			PaltProcessModel:			if(best_or_worst)  
											return compute_min(pm.ppmodel.map[x | x.pmodel.head],dsi,pmin_pmax, best_or_worst)
										else 
											return compute_max(pm.ppmodel.map[x | x.pmodel.head],dsi,pmin_pmax, best_or_worst)
			MutexProcessModel:			return compute(pm.pmodel.head,dsi,pmin_pmax, best_or_worst)	
			DesAltProcessModel:			return compute_desalt(pm, dsi, pmin_pmax, best_or_worst)
			LoadBalancerProcessModel:	return compute_taskload(pm.pmodel.head, dsi, pmin_pmax, best_or_worst)
			default:					throw new Throwable("compute: Processmodel type not supported")	
		}		       	
	}
	
	def static public Pair<Integer,String> compute_desalt(DesAltProcessModel dpm,DesignSpaceModel dsi, boolean pmin_pmax, boolean best_or_worst /* true=best */){
		var ds_value = IdslGeneratorDesignSpace.loopUpDSEValue(dpm.param.head,dsi)
		for(spm:dpm.pmodel){
			if(spm.select.head.equals(ds_value)) // the right select branch
				return compute(spm.pmodel.head, dsi, pmin_pmax, best_or_worst)
		}
		throw new Throwable("compute_desalt: the value as found in the DSI cannot be found in the process design alternatives")
	}
	
	def static public Pair<Integer,String> compute_taskload (AtomicProcessModel pm, DesignSpaceModel dsi, boolean pmin_pmax, boolean best_or_worst /* true=best */){ 
		if(pmin_pmax) // pmin, the second value
			if(/*pm.taskload_nondet==null ||*/ pm.taskload_nondet.empty) // use the first value
				compute_taskload(pm,dsi,!pmin_pmax, best_or_worst)
			else
			{
				var exp = pm.taskload_nondet.head.load
				return compute_exp(exp,dsi) 					
			}
		else{ // pmax, the first value
			var exp = pm.taskload.head.load
			return compute_exp(exp,dsi)
		}
	}

	def static public Pair<Integer,String> compute_exp (Exp exp, DesignSpaceModel dsi){
		switch(exp){
			AExpVal: 	  return new Integer(exp.value) -> exp.value.toString
			AExpDspace:	  {	var value = IdslGeneratorDesignSpace.loopUpDSEValue(exp.param.head,dsi); return new Integer(value) -> value }  
			AExpExpr:	  { return apply_op(exp.op.head, exp.a1.head, exp.a2.head, dsi)}
			default: 	  throw new Throwable("compute_exp: Kind of exp not supported")
		}
	}
	
	def static public Pair<Integer,String> apply_op(String op, Exp a1, Exp a2, DesignSpaceModel dsi){
		var String  val_str = compute_exp(a1,dsi).value + " " + op + " " + compute_exp(a2,dsi).value
		var Integer val_int
		
		// switch on OP
		if (op=="+") val_int = compute_exp(a1,dsi).key + compute_exp(a2,dsi).key
		if (op=="-") val_int = compute_exp(a1,dsi).key - compute_exp(a2,dsi).key
		if (op=="*") val_int = compute_exp(a1,dsi).key * compute_exp(a2,dsi).key
		if (op=="/") val_int = compute_exp(a1,dsi).key / compute_exp(a2,dsi).key

		return val_int -> val_str
	}
	
	def static public Pair<Integer,String> compute_min (List<ProcessModel> pms, DesignSpaceModel dsi, boolean pmin_pmax, boolean best_or_worst){
		var int val_int=9999999
		var     val_str="min (["
		for(pm:pms){
			var int_str = compute (pm, dsi, pmin_pmax, best_or_worst)
			val_str=val_str+int_str.value+","
			if(int_str.key<val_int)
				val_int=int_str.key
		}
		val_str=backspace(val_str) // removes the final comma	
		val_str=val_str+")]"
		return val_int -> val_str
	}

	def static public Pair<Integer,String> compute_max (List<ProcessModel> pms, DesignSpaceModel dsi, boolean pmin_pmax, boolean best_or_worst){
		var int val_int=0
		var     val_str="max (["
		for(pm:pms){
			var int_str = compute (pm, dsi, pmin_pmax, best_or_worst)
			val_str=val_str+int_str.value+","
			if(int_str.key>val_int)
				val_int=int_str.key
		}	
		val_str=backspace(val_str) // removes the final comma
		val_str=val_str+")]"
		return val_int -> val_str		
	}

	def static public Pair<Integer,String> compute_sum (List<ProcessModel> pms, DesignSpaceModel dsi, boolean pmin_pmax, boolean best_or_worst){
		var int val_int=0
		var     val_str="sum (["
		for(pm:pms){
			var int_str = compute (pm, dsi, pmin_pmax, best_or_worst)
			val_str=val_str+int_str.value+","
			val_int=val_int+int_str.key
		}
		val_str=backspace(val_str) // removes the final comma
		val_str=val_str+"])"
		return val_int -> val_str		
	}
	
	def static public String backspace (String str){
		return str.substring(0,str.length-1)
	}	

}