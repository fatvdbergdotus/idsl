# Repository for the domain-specific language iDSL (imaging DSL)
Language:
- [language](language) The source code of the language iDSL (unorganized)
- [grammar](language/Idsl.xtext) The grammar of the language iDSL
   
Instances:
- [biplane](instances/biplane.idsl) An iDSL instance of a Philips Biplane iXR System
- [ch4_thesis](instances/phd_thesis_chapter_4.idsl) An iDSL instance of a simple imaging System with two chains

## Summary of the initial paper
The paper “A Domain Specific Language for Performance Evaluation of Medical Imaging Systems” introduces iDSL, a domain-specific language designed to model, simulate, and evaluate the performance of medical imaging systems such as interventional X-ray platforms. The authors present iDSL as a high-level modeling language that separates processes, resources, mappings, scenarios, measures, and studies, enabling engineers to analyze system latency, resource utilization, concurrency effects, and timing guarantees early in the design phase. iDSL automatically transforms models into formal MoDeST, UPPAAL, and MODES representations, allowing both simulation-based and model-checking-based performance analysis. The paper demonstrates how iDSL can visually generate latency breakdowns, cumulative distribution functions, and absolute timing bounds for different design alternatives, helping engineers compare architectures and optimize system configurations before implementation. Overall, the work shows that iDSL simplifies the evaluation of complex cyber-physical medical systems by combining domain-specific abstractions with automated formal analysis and visualization tooling.
