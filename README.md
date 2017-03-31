# ![Tincr logo](http://byuccl.github.io/tincr/logo.png) Tincr
*A Tcl-based CAD Tool Framework for Xilinx's Vivado Design Suite*

## Introduction
Tincr is a suite of Tcl libraries written for Xilinx's Vivado IDE. The goal of Tincr is to enable users to build their own CAD tools on top of Vivado. It facilitates this through two primary methodologies, each of which have been implemented by a separate Tcl library. These two libraries have been named TincrCAD and TincrIO.

### TincrCAD
TincrCAD is a Tcl-based API built on top of native Vivado Tcl commands. It provides a set of commands that are common in the development of custom CAD tools, which supplement the user with higher levels of abstraction, performance gains, and a greater wealth of information.

### TincrIO
TincrIO provides a set of commands for pulling design and device data out of Vivado into a open, parsable format. With TincrIO, users are able to generate XDLRC device descriptions and export designs out of Vivado into a "Tincr checkpoint" of EDIF, placement, routing, and constraint files. Importing these checkpoints into Vivado is currently supported as a BETA feature.

## Installation
Installing Tincr can be done in three simple steps:

1. **[Download](https://github.com/byuccl/tincr/archive/master.zip) or [clone](https://github.com/byuccl/tincr/wiki/Clone-Tincr) Tincr**: Download the Tincr distribution to a directory on your machine.
2. **Set the `TINCR_PATH` environment variable**: Create an environment variable called `TINCR_PATH` and assign it the path to the root directory of the Tincr distribution you downloaded (i.e. the directory containing this `README.md` file).
3. **Copy `pkgIndex.tcl` to your Vivado install**: Copy the file `<TINCR_PATH>/install/pkgIndex.tcl` to `<Vivado path>/tps/tcl/tcl8.5` on your machine.

## Getting Started

### Loading Tincr
As with any package in Tcl, Tincr must be "required" before any of its commands become available to the Vivado Tcl interface. To do this, open Vivado and enter the following command into the Tcl prompt:
```
package require tincr
```
Vivado will load the Tincr packages and a message will be printed to the Tcl prompt indicating what version of Tincr was loaded (e.g. `0.0`). Ensure that this matches the version you downloaded. If you would like to test that Tincr is working, try executing the `::tincr::refresh_packages` command.

### Tincr Namespace
All commands in Tincr belong to the `::tincr::` namespace. This means calls to commands from Tincr must be prefixed with `::tincr::` (e.g. `::tincr::cells get`). It is possible to import all of Tincr's commands into the global namespace with the following command:
```
namespace import ::tincr::*
```
This will save you the trouble of prefixing every command with `::tincr::` (e.g. `cells get`). Please note that the commands from Tincr will override any commands of the same name already in the global namespace.

### Load Tincr on Startup
You can add the following lines to the end of `<Vivado path>/tps/tcl/tcl8.5/init.tcl` to force Vivado to automatically load the Tincr package and import all of its commands into the global namespace on startup:
```
package require tincr
namespace import ::tincr::*
```
This will save you the trouble of entering both commands each time you restart Vivado.

## Documentation

API documentation can be found [here](http://byuccl.github.io/tincr/).

Also, the [wiki](https://github.com/byuccl/tincr/wiki) is a great resource for beginners and veterans alike.

If you find any bugs, or have any feature requests, please create an [issue](https://github.com/byuccl/tincr/issues).
