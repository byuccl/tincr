# Load the Tincr packages
package require tincr

# Load the full adder design
open_checkpoint [file join $::env(TINCR_PATH) test_files checkpoints full_adder post_synth.dcp]

# Create a new cell named "buffer"
set cell [::tincr::cells new buffer [get_lib_cells BUF]]

# The cell will be inserted into this net
set net [get_nets xor1_net]

# The cell will be inserted into this "branch" of the net
set sink [get_pins xor2_lut/I0]

# Insert the cell
tincr::cells insert $cell $net $sink

# Start the GUI, open schematic view, and highlight the inserted cell
start_gui
show_schematic [get_cells]
highlight_objects $cell
