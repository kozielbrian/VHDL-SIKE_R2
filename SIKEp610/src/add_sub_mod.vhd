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

entity add_sub_mod is
    generic (SZ : integer := 504;
             PRIME : std_logic_vector(615 downto 0) := x"027bf6a768819010c251e7d88cb255b2fa10c4252a9ae7bf45048ff9abb1784de8aa5ab02e6e01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
             NUM_ADDS : integer := 1;
             BASE_SZ : integer := 506);
    port (  clk    : in std_logic;
            rst    : in std_logic;
            red_i  : in std_logic;
            opa_i  : in std_logic_vector(SZ-1 downto 0);
            opb_i  : in std_logic_vector(SZ-1 downto 0);
            sub_i  : in std_logic;
            res_o  : out std_logic_vector(SZ-1 downto 0));
end add_sub_mod;

architecture Behavioral of add_sub_mod is

component add_sub_gen is
    generic(
            N : integer := 14;
            L : integer := 2;
            H : integer := 2);
    port (
        a_i           : in std_logic_vector(N-1 downto 0);
        b_i           : in std_logic_vector(N-1 downto 0);
        sub_i         : in std_logic; -- 0 = add, 1 = sub
        c_i           : in std_logic;
        res_o         : out std_logic_vector(N-1 downto 0);
        c_o           : out std_logic);
end component;

constant L : integer := 39;
constant H : integer := 3;

subtype add_word is std_logic_vector(BASE_SZ-1 downto 0);
type input_arr is array(0 to NUM_ADDS-1,0 to NUM_ADDS-1) of add_word;
type res_arr is array(0 to NUM_ADDS-1) of add_word;
type carry_arr is array(0 to NUM_ADDS) of std_logic;
type add_ctrl_arr is array(0 to NUM_ADDS) of std_logic;

signal a_reg_array : input_arr;
signal b_reg_array : input_arr;
signal res1_array : res_arr;
signal res2_array : res_arr;
signal res1_reg_array : input_arr;
signal res2_reg_array : input_arr;
signal carry1_array : carry_arr;
signal carry1_reg_array : carry_arr;
signal carry2_array : carry_arr;
signal carry2_reg_array : carry_arr;
signal add_ctrl_reg_array : add_ctrl_arr;
signal red_array            : add_ctrl_arr;

signal full_a     : std_logic_vector(BASE_SZ*NUM_ADDS-1 downto 0);
signal full_b     : std_logic_vector(BASE_SZ*NUM_ADDS-1 downto 0);
signal full_p     : std_logic_vector(BASE_SZ*NUM_ADDS-1 downto 0);
signal full_2p    : std_logic_vector(BASE_SZ*NUM_ADDS-1 downto 0);
signal p_in       : std_logic_vector(BASE_SZ*NUM_ADDS-1 downto 0);
signal res1_full  : std_logic_vector(BASE_SZ*NUM_ADDS-1 downto 0);
signal res1_full_d1  : std_logic_vector(BASE_SZ*NUM_ADDS-1 downto 0);
signal res2_full  : std_logic_vector(BASE_SZ*NUM_ADDS-1 downto 0);

signal neg1_s,neg2_s : std_logic;
signal neg1_r : std_logic;
signal zero2_s : std_logic;

signal zeros : std_logic_vector(BASE_SZ*NUM_ADDS-SZ-1 downto 0);

begin
zeros <= (others => '0');
full_p  <= PRIME(BASE_SZ*NUM_ADDS-1 downto 0);
full_2p <= PRIME(BASE_SZ*NUM_ADDS-2 downto 0) & '0';
full_a  <= zeros & opa_i(SZ-1 downto 0);
full_b  <= zeros & opb_i(SZ-1 downto 0);

carry1_array(0) <= '0';
carry2_array(0) <= '0';

gen_p : process(full_p, full_2p, red_array)
begin

for j in 0 to NUM_ADDS-1 loop
    case red_array(j) is
        when '1' => p_in((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ)) <= full_p((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ));
        when '0' => p_in((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ)) <= full_2p((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ));
        when others => p_in((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ)) <= full_2p((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ));
    end case;
end loop;
end process;

GEN_ADD_SUB : for I in 0 to NUM_ADDS-1 generate
    
    FIRST_ELEMENT: if I = 0 generate
        ADD_SUB_GENERIC_INST_first : add_sub_gen
            generic map(BASE_SZ,L,H)
            port map(a_i   => full_a(BASE_SZ-1 downto 0),
                     b_i   => full_b(BASE_SZ-1 downto 0),
                     sub_i => sub_i,
                     c_i   => sub_i,
                     res_o => res1_array(0),
                     c_o   => carry1_array(1));
        SUB_ADD_GENERIC_INST_first : add_sub_gen
            generic map(BASE_SZ,L,H)
            port map(a_i   => res1_reg_array(0,0),
                     b_i   => p_in(BASE_SZ-1 downto 0),
                     sub_i => (not add_ctrl_reg_array(0)), --Inverted sub/add for second cascaded adder
                     c_i   => (not add_ctrl_reg_array(0)),
                     res_o => res2_array(0),
                     c_o   => carry2_array(1));     
    end generate FIRST_ELEMENT;
    OTHER_ELEMENTS: if I > 0 generate
        ADD_SUB_GENERIC_INST : add_sub_gen
            generic map(BASE_SZ,L,H)
            port map(a_i   => a_reg_array(I-1,I),
                     b_i   => b_reg_array(I-1,I),
                     sub_i => add_ctrl_reg_array(I-1),
                     c_i   => carry1_reg_array(I),
                     res_o => res1_array(I),
                     c_o   => carry1_array(I+1));
        SUB_ADD_GENERIC_INST : add_sub_gen
            generic map(BASE_SZ,L,H)
            port map(a_i   => res1_reg_array(I,I),
                     b_i   => p_in((I+1)*(BASE_SZ)-1 downto (I)*(BASE_SZ)),
                     sub_i => (not add_ctrl_reg_array(I)),
                     c_i   => carry2_reg_array(I),
                     res_o => res2_array(I),
                     c_o   => carry2_array(I+1));
                end generate OTHER_ELEMENTS;
end generate GEN_ADD_SUB;


temp_reg : process(clk, rst)
begin
if rst = '1' then
    carry1_reg_array(NUM_ADDS) <= '0';
    carry1_reg_array(0) <= '0';
    carry2_reg_array(NUM_ADDS) <= '0';
    carry2_reg_array(0) <= '0';
    add_ctrl_reg_array(NUM_ADDS) <= '0';
    
    red_array(0) <= '0';
    red_array(NUM_ADDS) <= '0';
    
    res1_full_d1 <= (others => '0');
    neg1_r <= '0';
    
    add_ctrl_reg_array(0) <= '0';
    for j in 1 to NUM_ADDS-1 loop --Initialize a and b
        a_reg_array(0,j) <= (others => '0');
        b_reg_array(0,j) <= (others => '0');
    end loop;
    res1_reg_array(0,0) <= (others => '0');
    res2_reg_array(0,0) <= (others => '0');
    for i in 1 to NUM_ADDS-1 loop
        carry1_reg_array(i) <= '0';
        carry2_reg_array(i) <= '0';
        add_ctrl_reg_array(i) <= '0';
        red_array(i) <= '0';
        for j in 0 to NUM_ADDS-1 loop
            if (i >= j) then
                res1_reg_array(i,j) <= (others => '0');
                res2_reg_array(i,j) <= (others => '0');
            end if;
            if (i < j) then
                a_reg_array(i,j) <= (others => '0');
                b_reg_array(i,j) <= (others => '0');            
            end if;
        end loop;
    end loop;
elsif rising_edge(clk) then
    res1_full_d1 <= res1_full;
    neg1_r <= neg1_s;
    carry1_reg_array(NUM_ADDS) <= carry1_array(NUM_ADDS);
    carry2_reg_array(NUM_ADDS) <= carry2_array(NUM_ADDS);
    add_ctrl_reg_array(NUM_ADDS) <= add_ctrl_reg_array(NUM_ADDS-1);
    add_ctrl_reg_array(0) <= sub_i;
    for j in 1 to NUM_ADDS-1 loop --Initialize a and b
        a_reg_array(0,j) <= full_a((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ));
        b_reg_array(0,j) <= full_b((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ));
    end loop;
    res1_reg_array(0,0) <= res1_array(0);
    res2_reg_array(0,0) <= res2_array(0);
    red_array(0) <= red_i;
    red_array(NUM_ADDS) <= red_array(NUM_ADDS-1);
    for i in 1 to NUM_ADDS-1 loop
        red_array(i) <= red_array(i-1);
        carry1_reg_array(i) <= carry1_array(i);
        carry2_reg_array(i) <= carry2_array(i);
        add_ctrl_reg_array(i) <= add_ctrl_reg_array(i-1);
        for j in 0 to NUM_ADDS-1 loop
            
            if (i = j) then
                res1_reg_array(i,j) <= res1_array(i);
                res2_reg_array(i,j) <= res2_array(i);
            elsif (i > j) then
                res1_reg_array(i,j) <= res1_reg_array(i-1,j);
                res2_reg_array(i,j) <= res2_reg_array(i-1,j);
            end if;
            if (i < j) then
                a_reg_array(i,j) <= a_reg_array(i-1,j);
                b_reg_array(i,j) <= b_reg_array(i-1,j);            
            end if;
        end loop;
    end loop;
    
end if;
end process;

combine_res : process(res1_reg_array,res2_reg_array)
begin
for j in 0 to NUM_ADDS-1 loop
    res1_full((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ)) <= res1_reg_array(NUM_ADDS-1,j);
    res2_full((j+1)*(BASE_SZ)-1 downto (j)*(BASE_SZ)) <= res2_reg_array(NUM_ADDS-1,j);
end loop;
end process;

neg1_s <= res1_reg_array(NUM_ADDS-1,NUM_ADDS-1)(BASE_SZ-1);
neg2_s <= res2_reg_array(NUM_ADDS-1,NUM_ADDS-1)(BASE_SZ-1);

pick_res : process(res1_full_d1,res2_full,neg1_r, neg2_s, zero2_s, red_array,add_ctrl_reg_array(NUM_ADDS))
begin
    if add_ctrl_reg_array(NUM_ADDS) = '0' then --A+B-p
        if (neg2_s = '0') or (red_array(NUM_ADDS-1) = '1' and zero2_s = '1') then
            res_o <= res2_full(SZ-1 downto 0);
        else
            res_o <= res1_full_d1(SZ-1 downto 0);
        end if;
    else --A-B+p
        if neg1_r = '1' then
            res_o <= res2_full(SZ-1 downto 0);
        else
            res_o <= res1_full_d1(SZ-1 downto 0);
        end if;
    end if;
end process;

zero_test : process(res1_full,res2_full)
begin
if unsigned(res2_full) = 0 then
    zero2_s <= '1';
else
    zero2_s <= '0';
end if;
end process;

end Behavioral;
