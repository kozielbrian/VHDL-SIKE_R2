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

entity sike_p610 is
    generic (NUM_MULTS : integer := 3;
             SZ   : integer := 616;
             PRIME : std_logic_vector(615 downto 0) := x"027bf6a768819010c251e7d88cb255b2fa10c4252a9ae7bf45048ff9abb1784de8aa5ab02e6e01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
             ADD_NUM_ADDS : integer := 1;
             ADD_BASE_SZ  : integer := 616);
    Port ( clk                     : in  std_logic;
           rst                     : in  std_logic;
           sike_cmd_i              : in  std_logic_vector(2 downto 0);
           iso_cmd_i               : in  std_logic_vector(2 downto 0);
           reg_sel_i               : in  std_logic_vector(7 downto 0);
           wr_input_sel_i          : in  std_logic;
           wr_op_sel_i             : in  std_logic_vector(1 downto 0);
           wr_word_sel_i           : in  std_logic_vector(3 downto 0);
           wr_en_i                 : in  std_logic;
           rd_reg_i                : in  std_logic;
           rd_op_sel_i             : in  std_logic_vector(1 downto 0);
           rd_word_sel_i           : in  std_logic_vector(3 downto 0);
           buffer_xor_i            : in  std_logic;
           keccak_clear_i          : in  std_logic;
           keccak_din_i            : in  std_logic_vector(7 downto 0);
           keccak_din_valid_byte_i : in  std_logic;
           keccak_word_cnt_i       : in  std_logic_vector(7 downto 0);
           keccak_word_valid_i     : in  std_logic;
           keccak_finish_i         : in  std_logic;
           data_i                  : in  std_logic_vector (63 downto 0);
           data_o                  : out std_logic_vector (63 downto 0);
           busy_o                  : out std_logic
    );
end sike_p610; 

architecture structural of sike_p610 is

    constant INSTRUCTION_LENGTH    : integer := 32;
    constant PROG_ADDR_W           : integer := 8;
    constant PROG_LENGTH           : integer := 2**PROG_ADDR_W;
    -- SIKE Program ROM    
    COMPONENT sike_rom IS
      PORT (
        clka  : IN  std_logic;
        ena   : IN  std_logic;
        addra : IN  std_logic_vector(PROG_ADDR_W-1 DOWNTO 0);
        douta : OUT std_logic_vector(INSTRUCTION_LENGTH-1 DOWNTO 0)
      );
    END COMPONENT sike_rom;     
    
    component sike_arith_unit is
        generic (NUM_MULTS : integer := 2;
                 REG_SZ   : integer := 504;
                 PRIME : std_logic_vector(615 downto 0) := x"027bf6a768819010c251e7d88cb255b2fa10c4252a9ae7bf45048ff9abb1784de8aa5ab02e6e01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
                 ADD_NUM_ADDS : integer := 4;
                 ADD_BASE_SZ  : integer := 127);
        port ( clk                     : in  std_logic;
               rst                     : in  std_logic;
               iso_cmd_i               : in  std_logic_vector(2 downto 0);
               reg_sel_i               : in  std_logic_vector(7 downto 0);
               wr_input_sel_i          : in  std_logic;
               wr_op_sel_i             : in  std_logic_vector(1 downto 0);
               wr_word_sel_i           : in  std_logic_vector(3 downto 0);
               wr_en_i                 : in  std_logic;
               rd_reg_i                : in  std_logic;
               rd_op_sel_i             : in  std_logic_vector(1 downto 0);
               rd_word_sel_i           : in  std_logic_vector(3 downto 0);
               buffer_xor_i            : in  std_logic;
               keccak_clear_i          : in  std_logic;
               keccak_din_i            : in  std_logic_vector(7 downto 0);
               keccak_din_valid_byte_i : in  std_logic;
               keccak_word_cnt_i       : in  std_logic_vector(7 downto 0);
               keccak_word_valid_i     : in  std_logic;
               keccak_finish_i         : in  std_logic;
               data_i                  : in  std_logic_vector (63 downto 0);
               data_o                  : out std_logic_vector (63 downto 0);
               busy_o                  : out std_logic
    );
    end component sike_arith_unit; 

    --Subroutine listing
    constant NOP              : integer := 0;
    constant KEYGEN_S         : integer := 1;
    constant KEYGEN_E         : integer := 1;
    constant BOBISOKECCAK_S   : integer := 2;
    constant BOBISOKECCAK_E   : integer := 24;
    constant ALICEISOKECCAK_S : integer := 25;
    constant ALICEISOKECCAK_E : integer := 42;
    constant ENCAPSULATE1_S   : integer := 43;
    constant ENCAPSULATE1_E   : integer := 44;
    constant ENCAPSULATE2_S   : integer := 45;
    constant ENCAPSULATE2_E   : integer := 66;
    constant ENCAPSULATE3_S   : integer := 67;
    constant ENCAPSULATE3_E   : integer := 72;
    constant DECAPSULATE1_S   : integer := 73;
    constant DECAPSULATE1_E   : integer := 88;
    constant DECAPSULATE2_S   : integer := 89;
    constant DECAPSULATE2_E   : integer := 94;
    constant DECAPBAD_S       : integer := 95;
    constant DECAPBAD_E       : integer := 96;
    constant DECAPGOOD_S      : integer := 97;
    constant DECAPGOOD_E      : integer := 98;
    constant DECAPFINAL_S     : integer := 99;
    constant DECAPFINAL_E     : integer := 104;

    signal prog_cntr : integer range 0 to PROG_LENGTH := NOP;   
    signal stall_cntr : integer range 0 to 150;

    signal prog_addr : std_logic_vector(PROG_ADDR_W-1 downto 0);
    signal prog_line : std_logic_vector(INSTRUCTION_LENGTH-1 downto 0);

    signal iso_busy_s : std_logic;
    signal busy_s,busy_r,busy_d1,busy_d2 : std_logic;
    
    signal iso_cmd_s : std_logic_vector(2 downto 0);
    signal reg_sel_s : std_logic_vector(7 downto 0);
    signal wr_input_sel_s : std_logic;
    signal wr_op_sel_s : std_logic_vector(1 downto 0);
    signal wr_word_sel_s : std_logic_vector(3 downto 0);
    signal wr_en_s : std_logic;
    signal rd_reg_s : std_logic;
    signal rd_op_sel_s : std_logic_vector(1 downto 0);
    signal rd_word_sel_s : std_logic_vector(3 downto 0);
    signal buffer_xor_s : std_logic;
    signal keccak_clear_s : std_logic;
    signal keccak_din_s : std_logic_vector(7 downto 0);
    signal keccak_din_valid_byte_s : std_logic;
    signal keccak_word_cnt_s : std_logic_vector(7 downto 0);
    signal keccak_word_valid_s : std_logic;
    signal keccak_finish_s    : std_logic;
    signal read_cnt_r : std_logic_vector(3 downto 0);
    signal read_cnt_target_s : std_logic_vector(3 downto 0);
    signal cycle_count_r : std_logic_vector(1 downto 0);
    signal cycle_count_d1 : std_logic_vector(1 downto 0);
    signal w_one_2 : std_logic_vector(1 downto 0);
    signal w_one_4 : std_logic_vector(3 downto 0);
    signal encap_decap_n : std_logic;

begin
    w_one_2 <= "01";
    w_one_4 <= "0001";
    -- Program ROM
    prog_addr <= std_logic_vector(to_unsigned(prog_cntr,PROG_ADDR_W));

    sike_input_sel : process(prog_line, busy_s, cycle_count_r, cycle_count_d1,
                             iso_cmd_i, reg_sel_i, wr_input_sel_i,
                             wr_op_sel_i, wr_word_sel_i, wr_en_i, rd_reg_i, rd_op_sel_i,
                             rd_word_sel_i, buffer_xor_i, keccak_clear_i, keccak_din_i,
                             keccak_finish_i, read_cnt_r,
                             keccak_din_valid_byte_i, keccak_word_cnt_i, keccak_word_valid_i)
    begin
        if (busy_s = '1') then
            if (prog_line(31 downto 29) = "111") then -- Load zero bytes
                keccak_word_cnt_s       <= prog_line(21 downto 14);
                reg_sel_s               <= (others => '0'); --Point to zero reg
                keccak_finish_s         <= '0';
                read_cnt_target_s     <= "0000";
            elsif (prog_line(31 downto 29) = "110") then --Wait for keccak to finish
                keccak_word_cnt_s       <= (others => '0');
                reg_sel_s               <= (others => '0'); --Point to zero reg
                keccak_finish_s         <= '1';
                read_cnt_target_s     <= "0000";
            elsif (prog_line(31 downto 29) = "101") then --Load a set of words from register or secret msg
                keccak_word_cnt_s       <= "00000111";
                reg_sel_s               <= (others => '0'); --Point to zero reg
                keccak_finish_s         <= '0';
                read_cnt_target_s     <= prog_line(17 downto 14);
            else 
                keccak_word_cnt_s       <= "00000" & prog_line(27 downto 25); 
                reg_sel_s               <= prog_line(21 downto 14);
                keccak_finish_s         <= '0';
                read_cnt_target_s     <= "0000";
            end if;
            if ((cycle_count_r = "11") and (cycle_count_d1 = "10")) then --Only pulses for command signals
                iso_cmd_s               <= prog_line(31 downto 29);
                --iso_cmd_s               <= (others => '0');
                keccak_word_valid_s     <= prog_line(28);
                wr_en_s                 <= prog_line(7); 
                keccak_din_valid_byte_s <= prog_line(24);  
                keccak_clear_s          <= prog_line(23);
                buffer_xor_s            <= prog_line(22); 
            else
                iso_cmd_s               <= (others => '0'); 
                keccak_word_valid_s     <= '0';
                wr_en_s                 <= '0';
                keccak_din_valid_byte_s <= '0';
                keccak_clear_s          <= '0';
                buffer_xor_s            <= '0'; 
            end if;
            
            wr_input_sel_s          <= '1'; 
            wr_op_sel_s             <= prog_line(13 downto 12); 
            wr_word_sel_s           <= prog_line(11 downto 8);
            rd_reg_s                <= prog_line(6);  
            rd_op_sel_s             <= prog_line(5 downto 4); 
            rd_word_sel_s           <= std_logic_vector(unsigned(prog_line(3 downto 0)) + unsigned(read_cnt_r)); 
            keccak_din_s            <= prog_line(21 downto 14);
             
        else
            iso_cmd_s               <=  iso_cmd_i;  
            reg_sel_s               <=  reg_sel_i;               
            wr_input_sel_s          <=  wr_input_sel_i;          
            wr_op_sel_s             <=  wr_op_sel_i;             
            wr_word_sel_s           <=  wr_word_sel_i;           
            wr_en_s                 <=  wr_en_i;                 
            rd_reg_s                <=  rd_reg_i;                
            rd_op_sel_s             <=  rd_op_sel_i;             
            rd_word_sel_s           <=  rd_word_sel_i;           
            buffer_xor_s            <=  buffer_xor_i;            
            keccak_clear_s          <=  keccak_clear_i;          
            keccak_din_s            <=  keccak_din_i;            
            keccak_din_valid_byte_s <=  keccak_din_valid_byte_i; 
            keccak_word_cnt_s       <=  keccak_word_cnt_i;       
            keccak_word_valid_s     <=  keccak_word_valid_i;
            keccak_finish_s         <=  keccak_finish_i;
            read_cnt_target_s       <= "0000";     
        end if;
    end process sike_input_sel;

    i_sike_rom : sike_rom
        port map (clka  => clk,
	          ena   => '1',
	          addra => prog_addr,
	          douta => prog_line);
	          
    -- SIKE Control logic
    i_sike : sike_arith_unit
        generic map (NUM_MULTS    => NUM_MULTS,
                     REG_SZ        => SZ,
                     PRIME        => PRIME,
                     ADD_NUM_ADDS => ADD_NUM_ADDS,
                     ADD_BASE_SZ  => ADD_BASE_SZ)
        port map (clk                     => clk,
	              rst                     => rst,
	              iso_cmd_i               => iso_cmd_s,              
                  reg_sel_i               => reg_sel_s,              
                  wr_input_sel_i          => wr_input_sel_s,         
                  wr_op_sel_i             => wr_op_sel_s,            
                  wr_word_sel_i           => wr_word_sel_s,          
                  wr_en_i                 => wr_en_s,                
                  rd_reg_i                => rd_reg_s,               
                  rd_op_sel_i             => rd_op_sel_s,            
                  rd_word_sel_i           => rd_word_sel_s,          
                  buffer_xor_i            => buffer_xor_s,           
                  keccak_clear_i          => keccak_clear_s,         
                  keccak_din_i            => keccak_din_s,           
                  keccak_din_valid_byte_i => keccak_din_valid_byte_s,
                  keccak_word_cnt_i       => keccak_word_cnt_s,      
		          keccak_word_valid_i     => keccak_word_valid_s,
		          keccak_finish_i         => keccak_finish_s,    
		          data_i                  => data_i,
		          data_o                  => data_o,
                  busy_o                  => iso_busy_s);
		
    -- Program subroutine flow for sike operations
    sike_flow : process (clk,rst)
    begin
        if rst = '1' then
            prog_cntr <= 0;
            cycle_count_r <= "00";
            cycle_count_d1 <= "00";
            read_cnt_r <= (others => '0');
        elsif rising_edge(clk) then
            cycle_count_d1 <= cycle_count_r;
            if iso_busy_s = '1' then --Stalled until command is done
                prog_cntr <= prog_cntr;
                cycle_count_r <= cycle_count_r;
            elsif ((busy_s = '1') and (cycle_count_r /= "11")) then --When not NOP
                cycle_count_r <= std_logic_vector(unsigned(cycle_count_r) + unsigned(w_one_2));
            elsif (read_cnt_r /= read_cnt_target_s) then
                read_cnt_r <= std_logic_vector(unsigned(read_cnt_r) + unsigned(w_one_4));
                cycle_count_r <= "00";
            else
                read_cnt_r <= "0000";
                cycle_count_r <= "00";
                case prog_cntr is
		    -- Waiting for new valid command    
                    when NOP =>
                        case sike_cmd_i is
                            when "001"  => prog_cntr <= KEYGEN_S;
                                           encap_decap_n <= '0';
                            when "010"  => prog_cntr <= ENCAPSULATE1_S;
                                           encap_decap_n <= '1';
                            when "011"  => prog_cntr <= DECAPSULATE1_S;
                                           encap_decap_n <= '0';                            
                            when "100"  => prog_cntr <= DECAPBAD_S;    -- cipher texts do not match
                                           encap_decap_n <= '0';                                
                            when "101"  => prog_cntr <= DECAPGOOD_S;   -- (cipher texts match)
                                           encap_decap_n <= '0';     
                            when others => prog_cntr <= NOP;
                                           encap_decap_n <= '0';          
                        end case;
                    when KEYGEN_E         => prog_cntr <= NOP;
                    when BOBISOKECCAK_E   => 
                        if (encap_decap_n = '1') then
                            prog_cntr <= ENCAPSULATE2_S;
                        else
                            prog_cntr <= DECAPSULATE2_S;
                        end if;
                    when ALICEISOKECCAK_E => 
                        if (encap_decap_n = '1') then
                            prog_cntr <= ENCAPSULATE3_S;
                        else
                            prog_cntr <= DECAPFINAL_S;
                        end if;
                    when ENCAPSULATE1_E   => prog_cntr <= BOBISOKECCAK_S;
                    when ENCAPSULATE2_E   => prog_cntr <= ALICEISOKECCAK_S;
                    when ENCAPSULATE3_E   => prog_cntr <= NOP;
                    when DECAPSULATE1_E   => prog_cntr <= BOBISOKECCAK_S;
                    when DECAPSULATE2_E   => prog_cntr <= NOP;
                    when DECAPBAD_E       => prog_cntr <= ALICEISOKECCAK_S;
                    when DECAPGOOD_E      => prog_cntr <= ALICEISOKECCAK_S;
                    when DECAPFINAL_E     => prog_cntr <= NOP;
                    when others           => prog_cntr <= prog_cntr + 1;
                end case;
            end if;
        end if;
    end process sike_flow;

    busy_s <= '0' when prog_cntr = NOP else '1';
    busy_o <= busy_s or busy_r or busy_d1 or busy_d2 or iso_busy_s;
    
    program_pipeline : process (clk,rst)
    begin
        if rst = '1' then
            busy_r  <= '0';
            busy_d1 <= '0';
            busy_d2 <= '0';
        elsif rising_edge(clk) then
            busy_r  <= busy_s;
            busy_d1 <= busy_r;
            busy_d2 <= busy_d1;
        end if;
    end process program_pipeline;

end structural;
