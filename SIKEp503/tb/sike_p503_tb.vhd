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

entity sike_p503_tb is
--  Port ( );
end sike_p503_tb;

architecture Behavioral of sike_p503_tb is

    constant PERIOD : time := 5000 ps;
    
    constant TEST_WITHOUT_CFK : boolean := true;
    constant TEST_WITH_CFK : boolean := false;

component sike_p503 is
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
end component sike_p503; 

    constant REG_SZ : integer := 63;
    constant REG_LOOPS : integer := 8;
    constant MSG_SZ : integer := 24;
    constant MSG_LOOPS : integer := 3;
    constant PK_SZ : integer := 6*REG_SZ;
    constant KEY_SZ : integer := 32;
    constant KEY_LOOPS : integer := 4;
    constant SK_SZ : integer := MSG_SZ+PK_SZ+KEY_SZ;
    constant CT_SZ : integer := MSG_SZ+PK_SZ;
    constant SS_SZ : integer := 24;
    constant SS_LOOPS : integer := 3;

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
    
  
    
    type alice_key_array is array(0 to 1) of std_logic_vector(8*KEY_SZ-1 downto 0); 
    constant alice_keys_hex : alice_key_array :=( --Only for Debug purposes
    x"00a55f1ddfa3b0157cc4a0103c1dd1700e52545836e9431d7c5b8eae692f1573",
    x"03abce75fa9e4ad0fd67114cfbd7a5006fd25c6b88fe22b6386e87e0eab6305c"
    );
    
    type bob_key_array is array(0 to 1) of std_logic_vector(8*KEY_SZ-1 downto 0);
    constant bob_keys_hex : bob_key_array :=(
    x"0ffb2b878b9efa90dc137d406760550e21f856b9593be000081451d479ed2686",
    x"02f60ba4eab0f165f76cba6ca646b343308546cbd51e72b88572f21c53713200"
    );
    
    
    type mont_constants_array is array(0 to 6) of std_logic_vector(8*(REG_SZ+1)-1 downto 0);
    constant mont_array_hex : mont_constants_array :=(
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --0
    x"0039f7a1296f3c385be95ae032fd57ce61dc8a40c396a2bde2829e3800f36d95ec0000000000000000000000000000000000000000000000000000000000000f", --mont 1
    x"0033884d115d5a52578cef028b830acca81d1db90baec7ccb1fce095dfd4f38b2c0000000000000000000000000000000000000000000000000000000000001f", --mont 2
    x"0004872d9f15878db7f3522e153ba369305b363448e1f0a3ddbf4b093180a5ff1442fc57ab6eff168eca3b365d58dc8f17a9b88257189fed2b95289a0cf641d0", --R^2
    x"003ecb203b7ca5a4df2eabc67099118fad2c1ba68d8486f2c6e6ec7199ca491dfc00000000000000000000000000000000000000000000000000000000000003", --4^-1
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", --1
    x"0019cafcb115d2ba461b3f8bed99d6c5c11f6b9a2c0f5c07efe5ea0d5b5b0b602c0000000000000000000000000000000000000000000000000000000000005f" --mont 6
    );
    
    type params_array is array(0 to 30) of std_logic_vector(8*(REG_SZ+1)-1 downto 0);
    constant params_hex : params_array :=(
    x"0027381751ecf0e4ee4defae8f9275f3e2e66b7d64c50c5689443a8710583debbedd5e4a7aec65c2f393401ccfbba0942d90fe01606c035116a50459621e1361", --R0
    x"0031de228c1a87369f4b56d2ab00ca3ee9896e777218d06eec35bea10a3bf4d9c097ce1389a5b1d8560d8297d4d495104513e9a493548b905e5c7474fdec65ff", --R1
    x"004025944fefc8ef35ae2cd6def04b77aa8323f6a17739631b6ebfdd447364c8959f352e4983b1175698042793a9ba74a4ae0b71d637d8f2005075e8e99662ae", --R2
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006", --A.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A24.a Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A24.b Unused
    x"001ee4e4e9448fbbab4b5baef280a99b7bf86a1ce05d55bd603c3ba9d7c08fd8de7968b49a78851ffbc6d0a17cb2fa1b57f3babef87720dd9a489b5581f915d2", --PAx.a
    x"0002ed31a03825fa14bc1d92c503c061d843223e611a92d7c5fbec0f2c915ee7eee73374df6a1161ea00cdcb786155e21fd38220c3772ce670bc68274b851678", --PAx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PAy.a Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PAy.b Unused
    x"003e7b0494c8e60a8b72308ae09ed34845b34ea0911e356b77a11872cf7feeff745d98d0624097bc1ad7cd2adf7ffc2c1aa5ba3c6684b964fa555a0715e57db1", --QAx.a
    x"00325cf6a8e2c6183a8b9932198039a7f965ba8587b67925d08d809dbf9a69de1b621f7f134fa2dab82ff5a2615f92cc71419fffaaf86a290d604ab167616461", --QAx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QAy.a Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QAy.b Unused
    x"0006869ea28e4cee05dcee8b08acd59775d03daa0dc8b094c85156c212c23c72cb2ab2d2d90d46375aa6d66e58e44f8f219431d3006fded7993f51649c029498", --QPAx.a
    x"003d24cf1f347f1da54c1696442e6afc192cee5e320905e0eab3c9d3fb595ca26c154f39427a0416a9f36337354cf1e6e5aedd73df80c710026d49550ac8ce9f", --QPAx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPAy.a Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPAy.b Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBx.a
    x"0032d03fd1e99ed0cb05c0707af74617cbea5ac6b75905b4b54b1b0c2d73697840155e7b1005efb02b5d02797a8b66a5d258c76a3c9ef745cece11e9a178badf", --PBx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBy.a Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBy.b Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBx.a
    x"0039014a74763076675d24cf3fa28318dac75bcb04e54addc6494693f72ebb7da7dc6a3bbcd188dad5bece9d6bb4abdd05db38c5fbe52d985dcaf74422c24d53", --QBx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBy.a Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBy.b Unused
    x"00288165466888be1e78db339034e2b8c7bdf0483bfa7ab943dfa05b2d1712317916690f5e713740e7c7d4838296e67357dc34e3460a95c330d5169721981758", --QPBx.a
    x"0000c1465fd048ffb8bf2158ed57f0cfff0c4d5a4397c7542d722567700fdbb8b2825cab4b725764f5f528294b7f95c17d560e25660ad3d07ab011d95b2cb522", --QPBx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPBy.a Unused
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"); --QPBy.b Unused

    type kat1_results_array is array(0 to 35) of std_logic_vector(8*(REG_SZ+1)-1 downto 0); --For KAT0 only
    constant kat1_results_hex : kat1_results_array :=(
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA.b
    x"000ca9c568b62bcf6d9e49accc2261524c3898c7ef46ac1ce90a2354c5afa5479a7f038cbdae4c1e06336523ef832f01a79d488475998e7e788b80768d54762c", --j(EAB).a
    x"000df5e4467b92403a295ef346c55393628b53056b2de20aa7869c45e5bff77c3cb32fe3e0c07efac3452049f10c01221b0c523ebf3ea12f84c3684d5e38570a", --j(EAB).b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA24.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA24.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB.b
    x"000ca9c568b62bcf6d9e49accc2261524c3898c7ef46ac1ce90a2354c5afa5479a7f038cbdae4c1e06336523ef832f01a79d488475998e7e788b80768d54762c", --j(EBA).a
    x"000df5e4467b92403a295ef346c55393628b53056b2de20aa7869c45e5bff77c3cb32fe3e0c07efac3452049f10c01221b0c523ebf3ea12f84c3684d5e38570a", --j(EBA).b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB24.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB24.b
    x"0000f7055b7175076aba83f7b5bd30cff463d23fa9bb0d0da55e493a2f806bc09b0504186d97368e1d742920276c2c5c32149ad568253a686e462300992f34ae", --phiPBx.a
    x"0021632debf1fe1a1e9cd9142e23ac779daa157130ce3255c1c3a5750ba63ce6ed4b196a42724bd638407f58b221380d063ad9f81a6bace81bf030bda8920610", --phiPBx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPBy.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPBy.b
    x"000a0a644135aad54e6afb3c99445d08ceb42c79758e07aff641276825e432b190fdb5ca76b36ce8f95d92ff607f963334cd03621026d82e23fb94d91d5f7705", --phiQBx.a
    x"003d0f902d280f2b12e8e6a51444eb7587481d39849502948afb43864b780fa0679d3753f518246b1de198c67af46b3191ffdb415988734962a1a17a6f315bc8", --phiQBx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQBy.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQBy.b
    x"003ed4bb5e48649ea899de5f20082c48ecfc15f5c5b9aee1583a846ac71013604c90310ef09066d72026aad50d123d2fed166f9e9c4eb51f7cf2496400cc48d4", --phiQPBx.a
    x"00087fe4dadb06f2cc92324a3fd16a400d5910955476f0b176d653a31096f6fe54709de1dff793232eca51e67cc1c79c261a0158d36a7cc4ca8223b922796867", --phiQPBx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPBy.a not used
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPBy.b not used
    x"003a1cae1771150c5a0b7483a862be12166b5920f97e9574652e6a6b745349dd69513d1c41eecb8554f09c0e73a4df27480aaa2a9f0622a95ab8c41a85298840", --phiPAx.a
    x"001249092dbb205573e6f37c7c94a8f89d8db591825f4960e16322fb12400f2ad232755938656ae05fe3ead332d830c031583be2cf5db0ab383a7eff279d2705", --phiPAx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPAy.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPAy.b
    x"00222d6f6800a9cc7d29630cf4f1860cc45244fb5c2b9c7415590fd6523211cd0a81e1d117d0780360b65c03616d0a6164365da63b3e4950bce9a497729cef71", --phiQAx.a
    x"002e4c0d64f560daa82793e3331fa6d0cfc1b4a22dd7baf57107e48da434ff01394ccb7ecbf691d273e10343f39308ae19f07f500ac2e78fe8e9e7cc8ccee407", --phiQAx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQAy.a
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQAy.b
    x"00084039311e3ea5571379b3c32df47fa52becc9011423cdf5efe386535e4ffb624f248d8fbc538581eaa892e5bc26eed93199261df753e02c989ba3ac0cdcf2", --phiQPAx.a
    x"00119fa1afa884dea23bd6a899790bc9c531aa0ece661825799129b0e3d595d12e1b96ed71a21e26a5fcaa07b76eaaedf3d43bfcb22ff5b113bad9394544f966", --phiQPAx.b
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPAy.a not used
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"); --phiQPAy.b not used)
    
    type secret_msg_alice_array is array(0 to 1) of std_logic_vector(8*MSG_SZ-1 downto 0);
    constant secret_msg_alice_array_hex : secret_msg_alice_array :=(
    x"0348b1cc251ad82fdd1a6bdbe4106d0caa9476b0a035997c",
    x"173fa91081ee6c40f33731730bfca67b1c8c1d2a49930bd6");
 
    type secret_msg_bob_array is array(0 to 1) of std_logic_vector(8*MSG_SZ-1 downto 0);
    constant secret_msg_bob_array_hex : secret_msg_bob_array :=(
    x"74a8a9a379fe0ec8137f4d87e1fac806a4bbbea5f7037c14",
    x"129390744cb82aeb013e841158d1c5f63172e68cdf97e7cd");   
 
    signal public_key : std_logic_vector(PK_SZ*8-1 downto 0) := (others => '0');
    signal secret_key : std_logic_vector(SK_SZ*8-1 downto 0) := (others => '0');
    signal cipher_text : std_logic_vector(CT_SZ*8-1 downto 0) := (others => '0');
    signal shared_secretA : std_logic_vector(SS_SZ*8-1 downto 0) := (others => '0');
    signal shared_secretB : std_logic_vector(SS_SZ*8-1 downto 0) := (others => '0');  
    
    type public_key_array is array(0 to 1) of std_logic_vector(PK_SZ*8-1 downto 0);
    constant public_key_kat : public_key_array :=(
    x"084039311e3ea5571379b3c32df47fa52becc9011423cdf5efe386535e4ffb624f248d8fbc538581eaa892e5bc26eed93199261df753e02c989ba3ac0cdcf2119fa1afa884dea23bd6a899790bc9c531aa0ece661825799129b0e3d595d12e1b96ed71a21e26a5fcaa07b76eaaedf3d43bfcb22ff5b113bad9394544f966222d6f6800a9cc7d29630cf4f1860cc45244fb5c2b9c7415590fd6523211cd0a81e1d117d0780360b65c03616d0a6164365da63b3e4950bce9a497729cef712e4c0d64f560daa82793e3331fa6d0cfc1b4a22dd7baf57107e48da434ff01394ccb7ecbf691d273e10343f39308ae19f07f500ac2e78fe8e9e7cc8ccee4073a1cae1771150c5a0b7483a862be12166b5920f97e9574652e6a6b745349dd69513d1c41eecb8554f09c0e73a4df27480aaa2a9f0622a95ab8c41a852988401249092dbb205573e6f37c7c94a8f89d8db591825f4960e16322fb12400f2ad232755938656ae05fe3ead332d830c031583be2cf5db0ab383a7eff279d2705",
    x"03a90d761abfe5d770ae65f6fc079b2f19a0d6e2bcc65b8125c664430e7334163efeaa1a0a5db3be603faa001add82ff36e493132cd9e75cc150b29713bb0a26d761e3ea0fc41262efdb73a24ce074bae6f903b866ff427fa6efaaeaeb4dcfc59d14620b700a8fbb48012e88a93ae0a5e0c72343a0a99ab8bf29353b36f9019a7e2c2f3315125ad3bea3fbe82650232fe5e59de4dd684054b5cbab7c8251fcaf286db2cd931c732dad3bb5a41576cb4f3c03f98b28e808003326c56c121521b02602ef3a891be5b1ce95b8068c28311f646d46a5ba7e351971365789f3be44c00de35daf9b7fcd90107c9ae9798a0b9e1ce831cb72227da38ecd2c0613dd900dfd25860db43fb7e2248798d4e15922a2e3c95272160d4082fc1e3f21d960302fc67315a95c97c4d7e05de74d80a5ad43813d8597b08aac70fa9e0e3b7a7e9e340f9c3e58d828073b77dbc92741a8482e68ab6f3ceea69e922ae77e603e9d1a3dc64a4b19661968cbcfd80f1bb634b8fa3305a8a056c6d655f6cc");    
    
    type secret_key_array is array(0 to 1) of std_logic_vector(SK_SZ*8-1 downto 0);
    constant secret_key_kat : secret_key_array :=(
    x"084039311e3ea5571379b3c32df47fa52becc9011423cdf5efe386535e4ffb624f248d8fbc538581eaa892e5bc26eed93199261df753e02c989ba3ac0cdcf2119fa1afa884dea23bd6a899790bc9c531aa0ece661825799129b0e3d595d12e1b96ed71a21e26a5fcaa07b76eaaedf3d43bfcb22ff5b113bad9394544f966222d6f6800a9cc7d29630cf4f1860cc45244fb5c2b9c7415590fd6523211cd0a81e1d117d0780360b65c03616d0a6164365da63b3e4950bce9a497729cef712e4c0d64f560daa82793e3331fa6d0cfc1b4a22dd7baf57107e48da434ff01394ccb7ecbf691d273e10343f39308ae19f07f500ac2e78fe8e9e7cc8ccee4073a1cae1771150c5a0b7483a862be12166b5920f97e9574652e6a6b745349dd69513d1c41eecb8554f09c0e73a4df27480aaa2a9f0622a95ab8c41a852988401249092dbb205573e6f37c7c94a8f89d8db591825f4960e16322fb12400f2ad232755938656ae05fe3ead332d830c031583be2cf5db0ab383a7eff279d27050ffb2b878b9efa90dc137d406760550e21f856b9593be000081451d479ed26860348b1cc251ad82fdd1a6bdbe4106d0caa9476b0a035997c",
    x"03a90d761abfe5d770ae65f6fc079b2f19a0d6e2bcc65b8125c664430e7334163efeaa1a0a5db3be603faa001add82ff36e493132cd9e75cc150b29713bb0a26d761e3ea0fc41262efdb73a24ce074bae6f903b866ff427fa6efaaeaeb4dcfc59d14620b700a8fbb48012e88a93ae0a5e0c72343a0a99ab8bf29353b36f9019a7e2c2f3315125ad3bea3fbe82650232fe5e59de4dd684054b5cbab7c8251fcaf286db2cd931c732dad3bb5a41576cb4f3c03f98b28e808003326c56c121521b02602ef3a891be5b1ce95b8068c28311f646d46a5ba7e351971365789f3be44c00de35daf9b7fcd90107c9ae9798a0b9e1ce831cb72227da38ecd2c0613dd900dfd25860db43fb7e2248798d4e15922a2e3c95272160d4082fc1e3f21d960302fc67315a95c97c4d7e05de74d80a5ad43813d8597b08aac70fa9e0e3b7a7e9e340f9c3e58d828073b77dbc92741a8482e68ab6f3ceea69e922ae77e603e9d1a3dc64a4b19661968cbcfd80f1bb634b8fa3305a8a056c6d655f6cc02f60ba4eab0f165f76cba6ca646b343308546cbd51e72b88572f21c53713200173fa91081ee6c40f33731730bfca67b1c8c1d2a49930bd6");

    type cipher_text_array is array(0 to 1) of std_logic_vector(CT_SZ*8-1 downto 0);
    constant cipher_text_kat : cipher_text_array :=(
    x"c0f5982c869683e2127566c613e1f60df2e8ee184de2e2ef3ed4bb5e48649ea899de5f20082c48ecfc15f5c5b9aee1583a846ac71013604c90310ef09066d72026aad50d123d2fed166f9e9c4eb51f7cf2496400cc48d4087fe4dadb06f2cc92324a3fd16a400d5910955476f0b176d653a31096f6fe54709de1dff793232eca51e67cc1c79c261a0158d36a7cc4ca8223b9227968670a0a644135aad54e6afb3c99445d08ceb42c79758e07aff641276825e432b190fdb5ca76b36ce8f95d92ff607f963334cd03621026d82e23fb94d91d5f77053d0f902d280f2b12e8e6a51444eb7587481d39849502948afb43864b780fa0679d3753f518246b1de198c67af46b3191ffdb415988734962a1a17a6f315bc800f7055b7175076aba83f7b5bd30cff463d23fa9bb0d0da55e493a2f806bc09b0504186d97368e1d742920276c2c5c32149ad568253a686e462300992f34ae21632debf1fe1a1e9cd9142e23ac779daa157130ce3255c1c3a5750ba63ce6ed4b196a42724bd638407f58b221380d063ad9f81a6bace81bf030bda8920610",
    x"98c964379dc3bd7380b27d35207990ac34d6479aad7f94ed0e99f9191034e85d09e2975b12e0f9d3177985e74c8894b2a2e4ae2a08ae9092c23c84576a475d10d47a49f53462b085668e49fe05b38b334e2a66b633ae2a3629ebe9f12f41614ea062c283409e6e74aa7fe3af18b219c1cee58646821f5c03ba04cd7173540b2e3416976efa4924b31fb18d2801f15d0ce4f25bb02df7311c375d67fb68345b4be96aee67074c30d353f693a09ea4e2cf808c7685b316802a13f081bac265d6aac8cc6dc7d9e4fd6853e034e0333f161cd1c1f861ce1ec697040f28debed029d210a7380411bc85f86f3e70b8e1f6800c6c8c9323e18e6e453151eff79c3c67528a8a70b3c2d4432430e09f92b24fca0ca4a1df9f0f9ea593c1a5adbdb3aa7d5bf98b80031f0061e4bf234141111e4afc00f1640d7ede131d1083b717c60353215153622183af70a9f611b7f7b931d24e1620163709194e8fca64882a142ec3f9fa0ad7752db331e3571585afea77a0822b97087578c59b5911062793e2865c13d07b27522c33b15280001710f21907e08830");
    
    type shared_secret_array is array(0 to 1) of std_logic_vector(SS_SZ*8-1 downto 0);
    constant shared_secret_kat : shared_secret_array :=(
    x"dadd9b3ca8ce230559717fba180b15d4b4592c1c158012af",
    x"224cb0ec3033ff636a6f3875bbadee456eddb3be49350d81");
    
    type invalid_shared_secret_array is array(0 to 1) of std_logic_vector(SS_SZ*8-1 downto 0); --For when decap ciphertext does not match
    constant invalid_shared_secret_kat : invalid_shared_secret_array :=(
    x"ecc57b8444c7dd441fa68f336a5625a9ede1813f65cd73ad",
    x"3b4307e87dfed47badf3be8fe5afc7d63cd697ecb375be41");    
    
    signal do_read1 : std_logic_vector(8*(REG_SZ+1)-1 downto 0);
    signal do_read2 : std_logic_vector(8*(REG_SZ+1)-1 downto 0);
    signal addr_part_1 : std_logic_vector(7 downto 0);
    signal w_one_8     : std_logic_vector(7 downto 0) := "00000001";
    signal w_addr_inc : std_logic_vector(2 downto 0);
    signal w_one_3      : std_logic_vector(2 downto 0) := "001";
    signal combine_key : std_logic_vector(8*(REG_SZ+1)-1 downto 0);

begin

    -- 200 MHz clock
    oscillator : process
    begin
        clk <= '0';
        wait for PERIOD/2;
        clk <= '1';
        wait for PERIOD/2;
    end process oscillator;   

    uut : sike_p503
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
            wr_word_sel_i <= std_logic_vector(to_unsigned(j+6,4));
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
            rd_word_sel_i <= std_logic_vector(to_unsigned(j+6,4));
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
            rd_word_sel_i <= std_logic_vector(to_unsigned(j+3,4));
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

        --sike_cmd_i <= "100"; --For when ciphertexts do not match
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
            hwrite(outline,do_read2(511 downto 0));
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
