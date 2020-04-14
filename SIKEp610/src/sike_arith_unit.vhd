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

entity sike_arith_unit is
    generic (NUM_MULTS : integer := 4;
             REG_SZ   : integer := 504;
             PRIME : std_logic_vector(615 downto 0) := x"027bf6a768819010c251e7d88cb255b2fa10c4252a9ae7bf45048ff9abb1784de8aa5ab02e6e01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
             ADD_NUM_ADDS : integer := 4;
             ADD_BASE_SZ  : integer := 127);
    Port ( clk                     : in  std_logic;
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
end sike_arith_unit; 

architecture structural of sike_arith_unit is

    constant MSG_SZ : integer := 192;
    constant SS_SZ  : integer := 192;

    component fau is
        generic (NUM_MULTS : integer := 2;
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
               opa_i : in STD_LOGIC_VECTOR (REG_SZ-1 downto 0);
               opb_i : in STD_LOGIC_VECTOR (REG_SZ-1 downto 0);
               mult_res_read_i : in STD_LOGIC;
               add_res_o : out STD_LOGIC_VECTOR (REG_SZ-1 downto 0);
               mult_res_o : out STD_LOGIC_VECTOR (REG_SZ-1 downto 0));
    end component;

    component reg_file IS
      PORT ( clka  : IN  std_logic;
             ena   : IN  std_logic;
             wea   : IN  std_logic_vector(0 DOWNTO 0);
             addra : IN  std_logic_vector(7 DOWNTO 0);
             dina  : IN  std_logic_vector(REG_SZ-1 DOWNTO 0);
             douta : OUT std_logic_vector(REG_SZ-1 DOWNTO 0);
             clkb  : IN  std_logic;
             enb   : IN  std_logic;
             web   : IN  std_logic_vector(0 DOWNTO 0);
             addrb : IN  std_logic_vector(7 DOWNTO 0);
             dinb  : IN  std_logic_vector(REG_SZ-1 DOWNTO 0);
             doutb : OUT std_logic_vector(REG_SZ-1 DOWNTO 0)
             );
    end component reg_file;
    
    component iso_ctrl is
        Port ( clk         : in  std_logic;
               rst         : in  std_logic;
               iso_cmd_i   : in  std_logic_vector (2 downto 0);
               digit_i     : in  std_logic;
	           instr_o     : out std_logic_vector(24 downto 0);
               req_digit_o : out std_logic;
               alice_o     : out std_logic;
               busy_o      : out std_logic
               );
    end component iso_ctrl;  

    component keccak_1088 is
  
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        clear_state   : in  std_logic;
        din           : in  std_logic_vector(7 downto 0);
        din_valid     : in  std_logic;
        buffer_full   : out std_logic;
        ready         : out std_logic;
        dout          : out std_logic_vector(511 downto 0));
    end component keccak_1088;

    -- Memory interface
    signal reg_dinb_r, reg_dout_r  : std_logic_vector(639 downto 0);
    signal dinb_mux_s : std_logic_vector(REG_SZ-1 downto 0);
    signal reg_addr_r, addrb_mux_s : std_logic_vector(7 downto 0);
    signal reg_web_r,  web_mux_s   : std_logic;

    signal di_mux : std_logic_vector(63 downto 0);
    signal do : std_logic_vector(63 downto 0);
    -- FAU signals
    signal opa_s, opb_s : std_logic_vector(REG_SZ-1 downto 0);
    signal add_res_s, mult_res_s : std_logic_vector(REG_SZ-1 downto 0);
    
    signal iso_instr_s : std_logic_vector(24 downto 0);

    signal alice_s : std_logic;
    signal Alicekey : std_logic_vector(304 downto 0);
    signal Bobkey   : std_logic_vector(304 downto 0);
    signal keys_r : std_logic_vector(639 downto 0);
   
    signal iso_busy_s : std_logic;
    
    signal digit_in : std_logic;
    signal req_digit : std_logic;
 
    signal alice_secret_msg : std_logic_vector(MSG_SZ-1 downto 0);
    signal bob_secret_msg : std_logic_vector(MSG_SZ-1 downto 0);
    signal bob_cipher_msg : std_logic_vector(MSG_SZ-1 downto 0);

    signal msg_buffer_r    : std_logic_vector(3*MSG_SZ-1 downto 0);
 
    signal keccak_working_s : std_logic;
    signal keccak_working_r : std_logic;
    signal keccak_cnt_r : std_logic_vector(7 downto 0);
    signal keccak_buffer_in_r : std_logic_vector(63 downto 0);
    signal keccak_din_s : std_logic_vector(7 downto 0);
    signal keccak_din_valid_s : std_logic;
    signal keccak_buffer_full_s : std_logic;
    signal keccak_ready_s : std_logic;
    signal keccak_buffer_out_s : std_logic_vector(511 downto 0);
    signal keccak_busy_s : std_logic;
    signal w_one_8      : std_logic_vector(7 downto 0);
    
    signal shared_secret : std_logic_vector(SS_SZ-1 downto 0);

begin

    shared_secret <= keccak_buffer_out_s(SS_SZ-1 downto 0);
    w_one_8 <= "00000001";
    alice_secret_msg <= msg_buffer_r(3*MSG_SZ-1 downto 2*MSG_SZ);
    bob_cipher_msg   <= msg_buffer_r(2*MSG_SZ-1 downto MSG_SZ);
    bob_secret_msg   <= msg_buffer_r(MSG_SZ-1 downto 0);
    --Zeroize unused key bits
    Alicekey <= keys_r(624 downto 320);
    Bobkey <= keys_r(304 downto 0);
    keys_r(639 downto 625) <= (others => '0');
    keys_r(319 downto 305)   <= (others => '0');
    reg_dout_r(639 downto 616) <= (others => '0');
    di_mux <= data_i when (wr_input_sel_i='0') else
              do;
    keccak_working_s <= '1' when ((keccak_word_valid_i = '1') or (keccak_cnt_r /= "00000000") or (keccak_cnt_r = "00000000" and (keccak_buffer_full_s = '1') and (keccak_word_cnt_i /= "00000000"))) else
                        '0';
    keccak_din_s <= keccak_din_i when keccak_din_valid_byte_i = '1' else
                    keccak_buffer_in_r(7 downto 0);
    keccak_din_valid_s <= (keccak_working_r or keccak_din_valid_byte_i) and (not keccak_buffer_full_s);
    -- Isogeny Control logic
    i_iso_ctrl : iso_ctrl
        port map (clk         => clk,
	              rst         => rst,
		          iso_cmd_i   => iso_cmd_i,
		          digit_i     => digit_in,
		          instr_o     => iso_instr_s,
                  req_digit_o => req_digit,
		          alice_o     => alice_s,
		          busy_o      => iso_busy_s);
		
    -- Register file memory
    i_reg_file : reg_file
        port map (clka   => clk,
                  ena    => '1',
                  wea(0) => iso_instr_s(17),
                  addra  => iso_instr_s(15 downto 8),
                  dina   => add_res_s,
                  douta  => opa_s,
                  clkb   => clk,
                  enb    => '1',
                  web(0) => web_mux_s,
                  addrb  => addrb_mux_s,
                  dinb   => dinb_mux_s,
                  doutb  => opb_s);
    -- Field aritmetic unit
    i_fau : fau
        generic map (NUM_MULTS => NUM_MULTS,
                     SZ        => REG_SZ,
                     PRIME     => PRIME,
                     ADD_NUM_ADDS => ADD_NUM_ADDS,
                     ADD_BASE_SZ  => ADD_BASE_SZ)
        port map ( clk             => clk,
                   rst             => rst,
                   sub_i           => iso_instr_s(18),
                   red_i           => iso_instr_s(19),
                   mult_start_i    => iso_instr_s(20),
                   mult_reset_even_odd_i => iso_instr_s(21),
                   opa_i           => opa_s,
                   opb_i           => opb_s,
                   mult_res_read_i => web_mux_s,
                   add_res_o       => add_res_s,
                   mult_res_o      => mult_res_s);

    --Keccak block
    i_keccak : keccak_1088
        port map(clk         => clk, 
                 rst         => rst, 
                 clear_state => keccak_clear_i, 
                 din         => keccak_din_s, 
                 din_valid   => keccak_din_valid_s, 
                 buffer_full => keccak_buffer_full_s, 
                 ready       => keccak_ready_s, 
                 dout        => keccak_buffer_out_s); 


    -- Memory mapped register interface
    i_reg_interface : process (clk,rst)
    begin
        -- Asynchronous active-high reset
        if rst = '1' then
        
            reg_dinb_r               <= (others => '0');
            reg_addr_r               <= (others => '0');
            reg_web_r                <= '0';
            keys_r(624 downto 620)   <= (others => '0');
            keys_r(304 downto 0)     <= (others => '0');
            digit_in                 <= '0';
            msg_buffer_r             <= (others => '0');
            keccak_cnt_r             <= (others => '0');
            keccak_buffer_in_r       <= (others => '0');
            keccak_working_r         <= '0';
            reg_dout_r(610 downto 0) <= (others => '0');
        
        elsif rising_edge(clk) then

            -- Write new register
            if (wr_en_i = '1') and (wr_op_sel_i = "00") then
                case wr_word_sel_i is
                    when "0000" => reg_dinb_r(63 downto 0)    <= di_mux;
                    when "0001" => reg_dinb_r(127 downto 64)  <= di_mux;
                    when "0010" => reg_dinb_r(191 downto 128) <= di_mux;
                    when "0011" => reg_dinb_r(255 downto 192) <= di_mux;
                    when "0100" => reg_dinb_r(319 downto 256) <= di_mux;
                    when "0101" => reg_dinb_r(383 downto 320) <= di_mux;
                    when "0110" => reg_dinb_r(447 downto 384) <= di_mux;
                    when "0111" => reg_dinb_r(511 downto 448) <= di_mux;
                    when "1000" => reg_dinb_r(575 downto 512) <= di_mux;
                    when "1001" => reg_dinb_r(610 downto 576) <= di_mux(34 downto 0);
                    when others =>
                end case;
            end if;

            -- Write new key
            if (wr_en_i = '1') and (wr_op_sel_i = "01") then
                case wr_word_sel_i is
                    when "0000" => keys_r(63 downto 0)    <= di_mux;
                    when "0001" => keys_r(127 downto 64)  <= di_mux;
                    when "0010" => keys_r(191 downto 128) <= di_mux;
                    when "0011" => keys_r(255 downto 192) <= di_mux; 
                    when "0100" => keys_r(304 downto 256) <= di_mux(48 downto 0);
                    when "0101" => keys_r(383 downto 320) <= di_mux;
                    when "0110" => keys_r(447 downto 384) <= di_mux;
                    when "0111" => keys_r(511 downto 448) <= di_mux;
                    when "1000" => keys_r(575 downto 512) <= di_mux;
                    when "1001" => keys_r(624 downto 576) <= di_mux(48 downto 0);
                    when others =>
                end case;
            elsif req_digit = '1' then
                --Shift digit
                if alice_s = '1' then
                    keys_r(623 downto 320) <= keys_r(624 downto 321);
                    keys_r(624) <= keys_r(320);
                else
                    keys_r(303 downto 0) <= keys_r(304 downto 1);
                    keys_r(304) <= keys_r(0);
                end if;
            end if;
            -- Message buffer logic
            if (wr_en_i = '1') and (wr_op_sel_i = "10") then
                case wr_word_sel_i is
                    when "0000" => msg_buffer_r(63 downto 0)    <= di_mux;
                    when "0001" => msg_buffer_r(127 downto 64)  <= di_mux;
                    when "0010" => msg_buffer_r(191 downto 128) <= di_mux;
                    when "0011" => msg_buffer_r(255 downto 192) <= di_mux;
                    when "0100" => msg_buffer_r(319 downto 256) <= di_mux;
                    when "0101" => msg_buffer_r(383 downto 320) <= di_mux;
                    when "0110" => msg_buffer_r(447 downto 384) <= di_mux;
                    when "0111" => msg_buffer_r(511 downto 448) <= di_mux;
                    when "1000" => msg_buffer_r(575 downto 512) <= di_mux;
                    when others => 
                end case;
            elsif buffer_xor_i = '1' then
                msg_buffer_r(2*MSG_SZ-1 downto MSG_SZ) <= msg_buffer_r(MSG_SZ-1 downto 0) xor keccak_buffer_out_s(MSG_SZ-1 downto 0);
            end if;
                -- Keccak word in
            keccak_working_r <= keccak_working_s;
            if (keccak_word_valid_i = '1') then
                keccak_cnt_r <= keccak_word_cnt_i;
            elsif (keccak_working_r = '1') and (keccak_cnt_r /= "00000000") and (keccak_buffer_full_s = '0') then
                keccak_cnt_r <= std_logic_vector(unsigned(keccak_cnt_r) - unsigned(w_one_8));
            end if;

            if (wr_en_i = '1') and (wr_op_sel_i = "11") then
                keccak_buffer_in_r <= di_mux;
            elsif ((keccak_working_r = '1') and (keccak_buffer_full_s = '0')) then
                keccak_buffer_in_r(63 downto 56) <= keccak_buffer_in_r(7 downto 0);
                keccak_buffer_in_r(55 downto 0)  <= keccak_buffer_in_r(63 downto 8);
            end if;

            --Push key bit to iso control
            if alice_s = '1' then
                digit_in <= keys_r(320);
            else
                digit_in <= keys_r(0);
            end if;
                        
            reg_addr_r <= reg_sel_i;
            
            if (wr_op_sel_i = "00") then
                reg_web_r <= wr_en_i and wr_word_sel_i(0) and (not wr_word_sel_i(1)) and (not wr_word_sel_i(2)) and wr_word_sel_i(3); -- Write after the highest 64-bit word has been written
            end if;
            -- Read multiplexer    
            if (rd_reg_i = '1') then
                reg_dout_r(REG_SZ-1 downto 0) <= opb_s;
            end if;
        end if;
    end process;
    -- Memory mapped register interface
    i_read_process : process (rd_op_sel_i, rd_word_sel_i, reg_dout_r,keys_r,msg_buffer_r,keccak_buffer_out_s)
    begin
        case rd_op_sel_i is
            when "00" =>
                case rd_word_sel_i is
                    when "0000" => do               <= reg_dout_r(63 downto 0) ;
                    when "0001" => do               <= reg_dout_r(127 downto 64);
                    when "0010" => do               <= reg_dout_r(191 downto 128);
                    when "0011" => do               <= reg_dout_r(255 downto 192);
                    when "0100" => do               <= reg_dout_r(319 downto 256);
                    when "0101" => do               <= reg_dout_r(383 downto 320);
                    when "0110" => do               <= reg_dout_r(447 downto 384);
                    when "0111" => do               <= reg_dout_r(511 downto 448);
                    when "1000" => do               <= reg_dout_r(575 downto 512);
                    when "1001" => do               <= reg_dout_r(639 downto 576);
                    when others => do               <= (others => '0');
                end case;            
            when "01" =>
                case rd_word_sel_i is
                    when "0000" => do               <= keys_r(63 downto 0) ;
                    when "0001" => do               <= keys_r(127 downto 64);
                    when "0010" => do               <= keys_r(191 downto 128);
                    when "0011" => do               <= keys_r(255 downto 192);
                    when "0100" => do               <= keys_r(319 downto 256);
                    when "0101" => do               <= keys_r(383 downto 320);
                    when "0110" => do               <= keys_r(447 downto 384);
                    when "0111" => do               <= keys_r(511 downto 448);
                    when "1000" => do               <= keys_r(575 downto 512);
                    when "1001" => do               <= keys_r(639 downto 576);
                    when others => do               <= (others => '0');
                end case;            
            when "10" =>
                case rd_word_sel_i is
                    when "0000" => do               <= msg_buffer_r(63 downto 0) ;
                    when "0001" => do               <= msg_buffer_r(127 downto 64);
                    when "0010" => do               <= msg_buffer_r(191 downto 128);
                    when "0011" => do               <= msg_buffer_r(255 downto 192);
                    when "0100" => do               <= msg_buffer_r(319 downto 256);
                    when "0101" => do               <= msg_buffer_r(383 downto 320);
                    when "0110" => do               <= msg_buffer_r(447 downto 384);
                    when "0111" => do               <= msg_buffer_r(511 downto 448);
                    when "1000" => do               <= msg_buffer_r(575 downto 512);
                    when others => do               <= (others => '0');
                end case;            
            when "11" =>
                case rd_word_sel_i is
                    when "0000" => do               <= keccak_buffer_out_s(63 downto 0) ;
                    when "0001" => do               <= keccak_buffer_out_s(127 downto 64);
                    when "0010" => do               <= keccak_buffer_out_s(191 downto 128);
                    when "0011" => do               <= keccak_buffer_out_s(255 downto 192);
                    when "0100" => do               <= keccak_buffer_out_s(319 downto 256);
                    when "0101" => do               <= keccak_buffer_out_s(383 downto 320);
                    when "0110" => do               <= keccak_buffer_out_s(447 downto 384);
                    when "0111" => do               <= keccak_buffer_out_s(511 downto 448);
                    when others => do               <= (others => '0');
                end case;            
            when others =>
        end case;   
    end process;         
            
    addrb_mux_s <= iso_instr_s(7 downto 0) when iso_busy_s = '1' else reg_addr_r;
    web_mux_s   <= iso_instr_s(16)         when iso_busy_s = '1' else reg_web_r;
    dinb_mux_s  <= mult_res_s  when iso_busy_s = '1' else reg_dinb_r(REG_SZ-1 downto 0);
    keccak_busy_s <= keccak_buffer_full_s or keccak_working_s or (keccak_finish_i and (not keccak_ready_s));
    busy_o <= iso_busy_s or keccak_busy_s;
    data_o <= do;

end structural;