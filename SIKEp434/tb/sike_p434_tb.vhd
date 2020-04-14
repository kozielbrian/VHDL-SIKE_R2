--********************************************************************************************
--* FPGASIKE: a speed optimized hardware implementation of the 
--*           Supersingular Isogeny Key Encapsulation scheme
--*
--*    Copyright (c) Brian Koziel, Reza Azarderakhsh, and Rami El Khatib
--*
--********************************************************************************************* 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity sike_p434_tb is
--  Port ( );
end sike_p434_tb;

architecture Behavioral of sike_p434_tb is

    constant PERIOD : time := 5000 ps;
    
    constant TEST_WITHOUT_CFK : boolean := true;
    constant TEST_WITH_CFK : boolean := false;

component sike_p434 is
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
end component sike_p434; 

    constant REG_SZ : integer := 55;
    constant REG_LOOPS : integer := 7;
    constant MSG_SZ : integer := 16;
    constant MSG_LOOPS : integer := 2;
    constant PK_SZ : integer := 6*REG_SZ;
    constant KEY_REG_SZ : integer := 32;
    constant KEY_SZ : integer := 28;
    constant KEY_LOOPS : integer := 4;
    constant SK_SZ : integer := MSG_SZ+PK_SZ+KEY_SZ;
    constant CT_SZ : integer := MSG_SZ+PK_SZ;
    constant SS_SZ : integer := 16;
    constant SS_LOOPS : integer := 2;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '0';
    signal sike_cmd_i : std_logic_vector(2 downto 0) := (others => '0');
    signal iso_cmd_i : std_logic_vector(2 downto 0) := (others => '0');
    signal reg_sel_i : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_input_sel_i : std_logic := '0';
    signal wr_op_sel_i : std_logic_vector(1 downto 0) := (others => '0');
    signal wr_word_sel_i : std_logic_vector(3 downto 0) := (others => '0');
    signal wr_en_i : std_logic := '0';
    signal rd_reg_i : std_logic := '0';
    signal rd_op_sel_i : std_logic_vector(1 downto 0) := (others => '0');
    signal rd_word_sel_i : std_logic_vector(3 downto 0) := (others => '0');
    signal buffer_xor_i : std_logic := '0';
    signal keccak_clear_i : std_logic := '0';
    signal keccak_din_i : std_logic_vector(7 downto 0) := (others => '0');
    signal keccak_din_valid_byte_i : std_logic := '0';
    signal keccak_word_cnt_i : std_logic_vector(7 downto 0) := (others => '0');
    signal keccak_word_valid_i : std_logic := '0';
    signal keccak_finish_i : std_logic := '0';
    signal data_i : std_logic_vector(63 downto 0) := (others => '0');
    signal data_o : std_logic_vector(63 downto 0);
    signal busy_o : std_logic;
    
    signal list_mem : std_logic := '0';
    signal list_mem_done : std_logic := '0';
    
  
    
    type alice_key_array is array(0 to 1) of std_logic_vector(8*KEY_REG_SZ-1 downto 0); 
    constant alice_keys_hex : alice_key_array :=( --Only for Debug purposes
    x"0000000000d47855690676973ea10a9e556f7f67143f235ed3e4db38e16f797d",
    x"0000000000cb9fe18ad2885a9a165f30354064ee454b5bf318988a2e85dc00a0"
    );
    
    type bob_key_array is array(0 to 1) of std_logic_vector(8*KEY_REG_SZ-1 downto 0);
    constant bob_keys_hex : bob_key_array :=(
    x"00000000015eeffe15b3f4ee237bac5b4d601939d5ac2c7c5eb54c6514222891",
    x"00000000017098eb36352b1deabfad94ec26d2d80359378f44323bb455fe7be3"
    );
    
    
    type mont_constants_array is array(0 to 6) of std_logic_vector(8*(REG_SZ+1)-1 downto 0);
    constant mont_array_hex : mont_constants_array :=(
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --0
    x"000061e2495fc4fe9da492cd32ad58cfea1e1989a3d0ddb10456505124000000000000000000000000000000000000000000000000000074", --mont 1
    x"0000c3c492bf89fd3b49259a655ab19fd43c331347a1bb6208aca0a2480000000000000000000000000000000000000000000000000000e8", --mont 2
    x"000155f8c82b22fddbfba73a432c76f2dac2fafbaf29203c3de1ce5f652b1d6c7c0bab27973f8311688dacec7367768798c228e55b65dcd6", --R^2
    x"000018789257f13fa76924b34cab5633fa87866268f4376c411594144900000000000000000000000000000000000000000000000000001d", --4^-1
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", --1
    x"0000172e91272ab344df10f8ae4af48900ee3cc1a58c83821c446b6bf50000000000000000000000000000000000000000000000000002b9" --mont 6
    );
    
    type params_array is array(0 to 30) of std_logic_vector(8*(REG_SZ+1)-1 downto 0);
    constant params_hex : params_array :=(
    x"000027381751ecf0e4ee4defae8f9275f3e2e66b7d64c50c5689443a8710583debbedd5ccfbba0942d90fe01606c035116a50459621e1361", --R0
    x"000031de228c1a87369f4b56d2ab00ca3ee9896e777218d06eec35bea10a3bf4d9c09797d4d495104513e9a493548b905e5c7474fdec65ff", --R1
    x"00004fefc8ef35ae2cd6def04b77aa8323f6a17739631b6ebfdd447364c8959f352e492793a9ba74a4ae0b71d637d8f2005075e8e99662ae", --R2
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006", --A.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A24.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A24.b Unused
    x"0001ad1c1cae7840edda6d8a924520f60e573d3b9dfac6d189941cb22326d284a8816cc4249410fe80d68047d823c97d705246f869e3ea50", --PAx.a
    x"00003ccfc5e1f050030363e6920a0f7a4c6c71e63de63a0e6475af621995705f7c84500cb2bb61e950e19eab8661d25c4a50ed279646cb48", --PAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PAy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PAy.b Unused
    x"000025de37157f50d75d320dd0682ab4a67e471586fbc2d31aa32e6957fa2b2614c4cd40a1e27283eaaf4272ae517847197432e2d61c85f5", --QAx.a
    x"0000c7461738340efcf09ce388f666eb38f7f3afd42dc0b664d9f461f31aa2edc6b4ab71bd42f4d7c058e13f64b237ef7ddd2abc0deb0c6c", --QAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QAy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QAy.b Unused
    x"000196ca2ed06a657e90a73543f3902c208f410895b49cf84cd89be9ed6e4ee7e8df90b05f3fdb8bdfe489d1b3558e987013f9806036c5ac", --QPAx.a
    x"0000f37ab34ba0cead94f43cdc50de06ad19c67ce4928346e829cb92580da84d7c36506a2516696bbe3aeb523ad7172a6d239513c5fd2516", --QPAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPAy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPAy.b Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBx.a
    x"00008664865ea7d816f03b31e223c26d406a2c6cd0c3d667466056aae85895ec37368bfc009dfafcb3d97e639f65e9e45f46573b0637b7a9", --PBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBy.b Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBx.a
    x"00012e84d7652558e694bf84c1fbdaaf99b83b4266c32ec65b10457bcaf94c63eb063681e8b1e7398c0b241c19b9665fdb9e1406da3d3846", --QBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBy.b Unused
    x"000147073290d78dd0cc8420b1188187d1a49dbfa24f26aad46b2d9bb547dbb6f63a760ecb0c2b20be52fb77bd2776c3d14bcbc404736ae4", --QPBx.a
    x"0001cd28597256d4ffe7e002e87870752a8f8a64a1cc78b5a2122074783f51b4fde90e89c48ed91a8f4a0ccbacbfa7f51a89ce518a52b76c", --QPBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPBy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"); --QPBy.b Unused

    type kat1_results_array is array(0 to 35) of std_logic_vector(8*(REG_SZ+1)-1 downto 0); --For KAT0 only
    constant kat1_results_hex : kat1_results_array :=(
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA.b
    x"0001aa9fc023438ba682c2aeca02333dd7175340cd7370e840f5d67b28633e25555a67e48a653d91753583809305c6b84546f62aed638178", --j(EAB).a
    x"00020784b7956b866bae393e37f0ba9134fa5291815889ad2fdc0a988c3cce59835cf41a78ac2be7eb981df2cdcebfc7a4f4a82fec2eedda", --j(EAB).b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA24.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA24.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB.b
    x"0001aa9fc023438ba682c2aeca02333dd7175340cd7370e840f5d67b28633e25555a67e48a653d91753583809305c6b84546f62aed638178", --j(EBA).a
    x"00020784b7956b866bae393e37f0ba9134fa5291815889ad2fdc0a988c3cce59835cf41a78ac2be7eb981df2cdcebfc7a4f4a82fec2eedda", --j(EBA).b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB24.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB24.b
    x"0001f697270e2229348b4c3c86b1fee9daf26b83f85bcdfeb608119ea7ced82ec6e544fae384e7f3a0962a56149071c2c6f9bec32be0b9e6", --phiPBx.a
    x"00012c3b38a32ac95c43ab12cdaabeeed70b6e88f9397fe4e48a03edde26a93cf824fcb79a7f9abc3514dd5bca832227cde096bd6db2de0f", --phiPBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPBy.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPBy.b
    x"0001f69595c63ce3bdba024948f75bec8dcb9420324ebe9ae1d7f538be1c263c5ef2cc954829100efa5b89da932c4538a7998498110ed0d4", --phiQBx.a
    x"0000207e8527a0155682342771e0e2eea3e9539abb5d32317fe940326df724e833510b48e5f667d12107a69c258d505573f1d4fdba8e4bfb", --phiQBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQBy.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQBy.b
    x"0000a110f054d88d3a01e8ca869867b1b993493d79dfc770cd58d4a18875cad10115b275e8999e840ebc0d82d2871ee6d4c0ef195836bf82", --phiQPBx.a
    x"000196395606a346ab82798d641f3045075b1a6e273c5743b6212d4d374809489d5949b5a3ee6f4e291975d5656fbca2dec19896baaa203b", --phiQPBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPBy.a not used
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPBy.b not used
    x"0001634b649ca4257b4c0db52b941e7c409151b91b45121c46381e4616ccc76edce0be7651c427a8b3e00808cf533a08c0cd4aa4d2603009", --phiPAx.a
    x"0000a7590be2c359bf7d0fb1ba7a0bd2dea2d19a328fb4796f5f2f4b2515624a6188593f86e2e6602a142c8b56dc80c10cb444dbaad78444", --phiPAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPAy.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPAy.b
    x"0000c5647a9d67cd5b6a7fe8801f5a596f1e0a63d25383c76701ff941f3669e70408041a93157523db008054264b3d11a5b211537dd205c2", --phiQAx.a
    x"00007f64ab6c5358a463345db0ca2ae7691571fb07509fbf9b5fe1a67b3f95f76a7824a7a47b65d03e69eaada7f4fb89e638386503c4e659", --phiQAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQAy.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQAy.b
    x"0000f62dab19540366978566cc92db586fe5d04ff23ac3d3ba4a4c10e2f652a2cfec533690f0394630f3b747ff73def865dfe66b4d71b765", --phiQPAx.a
    x"0001ab803cf1e561cbea57c33191d3894f65e1eb0ccbec52de3afc5b17520b0009c7cc80fe2dfef453d417708b38f667eaa1efadd491616f", --phiQPAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPAy.a not used
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"); --phiQPAy.b not used)
    
    type secret_msg_alice_array is array(0 to 1) of std_logic_vector(8*MSG_SZ-1 downto 0);
    constant secret_msg_alice_array_hex : secret_msg_alice_array :=(
    x"dd1a6bdbe4106d0caa9476b0a035997c",
    x"f33731730bfca67b1c8c1d2a49930bd6");
 
    type secret_msg_bob_array is array(0 to 1) of std_logic_vector(8*MSG_SZ-1 downto 0);
    constant secret_msg_bob_array_hex : secret_msg_bob_array :=(
    x"56c38e4258d6961b3a763e3cd49792cf",
    x"110af0bf950bb375683ceded98ef092e");   
 
    signal public_key : std_logic_vector(PK_SZ*8-1 downto 0) := (others => '0');
    signal secret_key : std_logic_vector(SK_SZ*8-1 downto 0) := (others => '0');
    signal cipher_text : std_logic_vector(CT_SZ*8-1 downto 0) := (others => '0');
    signal shared_secretA : std_logic_vector(SS_SZ*8-1 downto 0) := (others => '0');
    signal shared_secretB : std_logic_vector(SS_SZ*8-1 downto 0) := (others => '0');  
    
    type public_key_array is array(0 to 1) of std_logic_vector(PK_SZ*8-1 downto 0);
    constant public_key_kat : public_key_array :=(
    x"00f62dab19540366978566cc92db586fe5d04ff23ac3d3ba4a4c10e2f652a2cfec533690f0394630f3b747ff73def865dfe66b4d71b76501ab803cf1e561cbea57c33191d3894f65e1eb0ccbec52de3afc5b17520b0009c7cc80fe2dfef453d417708b38f667eaa1efadd491616f00c5647a9d67cd5b6a7fe8801f5a596f1e0a63d25383c76701ff941f3669e70408041a93157523db008054264b3d11a5b211537dd205c2007f64ab6c5358a463345db0ca2ae7691571fb07509fbf9b5fe1a67b3f95f76a7824a7a47b65d03e69eaada7f4fb89e638386503c4e65901634b649ca4257b4c0db52b941e7c409151b91b45121c46381e4616ccc76edce0be7651c427a8b3e00808cf533a08c0cd4aa4d260300900a7590be2c359bf7d0fb1ba7a0bd2dea2d19a328fb4796f5f2f4b2515624a6188593f86e2e6602a142c8b56dc80c10cb444dbaad78444",
    x"021b8f50633d7527cdde64b654cf2aae69ac239a7aaa114ccaa8c3befb871e677e0b24adaf832103819174be7f2d031aa26536cedcb570004c41cc9fddd0e7f1527204e8dc09f5136753fabdf6fff4d56a1f8d49fd9082dda65197273579738a81a728fbdc4c7a3d0d3e22c495d2016d6c2e6a7b26619060b2b743fbd9d6c23848c559e9a5c4af5f2758bdbb3a144d37c0c91ab5621ae5b502d02a610674b3b01247cdd19d00c150c25acc622bde44a2edd6bbf6abde1923da29781895335f6bf5ad78f29d71b1a324cb643fd49deef5f3b8f0a9a512da96d7d1aeb400b4b641b91942a1ba440f9367852a9e7aa8054d125b02b6c053c22ac3e2e916f8f2a0a4845d7f2b3bb94e73b2178c8b5010bfd132afb801defef50db44b1cf5c0705687bcde731b88855829bbe9b3faf5c1f08c80c38c3b270ea14b93838a6a86358168ebf9fda3aa97443ef7c9");    
    
    type secret_key_array is array(0 to 1) of std_logic_vector(SK_SZ*8-1 downto 0);
    constant secret_key_kat : secret_key_array :=(
    x"00f62dab19540366978566cc92db586fe5d04ff23ac3d3ba4a4c10e2f652a2cfec533690f0394630f3b747ff73def865dfe66b4d71b76501ab803cf1e561cbea57c33191d3894f65e1eb0ccbec52de3afc5b17520b0009c7cc80fe2dfef453d417708b38f667eaa1efadd491616f00c5647a9d67cd5b6a7fe8801f5a596f1e0a63d25383c76701ff941f3669e70408041a93157523db008054264b3d11a5b211537dd205c2007f64ab6c5358a463345db0ca2ae7691571fb07509fbf9b5fe1a67b3f95f76a7824a7a47b65d03e69eaada7f4fb89e638386503c4e65901634b649ca4257b4c0db52b941e7c409151b91b45121c46381e4616ccc76edce0be7651c427a8b3e00808cf533a08c0cd4aa4d260300900a7590be2c359bf7d0fb1ba7a0bd2dea2d19a328fb4796f5f2f4b2515624a6188593f86e2e6602a142c8b56dc80c10cb444dbaad78444015eeffe15b3f4ee237bac5b4d601939d5ac2c7c5eb54c6514222891dd1a6bdbe4106d0caa9476b0a035997c",
    x"021b8f50633d7527cdde64b654cf2aae69ac239a7aaa114ccaa8c3befb871e677e0b24adaf832103819174be7f2d031aa26536cedcb570004c41cc9fddd0e7f1527204e8dc09f5136753fabdf6fff4d56a1f8d49fd9082dda65197273579738a81a728fbdc4c7a3d0d3e22c495d2016d6c2e6a7b26619060b2b743fbd9d6c23848c559e9a5c4af5f2758bdbb3a144d37c0c91ab5621ae5b502d02a610674b3b01247cdd19d00c150c25acc622bde44a2edd6bbf6abde1923da29781895335f6bf5ad78f29d71b1a324cb643fd49deef5f3b8f0a9a512da96d7d1aeb400b4b641b91942a1ba440f9367852a9e7aa8054d125b02b6c053c22ac3e2e916f8f2a0a4845d7f2b3bb94e73b2178c8b5010bfd132afb801defef50db44b1cf5c0705687bcde731b88855829bbe9b3faf5c1f08c80c38c3b270ea14b93838a6a86358168ebf9fda3aa97443ef7c9017098eb36352b1deabfad94ec26d2d80359378f44323bb455fe7be3f33731730bfca67b1c8c1d2a49930bd6");

    type cipher_text_array is array(0 to 1) of std_logic_vector(CT_SZ*8-1 downto 0);
    constant cipher_text_kat : cipher_text_array :=(
    x"d3986bd36e788599ea0adc42a63f93c900a110f054d88d3a01e8ca869867b1b993493d79dfc770cd58d4a18875cad10115b275e8999e840ebc0d82d2871ee6d4c0ef195836bf820196395606a346ab82798d641f3045075b1a6e273c5743b6212d4d374809489d5949b5a3ee6f4e291975d5656fbca2dec19896baaa203b01f69595c63ce3bdba024948f75bec8dcb9420324ebe9ae1d7f538be1c263c5ef2cc954829100efa5b89da932c4538a7998498110ed0d400207e8527a0155682342771e0e2eea3e9539abb5d32317fe940326df724e833510b48e5f667d12107a69c258d505573f1d4fdba8e4bfb01f697270e2229348b4c3c86b1fee9daf26b83f85bcdfeb608119ea7ced82ec6e544fae384e7f3a0962a56149071c2c6f9bec32be0b9e6012c3b38a32ac95c43ab12cdaabeeed70b6e88f9397fe4e48a03edde26a93cf824fcb79a7f9abc3514dd5bca832227cde096bd6db2de0f",
    x"7435fbe4bdf1f3db54fd896b6bfed8180079befc90cd93c719a82ffbe886ac35d99e8a0b89f0839984256480ed5280615949c97cb4c4a64430544a2ecea99617c520531f3b75a402036e2c5b02ad342ead36babc7247a8b1edbf03ae99068220e4ced59c2635ca3960db2cd487a1291efe6efa2a48822cd0c53a56367a5800ba37bbca3cf6847e0ec3545dbc100826d98d453b67f3b7c843a8012b9dc7aba4dfb53af47b880437a7646efdb258b7848f7690a40b59015e97d3c7c93630ab5fd455dd4a4bef8de5286cb00d3126784464d111857d2708af81ef796054ce652527cea291e82dcb37e60a728375002edf558fcf45fa93160219d5f586ab8793defb27ada6c16028b6b5ef2da04c51d593a3a28e0ea5f60b10a01ba5623e952d99461a275e0112f07864b1237b5a662923b18744071ae5f369293d5b7a113ff50f9e56d0fd810ee58129eccf8de75af9f1ad37fdae23bbfc7bd30b5c");
    
    type shared_secret_array is array(0 to 1) of std_logic_vector(SS_SZ*8-1 downto 0);
    constant shared_secret_kat : shared_secret_array :=(
    x"c9ed8c0739f141dcde148738fff8f735",
    x"300792ad85d575ddfd0ee678ccdc7e9d");
    
    type invalid_shared_secret_array is array(0 to 1) of std_logic_vector(SS_SZ*8-1 downto 0); --For when decap ciphertext does not match
    constant invalid_shared_secret_kat : invalid_shared_secret_array :=(
    x"3e9488a208910e5223ef0f1be6ef30f9",
    x"6944a8a11d991432b79c180a615131cb");    
    
    signal do_read1 : std_logic_vector(8*(REG_SZ+1)-1 downto 0);
    signal do_read2 : std_logic_vector(8*(REG_SZ+1)-1 downto 0);
    signal addr_part_1 : std_logic_vector(7 downto 0);
    signal w_one_8     : std_logic_vector(7 downto 0) := "00000001";
    signal w_addr_inc : std_logic_vector(2 downto 0);
    signal w_one_3      : std_logic_vector(2 downto 0) := "001";
    signal combine_key : std_logic_vector(8*(2*KEY_REG_SZ)-1 downto 0);

begin

    -- 200 MHz clock
    oscillator : process
    begin
        clk <= '0';
        wait for PERIOD/2;
        clk <= '1';
        wait for PERIOD/2;
    end process oscillator;   

    uut : sike_p434
        port map (clk,rst,sike_cmd_i,iso_cmd_i,reg_sel_i,
                  wr_input_sel_i,wr_op_sel_i, wr_word_sel_i, wr_en_i,
                  rd_reg_i, rd_op_sel_i, rd_word_sel_i, buffer_xor_i,
                  keccak_clear_i, keccak_din_i, keccak_din_valid_byte_i, keccak_word_cnt_i, keccak_word_valid_i, keccak_finish_i,
                  data_i, data_o, busy_o);
        
    -- Testbench
    tb : process
    variable outline: line;
    variable errors       : boolean := FALSE;
    file outfile: text is out "mem_out";
    begin
        
        wait for PERIOD;
        
        rst <= '1';
        
        wait for 5 * PERIOD;
        
        rst <= '0';               
            
        wait for PERIOD;

        -- Insert elements
        wr_en_i <= '1';
        wr_input_sel_i <= '0';
        wr_op_sel_i <= "10";
        
        wait for PERIOD;
        for j in 0 to MSG_LOOPS-1 loop
            data_i <= secret_msg_alice_array_hex(0)(64*(j+1)-1 downto 64*j);
            wr_word_sel_i <= std_logic_vector(to_unsigned(j+2*MSG_LOOPS,4));
            wait for PERIOD;
        end loop;
        
        for j in 0 to MSG_LOOPS-1 loop
            data_i <= secret_msg_bob_array_hex(0)(64*(j+1)-1 downto 64*j);
            wr_word_sel_i <= std_logic_vector(to_unsigned(j,4));
            wait for PERIOD;
        end loop;
        
        keccak_clear_i <= '1';
        wait for PERIOD;
        keccak_clear_i <= '0';
        
        wr_op_sel_i <= "00";
        
        addr_part_1 <= "00000000";
        w_addr_inc <= (others => '0');
        wait for PERIOD;
        for i in 0 to mont_array_hex'length-1 loop
            reg_sel_i <= addr_part_1;
            w_addr_inc <= (others => '0');
            wait for PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                data_i <= mont_array_hex(i)(64*(j+1)-1 downto 64*j);
                wr_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD;
                w_addr_inc <= std_logic_vector(unsigned(w_addr_inc) + unsigned(w_one_3)); 
            end loop;
            addr_part_1 <= std_logic_vector(unsigned(addr_part_1)+unsigned(w_one_8));
            wait for PERIOD;
        end loop;
        wait for PERIOD;
        
        --addr_part_1 <= "00010000";
        w_addr_inc <= (others => '0');
        wait for PERIOD;
        for i in 0 to params_hex'length-1 loop
            
            reg_sel_i <= addr_part_1;
            w_addr_inc <= (others => '0');
            wait for PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                data_i <= params_hex(i)(64*(j+1)-1 downto 64*j);
                wr_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD;
                w_addr_inc <= std_logic_vector(unsigned(w_addr_inc) + unsigned(w_one_3)); 
            end loop;
            addr_part_1 <= std_logic_vector(unsigned(addr_part_1)+unsigned(w_one_8));
            wait for PERIOD;
        end loop;
        
        w_addr_inc <= (others => '0');
        wait for PERIOD;
        for i in 0 to kat1_results_hex'length-1 loop
            
            reg_sel_i <= addr_part_1;
            w_addr_inc <= (others => '0');
            wait for PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                data_i <= kat1_results_hex(i)(64*(j+1)-1 downto 64*j);
                wr_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD;
                w_addr_inc <= std_logic_vector(unsigned(w_addr_inc) + unsigned(w_one_3)); 
            end loop;
            addr_part_1 <= std_logic_vector(unsigned(addr_part_1)+unsigned(w_one_8));
            wait for PERIOD;
        end loop;
        
        --Shift in keys
        wr_op_sel_i <= "01";
        wr_en_i <= '1';
        
        combine_key <=  alice_keys_hex(1) & bob_keys_hex(0);
        wait for 4*PERIOD;
        for j in 0 to REG_LOOPS-1 loop
            wr_word_sel_i <= std_logic_vector(to_unsigned(j,4));
            wait for PERIOD;
            data_i <= combine_key(64*(j+1)-1 downto 64*j);
            wait for PERIOD;
        end loop;
        wait for PERIOD;
        wr_en_i <= '0';
        wait for PERIOD;
        
        --#############################KEYGEN#################################
        sike_cmd_i <= "001";
        wait for PERIOD;
        sike_cmd_i <= "000";
        wait for PERIOD;
        while busy_o = '1' loop
            wait for PERIOD;
        end loop;       
        
        wait for PERIOD*10;
        
        --Collect public key and secret key
        rd_op_sel_i <= "10";
        wait for PERIOD;
        for j in 0 to MSG_LOOPS-1 loop
            rd_word_sel_i <= std_logic_vector(to_unsigned(j+2*MSG_LOOPS,4));
            wait for PERIOD;
            do_read2(64*(j+1)-1 downto 64*j) <= data_o;
            wait for PERIOD;
        end loop;
        secret_key(SK_SZ*8-1 downto (SK_SZ-MSG_SZ)*8) <= do_read2(MSG_SZ*8-1 downto 0);
        wait for PERIOD;
        
        rd_op_sel_i <= "01";
        wait for PERIOD;
        for j in 0 to KEY_LOOPS-1 loop
            rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
            wait for PERIOD;
            do_read2(64*(j+1)-1 downto 64*j) <= data_o;
            wait for PERIOD;
        end loop;
        secret_key((SK_SZ-KEY_SZ)*8-1 downto 0)     <= secret_key(SK_SZ*8-1 downto KEY_SZ*8);
        secret_key(SK_SZ*8-1 downto (SK_SZ-KEY_SZ)*8) <= do_read2(KEY_SZ*8-1 downto 0);
        wait for PERIOD;        
        
        rd_op_sel_i <= "00";
        for i in 63 downto 62 loop
            reg_sel_i <= std_logic_vector(to_unsigned(i,8));
            rd_reg_i <= '1';
            wait for 5*PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD*5;
                do_read2(64*(j+1)-1 downto 64*j) <= data_o;
                wait for PERIOD;
            end loop;           
            wait for PERIOD;
            secret_key((SK_SZ-REG_SZ)*8-1 downto 0)     <= secret_key(SK_SZ*8-1 downto REG_SZ*8);
            public_key((PK_SZ-REG_SZ)*8-1 downto 0)     <= public_key(PK_SZ*8-1 downto REG_SZ*8);
            secret_key(SK_SZ*8-1 downto (SK_SZ-REG_SZ)*8) <= do_read2(REG_SZ*8-1 downto 0);
            public_key(PK_SZ*8-1 downto (PK_SZ-REG_SZ)*8) <= do_read2(REG_SZ*8-1 downto 0);
            wait for PERIOD;
        end loop;         

        for i in 67 downto 66 loop
            reg_sel_i <= std_logic_vector(to_unsigned(i,8));
            rd_reg_i <= '1';
            wait for 5*PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD*5;
                do_read2(64*(j+1)-1 downto 64*j) <= data_o;
                wait for PERIOD;
            end loop;           
            wait for PERIOD;
            secret_key((SK_SZ-REG_SZ)*8-1 downto 0)     <= secret_key(SK_SZ*8-1 downto REG_SZ*8);
            public_key((PK_SZ-REG_SZ)*8-1 downto 0)     <= public_key(PK_SZ*8-1 downto REG_SZ*8);
            secret_key(SK_SZ*8-1 downto (SK_SZ-REG_SZ)*8) <= do_read2(REG_SZ*8-1 downto 0);
            public_key(PK_SZ*8-1 downto (PK_SZ-REG_SZ)*8) <= do_read2(REG_SZ*8-1 downto 0);
            wait for PERIOD;
        end loop;   

        for i in 71 downto 70 loop
            reg_sel_i <= std_logic_vector(to_unsigned(i,8));
            rd_reg_i <= '1';
            wait for 5*PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD*5;
                do_read2(64*(j+1)-1 downto 64*j) <= data_o;
                wait for PERIOD;
            end loop;           
            wait for PERIOD;
            secret_key((SK_SZ-REG_SZ)*8-1 downto 0)     <= secret_key(SK_SZ*8-1 downto REG_SZ*8);
            public_key((PK_SZ-REG_SZ)*8-1 downto 0)     <= public_key(PK_SZ*8-1 downto REG_SZ*8);
            secret_key(SK_SZ*8-1 downto (SK_SZ-REG_SZ)*8) <= do_read2(REG_SZ*8-1 downto 0);
            public_key(PK_SZ*8-1 downto (PK_SZ-REG_SZ)*8) <= do_read2(REG_SZ*8-1 downto 0);
            wait for PERIOD;
        end loop;  
        
        if (public_key /= public_key_kat(0)) then
            assert false
                report "Public keys do not match!";
            errors := TRUE;
        end if; 
 
        if (secret_key /= secret_key_kat(0)) then
            assert false
                report "Secret keys do not match!";
            errors := TRUE;
        end if; 
        
        --#############################ENCAPSULATION#################################
        sike_cmd_i <= "010";
        wait for PERIOD;
        sike_cmd_i <= "000";
        wait for PERIOD;
        while busy_o = '1' loop
            wait for PERIOD;
        end loop;
        
        wait for PERIOD*10;
        
        --Collect ciphertext and shared_secret
        rd_op_sel_i <= "00";
        for i in 51 downto 50 loop
            reg_sel_i <= std_logic_vector(to_unsigned(i,8));
            rd_reg_i <= '1';
            wait for 5*PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD*5;
                do_read2(64*(j+1)-1 downto 64*j) <= data_o;
                wait for PERIOD;
            end loop;           
            wait for PERIOD;
            cipher_text((CT_SZ-REG_SZ)*8-1 downto 0)    <= cipher_text(CT_SZ*8-1 downto REG_SZ*8);
            cipher_text(CT_SZ*8-1 downto (CT_SZ-REG_SZ)*8)<= do_read2(REG_SZ*8-1 downto 0);
            wait for PERIOD;
        end loop;         

        for i in 55 downto 54 loop
            reg_sel_i <= std_logic_vector(to_unsigned(i,8));
            rd_reg_i <= '1';
            wait for 5*PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD*5;
                do_read2(64*(j+1)-1 downto 64*j) <= data_o;
                wait for PERIOD;
            end loop;           
            wait for PERIOD;
            cipher_text((CT_SZ-REG_SZ)*8-1 downto 0)    <= cipher_text(CT_SZ*8-1 downto REG_SZ*8);
            cipher_text(CT_SZ*8-1 downto (CT_SZ-REG_SZ)*8)<= do_read2(REG_SZ*8-1 downto 0);
            wait for PERIOD;
        end loop;   

        for i in 59 downto 58 loop
            reg_sel_i <= std_logic_vector(to_unsigned(i,8));
            rd_reg_i <= '1';
            wait for 5*PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD*5;
                do_read2(64*(j+1)-1 downto 64*j) <= data_o;
                wait for PERIOD;
            end loop;           
            wait for PERIOD;
            cipher_text((CT_SZ-REG_SZ)*8-1 downto 0)    <= cipher_text(CT_SZ*8-1 downto REG_SZ*8);
            cipher_text(CT_SZ*8-1 downto (CT_SZ-REG_SZ)*8)<= do_read2(REG_SZ*8-1 downto 0);
            wait for PERIOD;
        end loop;       

        rd_op_sel_i <= "10";
        wait for PERIOD;
        for j in 0 to MSG_LOOPS-1 loop
            rd_word_sel_i <= std_logic_vector(to_unsigned(j+MSG_LOOPS,4));
            wait for PERIOD;
            do_read2(64*(j+1)-1 downto 64*j) <= data_o;
            wait for PERIOD;
        end loop;
        cipher_text(PK_SZ*8-1 downto 0)     <= cipher_text(CT_SZ*8-1 downto MSG_SZ*8);
        cipher_text(CT_SZ*8-1 downto PK_SZ*8) <= do_read2(MSG_SZ*8-1 downto 0);
        wait for PERIOD;        
            
        rd_op_sel_i <= "11";
        wait for PERIOD;
        for j in 0 to SS_LOOPS-1 loop
            rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
            wait for PERIOD;
            do_read2(64*(j+1)-1 downto 64*j) <= data_o;
            wait for PERIOD;
        end loop;
        shared_secretA(SS_SZ*8-1 downto 0)     <= do_read2(SS_SZ*8-1 downto 0);
        wait for PERIOD;        

        if (cipher_text /= cipher_text_kat(0)) then
            assert false
                report "Cipher texts do not match!";
            errors := TRUE;
        end if; 

        if (shared_secretA /= shared_secret_kat(0)) then
            assert false
                report "Encap shared secrets do not match!";
            errors := TRUE;
        end if; 
       
        --Perform Decapsulation after swapping places of messages
        wr_op_sel_i <= "10";
        rd_op_sel_i <= "10";
        wr_input_sel_i <= '1';
        for j in 0 to MSG_LOOPS-1 loop
            rd_word_sel_i <= std_logic_vector(to_unsigned(j+MSG_LOOPS,4));
            wr_word_sel_i <= std_logic_vector(to_unsigned(j,4));
            wr_en_i <= '1';
            wait for PERIOD;
        end loop;        
        wr_en_i <= '0';
        wr_input_sel_i <= '0';
        
        wait for PERIOD;
        
        --#############################DECAPSULATION#################################
        sike_cmd_i <= "011";
        wait for PERIOD;
        sike_cmd_i <= "000";
        wait for PERIOD;
        while busy_o = '1' loop
            wait for PERIOD;
        end loop;        
        wait for PERIOD*10;

        --sike_cmd_i <= "100"; For when ciphertexts do not match
        sike_cmd_i <= "101";
        wait for PERIOD;
        sike_cmd_i <= "000";
        wait for PERIOD;
        while busy_o = '1' loop
            wait for PERIOD;
        end loop;      
        wait for PERIOD*10;
        
        --Collect shared secret
        rd_op_sel_i <= "11";
        wait for PERIOD;
        for j in 0 to SS_LOOPS loop
            rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
            wait for PERIOD;
            do_read2(64*(j+1)-1 downto 64*j) <= data_o;
            wait for PERIOD;
        end loop;
        shared_secretB(SS_SZ*8-1 downto 0)     <= do_read2(SS_SZ*8-1 downto 0);
        wait for PERIOD;         

        if (shared_secretB /= shared_secret_kat(0)) then
            assert false
                report "Decap shared secrets do not match!";
            errors := TRUE;
        end if; 

        list_mem <= '1';
        wait for PERIOD*2;
        list_mem <= '0';
        assert false
            report "Listing Memory"
                severity note;
        wait for PERIOD*2;
        --addr_part_1 <= (others => '0');
        rd_op_sel_i <= "00";
        for i in 0 to 255 loop
            reg_sel_i <= std_logic_vector(to_unsigned(i,8));
            rd_reg_i <= '1';
            wait for 5*PERIOD;
            for j in 0 to REG_LOOPS-1 loop
                rd_word_sel_i <= std_logic_vector(to_unsigned(j,4));
                wait for PERIOD*5;
                do_read2(64*(j+1)-1 downto 64*j) <= data_o;
                wait for PERIOD;
            end loop;
            wait for PERIOD;
            hwrite(outline, reg_sel_i);
            write(outline, string'(""" = """));
            hwrite(outline,do_read2(447 downto 0));
            writeline(outfile,outline);
        end loop;
        write(outline, string'(""" pk = """));
        hwrite(outline,public_key);
        writeline(outfile,outline);
        wait for PERIOD;
        write(outline, string'(""" sk = """));
        hwrite(outline,secret_key);
        writeline(outfile,outline);
        wait for PERIOD;    
        write(outline, string'(""" ct = """));
        hwrite(outline,cipher_text);
        writeline(outfile,outline);
        wait for PERIOD;
        write(outline, string'(""" ssA = """));
        hwrite(outline,shared_secretA);
        writeline(outfile,outline);
        wait for PERIOD;  
        write(outline, string'(""" ssB = """));
        hwrite(outline,shared_secretB);
        writeline(outfile,outline);
        wait for PERIOD;                            
        list_mem_done <= '1';    
        
        assert false report "Simulation finished." severity note;
        
        assert errors
            report "KAT test vector passed."
                severity note;
        assert not errors
            report "KAT test vector failed."
                severity note;        
        wait;
        
    end process tb;        

end Behavioral;
