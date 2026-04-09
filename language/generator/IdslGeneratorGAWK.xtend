package org.idsl.language.generator

class IdslGeneratorGAWK {
	// to combine all the results of the load balanacer and compute pareto optimals (3 steps):
	// step1) TO FILE: dir /b/s modes_sim_latency_summary.output | gawk "{print \"type \" $0 \" \076\076 results.dat\"}" | cmd
	// (TO SCREEN: dir /b/s modes_sim_latency_summary.output | gawk "{print \"type \" $0 \" \"}" | cmd )
	// step2) type results.dat | gawk "{if ($1==\"designSpaceInstance\") {split($2,x,\"_\");printf \"%s %s %s %s %s \",$2,x[2],x[4],x[6],x[11]} if ($1==\"averageLatency\") {printf \"%s \",$2} if ($1==\"averagePower\") {printf \"%s \",$2} if ($1==\"totalTimeouts\"){print $2}}" >> results_short.dat
	// step3) gawk -f "Z:\load balancer\load_balancerv2\pareto.awk" results_short.dat | gawk "{print $100000+$6, 100000+$7, $8, $1, $2, $3, $4, $5}" | sort | gawk "{print $4, $5, $6, $7, $8, $1, $2-100000, $3}" >> results_pareto.dat
	// derive timeouts from results:
	// DO NOT USE: step 4) for /d %n in (*.*) do (echo %n >> results_timeouts.dat & type %n\ExpSimulation_2_10\results\modes_sim_latency_all_short.output | find "timeouts" | gawk "{sum+=$3}END{print $3}" >> \results_timeouts.dat)
	
	// EXTRACT Bjorn's values: type "results_pareto+anylogic.dat" | gawk "{if($8>0)print $1,$2,$3,$4,$5,$8,$9,0}" >> results_bjorn.dat
	
	// CONVERT Bjorn's values: type bjorn_raw.txt | gawk "BEGIN{ FS = \",\" }{print \"p_1_q_\" $4 \"_to_\" 1000*$5 \"_lb_policy_noname_2_\" $6 \"_\",$2/4,$3*1000}" >> bjorn.txt

	// EXTRA designs with a high delta: type results_bjorn_and_freek.txt | gawk "NR>1 {if(($5>0 && $3>0) && ($3/$5>1.5 || $5/$3>1.5)) {cnt++;print $1,$3,$5}}END{print cnt}"
	
	// BJORN CONVERSION. ADD FULL DESIGNSPACE: type 20160211results.csv | gawk "{ FS = \",\" }; {print $1,\"p_1_q_\" $4 \"_to_\" 1000*$5 \"_lb_policy_noname_2_\" $6 \"_\",$2,1000*$3}" >> 20160211results_processed.txt
	
	def static pta_model_checking2_timestamp_aggregation ()'''
		function reset()
		{
		     starting_time = $1
			 benchmark_counter = 0
			 modelcheck_counter = 0
		}
		
		{
			# start of a step: store the starting time
			if($2=="START" && $3=="PTAModelcheck:"){
				print ""; 
				print $4
				reset()
			}
			if($2=="START" && $3=="PTAModelcheck" && $4=="(step1):"){ # also end of step0
				print "Modelcheck0: benchmarking", $1 - starting_time, "seconds" 
				starting_time = 0
				print "  num_benchmarks: ", benchmark_counter 
				reset()
			}
			if($2=="START" && $3=="PTAModelcheck" && $4=="(step2):"){
				reset()
			}
			if($2=="START" && $3=="PTAModelcheck" && $4=="(step3):"){
				reset()
			}
			
			# end of a step: print details + compute executing time (using starting time)
			if($2=="STOP" && $3=="PTAModelcheck:"){ # non-existing
			}
			if($2=="STOP" && $3=="PTAModelcheck" && $4=="(step1"){ # typo in iDSL (step 1)
				print "Modelcheck1: Best/worst case + Simulation", $1 - starting_time, "seconds"
				starting_time = $1
			}
			if($2=="STOP" && $3=="PTAModelcheck" && $4=="(step2):"){
				print "Modelcheck2: Find absolute bounds", $1 - starting_time, "seconds"
				starting_time = 0
				print "  num_modelcheck: ", modelcheck_counter
			}
			if($2=="STOP" && $3=="PTAModelcheck" && $4=="(step3):"){
				print "Modelcheck3: Compute whole CDF", $1 - starting_time, "seconds" 
				starting_time = 0
				print "  num_modelcheck: ", modelcheck_counter
			}
			
			# cases that require variable updates
			if($2=="PTA2" && $3=="benchmark" && $4 =="stop"){
				benchmark_counter++
			}
			if($2=="START" && $3=="PTAmodelcheck_unit"){
				modelcheck_counter++
			}
		}	
	
	
	'''
	
	
	def static latency_to_cdf()'''
		# converts a 1 column range of latency value into CDF values, i.e., one column of sorted values and one colum with their cumulative probabilties
		# can serve as input for GNUplot to create a CDF
		{
			count++
			freq[$1+10000]++         # the +10000 makes the ASCII asorti sort the numbers the numeric way. It is substracted again later.
		}
		END{
			n = asorti(freq,dest)
			
			for (i = 1; i <= n; i++){
				#print dest[i],freq[dest[i]]
				increment=freq[dest[i]]
				for(j=0;j<increment;j++)
					print dest[i]-10000, (cumulative+j) / (count-1)
				cumulative+=increment
			}		
		}
		'''	
 	
 	def static create_gawk_util_and_latency_in_graphviz(String filename)'''
		# parses the MODEST output properties
		{	#print $1, $1=="+", $1=="Mean:"
			if ($1=="+"){   				# start of property detected
				property_value=$2
				property_name=$3
				getline			
				# see if it has a value and, if yes, print it
				if ($1=="Mean:"){
					utility = index(property_name,"property_utilization")>0
					print "fart","«filename»", "xxx" property_name "xxx", property_value # pre-/postfix xxx enables virtually unique identification
					print "fart","«filename»", "xxx" property_name "_colorxxx", to_color_hex(property_value,utility)
				}
			}	
		}
		
		function to_color_hex(val, utility){
			if(utility) 	# utility
				return normalized_tocolor_hex(val*100)		# lineary colouring schema for resource utilizations (from [0,1] to [0,100])
			else 			# latency
				return "blue"  								# (yet) a fixed color for process latencies
		}
		
		function normalized_tocolor_hex(val){	 # from 0-100 value to hex
			R=(255*val)/100; G=(255*(100-val))/100;	B=0
			return "\"#" hex12(R) "" hex12(G) "" hex12(B) "\""
		}
		
		function hex12(val){
			intval=int(val)
			return decimal_to_hex(hex1(intval)) "" decimal_to_hex(hex2(intval))
		}
	
		function hex1(val){ return int(val/16) } # converts the first decimal to hex
		function hex2(val){ return val%16 }		 # converts the second decimal to hex
		
		function decimal_to_hex(val){			 # converts one 0-15 decimal to one hex
			if(val==0) return "0"; if(val==1) return "1"; if(val==2) return "2"; if(val==3) return "3"; if(val==4) return "4"; if(val==5) return "5"
			if(val==6) return "6"; if(val==7) return "7"; if(val==8) return "8"; if(val==9) return "9"; if(val==10) return "A"; if(val==11) return "B"
			if(val==12) return "C"; if(val==13) return "D"; if(val==14) return "E"; if(val==15) return "F"
		}
 	'''
 
  	def static create_gawk_aggregated_util_and_latency_in_graphviz(String filename)'''
		# parses the MODEST output properties
		{	#print $1, $1=="+", $1=="Mean:"
			if ($1=="+"){   				# start of property detected
				property_name=$3
				getline				 		# see if it has a value and, if yes, print it
				if ($1=="Mean:"){
					if(index(property_name,"property_latency_")>0){
						split(property_name,arr,"_")
						cnt=int(arr[length(arr)])
						property_name=substr(property_name,1,length(property_name)-length(cnt)-1)
					}
					d_count[property_name]++
					d_sum[property_name]+=$2
				}
			}
		}
		END{ 
			for (property in d_count){
				utility = index(property,"property_utilization")
				avg_value = d_sum[property]/d_count[property]
				print "rem utility? " utility
				print "fart","«filename»","xxx" property "xxx", avg_value
				print "fart","«filename»","xxx" property "_colorxxx", to_color_hex(avg_value, utility)
			}
		}
		
		function to_color_hex(val, utility){
			if(utility>0) 	# utility
				return normalized_tocolor_hex(val*100)		# lineary colouring schema for resource utilizations (from [0,1] to [0,100])
			else 			# latency
				return "blue"  								# (yet) a fixed color for process latencies
		}
		
		function normalized_tocolor_hex(val){	 # from 0-100 value to hex
			R=(255*val)/100; G=(255*(100-val))/100;	B=0
			return "\"#" hex12(R) "" hex12(G) "" hex12(B) "\""
		}

		function hex12(val){
			intval=int(val)
			return decimal_to_hex(hex1(intval)) "" decimal_to_hex(hex2(intval))
		}
		
		function hex1(val){ return int(val/16) } # converts the first decimal to hex
		function hex2(val){ return val%16 }		 # converts the second decimal to hex
		
		function decimal_to_hex(val){			 # converts one 0-15 decimal to one hex
			if(val==0) return "0"; if(val==1) return "1"; if(val==2) return "2"; if(val==3) return "3"; if(val==4) return "4"; if(val==5) return "5"
			if(val==6) return "6"; if(val==7) return "7"; if(val==8) return "8"; if(val==9) return "9"; if(val==10) return "A"; if(val==11) return "B"
			if(val==12) return "C"; if(val==13) return "D"; if(val==14) return "E"; if(val==15) return "F"
		}		
 	'''
 
  	def static create_gawk_latency_in_gnuplot()'''
		# parses the MODEST output properties
		{	#print $1, $1=="+", $1=="Mean:"
			if ($1=="+"){   				# start of property detected
				property_name=$3
				getline				 		# see if it has a value and, if yes, print it
				if ($1=="Mean:"){
					split(property_name,arr,"_")
					cnt=int(arr[length(arr)])
					
					print property_name,cnt,$2
		
					cnt++
				}
			}	
		}
 	'''	
 	
 	
 	def static create_gawk_throughput_in_graphviz(String activity_name)'''
		# parses the MODEST output properties
		{	#print $1, $1=="+", $1=="Mean:"
			if ($1=="+"){   				# start of property detected
				property_name=$3
				if (index(property_name,"«activity_name»"))
				{
					getline				 		# see if it has a value and, if yes, print it
					if ($1=="Mean:"){
						split(property_name,arr,"_")
						cnt=int(arr[length(arr)])
						
						print "xxx" property_name "xxx", cnt, int($2) # postfix xxx enables unique identification
						cnt++
					}
				}
			}	
		}
 	'''
 
 	def static create_gawk_theoretical_bounds_parser()'''	
		BEGIN{
			global_max=-1
			global_min=999999
		}
		{
			if ($1=="+"){
				prop_name=$3
				split(prop_name,props,"_")
		
				min_or_max=props[length(props)-1]
				value=props[length(props)]
				
				getline
				probability=$2 $3
						
				#FOR DEBUGGING: print min_or_max, value, probability
				
				if(min_or_max=="greater" && probability=="0" && global_max==-1) # for greater, the first 0 value is wanted
					global_max=value
				
				if (min_or_max=="smaller" && probability=="0") # for smaller the last 0 value is wanted
					global_min=value
			}
		}
		END{
			print "The theoretical range is: [" global_min "," global_max "]"
			print global_min
			print global_max
		}
	'''		 	
 	
 	
}