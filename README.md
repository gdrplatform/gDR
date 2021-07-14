# gDR
Umbrella package for the gDR programmatic R interface

The gDR suite offers a full stack solution for storing, processing, and visualizing drug response data. This enables a range of users across computational savvy, (i.e. lab scientists and computational scientists alike) to access the same, standardized data. The suite is made up of several core R packages, a database, a shiny visualization app. 


```       

                                                     +-----+
                                                     | gDR |
                                                     +-----+
                                                        |
          +---------------------------------------------------------------------------------------------------+
          |                                                                                                   |
          |                                                                                                   |
   
                                                                               ---------------------
			+-------------+                                        | go.gene.com/gDRin |
			| BumpyMatrix |			                       ---------------------
			+-------------+   \           +----------+                +-----------+
		+----------------------+    --------  | gDRcore  | <------------- | gDRimport | 
		| SummarizedExperiment |  /           +----------+   load raw     +-----------+
		+----------------------+                   :        files for analysis
                                                           :
				      perform              :   gDRcore::runDrugResponseProcessingPipeline()
				      normalization, 	   :   
				      averaging, 	   :   
				      curve fitting	   : 
                                                           :

                                                     SummarizedExperiment object
                                                      with BumpyMatrix assays

							   :  gDRwrapper::fetch_SE() 
                                                           :
                                                    +--------------+                      +--------+
                                                    | gDRwrapper   | -------------------- | gDRviz |
                                                    +--------------+  visualize data      +--------+
                                                           ^    
                                                           |
                                                           | Fetch and push 
                                                           v data to database
						     --------------
						    ( gDR REST API )
						     --------------
                                                           ^
 -----------------------------                             |                    -------------------
( cell line metadata REST API )                            |                    | go.gene.com/gDR |
 -----------------------------    \                        V                    -------------------
                                    \                 (-----------)                  +--------+ 
                                      --------------  | gDR MySQL | ---------------- | gDRviz | 
 ----------------------------       /  populate       | database  |  visualize drug  +--------+
( compound metadata REST API )    /    cell and drug   -----------  response curves         
 ----------------------------          metadata                      and metrics


Key:

+------------+
| R packages |
+---------- -+
 ----------
( REST API )
 ----------
----------------------------
| Graphical User Interface |
----------------------------
(-----------)
| database  |       
-------------
```


## How to contribute
We are eager to make this tool useful for the community. We welcome any suggestions via GitHub issues, or pull requests for bugfixes/new features. When making pull requests, please first have a look at the style conventions in [gDRstyle](https://gdrplatform.github.io/gDRstyle/style_guide.html).
