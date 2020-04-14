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

entity iso_ctrl is
    Port ( clk         : in  std_logic;
           rst         : in  std_logic;
           iso_cmd_i   : in  std_logic_vector(2 downto 0);
           digit_i     : in  std_logic;
           instr_o     : out std_logic_vector(24 downto 0);
           req_digit_o : out std_logic;
           alice_o     : out std_logic;
           busy_o      : out std_logic);
end iso_ctrl;
architecture structural of iso_ctrl is

    constant INSTRUCTION_LENGTH    : integer := 24;
    constant PROG_ADDR_W           : integer := 15;
    constant PROG_LENGTH           : integer := 2**PROG_ADDR_W;

    -- Strategy lookup ROM
    COMPONENT lut43_table
      PORT (
        clka  : IN  std_logic;
        ena   : IN  std_logic;
        addra : IN  std_logic_vector(10 DOWNTO 0);
        douta : OUT std_logic_vector(8 DOWNTO 0)
      );
    END COMPONENT;

    -- Program ROM    
    COMPONENT prog_rom IS
      PORT (
        clka  : IN  std_logic;
        ena   : IN  std_logic;
        addra : IN  std_logic_vector(PROG_ADDR_W-1 DOWNTO 0);
        douta : OUT std_logic_vector(INSTRUCTION_LENGTH-1 DOWNTO 0)
      );
    END COMPONENT prog_rom;     

    --Subroutine listing
    constant NOP                 : integer := 0;
     
    constant ISO_LOOP_CHK_S      : integer := 1;
    constant ISO_LOOP_CHK_E      : integer := 1;
    constant A1_INIT_S           : integer := 2;
    constant A1_INIT_E           : integer := 48;
    constant B1_INIT_S           : integer := 49;
    constant B1_INIT_E           : integer := 95;
    constant THREE_PT_LADDER_INIT_S: integer := 96;
    constant THREE_PT_LADDER_INIT_E: integer := 131;
    constant THREE_PT_LADDER1_S  : integer := 132;
    constant THREE_PT_LADDER1_E  : integer := 377;
    constant THREE_PT_LADDER2_S  : integer := 378;
    constant THREE_PT_LADDER2_E  : integer := 623;
    constant ISO_INIT_ALICE_S    : integer := 624;
    constant ISO_INIT_ALICE_E    : integer := 630;
    constant ISO_INIT_BOB_S      : integer := 631;
    constant ISO_INIT_BOB_E      : integer := 640;
    constant ISO_REDUCE_S        : integer := 641;
    constant ISO_REDUCE_E        : integer := 648;
    constant ISO_SPLIT_S         : integer := 649;
    constant ISO_SPLIT_E         : integer := 656;
    constant MONT_QUAD_S         : integer := 657;
    constant MONT_QUAD_E         : integer := 944;
    constant MONT_TRIPLE_S       : integer := 945;
    constant MONT_TRIPLE_E       : integer := 1209;
    constant GET_4_ISO_S         : integer := 1210;
    constant GET_4_ISO_E         : integer := 1292;
    constant GET_3_ISO_S         : integer := 1293;
    constant GET_3_ISO_E         : integer := 1445;
    constant ALICE_R1_POST_ISO_S : integer := 1446;
    constant ALICE_R1_POST_ISO_E : integer := 1459;
    constant BOB_R1_POST_ISO_S   : integer := 1460;
    constant BOB_R1_POST_ISO_E   : integer := 1473;
    constant INV_3_WAY_PART1_S   : integer := 1474;
    constant INV_3_WAY_PART1_E   : integer := 1557;
    constant INV_3_WAY_PART2_S   : integer := 1558;
    constant INV_3_WAY_PART2_E   : integer := 1618;
    constant ALICE_R1_END_S      : integer := 1619;
    constant ALICE_R1_END_E      : integer := 1712;
    constant BOB_R1_END_S        : integer := 1713;
    constant BOB_R1_END_E        : integer := 1806;
    constant A2_INIT_S           : integer := 1807;
    constant A2_INIT_E           : integer := 1821;
    constant B2_INIT_S           : integer := 1822;
    constant B2_INIT_E           : integer := 1836;
    constant GET_A_PART1_S       : integer := 1837;
    constant GET_A_PART1_E       : integer := 1939;
    constant GET_A_PART2_S       : integer := 1940;
    constant GET_A_PART2_E       : integer := 1970;
    constant ALICE_R2_POST_ISO_S : integer := 1971;
    constant ALICE_R2_POST_ISO_E : integer := 1989;
    constant BOB_R2_POST_ISO_S   : integer := 1990;
    constant BOB_R2_POST_ISO_E   : integer := 2007;
    constant J_INV_PART1_S       : integer := 2008;
    constant J_INV_PART1_E       : integer := 2171;
    constant ALICE_J_INV_END_S   : integer := 2172;
    constant ALICE_J_INV_END_E   : integer := 2209;
    constant BOB_J_INV_END_S     : integer := 2210;
    constant BOB_J_INV_END_E     : integer := 2247;
    constant INV2_S              : integer := 2248;
    constant INV2_E              : integer := 6989;
    constant EVAL3_X1_S          : integer := 6990;
    constant EVAL3_X1_E          : integer := 7125;
    constant EVAL3_X2_S          : integer := 7126;
    constant EVAL3_X2_E          : integer := 7398;
    constant EVAL3_OPP_S         : integer := 7399;
    constant EVAL3_OPP_E         : integer := 7831;
    constant EVAL3_X3_S          : integer := 7832;
    constant EVAL3_X3_E          : integer := 8264;
    constant EVAL3_X4_S          : integer := 8265;
    constant EVAL3_X4_E          : integer := 8831;
    constant EVAL3_X5_S          : integer := 8832;
    constant EVAL3_X5_E          : integer := 9520;
    constant EVAL3_X6_S          : integer := 9521;
    constant EVAL3_X6_E          : integer := 10383;
    constant EVAL3_X7_S          : integer := 10384;
    constant EVAL3_X7_E          : integer := 11382;
    constant EVAL3_X8_S          : integer := 11383;
    constant EVAL3_X8_E          : integer := 12513;
    constant EVAL3_X9_S          : integer := 12514;
    constant EVAL3_X9_E          : integer := 13790;
    constant EVAL3_X10_S         : integer := 13791;
    constant EVAL3_X10_E         : integer := 15182;
    constant EVAL3_X11_S         : integer := 15183;
    constant EVAL3_X11_E         : integer := 16683;
    constant EVAL3_X12_S         : integer := 16684;
    constant EVAL3_X12_E         : integer := 18385;
    constant EVAL4_X1_S          : integer := 18386;
    constant EVAL4_X1_E          : integer := 18574;
    constant EVAL4_X2_S          : integer := 18575;
    constant EVAL4_X2_E          : integer := 18934;
    constant EVAL4_X3_S          : integer := 18935;
    constant EVAL4_X3_E          : integer := 19500;
    constant EVAL4_OPP_S         : integer := 19501;
    constant EVAL4_OPP_E         : integer := 20066;
    constant EVAL4_X4_S          : integer := 20067;
    constant EVAL4_X4_E          : integer := 20847;
    constant EVAL4_X5_S          : integer := 20848;
    constant EVAL4_X5_E          : integer := 21809;
    constant EVAL4_X6_S          : integer := 21810;
    constant EVAL4_X6_E          : integer := 22915;
    constant EVAL4_X7_S          : integer := 22916;
    constant EVAL4_X7_E          : integer := 24213;
    constant EVAL4_X8_S          : integer := 24214;
    constant EVAL4_X8_E          : integer := 25770;
    constant EVAL4_X9_S          : integer := 25771;
    constant EVAL4_X9_E          : integer := 27529;
    constant EVAL4_X10_S         : integer := 27530;
    constant EVAL4_X10_E         : integer := 29379;
    constant EVAL4_X11_S         : integer := 29380;
    constant EVAL4_X11_E         : integer := 31395;
    constant EVAL4_X12_S         : integer := 31396;
    constant EVAL4_X12_E         : integer := 31396;


    signal prog_cntr : integer range 0 to PROG_LENGTH := NOP;   
    signal stall_cntr : integer range 0 to 150;
    
    -- Program pipeline signals
    signal prog_addr : std_logic_vector(PROG_ADDR_W-1 downto 0);
    signal prog_line : std_logic_vector(INSTRUCTION_LENGTH-1 downto 0);
    signal prog_line_pipe1 : std_logic_vector(INSTRUCTION_LENGTH-1 downto 0);
    signal prog_line_pipe2 : std_logic_vector(INSTRUCTION_LENGTH-1 downto 0);
    
    signal first_round : std_logic;
    signal start_iso : std_logic;
    signal alice_round : std_logic;
    signal busy_s,busy_r,busy_d1,busy_d2,busy_d3 : std_logic;
    
    --Signals for splits
    signal num_mults : integer range 0 to 1023;
    
    signal mont_count : integer range 0 to 511;
    signal iso_count : integer range 0 to 511; --MAX
    constant ALICE_MONT_COUNT  : integer := 372; --31,250,372
    constant BOB_MONT_COUNT    : integer := 379; --32,253,379
    constant ALICE_ISO_COUNT   : integer := 186; --125,186
    constant BOB_ISO_COUNT     : integer := 239; --159,239
    
    signal iso_index : integer range 0 to 1023; --index
    signal iso_row   : integer range 0 to 1023; --row
    signal iso_m_addr: integer range 0 to 1023; --MAX-index-row+1
    signal iso_m     : integer range 0 to 1023; --m := splits[MAX-index-row+1]
    signal iso_loop  : integer range 0 to 1023; --MAX - row
    signal iso_done : std_logic;
    
    signal queue_size_r : integer range 0 to 15; --0 to 16
    signal queue_size_d1 : integer range 0 to 15;
    signal queue_size_d2 : integer range 0 to 15;
    signal queue_size_d3 : integer range 0 to 15;
    signal queue_size_d4 : integer range 0 to 15;
    signal queue_pointer : integer range 0 to 31; --What address the queue is pointing at
    signal lut43_out : std_logic_vector(8 downto 0);
    signal lut43_addr : std_logic_vector(10 downto 0);
    signal stalled : std_logic;
    signal stalled_pipe1 : std_logic;
    signal finish_get_A : std_logic;
    
    type index_array is array (0 to 15) of integer range 0 to 1023; --Array of indexes
    signal indices : index_array;

begin
    -- Strategy Lookup Table
    lut43_addr(10) <= not alice_round; --Alice's LUT is first 1024 entries
    lut43_addr(9 downto 0) <= std_logic_vector(to_unsigned(iso_m_addr,10));
    i_strategy_lookup : lut43_table
        port map (clka  => clk, 
	              ena   => '1', 
		          addra => lut43_addr, 
		          douta => lut43_out);
        
    -- Program ROM
    prog_addr <= std_logic_vector(to_unsigned(prog_cntr,PROG_ADDR_W));

    i_prog_rom : prog_rom
        port map (clka  => clk,
	              ena   => '1',
		          addra => prog_addr,
		          douta => prog_line);

    alice_o <= alice_round;
    -- Program subroutine flow for isogen and isoex
    program_flow : process (clk,rst)
    begin
        if rst = '1' then
            prog_cntr <= 0;
            stall_cntr <= 0;
            req_digit_o <= '0';
            first_round <= '0';
            alice_round <= '0';
            start_iso <= '0';
            mont_count <= 0;
            iso_count <= 0;
            queue_size_r <= 0;
            queue_size_d1 <= 0;
            queue_size_d2 <= 0;
            queue_size_d3 <= 0;
            queue_size_d4 <= 0;
            queue_pointer <= 0;
            stalled <= '0';
            stalled_pipe1 <= '0';
            
            iso_m_addr <= 0;
            iso_loop <= 0;
            iso_m <= 0;
            iso_row <= 0;
            iso_done <= '0';
            
            finish_get_A <= '0';
            
        elsif rising_edge(clk) then
            queue_size_d1 <= queue_size_r;
            queue_size_d2 <= queue_size_d1;
            queue_size_d3 <= queue_size_d2;
            queue_size_d4 <= queue_size_d3;
            queue_pointer <= queue_size_d4 + 4; --Use delayed queue size
            iso_m_addr <= iso_count - iso_index - iso_row;
            iso_loop <= iso_count - iso_row;
            iso_m <= to_integer(unsigned(lut43_out));            
            stalled_pipe1 <= stalled;
            if stalled = '1' and stall_cntr > 0 then
                req_digit_o <= '0';
                stall_cntr <= stall_cntr - 1;
            elsif (prog_line(23) = '1') and stalled = '0' and stalled_pipe1 = '0' then --stall counter to prevent more reads from program ROM
                req_digit_o <= '0';
                stalled <= '1';
                stall_cntr <= to_integer(unsigned(prog_line(7 downto 0)));
            elsif (stalled = '0') or (stalled = '1' and stall_cntr = 0) then
                stalled <= '0';
                case prog_cntr is
		    -- Waiting for new valid command    
                    when NOP =>
                        
                        case iso_cmd_i is
                            when "001" => prog_cntr <= A1_INIT_S; -- Alice1
                                          first_round <= '1';
                                          alice_round <= '1';
                                          start_iso <= '1';
                                          mont_count <= ALICE_MONT_COUNT;
                                          iso_count <= ALICE_ISO_COUNT;
                                          iso_done <= '0';
                                          iso_index <= 0;
                                          iso_row <= 1;
                                          queue_size_r <= 0;                                    
                            when "010" => prog_cntr <= B1_INIT_S; -- Bob1
                                          first_round <= '1';
                                          alice_round <= '0';
                                          mont_count <= BOB_MONT_COUNT;
                                          iso_count <= BOB_ISO_COUNT;
                                          iso_done <= '0';
                                          iso_index <= 0;
                                          iso_row <= 1;
                                          queue_size_r <= 0;
                            when "011" => prog_cntr <= A2_INIT_S; -- Alice2
                                          first_round <= '0';
                                          alice_round <= '1';
                                          start_iso <= '1';
                                          mont_count <= ALICE_MONT_COUNT;
                                          iso_count <= ALICE_ISO_COUNT;
                                          iso_done <= '0';
                                          iso_index <= 0;
                                          iso_row <= 1;
                                          queue_size_r <= 0;
                                          finish_get_A <= '1';               
                            when "100" => prog_cntr <= B2_INIT_S; -- Bob2
                                          first_round <= '0';
                                          alice_round <= '0';
                                          mont_count <= BOB_MONT_COUNT;
                                          iso_count <= BOB_ISO_COUNT;
                                          iso_done <= '0';
                                          iso_index <= 0;
                                          iso_row <= 1;
                                          queue_size_r <= 0;
                                          finish_get_A <= '1';
                            when others => prog_cntr <= NOP;
                        end case;
                        req_digit_o <= '0';
                    
                    when A1_INIT_E =>
                        prog_cntr <= THREE_PT_LADDER_INIT_S;                    
                    when B1_INIT_E =>
                        prog_cntr <= THREE_PT_LADDER_INIT_S;
                    
                    when A2_INIT_E =>
                        prog_cntr <= GET_A_PART1_S;
                    when B2_INIT_E =>
                        prog_cntr <= GET_A_PART1_S;

                    when GET_A_PART1_E =>
                        prog_cntr <= INV2_S;
                    when GET_A_PART2_E =>
                        prog_cntr <= THREE_PT_LADDER_INIT_S;
                        finish_get_A <= '0';

                    -- DOUBLE POINT MULTIPLICATION
                    
                    when THREE_PT_LADDER_INIT_E =>
                        mont_count <= mont_count - 1;
                        req_digit_o <= '1';
                        case digit_i is
                            when '0' =>
                                prog_cntr <= THREE_PT_LADDER1_S;
                            when '1' =>
                                prog_cntr <= THREE_PT_LADDER2_S;
                            when others =>
                        end case; 
                    
                    when THREE_PT_LADDER1_S => 
                        req_digit_o <= '0';
                        prog_cntr <= prog_cntr + 1;
                    
                    when THREE_PT_LADDER1_E =>
                        if mont_count = 0 then
                            if alice_round = '1' then
                                prog_cntr <= ISO_INIT_ALICE_S;
                            else
                                prog_cntr <= ISO_INIT_BOB_S;
                            end if;     
                        else
                            req_digit_o <= '1';   
                            case digit_i is
                                when '0' =>
                                    prog_cntr <= THREE_PT_LADDER1_S;
                                when '1' =>
                                    prog_cntr <= THREE_PT_LADDER2_S;
                                when others =>
                            end case;
                            mont_count <= mont_count - 1;
                        end if;  
                        
                    when THREE_PT_LADDER2_S => 
                        req_digit_o <= '0';
                        prog_cntr <= prog_cntr + 1;
                    
                    when THREE_PT_LADDER2_E =>
                        if mont_count = 0 then
                            if alice_round = '1' then
                                prog_cntr <= ISO_INIT_ALICE_S;
                            else
                                prog_cntr <= ISO_INIT_BOB_S;
                            end if;     
                        else
                            req_digit_o <= '1';   
                            case digit_i is
                                when '0' =>
                                    prog_cntr <= THREE_PT_LADDER1_S;
                                when '1' =>
                                    prog_cntr <= THREE_PT_LADDER2_S;
                                when others =>
                            end case;
                            mont_count <= mont_count - 1;
                        end if;  

                    when ISO_INIT_ALICE_E =>
                        prog_cntr <= ISO_SPLIT_S;
                    when ISO_INIT_BOB_E =>
                        prog_cntr <= ISO_SPLIT_S;                       
                    -- SHIFT ISO registers and increment queue size
                    
                    when ISO_REDUCE_E =>
                        prog_cntr <= ISO_LOOP_CHK_S;
                    
                    when ISO_LOOP_CHK_E =>
                        if iso_index >= iso_loop then
                            if alice_round = '1' then
                                prog_cntr <= GET_4_ISO_S;
                            else
                                prog_cntr <= GET_3_ISO_S;
                            end if;
                        else
                            prog_cntr <= ISO_SPLIT_S;
                        end if;                    
                        
                    when ISO_SPLIT_S =>
                        prog_cntr <= prog_cntr + 1;
                        indices(queue_size_r) <= iso_index;
                    when ISO_SPLIT_E => 
                        prog_cntr <= prog_cntr + 1;
                        queue_size_r <= queue_size_r + 1;
                        num_mults <= iso_m - 1;
                        iso_index <= iso_index + iso_m;
                        if alice_round = '1' then
                            prog_cntr <= MONT_QUAD_S;
                        else
                            prog_cntr <= MONT_TRIPLE_S;
                        end if;

                    when MONT_QUAD_E =>
                        if num_mults = 0 then
                            prog_cntr <= ISO_LOOP_CHK_S;
                        else
							prog_cntr <= MONT_QUAD_S;
                            num_mults <= num_mults - 1;
                        end if;
                    when MONT_TRIPLE_E =>
                        if num_mults = 0 then
                            prog_cntr <= ISO_LOOP_CHK_S;
                        else
                            prog_cntr <= MONT_TRIPLE_S;
                            num_mults <= num_mults - 1;
                        end if;
                    
                    when GET_4_ISO_E =>  
                        if queue_size_r /= 0 then
                            iso_index <= indices(queue_size_r-1);
                            indices(queue_size_r-1) <= 0;
                            queue_size_r <= queue_size_r - 1;
                        end if;
                        iso_row <= iso_row + 1;
                        case queue_size_r is
                            when 0 =>
                                case first_round is
                                    when '1' =>
                                        prog_cntr <= EVAL4_OPP_S;
                                        iso_done <= '1';
                                    when '0' =>
                                        prog_cntr <= ALICE_R2_POST_ISO_S;
                                    when others =>
                                end case;
                            when 1 =>
                                prog_cntr <= EVAL4_X1_S;
                            when 2 =>
                                prog_cntr <= EVAL4_X2_S;
                            when 3 =>
                                prog_cntr <= EVAL4_X3_S;
                            when 4 =>
                                prog_cntr <= EVAL4_X4_S;
                            when 5 =>
                                prog_cntr <= EVAL4_X5_S;
                            when 6 =>
                                prog_cntr <= EVAL4_X6_S;
                            when 7 =>
                                prog_cntr <= EVAL4_X7_S;
                            when 8 =>
                                prog_cntr <= EVAL4_X8_S;
                            when 9 =>
                                prog_cntr <= EVAL4_X9_S;
                            when 10 =>
                                prog_cntr <= EVAL4_X10_S;
                            when 11 =>
                                prog_cntr <= EVAL4_X11_S;
                            when 12 =>
                                prog_cntr <= EVAL4_X12_S;                            
                            when others =>
                       end case;               
                                        
                    when GET_3_ISO_E =>
                        if queue_size_r /= 0 then
                            iso_index <= indices(queue_size_r-1);
                            indices(queue_size_r-1) <= 0;
                            queue_size_r <= queue_size_r - 1;
                        end if;
                        iso_row <= iso_row + 1;
                        case queue_size_r is
                            when 0 =>
                                case first_round is
                                    when '1' =>
                                        prog_cntr <= EVAL3_OPP_S;
                                        iso_done <= '1';
                                    when '0' =>
                                        prog_cntr <= BOB_R2_POST_ISO_S;
                                    when others =>
                                end case;
                            when 1 =>
                                prog_cntr <= EVAL3_X1_S;
                            when 2 =>
                                prog_cntr <= EVAL3_X2_S;
                            when 3 =>
                                prog_cntr <= EVAL3_X3_S;
                            when 4 =>
                                prog_cntr <= EVAL3_X4_S;
                            when 5 =>
                                prog_cntr <= EVAL3_X5_S;
                            when 6 =>
                                prog_cntr <= EVAL3_X6_S;
                            when 7 =>
                                prog_cntr <= EVAL3_X7_S;
                            when 8 =>
                                prog_cntr <= EVAL3_X8_S;
                            when 9 =>
                                prog_cntr <= EVAL3_X9_S;
                            when 10=>
                                prog_cntr <= EVAL3_X10_S;
                            when 11 =>
                                prog_cntr <= EVAL3_X11_S;
                            when 12=>
                                prog_cntr <= EVAL3_X12_S;
                            when others =>   
                       end case;
                   when EVAL4_X1_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;     
                   when EVAL4_X2_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;
                   when EVAL4_X3_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;      
                   when EVAL4_X4_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;
                   when EVAL4_X5_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;
                   when EVAL4_X6_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;
                   when EVAL4_X7_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;     
                   when EVAL4_X8_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;    
                   when EVAL4_X9_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case; 
                   when EVAL4_X10_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;     
                   when EVAL4_X11_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;    
                   when EVAL4_X12_E =>
                       case first_round is
                           when '0' =>
                               prog_cntr <= ISO_REDUCE_S;
                           when '1' =>
                               prog_cntr <= EVAL4_OPP_S;
                           when others =>
                       end case;                          
                                               
                    when EVAL3_X1_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;     
                    when EVAL3_X2_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;
                    when EVAL3_X3_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;      
                    when EVAL3_X4_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;
                    when EVAL3_X5_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;
                    when EVAL3_X6_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;
                    when EVAL3_X7_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;     
                    when EVAL3_X8_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;    
                    when EVAL3_X9_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;        
                    when EVAL3_X10_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;
                    when EVAL3_X11_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;      
                    when EVAL3_X12_E =>
                        case first_round is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= EVAL3_OPP_S;
                            when others =>
                        end case;                                                     

                    when EVAL4_OPP_E =>
                        case iso_done is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= ALICE_R1_POST_ISO_S;
                            when others =>
                        end case;
                   
                    when EVAL3_OPP_E =>
                        case iso_done is
                            when '0' =>
                                prog_cntr <= ISO_REDUCE_S;
                            when '1' =>
                                prog_cntr <= BOB_R1_POST_ISO_S;
                            when others =>
                        end case;
                        
                    when ALICE_R1_POST_ISO_E =>
                        prog_cntr <= INV_3_WAY_PART1_S;
                    when BOB_R1_POST_ISO_E =>
                        prog_cntr <= INV_3_WAY_PART1_S;
                        
                    when ALICE_R2_POST_ISO_E =>
                        prog_cntr <= J_INV_PART1_S;
                    when BOB_R2_POST_ISO_E =>
                        prog_cntr <= J_INV_PART1_S;                        
                        
                    when INV_3_WAY_PART1_E =>
                        prog_cntr <= INV2_S;
                    when J_INV_PART1_E =>
                        prog_cntr <= INV2_S;
                    when INV2_E =>
                        case first_round is
                            when '0' =>
                                if finish_get_A = '1' then
                                    prog_cntr <= GET_A_PART2_S;
                                else
                                    case alice_round is
                                        when '0' =>
                                            prog_cntr <= BOB_J_INV_END_S;
                                        when '1' =>
                                            prog_cntr <= ALICE_J_INV_END_S;
                                        when others =>
                                    end case;                               
                                end if;
                            when '1' =>
                                prog_cntr <= INV_3_WAY_PART2_S;
                            when others =>
                        end case;
                    when INV_3_WAY_PART2_E =>
                        case alice_round is
                            when '0' =>
                                prog_cntr <= BOB_R1_END_S;
                            when '1' =>
                                prog_cntr <= ALICE_R1_END_S;
                            when others =>
                        end case;
                    when ALICE_R1_END_E =>
                        prog_cntr <= NOP;
                    when BOB_R1_END_E =>
                        prog_cntr <= NOP;
                    when ALICE_J_INV_END_E =>
                        prog_cntr <= NOP;
                    when BOB_J_INV_END_E =>
                        prog_cntr <= NOP;
                    when others => prog_cntr <= prog_cntr + 1;
                end case;
            end if;
        end if;
    end process program_flow;
    
    busy_s <= '0' when prog_cntr = NOP else '1';
    busy_o <= busy_s or busy_r or busy_d1 or busy_d2 or busy_d3;
    
    program_pipeline : process (clk,rst)
    begin
        if rst = '1' then
            prog_line_pipe1 <= (others => '0');
            prog_line_pipe2 <= (others => '0');
            busy_r  <= '0';
            busy_d1 <= '0';
            busy_d2 <= '0';
            busy_d3 <= '0';
        elsif rising_edge(clk) then
            if stalled_pipe1 = '1' then
                prog_line_pipe1 <= prog_line_pipe1;
                prog_line_pipe2 <= prog_line_pipe2;
            else
                prog_line_pipe1 <= prog_line;
                prog_line_pipe2 <= prog_line_pipe1;
            end if;
            busy_r  <= busy_s;
            busy_d1 <= busy_r or stalled or stalled_pipe1;
            busy_d2 <= busy_d1;
            busy_d3 <= busy_d2;
        end if;
    end process program_pipeline;
    
    --Instruction out to arithmetic units and memory
    i_instr_out : process (clk,rst)
    begin
    if rst = '1' then
        instr_o <= (others => '0');
	elsif rising_edge(clk) then
	    if prog_line_pipe2(23) = '1' then
            instr_o <= (others => '0');
	    else
	        instr_o(22 downto 22) <= (others => '0');
	        instr_o(24 downto 23) <= (others => '0');
		    instr_o(21 downto 20) <= prog_line_pipe2(21 downto 20); --Mult control
		    instr_o(17 downto 17) <= prog_line_pipe2(17 downto 17); --Mem writeA
		    instr_o(16 downto 16) <= prog_line_pipe2(16 downto 16); --Mem writeB
		    instr_o(7 downto 0)   <= prog_line_pipe2(7 downto 0);   --Addr B

		    --Special address for A (point queue select)
		    if prog_line_pipe2(22) = '1' then
                instr_o(15 downto 8) <= "1" & std_logic_vector(to_unsigned(queue_pointer,5)) & prog_line_pipe2(9 downto 8);
		    else
                instr_o(15 downto 8) <= prog_line_pipe2(15 downto 8);
		    end if;
		
		    --Adder controls
            case prog_line_pipe2(19 downto 18) is 
                when "00"  => instr_o(19 downto 18) <= "00"; -- NOP
                when "01"  => instr_o(19 downto 18) <= "00"; -- ADDM
                when "10"  => instr_o(19 downto 18) <= "01"; -- SUBM
	            when "11"  => instr_o(19 downto 18) <= "10"; -- REDM
                when others => instr_o(19 downto 18) <= (others => '0');
		    end case;
	    end if;
    end if;
    end process i_instr_out;

end structural;
