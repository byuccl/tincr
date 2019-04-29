The scripts in this directory can be used to assist in the generation of primitive definitions (.def files) from Xilinx ISE's xdl executable.

Example usage to generate primitive definitions for xa7z010clg400-1I:
xdl -report -pips -all_conns xa7z010clg400-1I xa7z010clg400-1I_ise_full.xdlrc
mkdir pdefs
extractAll.py xa7z010clg400-1I_ise_full.xdlrc pdefs