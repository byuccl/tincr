Tincr
=====

1.) How to install Tincr
2.) How to use Tincr

How to install Tincr
====================

Installing Tincr can be done in three simple steps:

1.) Download Tincr. Download the entire Tincr distribution to your machine.
2.) Set the TINCR_PATH environment variable. Create an environment variable called TINCR_PATH and assign it the path to the source folder ("src") in the Tincr distribution you downloaded.
3.) Copy pkgIndex.tcl to your Vivado install. Copy the file "<path to the local copy of Tincr>\install\pkgIndex.tcl" to "<path to Vivado install>\tps\tcl\tcl8.5" on your machine.

How to use Tincr
================

As with any package in Tcl, Tincr must be "required" before any of its commands become available in the Vivado Tcl interface. To do this, open Vivado in Tcl mode ("vivado -mode tcl" in the command prompt) and enter the following command into the prompt:

package require tincr

Vivado will load the Tincr packages and a message will be printed to the Tcl prompt indicating what version of Tincr was loaded. Ensure that this matches the version you downloaded.

All commands in Tincr belong to the ::tincr:: namespace. This means calls to commands from Tincr must be prefixed with "::tincr::" (i.e. "::tincr::cells get"). It is possible to import all of Tincr's commands into the global namespace with the command "namespace import ::tincr::*". The commands from Tincr will override any conflicting symbols in the global namespace.