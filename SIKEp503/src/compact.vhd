--********************************************************************************************
--* VHDL-SIKE: a speed optimized hardware implementation of the 
--*            Supersingular Isogeny Key Encapsulation scheme
--*
--*    Copyright (c) Brian Koziel, Reza Azarderakhsh, and Rami El Khatib
--*
--********************************************************************************************* 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity compact is
    port (
        a1      : in std_logic;
        b1      : in std_logic;
        a2      : in std_logic;
        b2      : in std_logic;
        A_out   : out std_logic;
        B_out   : out std_logic);
end compact;

architecture dataflow of compact is
    signal g2 : std_logic;
    signal p2 : std_logic;
begin
    g2 <= a2 and b2;
    p2 <= a2 xor b2;
    A_out <= g2 or (p2 and a1);
    B_out <= g2 or (p2 and b1);

end dataflow;
