# AXI-Stream Packet Mux - Basic Timing Constraints

# Define clock: 100 MHz (10ns period)
create_clock -name aclk -period 10.0 [get_ports aclk]

# Ignore timing on asynchronous reset
set_false_path -from [get_ports aresetn]

# All inputs: arrive 2ns after clock edge
set_input_delay -clock aclk 2.0 [all_inputs]

# All outputs: must be ready 2ns before next clock edge
set_output_delay -clock aclk 2.0 [all_outputs]