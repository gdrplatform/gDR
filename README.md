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
                                                           :   perform averaging, 
							   :   normalization, 	    
							   :   curve fitting	    
							   :	    
                                                           :
	+------------+				    +--------------+ 
	| gDRinternal| ---------------------------- | gDRwrapper   |  
	+------------+				    +--------------+ 
                                                           ^
                                                           | Fetch and push 
                                                           v data to database
						     --------------
						    ( gDR REST API )
						     --------------
                                                           ^
 -----------------------------                             |                    -------------------
( cell line metadata REST API )                            |                    | go.gene.com/gDR |
 -----------------------------    \                        V                    -------------------
                                    \                 +-----------+                  +--------+ 
                                      --------------  | gDR MySQL | ---------------- | gDRviz | 
 ----------------------------       /  populate       | database  |  visualize drug  +--------+
( compound metadata REST API )    /    cell and drug  +-----------+  response curves         
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

```

## How to contribute
We are eager to make this tool useful for the community. We welcome any suggestions via GitHub issues, or pull requests for bugfixes/new features. When making pull requests, please first have a look at the style conventions in gDRstyle/inst/style.Rmd.
