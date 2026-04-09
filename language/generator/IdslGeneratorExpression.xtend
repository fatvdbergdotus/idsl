package org.idsl.language.generator

import org.idsl.language.idsl.AExp
import org.idsl.language.idsl.AExpDspace
import org.idsl.language.idsl.AExpExpr
import org.idsl.language.idsl.AExpMiniform
import org.idsl.language.idsl.AExpVal
import org.idsl.language.idsl.DesignSpaceModel
import org.idsl.language.idsl.Exp
import org.idsl.language.idsl.impl.IdslFactoryImpl

class  IdslGeneratorExpression{
	
	def static AExpMinusOne() {
		var AExpVal m1 = IdslFactoryImpl::init.createAExpVal
		m1.setValue(0) // warning: do not change this value, because it is hardcoded at places in the code
		return m1
	}
	
	def static equalsAExpMinusOne(AExp aexp) {
		switch(aexp){
			AExpVal: return (aexp.value==-1)
			default: return false
		}
	}
	
	def static printExp (Exp exp, DesignSpaceModel dsi, String variableType){
		if(exp==null){ return "/* null pointer exception for expression */" }		
		
		switch(exp){
			AExp:			'''«printAExp (exp, dsi, variableType)»'''
			default:		'''/* non AExp expression */'''    //throw new Throwable("Trying to print a MVExp")
		}
	}
	
	def static printAExp (AExp aexp, DesignSpaceModel dsi, String variableType){
		var boolean int_in_recursion = IdslConfiguration.Lookup_value("print_aexp_use_int_in_recursion")=="true"
		
		if (aexp==null) {return "parent"}
		
		var String prefix
		if (variableType=="int") prefix="(int)" else prefix=""
		var String recursive_prefix
		if (int_in_recursion) recursive_prefix = "(int)" else recursive_prefix = ""
		
		switch(aexp){
			AExpVal:		'''«prefix»«aexp.value.toString»''' 
			AExpDspace:     '''«prefix»«IF dsi==null»/* no DSI value provided */«ELSE»«IdslGeneratorDesignSpace.loopUpDSEValue(aexp.param.head,dsi)»«ENDIF»'''  
			AExpExpr: 		'''«prefix»(«printAExp(aexp.a1.head, dsi, recursive_prefix)» «aexp.op.head.toString» «printAExp(aexp.a2.head, dsi, recursive_prefix)»)''' 
			AExpMiniform:	if (variableType=="real") return "Uniform(0,1)" else return "0"
			
			default:		'''parent'''	
		}
	}
	
	def static int evalAExp (Exp exp, DesignSpaceModel dsi){
		switch(exp){
			AExp: 		evalAExp(exp,dsi)
			default:	throw new Throwable("evalAExp: called with a non axep exp!")
		}
	}
	
	def static int evalAExp (AExp aexp, DesignSpaceModel dsi){
		if (aexp==null) 
			throw new Throwable("evalAExp: null pointer exception")
		
		switch(aexp){
			AExpVal:		return aexp.value 
			AExpDspace:     return new Integer(IdslGeneratorDesignSpace.loopUpDSEValue(aexp.param.head,dsi))  
			AExpExpr: {     if (aexp.op.head=="+")  return evalAExp(aexp.a1.head, dsi) + evalAExp(aexp.a2.head, dsi)
							if (aexp.op.head=="-")  return evalAExp(aexp.a1.head, dsi) - evalAExp(aexp.a2.head, dsi)
							if (aexp.op.head=="/")  return evalAExp(aexp.a1.head, dsi) / evalAExp(aexp.a2.head, dsi)
							if (aexp.op.head=="*")  return evalAExp(aexp.a1.head, dsi) * evalAExp(aexp.a2.head, dsi)
							else throw new Throwable("evalAExp: AExpExpr type not supported")
					  }
			default:		throw new Throwable("evalAExp: unsupported type")	
		}
	}
	
	def static boolean equalsAExp (AExp aexp1, AExp aexp2){
		if (aexp1==null && aexp2==null) return true
		if (aexp1==null || aexp2==null) return false
		
		switch(aexp1){
			AExpVal:		switch(aexp2) { AExpVal: return aexp1.value==aexp2.value 													default: return false }
			AExpDspace:		switch(aexp2) { AExpDspace: return aexp1.param.equals(aexp2.param) 											default: return false }
			AExpExpr:		switch(aexp2) { AExpExpr: equalsAExp(aexp1.a1.head,aexp2.a1.head) && 
													  equalsAExp(aexp1.a2.head,aexp2.a2.head) && aexp1.op.equals(aexp2.op)				default: return false }
			AExpMiniform:	switch(aexp2) { AExpMiniform: return true																	default: return false }
			default:		throw new Throwable("equalsAExp does not support expresison "+aexp1.toString)	
		}
	}		
}
			
	

