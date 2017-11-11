The files in this directory are from creating zynq primitive defs.

Zynq parts were identified by the 4th letter of the part name being
'z' (an assumption).  A partial selection of part/package/speed grade
combinations were then made and xdlrc files generated for them.

The file "generatePrimitiveDefs" is the script used to generate the
xdlrc files.  It relies on the extractAll.py and extractFile.py
programs to strip out the primitive defs and place into
subdirectories.

The resulting primitive defs were then compared by running the "comp"
script. The results were: all parts processed resulted in the
same list of primitive defs. However, the primitive defs were NOT all
identical. The defs can be divided into 2 groups:

Group 1:
1. xa7z010clg400-1I_ise_full.xdlrc
2. xa7z020clg400-1I_ise_full.xdlrc
3. xq7z020cl400-1Q_ise_full.xdlrc
5. xc7z010clg400-1_ise_full.xdlrc
6. xc7z020clg400-2_ise_full.xdlrc
11. xa7z010clg225-1I_ise_full.xdlrc
12. xa7z010clg484-1I_ise_full.xdlrc

Group 2:
4. xq7z045rf676-2I_ise_full.xdlrc
7. xc7z030fbg676-3_ise_full.xdlrc
8. xc7z045fbg676-3_ise_full.xdlrc
9. xc7z100ffg900-2_ise_full.xdlr
10. xq7z030rf676-2I_ise_full.xdlrc
13. xq7z030rb484-2I_ise_full.xdlrc

The defs between all of group 1 are identical.  Similarly for the defs
in group 2. Running a diff between one from each group results in the
following:

------------------------------------------------------------------------
Comparing 1 with 4
1c1
< 	(primitive_def IDELAYE2_FINEDELAY 23 36
---
> 	(primitive_def IDELAYE2_FINEDELAY 23 37
221a222,225
> 		(element _ROUTETHROUGH-IDATAIN-DATAOUT 2
> 			(pin IDATAIN input)
> 			(pin DATAOUT output)
> 		)
1c1
< 	(primitive_def ILOGICE2 31 56
---
> 	(primitive_def ILOGICE2 31 58
318a319,326
> 		(element _ROUTETHROUGH-D-O 2
> 			(pin D input)
> 			(pin O output)
> 		)
> 		(element _ROUTETHROUGH-DDLY-O 2
> 			(pin DDLY input)
> 			(pin O output)
> 		)
1c1
< 	(primitive_def IOB18M 17 41
---
> 	(primitive_def IOB18M 17 43
243a244,251
> 		(element _ROUTETHROUGH-O-O_OUT 2
> 			(pin O input)
> 			(pin O_OUT output)
> 		)
> 		(element _ROUTETHROUGH-T-T_OUT 2
> 			(pin T input)
> 			(pin T_OUT output)
> 		)
1c1
< 	(primitive_def OLOGICE2 33 70
---
> 	(primitive_def OLOGICE2 33 76
390a391,414
> 		(element _ROUTETHROUGH-D1-OFB 2
> 			(pin D1 input)
> 			(pin OFB output)
> 		)
> 		(element _ROUTETHROUGH-D1-OQ 2
> 			(pin D1 input)
> 			(pin OQ output)
> 		)
> 		(element _ROUTETHROUGH-OQ-OFB 2
> 			(pin OQ input)
> 			(pin OFB output)
> 		)
> 		(element _ROUTETHROUGH-T1-TFB 2
> 			(pin T1 input)
> 			(pin TFB output)
> 		)
> 		(element _ROUTETHROUGH-T1-TQ 2
> 			(pin T1 input)
> 			(pin TQ output)
> 		)
> 		(element _ROUTETHROUGH-TQ-TFB 2
> 			(pin TQ input)
> 			(pin TFB output)
> 		)
------------------------------------------------------------------------

In summary, a set of additional routethrough elements are included in
the following defs from group 2:
    IDELAYE2_FINEDELAY
    ILOGICE2
    IOB18M
    OLOGICE2

FYI, there are two primitive defs in zynq that are not in
artix7
   IOPAD
   PS7

The set of primitive defs include in tincr/cache/zynq/primitive_defs
are those from set 2 for now.  Is this correct?
