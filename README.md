# gDR
Umbrella package for the gDR programmatic R interface

The gDR suite offers a full stack, allows for a range of users across computational savvy, scientists, etc. made up of several core R packages, a database, a visualization component. 


```       
                                                                               ---------------------
			+-------------+                                        | go.gene.com/gDRin |
			| BumpyMatrix |			                       ---------------------
			+-------------+   \           +----------+                +----------+
		+----------------------+    --------  | gDRcore  | <------------- | gDRshiny | 
		| SummarizedExperiment |  /           +----------+   load raw     +----------+
		+----------------------+                   :        files for analysis
                                                           :
				      perform averaging,   :   gDRcore::normalize_SE()
				      normalization, 	   :   gDRcore::
				      curve fitting	   : 


                                                     SummarizedExperiment object
                                                      with BumpyMatrix assays

							   :	   gDRwrapper::fetch_SE() 
                                                           :
	+------------+				    +--------------+                      +--------+
	| gDRinternal| ---------------------------- | gDRwrapper   | -------------------- | gDRviz | 
	+------------+				    +--------------+  visualize drug                       +--------+
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
We are eager to make this tool useful for the community. We welcome any suggestions via GitHub issues, or pull requests for bugfixes/new features. When making pull requests, please first have a look at the style conventions in gDRstyle/inst/style.Rmd.
