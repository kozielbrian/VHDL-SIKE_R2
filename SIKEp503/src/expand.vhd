--********************************************************************************************
--* VHDL-SIKE: a speed optimized hardware implementation of the 
--*            Supersingular Isogeny Key Encapsulation scheme
--*
--*    Copyright (c) Brian Koziel, Reza Azarderakhsh, and Rami El Khatib
--*
--********************************************************************************************* 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity expand is
    port (
        a1      : in std_logic;
        b1      : in std_logic;
        a2      : in std_logic;
        b2      : in std_logic;
        S_in    : in std_logic;
        s1      : out std_logic;
        s2      : out std_logic);
end expand;

architecture dataflow of expand is
    signal p1       : std_logic;
    signal p2       : std_logic;
    signal P_all    : std_logic;
    signal c1       : std_logic;
    signal c2       : std_logic;
    signal g1       : std_logic;
begin
    p1 <= a1 xor b1;
    p2 <= a2 xor b2;
    P_all <= p1 and p2;
    c1 <= S_in xor P_all;
    g1 <= a1 and b1;
    c2 <= g1 or (p1 and c1);
    
    s1 <= p1 xor c1;
    s2 <= p2 xor c2;
end dataflow;
