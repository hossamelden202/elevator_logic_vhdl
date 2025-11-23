
vlib work
vmap work work

# Compile all source files
vcom -2008 rtl/ssd.vhd
vcom -2008 rtl/request_resolver.vhd
vcom -2008 rtl/elevator_ctrl.vhd
vcom -2008 rtl/elevator_top.vhd
vcom -2008 tb/elevator_ctrl_tb.vhd

# Run simulation
vsim work.elevator_ctrl_tb

# Add signals to waveform
add wave -r /*

# Run for full simulation time
run 500 ms

# Optional: save waveform layout
write format wave wave_elevator_ctrl.wlf



