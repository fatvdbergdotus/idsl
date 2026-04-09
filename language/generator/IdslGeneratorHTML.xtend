package org.idsl.language.generator

import java.util.List

class IdslGeneratorHTML {
	def static CharSequence createTable (List<List<String>> table){
		createTable(table,false,false) // do not reverse rows and columns	
	}

	def static String createTable (List<List<String>> _integer_table, boolean reverse_rows, boolean reverse_columns){
		var List<List<String>> integer_table
		if(reverse_rows) integer_table = _integer_table.reverseView else integer_table = _integer_table
		'''
			<table border=1>
			«FOR row:integer_table»
				<tr>
				«IF reverse_columns»
					«FOR element:row.reverseView»
						<td>«element»</td>
					«ENDFOR»
				«ELSE»
					«FOR element:row»
						<td>«element»</td>
					«ENDFOR»
				«ENDIF»
				</tr>
			«ENDFOR»
			</table>
		'''
	}
	
	def static String createCSV (List<List<String>> _integer_table, boolean reverse_rows, boolean reverse_columns){
		var List<List<String>> integer_table
		if(reverse_rows) integer_table = _integer_table.reverseView else integer_table = _integer_table
		'''«FOR row:integer_table»«IF reverse_columns»«FOR element:row.reverseView»«ENDFOR»«ELSE»«FOR element:row»«element»«ENDFOR»«ENDIF»
		«ENDFOR»'''		
	}
}
