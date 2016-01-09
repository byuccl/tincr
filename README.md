# ![Alt text](http://bradselw.github.io/tincr/logo.png) Tincr
A Tcl-based CAD Tool Framework for Xilinx's Vivado Design Suite

Tincr is a suite of Tcl libraries written for Xilinx's Vivado IDE. The goal of Tincr is to enable users to build their own CAD tools on top of Vivado. It facilitates this through two primary mechanisms, each of which are encapsulated by a distinct Tcl library, dubbed TincrCAD and TincrIO.

TincrCAD is a Tcl-based API built on top of native Vivado Tcl commands. It consists of a set of commands that are common in the development of custom CAD tools, and provides the user with higher levels of abstraction, performance gains, and a greater wealth of information.

TincrIO comprises a set of commands for pulling design and device data out of the Vivado sandbox into a open, parsable format. With TincrIO, users are able to generate XDLRC device descriptions and export designs out of Vivado into a "checkpoint" of EDIF and constraint files. Beta support is also provided for importing these checkpoints into Vivado.

You can view the API documentation [here](http://bradselw.github.io/tincr/).
