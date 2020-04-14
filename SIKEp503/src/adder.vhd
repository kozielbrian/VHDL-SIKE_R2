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

entity adder is
    generic (N : integer := 8);
    port (
        a       : in std_logic_vector(N-1 downto 0);
        b       : in std_logic_vector(N-1 downto 0);
        cin     : in std_logic;
        s       : out std_logic_vector(N-1 downto 0);
        cout    : out std_logic);
end adder;

architecture dataflow of adder is
    signal s_full : std_logic_vector(N downto 0);
begin
    s_full <= std_logic_vector(unsigned("0" & a) + unsigned(b) + ("" & cin));
    
    s <= s_full(N-1 downto 0);
    cout <= s_full(N);

end dataflow;
