derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -to {*Hq2x*} -setup 4
set_multicycle_path -to {*Hq2x*} -hold 3

set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to {ascal|*} -setup 4
set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to {ascal|*} -hold 3

set_multicycle_path -from {emu|sdram|*} -to {emu|S32X|s32x_if|*} -start -setup 2
set_multicycle_path -from {emu|sdram|*} -to {emu|S32X|s32x_if|*} -start -hold 1
