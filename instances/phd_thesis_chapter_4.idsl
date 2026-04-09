Section Process
ProcessModel image_processing_application
 seq image_processing_seq {
  atom image_pre_processing load 50
  seq image_processing {
   atom motion_compensation load 44
   atom noise_reduction load uniform(80:140)
   atom contrast load 134 }
  atom image_post_processing load 25 }

Section Resource
 ResourceModel image_processing_PC
  decomp image_processing_decomp {
   atom CPU rate 2, 
   atom GPU rate 5 }
  connections { ( CPU , GPU ) }

Section System
 Service image_processing_service
  Process image_processing_application
  Resource image_processing_PC
  Mapping assign { 
   ( image_pre_processing, CPU )
   ( motion_compensation, CPU )
   ( noise_reduction, CPU )
   ( contrast, CPU )
   ( image_post_processing, GPU) }

Section Scenario
 Scenario image_processing_run
  ServiceRequest image_processing_service
   at time 0, 400, ...
   
  ServiceRequest image_processing_service
   at time dspace("offset"), dspace("offset")+400, ...

Section Measure
 Measure ServiceResponse times using 1 runs of 280 ServiceRequests
 Measure ServiceResponse absolute times

Section Study
 Scenario image_processing_run
 DesignSpace ("offset" {"0" "20" "40" "80" "120" "160" "200"})

Section Configuration
	( "execute_this" "false" )
