# ![Alt text](http://byuccl.github.io/tincr/logo.png) Tincr
*A Tcl-based CAD Tool Framework for Xilinx's Vivado Design Suite*

## Introduction
Tincr is a suite of Tcl libraries written for Xilinx's Vivado IDE. The goal of Tincr is to enable users to build their own CAD tools on top of Vivado. It facilitates this through two primary mechanisms, each of which are encapsulated by a distinct Tcl library, dubbed TincrCAD and TincrIO.

### TincrCAD
TincrCAD is a Tcl-based API built on top of native Vivado Tcl commands. It consists of a set of commands that are common in the development of custom CAD tools, and provides the user with higher levels of abstraction, performance gains, and a greater wealth of information.

### TincrIO
TincrIO comprises a set of commands for pulling design and device data out of the Vivado sandbox into a open, parsable format. With TincrIO, users are able to generate XDLRC device descriptions and export designs out of Vivado into a "Tincr checkpoint" of EDIF and constraint files. Beta support is also provided for importing these checkpoints into Vivado.

## Installation
Installing Tincr can be done in three simple steps:

1. **Download Tincr**: Download the entire Tincr distribution to your machine.
2. **Set the `TINCR_PATH` environment variable**: Create an environment variable called TINCR_PATH and assign it the path to the root directory of the Tincr distribution you downloaded (i.e. the directory containing this README.md file).
3. **Copy pkgIndex.tcl to your Vivado install**: Copy the file `%TINCR_PATH%/install/pkgIndex.tcl` to `<path to Vivado install>/tps/tcl/tcl8.5` on your machine.

## Getting Started
As with any package in Tcl, Tincr must be "required" before any of its commands become available in the Vivado Tcl interface. To do this, open Vivado in Tcl mode ("vivado -mode tcl" in the command prompt) and enter the following command into the prompt:
```
package require tincr
```
Vivado will load the Tincr packages and a message will be printed to the Tcl prompt indicating what version of Tincr was loaded (e.g. `0.0`). Ensure that this matches the version you downloaded.

All commands in Tincr belong to the `::tincr::` namespace. This means calls to commands from Tincr must be prefixed with `::tincr::` (e.g. `::tincr::cells get`). It is possible to import all of Tincr's commands into the global namespace with the following command:
```
namespace import ::tincr::*
```
The commands from Tincr will override any conflicting symbols in the global namespace.

You can add both lines to the end of `<path to Vivado install>/tps/tcl/tcl8.5/init.tcl` to force Vivado to automatically load the Tincr package and import all of its commands into the global namespace on startup:
```
package require tincr
namespace import ::tincr::*
```

## Documentation

API documentation can be found [here](http://byuccl.github.io/tincr/).

Also, the [wiki](https://github.com/byuccl/tincr/wiki) is a great resource for beginners and veterans alike.

If you find any bugs, or have any feature requests, please create an [issue](https://github.com/byuccl/tincr/issues).
