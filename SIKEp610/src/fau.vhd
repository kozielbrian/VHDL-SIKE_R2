--********************************************************************************************
--* VHDL-SIKE: a speed optimized hardware implementation of the 
--*            Supersingular Isogeny Key Encapsulation scheme
--*
--*    Copyright (c) Brian Koziel, Reza Azarderakhsh, and Rami El Khatib
--*
--********************************************************************************************* 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fau is
    generic (NUM_MULTS : integer := 4;
             SZ   : integer := 504;
             PRIME : std_logic_vector(615 downto 0) := x"027bf6a768819010c251e7d88cb255b2fa10c4252a9ae7bf45048ff9abb1784de8aa5ab02e6e01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
             ADD_NUM_ADDS : integer := 4;
             ADD_BASE_SZ  : integer := 127);
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           sub_i: in STD_LOGIC;
           red_i: in STD_LOGIC;
           mult_start_i: in STD_LOGIC;
           mult_reset_even_odd_i: in STD_LOGIC;
           opa_i : in STD_LOGIC_VECTOR (SZ-1 downto 0);
           opb_i : in STD_LOGIC_VECTOR (SZ-1 downto 0);
           mult_res_read_i : in STD_LOGIC;
           add_res_o : out STD_LOGIC_VECTOR (SZ-1 downto 0);
           mult_res_o : out STD_LOGIC_VECTOR (SZ-1 downto 0));
end fau;

architecture rtl of fau is

component add_sub_mod is
    generic (SZ : integer := 504;
             PRIME : std_logic_vector(615 downto 0) := x"027bf6a768819010c251e7d88cb255b2fa10c4252a9ae7bf45048ff9abb1784de8aa5ab02e6e01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
             BASE_SZ : integer := 127;
             NUM_ADDS : integer := 4);
    port (  clk    : in std_logic;
            rst    : in std_logic;
            red_i  : in std_logic;
            opa_i  : in std_logic_vector(SZ-1 downto 0);
            opb_i  : in std_logic_vector(SZ-1 downto 0);
            sub_i  : in std_logic;
            res_o  : out std_logic_vector(SZ-1 downto 0));
end component;

component mult_unit is
    generic (
            NUM_MULTS   : integer := 2;
            SZ : integer := 512;
            PE_UNITS : integer := 32;
            RADIX    : integer := 16     
    );
    port (clk              : in std_logic;
          rst              : in std_logic;
          start_i          : in std_logic;
          opa_i            : in std_logic_vector(SZ-1 downto 0);
          opb_i            : in std_logic_vector(SZ-1 downto 0);
          res_read_i       : in std_logic;
          reset_even_odd_i : in std_logic;
          res_o            : out std_logic_vector(SZ-1 downto 0));        
end component mult_unit;

    -- Signals for full-precision multiplication
    signal mult_res_s : std_logic_vector(623 downto 0);
    signal mult_opa   : std_logic_vector(623 downto 0);
    signal mult_opb   : std_logic_vector(623 downto 0);
    signal add_res_s : std_logic_vector(615 downto 0);

begin
mult_opa <= x"00" & opa_i;
mult_opb <= x"00" & opb_i;

----------------MULTIPILER------------------
    -- Multiply unit has x multipliers
    i_MULT_UNIT : mult_unit
        generic map(NUM_MULTS => NUM_MULTS,
                    SZ        => 624,
                    PE_UNITS  => 26,
                    RADIX     => 24)
        port map (clk              => clk,
	              rst              => rst, 
		          start_i          => mult_start_i,
		          opa_i            => mult_opa, 
		          opb_i            => mult_opb,
		          res_read_i       => mult_res_read_i,
		          reset_even_odd_i => mult_reset_even_odd_i,
		          res_o            => mult_res_s);
    
----------------ADDER/SUBTRACTOR------------------
    -- Adder/subtractor
    i_ADDER_SUBTRACTOR : add_sub_mod
        generic map (SZ        => SZ,
                     PRIME     => PRIME,
                     NUM_ADDS  => ADD_NUM_ADDS,
                     BASE_SZ   => ADD_BASE_SZ)
        port map(clk    => clk, 
                 rst    => rst,
                 red_i  => red_i, 
                 opa_i  => opa_i, 
                 opb_i  => opb_i, 
                 sub_i  => sub_i, 
                 res_o  => add_res_s);

    mult_res_o <= mult_res_s(SZ-1 downto 0);
    add_res_o  <= add_res_s(SZ-1 downto 0);
end rtl;
