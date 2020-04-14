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

entity sike_p610_tb is
--  Port ( );
end sike_p610_tb;

architecture Behavioral of sike_p610_tb is

    constant PERIOD : time := 5000 ps;
    
    constant TEST_WITHOUT_CFK : boolean := true;
    constant TEST_WITH_CFK : boolean := false;

component sike_p610 is
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
end component sike_p610; 

    constant REG_SZ : integer := 77;
    constant REG_LOOPS : integer := 10;
    constant MSG_SZ : integer := 24;
    constant MSG_LOOPS : integer := 3;
    constant PK_SZ : integer := 6*REG_SZ;
    constant KEY_REG_SZ : integer := 40;
    constant KEY_SZ : integer := 38;
    constant KEY_LOOPS : integer := 5;
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
    
  
    
    type alice_key_array is array(0 to 1) of std_logic_vector(8*KEY_REG_SZ-1 downto 0); 
    constant alice_keys_hex : alice_key_array :=( --Only for Debug purposes
    x"0001a2130d98c53186e19acdbcc4628212ae02d47820951e472d231e1b7ad8c26f3048c707e93e7b",
    x"0001ac025ee8d9b6eaabc82ad73aab91a098735ca2f58afe509016730e9805c96b1467a5bc636fe4"
    );
    
    type bob_key_array is array(0 to 1) of std_logic_vector(8*KEY_REG_SZ-1 downto 0);
    constant bob_keys_hex : bob_key_array :=(
    x"0000218589720aab8ffb2b878b9efa90dc137d406760550e21f856b9593be000081451d479ed2686",
    x"000097ff1879323f72f60ba4eab0f165f76cba6ca646b343308546cbd51e72b88572f21c53713200"
    );
    
    
    type mont_constants_array is array(0 to 6) of std_logic_vector(8*(REG_SZ+3)-1 downto 0);
    constant mont_array_hex : mont_constants_array :=(
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --0
    x"00000001f3151af8f68107efe1013da728f8ff884bda1dad7f2e43eddbcc378c4703bc8d86dd0f9009e8000000000000000000000000000000000000000000000000000000000000000000000000670c", --mont 1
    x"000000016a338e896b71ff1d701aa2c19f9c4c1686f016306374c896b308756cdc8f2b32635f6ef1a5ce000000000000000000000000000000000000000000000000000000000000000000000000ce19", --mont 2
    x"0000000040d650180eeb6dde8422025f0143247ba71b5f36d80da2418237f07b840ae097b7859d1ff642b8c423a6030979ede54adc7f419940d1a0c56bc1707818de493de0b85963b627392ee75f5d20", --R^2
    x"000000007cc546be3da041fbf8404f69ca3e3fe212f6876b5fcb90fb76f30de311c0ef2361b743e4027a00000000000000000000000000000000000000000000000000000000000000000000000019c3", --4^-1
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", --1
    x"00000001c2a40433c0c5ec95fe680fb82c7f3149840c1d668f769a7f1489669ae43533ae7fc39ca683680000000000000000000000000000000000000000000000000000000000000000000000026a4c" --mont 6
    );
    
    type params_array is array(0 to 30) of std_logic_vector(8*(REG_SZ+3)-1 downto 0);
    constant params_hex : params_array :=(
    x"000000000000000000000000000000000027381751ecf0e4ee4defae8f9275f3e2e66b7d64c50c5689443a8710583debbedd5e4a7aec65c2f393401ccfbba0942d90fe01606c035116a50459621e1361", --R0
    x"000000000000000000000000000000000031de228c1a87369f4b56d2ab00ca3ee9896e777218d06eec35bea10a3bf4d9c097ce1389a5b1d8560d8297d4d495104513e9a493548b905e5c7474fdec65ff", --R1
    x"00000000000000000000000000000000004025944fefc8ef35ae2cd6def04b77aa8323f6a17739631b6ebfdd447364c8959f352e4983b1175698042793a9ba74a4ae0b71d637d8f2005075e8e99662ae", --R2
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006", --A.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A24.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A24.b Unused
    x"00000001459685dca7112d1f6030dbc98f2c9cbb41617b6ad913e6523416ccbd8ed9c7841d97df83092b9b3f2af00d62e08dad8fa743cbcccc1782be0186a3432d3c97c37ca16873bede01f0637c1aa2", --PAx.a
    x"00000001b368bc6019b46cd802129209b3e65b98bc64a92bc4db2f9f3ac96b97a1b9c124df549b528f18beecb1666d27d47530435e84221272f3a97fb80527d8f8a359f8f1598d365744ca3070a5f26c", --PAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PAy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PAy.b Unused
    x"00000002250e1959256ae502428338cb4715399551aec78d8935b2dc73fcdcfbdb1a0118a2d3ef03489ba6f637b1c7fee7e5f31340a1a537b76b5b736b4cdd284918918e8c986fc02741fb8c98f0a0ed", --QAx.a
    x"0000000025da39ec90cdfb9bc0f772cda52cb8b5a9f478d7af8dbba0aeb3e52432822dd88c38f4e3aec0746e56149f1fe89707c77f8ba4134568629724f4a8e34b06bfe5c5e66e0867ec38b283798b8a", --QAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QAy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QAy.b Unused
    x"0000000183c9abf2297ca69699357f58fed92553436bbeba2c3600d89522e7009d19ea5d6c18cff993aa3aa33923ed93592b0637ed0b33adf12388ae912bc4ae4749e2df3c3292994dcf37747518a992", --QPAx.a
    x"00000001b36a006d05f9e370d5078cca54a16845b2bff737c865368707c0dbbe9f5a62a9b9c79adf11932a9fa4806210e25c92db019cc146706dfbc7fa2638ecc4343c1e390426faa7f2f07fda163fb5", --QPAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPAy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPAy.b Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBx.a
    x"00000001587822e647707ed4313d3be6a811a694fb201561111838a0816bfb5dec625d23772de48a26d78c04eeb26ca4a571c67ce4dc4c620282876b2f2fc2633ca548c3ab0c45cc991417a56f7fefeb", --PBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBy.b Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBx.a
    x"000000014e647cb19b7eaaac640a9c26b9c26db7deda8fc9399f4f8ce620d2b2200480f4338755ae16d0e090f15ea1882166836a478c6e161c938e4eb8c2dd779b45ffdd17dcdf158af48de126b3a047", --QBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBy.b Unused
    x"00000001b2c30180daf5d91871555ce8efec76a4d521f877b754311228c7180a3e2318b4e7a00341ff99f34e35bf7a1053ca76fd77c0afae38e2091862ab4f1dd4c8d9c83de37acba6646edb4c238b48", --QPBx.a
    x"00000001db73bc2de666d24e59af5e23b79251ba0d189629ef87e56c38778a448face312d08edfb876c3fd45ecf3746d96e2cadbba08b1a206c47ddd93137059e34c90e2e42e10f30f6e5f52ded74222", --QPBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPBy.a Unused
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"); --QPBy.b Unused

    type kat1_results_array is array(0 to 35) of std_logic_vector(8*(REG_SZ+3)-1 downto 0); --For KAT0 only
    constant kat1_results_hex : kat1_results_array :=(
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA.b
    x"000000014146c6d547d7d601753c7decff4313e1ec074962dfc10b91be86185c7c693dc7004fe31e9193b2a031b586a4d35d40eefe137b0e8f9814183794fb6d3be37cb83c0cb94efc5df25a6808fab6", --j(EAB).a
    x"000000023b57d44520f748f3120d5afd273492eee3275d8611807f55e62a95c106393ede745b4585e2f910410b5bec3c2b565da15e0efd99ab7cc9c1e6f5bd332c9f8feeb6a37200bd3c0b289b532733", --j(EAB).b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA24.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA24.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB.b
    x"000000014146c6d547d7d601753c7decff4313e1ec074962dfc10b91be86185c7c693dc7004fe31e9193b2a031b586a4d35d40eefe137b0e8f9814183794fb6d3be37cb83c0cb94efc5df25a6808fab6", --j(EBA).a
    x"000000023b57d44520f748f3120d5afd273492eee3275d8611807f55e62a95c106393ede745b4585e2f910410b5bec3c2b565da15e0efd99ab7cc9c1e6f5bd332c9f8feeb6a37200bd3c0b289b532733", --j(EBA).b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB24.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB24.b
    x"00000001d341b7b5b04d5f3bd88cdd53c64c6d3bd20ce167fbc84eef321bce8de5c843b0f110d716887f6dceb9feb1142a937675d70b9cc84bbf069c285a28228b00c837b2dfa101dea0df81ae26ff97", --phiPBx.a
    x"00000002250b5d114d18ff032b9302133c58b4052d3716d239f6d1615628731d33d8f0e470dc7ee86471c026551c9e25e6ba3134157b0ca5b47503f3bb10dde6621f2f73d8290bac32313135d8e775fb", --phiPBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPBy.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPBy.b
    x"0000000040ad06f69beec252a8885d92bbe3a0e71f93ee0f841ac128edd8201d2cfdf71f23a2af62b5b69f7c00d0eceace1327caabbf72a20cb1753221f9c3821ecf2bf6a016199ccbe837ce278accbb", --phiQBx.a
    x"00000001ac61012a89a757e5ff339150855e8888a6ae35f84cfd041d5f1ff3a14b3c08e0f4c380aaf8394f6df1084ae75073e4704c358b2c82f0531535f278b1356966e4341e0e6540b93ee12e84cf25", --phiQBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQBy.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQBy.b
    x"000000013df531cacc13fe4a87272f7b243ea1bd9827173611b28b8f8cfa6ddaba349964d456e73fca75a4a93dc4cabc9ee99692378799d7e13d0be7f6d216153a7edd99582effc9234cd1709804e1ce", --phiQPBx.a
    x"000000024099482e749589c70c34440aa14c39606e32da9e3e5a334e533c6f364a59ebf3aa30812e8e684720a367358defe61d526ef7d9b0ad07d070a7c7ae67d7f8e88dbabad4d9cafea655316427fa", --phiQPBx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPBy.a not used
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPBy.b not used
    x"00000000b46559f7cfd4b54e47076c1ae1227d2c1b4c965e77408a43683f40797b5d4c72d35e4e916f4e4becf518a2aea63f781cbec5c546299b17331b239ecec8c79488a7ecb87e6ebbb96d7e6013c6", --phiPAx.a
    x"00000000a47ca0c9d4b9b97a6e86f4ab63a0ff4849dffaeb7960c353851fe0b83c50b0f62a1cb598bfa252840f457e580516e4258175c1153aa1c7189e5ab4e0531c74dec5f07ac918dd049376241b67", --phiPAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPAy.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPAy.b
    x"00000000a6aa797e96e1313923acd140fa4112f716a34019ee35aa978566736920652423b3be52b1ccb96b1ef3fa2c7ab286b73bcab89e63147004795b01542f86cc98843a8a7096338513d8a474ef7d", --phiQAx.a
    x"00000000285b7ebeb447c09b26701a9cee49417a0d2ad577807329581eeeb5a230cdb37ec75d083bd8476a47848026f6c7076f55b80f32cf6407e5d48e200aba6bd4fe305ebfba2d568a90a99f067e16", --phiQAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQAy.a
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQAy.b
    x"000000016e4c00b26e902b46d81bd958e86e1e100e5835e038ca8b4e15f5c5c15beb0d734139639820e9157abd3b9540ed059ba0a086be42a1066f7d953c700cd2e879f99b9ec1b6e8a7533e183a2ffe", --phiQPAx.a
    x"00000000fba1f5988d3c7f6d3696c028cdc021ea46027ad5898de05bea0433f2e46785d8c50a21e4465d52c92d1fc29bdcc0583db1dbaecbdae017ea3f48dee1477a2ff275734e92630a28c6fe836daa", --phiQPAx.b
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPAy.a not used
    x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"); --phiQPAy.b not used)
    
    type secret_msg_alice_array is array(0 to 1) of std_logic_vector(8*MSG_SZ-1 downto 0);
    constant secret_msg_alice_array_hex : secret_msg_alice_array :=(
    x"0348b1cc251ad82fdd1a6bdbe4106d0caa9476b0a035997c",
    x"173fa91081ee6c40f33731730bfca67b1c8c1d2a49930bd6");
 
    type secret_msg_bob_array is array(0 to 1) of std_logic_vector(8*MSG_SZ-1 downto 0);
    constant secret_msg_bob_array_hex : secret_msg_bob_array :=(
    x"fefcc84fab77ad7c78568d676708ca46217761a93b565562",
    x"f8a6b7b17619a9f73a70c40de7244c53c8dc54b5d1610c0b");   
 
    signal public_key : std_logic_vector(PK_SZ*8-1 downto 0) := (others => '0');
    signal secret_key : std_logic_vector(SK_SZ*8-1 downto 0) := (others => '0');
    signal cipher_text : std_logic_vector(CT_SZ*8-1 downto 0) := (others => '0');
    signal shared_secretA : std_logic_vector(SS_SZ*8-1 downto 0) := (others => '0');
    signal shared_secretB : std_logic_vector(SS_SZ*8-1 downto 0) := (others => '0');  
    
    type public_key_array is array(0 to 1) of std_logic_vector(PK_SZ*8-1 downto 0);
    constant public_key_kat : public_key_array :=(
    x"016e4c00b26e902b46d81bd958e86e1e100e5835e038ca8b4e15f5c5c15beb0d734139639820e9157abd3b9540ed059ba0a086be42a1066f7d953c700cd2e879f99b9ec1b6e8a7533e183a2ffe00fba1f5988d3c7f6d3696c028cdc021ea46027ad5898de05bea0433f2e46785d8c50a21e4465d52c92d1fc29bdcc0583db1dbaecbdae017ea3f48dee1477a2ff275734e92630a28c6fe836daa00a6aa797e96e1313923acd140fa4112f716a34019ee35aa978566736920652423b3be52b1ccb96b1ef3fa2c7ab286b73bcab89e63147004795b01542f86cc98843a8a7096338513d8a474ef7d00285b7ebeb447c09b26701a9cee49417a0d2ad577807329581eeeb5a230cdb37ec75d083bd8476a47848026f6c7076f55b80f32cf6407e5d48e200aba6bd4fe305ebfba2d568a90a99f067e1600b46559f7cfd4b54e47076c1ae1227d2c1b4c965e77408a43683f40797b5d4c72d35e4e916f4e4becf518a2aea63f781cbec5c546299b17331b239ecec8c79488a7ecb87e6ebbb96d7e6013c600a47ca0c9d4b9b97a6e86f4ab63a0ff4849dffaeb7960c353851fe0b83c50b0f62a1cb598bfa252840f457e580516e4258175c1153aa1c7189e5ab4e0531c74dec5f07ac918dd049376241b67",
    x"009f60f27327090744996bb1117d765fc60a4917a82c44a84a2dbc6414f1697eef6fd30ea0ad9e09a9518afb4411e74da2e2c97791582378337ca6e5dfce232cc92ad1b6f735e4ee4e8f4a3e490194927f7489c8045108b6c5ce9bc3505a4e919665ef79fa52fb38b95aa822bfe9580d4ed4b3a0e54b7b5bb747dc3cd4796225dd8326d25c5f80be6bb693122c586eb3ffa4334441194c0aa2b00166baa64eadd30f037436c8bf6cd9f36b10dd9da06667f6a6c703dc68f169f92919368ea655545b7a58ec0fe688e837c9bb560da6c48a985babb87a663427751512e3aef66a64ad18275aa75f00ca936a5371fbf22f07b27825fa38a6c2ee3d84eae20cca7345d893d49d6a1381e038f4de1b7b459a481b387c38bf30ad281c7c3fc3d7caf266e113417efda838ab6b2683bb63063e83d3c4ea0194f313b56ff7c4fef85f75f18e4bd9a829822db3fd9c9ecdaba0fd5175ba72bf41c24c2a7936506617a4b96cf0db09bb063ba96d75ae32baddffcb51c00181901936dffad261c995bd0d07cb024eca83e2d370d6fc10caa7d6260a54032a2e7fe16b34f754ac6bf97c00c481386ef7381d5c07dcfedbffd8fa20cc2236b4a9768f268f20d4ef1b891be102e2a0e144450187fbc372328a8e9c");    
    
    type secret_key_array is array(0 to 1) of std_logic_vector(SK_SZ*8-1 downto 0);
    constant secret_key_kat : secret_key_array :=(
    x"016e4c00b26e902b46d81bd958e86e1e100e5835e038ca8b4e15f5c5c15beb0d734139639820e9157abd3b9540ed059ba0a086be42a1066f7d953c700cd2e879f99b9ec1b6e8a7533e183a2ffe00fba1f5988d3c7f6d3696c028cdc021ea46027ad5898de05bea0433f2e46785d8c50a21e4465d52c92d1fc29bdcc0583db1dbaecbdae017ea3f48dee1477a2ff275734e92630a28c6fe836daa00a6aa797e96e1313923acd140fa4112f716a34019ee35aa978566736920652423b3be52b1ccb96b1ef3fa2c7ab286b73bcab89e63147004795b01542f86cc98843a8a7096338513d8a474ef7d00285b7ebeb447c09b26701a9cee49417a0d2ad577807329581eeeb5a230cdb37ec75d083bd8476a47848026f6c7076f55b80f32cf6407e5d48e200aba6bd4fe305ebfba2d568a90a99f067e1600b46559f7cfd4b54e47076c1ae1227d2c1b4c965e77408a43683f40797b5d4c72d35e4e916f4e4becf518a2aea63f781cbec5c546299b17331b239ecec8c79488a7ecb87e6ebbb96d7e6013c600a47ca0c9d4b9b97a6e86f4ab63a0ff4849dffaeb7960c353851fe0b83c50b0f62a1cb598bfa252840f457e580516e4258175c1153aa1c7189e5ab4e0531c74dec5f07ac918dd049376241b67218589720aab8ffb2b878b9efa90dc137d406760550e21f856b9593be000081451d479ed26860348b1cc251ad82fdd1a6bdbe4106d0caa9476b0a035997c",
    x"009f60f27327090744996bb1117d765fc60a4917a82c44a84a2dbc6414f1697eef6fd30ea0ad9e09a9518afb4411e74da2e2c97791582378337ca6e5dfce232cc92ad1b6f735e4ee4e8f4a3e490194927f7489c8045108b6c5ce9bc3505a4e919665ef79fa52fb38b95aa822bfe9580d4ed4b3a0e54b7b5bb747dc3cd4796225dd8326d25c5f80be6bb693122c586eb3ffa4334441194c0aa2b00166baa64eadd30f037436c8bf6cd9f36b10dd9da06667f6a6c703dc68f169f92919368ea655545b7a58ec0fe688e837c9bb560da6c48a985babb87a663427751512e3aef66a64ad18275aa75f00ca936a5371fbf22f07b27825fa38a6c2ee3d84eae20cca7345d893d49d6a1381e038f4de1b7b459a481b387c38bf30ad281c7c3fc3d7caf266e113417efda838ab6b2683bb63063e83d3c4ea0194f313b56ff7c4fef85f75f18e4bd9a829822db3fd9c9ecdaba0fd5175ba72bf41c24c2a7936506617a4b96cf0db09bb063ba96d75ae32baddffcb51c00181901936dffad261c995bd0d07cb024eca83e2d370d6fc10caa7d6260a54032a2e7fe16b34f754ac6bf97c00c481386ef7381d5c07dcfedbffd8fa20cc2236b4a9768f268f20d4ef1b891be102e2a0e144450187fbc372328a8e9c97ff1879323f72f60ba4eab0f165f76cba6ca646b343308546cbd51e72b88572f21c53713200173fa91081ee6c40f33731730bfca67b1c8c1d2a49930bd6");

    type cipher_text_array is array(0 to 1) of std_logic_vector(CT_SZ*8-1 downto 0);
    constant cipher_text_kat : cipher_text_array :=(
    x"3af3dcc1d7c54ff6763cb8d6bb9bebb1d1cdcbc320954ba9013df531cacc13fe4a87272f7b243ea1bd9827173611b28b8f8cfa6ddaba349964d456e73fca75a4a93dc4cabc9ee99692378799d7e13d0be7f6d216153a7edd99582effc9234cd1709804e1ce024099482e749589c70c34440aa14c39606e32da9e3e5a334e533c6f364a59ebf3aa30812e8e684720a367358defe61d526ef7d9b0ad07d070a7c7ae67d7f8e88dbabad4d9cafea655316427fa0040ad06f69beec252a8885d92bbe3a0e71f93ee0f841ac128edd8201d2cfdf71f23a2af62b5b69f7c00d0eceace1327caabbf72a20cb1753221f9c3821ecf2bf6a016199ccbe837ce278accbb01ac61012a89a757e5ff339150855e8888a6ae35f84cfd041d5f1ff3a14b3c08e0f4c380aaf8394f6df1084ae75073e4704c358b2c82f0531535f278b1356966e4341e0e6540b93ee12e84cf2501d341b7b5b04d5f3bd88cdd53c64c6d3bd20ce167fbc84eef321bce8de5c843b0f110d716887f6dceb9feb1142a937675d70b9cc84bbf069c285a28228b00c837b2dfa101dea0df81ae26ff9702250b5d114d18ff032b9302133c58b4052d3716d239f6d1615628731d33d8f0e470dc7ee86471c026551c9e25e6ba3134157b0ca5b47503f3bb10dde6621f2f73d8290bac32313135d8e775fb",
    x"07f85a0b62f457e08a3a510eaa4ee0cb798aef4e2fc3fb2b0167375d7117bfddd19b60055524565d2edea26c3cb65a5c130d54836606561b048b201c1dc231451363bdc62f07dfb7c0c55706aaa67182dde27e1f8f9a34e8af748178564e40767879be9b9c00f784d58af0016683e4d977224923434381b460d52d6d2ff12e7346dbc558ecf979a19ddbf6d88130fb3559dfeb9ba725a8c65b71dec65413498818d335ef491840de60f118b95c0fb09965640172a629b303b88bd1022fc6f5c624e55b8923480e90f4556a86cb26c9ce8e588c9b9c86610bea7927ed3de6ef7137311831de7ee1f47038197249ac4332bf781be162587404d5bcd2bdd6b252009782bbfae97d62573baa8e94e152165a24aacc0c2ed07ce6facc1e7a50dc90c8db664e042a7c02fb2ed34244b2c6e3db9cb6e3f8f86761a6c1ff768b79827f54581ba73ba486c1413f1cd42400343c83e97a3fec74395efc39f4bfcc1bdee60dc8859dfa9acd10e83b291718ae02bf66d49e7c66d0eb6663ad1289dd87f5b0c15bf7bcc3d23391dcacbee4b4b47d3e4c5be969e31a0e2d3e890147654f7fff5081805e6a3e01edc84abf8c27aa43330fc1414fb78fa6e29902f811e1876f26d6eca30ae0167a3ff83fb8064046fb2212f19a7255ffdea87a470ca55bc663deeacbdddd5a82de");
    
    type shared_secret_array is array(0 to 1) of std_logic_vector(SS_SZ*8-1 downto 0);
    constant shared_secret_kat : shared_secret_array :=(
    x"9d3068b87a8a6c3ad3ffd9fa9ef810ccd075578645fc5c0a",
    x"10f27f9b903c043b1701ebc1d3a9f25813bca528e283039a");
    
    type invalid_shared_secret_array is array(0 to 1) of std_logic_vector(SS_SZ*8-1 downto 0); --For when decap ciphertext does not match
    constant invalid_shared_secret_kat : invalid_shared_secret_array :=(
    x"7d44402d2c0419665aa3fa190437eeeea807466f5700a5d8",
    x"5104a13c58e87e9c36eb62e1d4d10c796f523aba27d537b9");    
    
    signal do_read1 : std_logic_vector(8*(REG_SZ+3)-1 downto 0);
    signal do_read2 : std_logic_vector(8*(REG_SZ+3)-1 downto 0);
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

    uut : sike_p610
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
        for j in 0 to 2*KEY_LOOPS-1 loop
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
            hwrite(outline,do_read2(615 downto 0));
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
