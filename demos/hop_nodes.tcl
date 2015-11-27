# Load the Tincr packages
package require tincr

# The maximum number of hops to calculate (decrease if the demo runs slow)
set max_hops 5

# Create an empty design called demo
::tincr::designs new demo xc7k70tfbg484-3

# Get a node on the device
set node [get_nodes INT_L_X14Y66/EE4BEG3]

# Start the GUI to view the nodes that are found
start_gui

# Iterate backwards so the smaller sets of nodes are highlighted last
for {set i $max_hops} {$i >= 1} {incr i -1} {
    # Get the set of nodes that are $i hops away from $node
    set nodes [::tincr::nodes hops $node $i]
    
    # Highlight the set of nodes in the GUI ("-color_index $i" changes the color for each set)
    highlight_objects -color_index $i $nodes
}
