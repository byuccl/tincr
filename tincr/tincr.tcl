## @file tincr.tcl
#  @brief Require this package to load all Tincr packages
#
# The <CODE>tincr</CODE> package requires all other "sub-packages" in the Tincr suite. This is so the user does not have to individually <CODE>package require</CODE> each of the packages in Tincr in order to use all of them.

## @mainpage The Tincr Design Suite
#
#  \section intro_sec Introduction
#   The Tincr Design Suite augments Vivado's native Tcl interface. Tincr is divided into two libraries, called TincrCAD and TincrIO. Each library consists of a number packages, and each package encapsulates a set of related functionality. For instance, the <CODE>design</CODE> package in TincrCAD contains all commands related the the querying and manipulating of design objects in Vivado. These packages are further divided into files that each represent a specific class of object in Vivado's Tcl interpreter. Examples include <CODE>cells.tcl</CODE> and <CODE>bels.tcl</CODE>. These files contain a number of procs for operating on these objects, giving the user a level of abstraction similar to an Object Oriented Programming language.
#   This unique organization can be observed in the <a href="files.html">Files</a> section. All Tcl
#   procedures are members of the <CODE>::tincr::</CODE> namespace.
#
#  \section install_sec Installation
#   <OL>
#   <LI><B>Set up the environment.</B> Place the source files in the desired directory. Set the environment
#   variable <CODE>TINCR_PATH</CODE> to that directory.</LI>
#   <LI><B>Set up the package index.</B> Place the file <CODE>install/pkgIndex.tcl</CODE> in
#   the appropriate folder for your Vivado installation (e.g. 
#   <CODE>&lt;install path&gt;/Vivado/&lt;version&gt;/tps/tcl/tcl8.5</CODE>).
#   <LI><B>Configure Vivado.</B> If desired, Vivado can be set to automatically
#   load all Tincr Tcl packages upon start up. This is done by adding the following line to
#   Vivado's <CODE>init.tcl</CODE> file:
#   \code{.tcl}package require tincr 0.0\endcode 
#   Individual libraries or packages can be loaded by replacing <CODE>tincr</CODE> with the 
#   desired library or package name (e.g. <CODE>tincr.cad</CODE> or <CODE>tincr.cad.design</CODE>). Packages can be loaded
#   using the same command when Vivado is running.</LI>
#   </OL>

package provide tincr 0.0

namespace eval ::tincr {
    # This variable controls the debug level of the Tincr suite. It may be changed by setting it to the appropriate debug level: set ::tincr::debug #
    set ::tincr::debug 0
    set ::tincr::verbose 0
    set ::tincr::enable_assertions 0
}

# Require both of Tincr's Tcl libraries, TincrCAD and TincrIO
package require tincr.cad 0.0
package require tincr.io 0.0