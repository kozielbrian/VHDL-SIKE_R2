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

entity PE_final is
    generic(RADIX : integer := 16);
    port(  clk    : in std_logic;
           rst    : in std_logic;
           si_i   : in std_logic_vector(1 downto 0);
           ci_i   : in std_logic_vector(RADIX downto 0); --k+1 bits
           sip1_o : out std_logic_vector(RADIX-1 downto 0);
           cip1_o : out std_logic_vector(1 downto 0)); --k+1 bits
           
end PE_final;

architecture Behavioral of PE_final is

signal s_in_exp : std_logic_vector(RADIX+1 downto 0);
signal c_in_exp : std_logic_vector(RADIX+1 downto 0);
signal res : std_logic_vector(RADIX+1 downto 0); --18 bits

begin

s_in_exp(RADIX+1 downto 2) <= (others => '0');
s_in_exp(1 downto 0) <= si_i;
c_in_exp(RADIX+1 downto RADIX+1) <= (others => '0');
c_in_exp(RADIX downto 0) <= ci_i;
res <= std_logic_vector(unsigned(s_in_exp) + unsigned(c_in_exp));

i_output_regs : process(clk) --synchronous reset
begin
if rising_edge(clk) then
    if rst = '1' then
        cip1_o <= (others => '0');
        sip1_o <= (others => '0');
    else
        cip1_o(1 downto 0) <= res(RADIX+1 downto RADIX);
        sip1_o <= res(RADIX-1 downto 0);
    end if;
end if;
end process;


end Behavioral;
