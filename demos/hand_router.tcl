# Load the Tincr packages
package require tincr

# Load the full adder design
open_checkpoint [file join $::env(TINCR_PATH) test_files checkpoints full_adder post_route.dcp]

# Bring up the GUI
start_gui

# Get a net to work with
set net [get_nets xor1_net]

# Select a node in the middle of $net, as it enters the switchbox
select_objects [get_nodes -of_objects $net CLBLL_L_X2Y1/CLBLL_LOGIC_OUTS8]

# Select all nodes one hop away from $node
select_objects [tincr::nodes hops [get_selected_objects] 1]

# User clicks on one of the selected nodes, ensuring it is now the only selected node
# User then enters the following command into the Tcl prompt (without the hash):
# tincr::nets add_node $net [get_selected_objects]

# Repeat lines 16-21 for each additional node you wish to add to $net
