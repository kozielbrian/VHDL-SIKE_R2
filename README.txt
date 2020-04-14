#VHDL-SIKE README
By Brian Koziel, Reza Azarderakhsh, and Rami El Khatib

--********************************************************************************************
--* VHDL-SIKE: a speed optimized hardware implementation of the 
--*            Supersingular Isogeny Key Encapsulation scheme
--*
--*    Copyright (c) Brian Koziel, Reza Azarderakhsh, and Rami El Khatib
--*
--********************************************************************************************* 

VHDL-SIKE is a VHDL implementation of the supersingular isogeny
Diffie-Hellman Key Encapsulation scheme (Round 2). This
implementation was made as a proof of concept to see how fast SIKE 
could be pushed if implemented in hardware.

The implementation details of this work can be found in the paper 
SIKE'd Up: Fast Hardware Architectures for Supersingular Isogeny Key 
Encapsulation by Brian Koziel, A-Bon Ackie, Rami El Khatib, Reza Azarderakhsh,
and Mehran Mozaffari-Kermani.
Cryptology ePrint URL: https://eprint.iacr.org/2019/711

1. Contents:

Where XXX is the SIKE prime size, e.g. SIKEp434

/SIKEpXXX/
	/constraints/
		constraints.xdc
	/rom/
		lut43_pXXX.coe
		sidhROM_pXXX.coe
		sikeROM_pXXX.coe
	/src/
		add_sub_gen.vhd
		add_sub_mod.vhd
		adder.vhd
		compact.vhd
		expand.vhd
		fau.vhd
		iso_ctrl.vhd
		keccak_1088.vhd
		keccak_buffer_1088.vhd
		keccak_globals.vhd
		keccak_round.vhd
		keccak_round_constants_gen.vhd
		mm.vhd
		mult_unit.vhd
		mux_generic.vhd
		PE.vhd
		PE_final.vhd
		PE_first.vhd
		PE_prefinal.vhd
		sike_arith_unit.vhd
		sike_pXXX.vhd	
	/tb/
		sike_pXXX_tb.vhd
README.txt
RAMLayout.txt

2. Main Features:

-Speed optimized hardware implementation of SIKE Round 2 parameter sets:
	-SIKEp434 --> NIST Level 1 (as difficult as breaking AES128 with brute force)
	-SIKEp503 --> NIST Level 2 (as difficult as finding SHA256 collision with exhaustive search)
	-SIKEp610 --> NIST Level 3 (as difficult as breaking AES192 with brute force)
	-SIKEp751 --> NIST Level 5 (as difficult as breaking AES256 with brute force)
-Constant-time implementation with projective Montgomery isogeny formulas
-Includes RTL, program ROM, and a simple testbench

3. Implementation Options:

VHDL-SIKE was built for FPGA using Xilinx Vivado 2019.2. Vivado's IP
tools were made to set up a register file, isogeny program ROM file,
SIKE program ROM file, strategy lookup ROM file, and radix base DSP
multiplier. The files can also be used to synthesize with ASIC cells.
For a full estimate of hardware resources, one can include the
definitions for the register file, program ROM file, and strategy lookup
ROM file. Targeted parts are a Xilinx Artix-7 xc7a200tffg1156-3 and 
Xilinx Kintext Ultrascale+ xcku13p-ffve900-3-e.

3.1 IP Generation

Using Xilinx Vivado's IP Generator, generate the following IP with the
following options:
	lut43_table: Block Memory Generator
	prog_rom: Block Memory Generator
	sike_rom: Block Memory Generator
	reg_file: Block Memory Generator
	mult_dsp: Multiplier

3.1.1 lut43_table
IP: Block Memory Generator
Basic
  Interface type: Native
  Memory type: Single Port ROM
Port A Options
  Port A Width: 9
  Port A Depth: 2048 bits
  Primitives Output Registered
Other Options
  Load init file --> load lut43_pXXX.coe

3.1.2 prog_rom
IP: Block Memory Generator
Basic
  Interface type: Native
  Memory type: Single Port ROM
Port A Options
  Port A Width: 24
  Port A Depth: {17830, 26021, 29983, 31397} for SIKEp{434, 503, 610, 751}, respectively
  Primitives Output Registered
Other Options
  Load init file --> load sidhROM_pXXX.coe

3.1.3 sike_rom
IP: Block Memory Generator
Basic
  Interface type: Native
  Memory type: Single Port ROM
Port A Options
  Port A Width: 32
  Port A Depth: 256
  Primitives Output Registered
Other Options
  Load init file --> load sikeROM_p751.coe
  
3.1.4 reg_file
IP: Block Memory Generator
Basic
  Interface type: Native
  Memory type: True Dual Port RAM 
Port A Options
  Port A Width: {440, 504, 616, 752} for SIKEp{434, 503, 610, 751}, respectively
  Port A Depth: 256
  Primitives Output Registered
  Operating Mode: Write First
  Enable Port Type: Use ENA Pin
Port B Options
  (Same as Port A)

3.1.5 mult_dsp
IP: Multiplier
Basic
  Multiplier type: Parallel Multiplier
  A: Unsigned {22, 23, 24, 24} bit for SIKEp{434, 503, 610, 751}, respectively
  B: Unsigned {22, 23, 24, 24} bit for SIKEp{434, 503, 610, 751}, respectively
  Multiplier Construction: Use Mults
  Optimization Options: Speed Optimized
Output and Control
  Pipeline Stages: 0

4 Running the Testbench

Upon creating the IP as described above with the correct sets of ROM,
the VHDL code can be tested and verified with the included testbench in each
parameter set. This testbench initializes the register file RAM to contain the 
public parameters listed for p{434, 503, 610, 751} as well as the key and 
secret message buffer. The values used in the initial testbench correspond to 
KAT0 for SIKEp{434, 503, 610, 751}. There are a few important values for 
Montgomery multiplication that appear at the beginning of the register file.  
All arithmetic is in the Montgomery domain and converted back to the regular 
domain at the end. 

For the provided testbench, upon finishing the test vector, the
simulation will automatically print the register file contents and KAT
values. Note that we list the values from MSB to LSB. The bytes are
aligned differently from in the software KAT (reverse order).
