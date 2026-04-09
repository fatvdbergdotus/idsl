package org.idsl.language.generator

import java.util.List
import java.util.ArrayList

class IdslGeneratorGNUplot {
	def static create_gnuplot_tradeoff_graph(String title, List<Double> x_values, List<Double> y_values, List<String> names, String outputfile){
		if(x_values.length!=y_values.length || x_values.length!=names.length) // x_values,y_values and names need to have the same length
			throw new Throwable("x_values,y_values and/or names are of different length")
			
		'''
		«IF IdslConfiguration.Lookup_value("Graph_titles")=="true"»set title "«title»"«ENDIF»
		set terminal «IdslConfiguration.Lookup_value("Output_format_graphics")»
		set output "«outputfile»"
		
		set border linewidth 1.5
		set pointsize 1.5
		
		# different styles of dots		
		set style line 1 lc rgb '#0060ad' pt 5   # square
		set style line 2 lc rgb '#00ad60' pt 7   # circle
		set style line 3 lc rgb '#000000' pt 9   # triangle
		unset key

		# Labels: names and coordinates (X,Y)
		«FOR cnt:1..x_values.length»set label "«names.get(cnt-1)»" at «x_values.get(cnt-1)»,«y_values.get(cnt-1)» + 1
		«ENDFOR»
		
		plot \
		«FOR cnt:1..x_values.length»'-' w p ls 2, «ENDFOR»sqrt(-1)
		«FOR cnt:1..x_values.length»«x_values.get(cnt-1)» «y_values.get(cnt-1)»
		e
		«ENDFOR»
		'''}
		
	def static create_gnuplot_bar_graph(String title, String datafile, String outputfile)'''
		«IF IdslConfiguration.Lookup_value("Graph_titles")=="true"»set title "«title»"«ENDIF»
		set xlabel " request number"
		set ylabel "time"
		set terminal «IdslConfiguration.Lookup_value("Output_format_graphics")»
		set boxwidth 0.8
		set style fill solid 1.0
		set output "«outputfile»"
		plot "«datafile»" using 2:3 with boxes title "Latency"
 		'''
 	
 	def static create_gnu_plot_point_throughput(String title, String path, String datafile, String outputfile){ // //overloading case, for one datafile
 		var List<String> datafiles = new ArrayList
 		datafiles.add(datafile)
		create_gnu_plot_point_throughput(title, path, datafiles, outputfile)	
 	}
 	
 	def static create_gnu_plot_point_throughput(String title, String path, List<String> datafiles, String outputfile)'''
		«IF IdslConfiguration.Lookup_value("Graph_titles")=="true"»set title "«title»"«ENDIF»
		set xlabel "request number"
		set ylabel "time"
		set terminal «IdslConfiguration.Lookup_value("Output_format_graphics")»
		set boxwidth 0.8
		set style fill solid 1.0
		set output "«path»«outputfile»"	
		plot «FOR datafile:datafiles»"«path»«datafile»" using 2:3 with point title "«datafile»",«ENDFOR» NaN
		'''
		
	def static create_gnu_plot_cdf(String title, String datafile, String datalegend, String outputfile){ // overloading for the 1 set of datapoints graph case
		var List<String> datafiles = new ArrayList<String>
		datafiles.add(datafile)
		var List<String> datalegends = new ArrayList<String>
		datalegends.add(datalegend)
		
		create_gnu_plot_cdf(title,  datafiles, datalegends, outputfile)
	}

	def static create_gnu_plot_cdf(String title, List<String> datafiles_lines, List<String> datalegends, String outputfile){ 
		create_gnu_plot_cdf(title, datafiles_lines, new ArrayList<String>, datalegends,  outputfile)
	}

	def static create_gnu_plot_cdf(String title, List<String> datafiles_lines, List<String> datafiles_circles, List<String> datalegends, String outputfile){ // overloading without plotsymbols
		var plotsymbols = (IdslConfiguration.Lookup_value("gnuplot_plot_symbols").equals("true"))
		create_gnu_plot_cdf(title, datafiles_lines, datalegends, datafiles_circles, outputfile, "Time", "Cumulative probability", "1", plotsymbols)
	}
	
	def static  create_gnu_plot_cdf(String title, List<String> datafiles, List<String> datalegends, String outputfile, 
								   String xlabel, String ylabel, String xdivisor, boolean plotsymbols){	
		create_gnu_plot_cdf(title, datafiles, new ArrayList<String>, datalegends, outputfile, xlabel, ylabel, xdivisor, plotsymbols)						   								   	
	}
	
	def static create_gnu_plot_cdf(String title, List<String> datafiles, List<String> datafiles_circles, List<String> datalegends, String outputfile, 
								   String xlabel, String ylabel, String xdivisor, boolean plotsymbols){	
		var show_titles=datalegends.length>0
	    var every      =new Integer(IdslConfiguration.Lookup_value("gnuplot_every"))
	    '''set key «IdslConfiguration.Lookup_value("gnuplot_legend_position")»
		set key title '«title»' # to add later if working: font '«IdslConfiguration.Lookup_value("gnuplot_title_font")»
		set xlabel "«xlabel»"
		set ylabel "«ylabel»"
		set yrange [0:1]
		set terminal «IdslConfiguration.Lookup_value("Output_format_graphics")» #size 2.5in,3in
		set output "«path_backslash_to_slash(outputfile)»"
		set style circle radius screen 0.01
		
		plot \
		«IF plotsymbols»
			«var int cnt=1»«FOR datafile:datafiles»"«path_backslash_to_slash(datafile)»" using ($1/«xdivisor»):($2) notitle lw 3 linecolor rgb "«colour(cnt)»" with lines, \
			"«path_backslash_to_slash(datafile)»" every «every»::«every*cnt/datafiles.length» using ($1/«xdivisor»):($2) title '«IF show_titles»«datalegends.get(cnt-1)»«ENDIF»' lw 3 linecolor rgb "«colour(cnt)»" with points, \«(cnt=cnt+1).toString.substring(0,0)»
			«ENDFOR»
		«ELSE»
			«var int cnt=1»«FOR datafile:datafiles»"«path_backslash_to_slash(datafile)»" using ($1/«xdivisor»):($2) title '«IF show_titles»«datalegends.get(cnt-1)»«ENDIF»' lw 3 linecolor rgb "«colour(cnt)»" with lines, \«(cnt=cnt+1).toString.substring(0,0)»
			«ENDFOR»	
		«ENDIF»
		«var int cnt=1»«FOR datafile_circles:datafiles_circles»"«path_backslash_to_slash(datafile_circles)»" using ($1):($2) with circles notitle lw 1 lc rgb  "«colour(cnt)»" fill solid, \«(cnt=cnt+1).toString.substring(0,0)»
		«ENDFOR»	
		2 with lines notitle # empty plot to allow a comma before'''
		// every 20::(20*«cnt»/«datafiles.length»)
	}
	
	def static create_gnu_plot_cdf(String title, String datafile, String outputfile){ //overloading case, for one datafile
 		var List<String> datafiles = new ArrayList
 		var List<String> legends = new ArrayList // no legends needed for a single-data based plot
 		datafiles.add(datafile)
		create_gnu_plot_cdf(title, datafiles, legends, outputfile)		
	}
	
	def static String colour(int number){
		switch(number){ case 1: return "red"  case 2: return "purple"  case 3: return "blue"  case 4: return "black"
						case 5: return "cyan"  case 6: return "green"  case 7: return "gray"  default: return "black" }
	}
	
	def static String path_backslash_to_slash(String path)		{path.replace("\\","/")}
	def static String path_slash_to_backslash(String path)		{path.replace("/","\\")}
	def static int number_of_lines_in_file (String filename)	{ return ( IdslGeneratorSyntacticSugarECDF.fileToList(filename) ).length }
	
	
	def static example_tradeoff_graph(){
		//create_gnuplot_tradeoff_graph(String title, List<Double> x_values, List<Double> y_values, List<String> names, String outputfile)
		
		
		System.out.println(create_gnuplot_tradeoff_graph("Example trade-off graph", 
									  #[10.0,20.0,30.0,40.0,50.0], 
									  #[20.0,70.0,50.0,20.0,10.0],
									  #["a","b","c","d","e"],
									  "z:/tradeoff.pdf")
		)
		
	}
	
	def static void main(String[] args) {
		example_tradeoff_graph
	}
}