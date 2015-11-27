package require tincr

# Load the synthesized BFT design
open_checkpoint [file join $::env(TINCR_PATH) test_files checkpoints bft post_synth.dcp]

# Call the random placer example on the current design
::tincr::random_placer

# Open the GUI to display the results
start_gui
