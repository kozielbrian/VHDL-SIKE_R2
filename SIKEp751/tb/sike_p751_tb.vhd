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

entity sike_p751_tb is
--  Port ( );
end sike_p751_tb;

architecture Behavioral of sike_p751_tb is

    constant PERIOD : time := 5000 ps;
    
    constant TEST_WITHOUT_CFK : boolean := true;
    constant TEST_WITH_CFK : boolean := false;

component sike_p751 is
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
end component sike_p751; 

    constant REG_SZ : integer := 94;
    constant REG_LOOPS : integer := 12;
    constant MSG_SZ : integer := 32;
    constant MSG_LOOPS : integer := 4;
    constant PK_SZ : integer := 6*REG_SZ;
    constant KEY_SZ : integer := 48;
    constant KEY_LOOPS : integer := 6;
    constant SK_SZ : integer := MSG_SZ+PK_SZ+KEY_SZ;
    constant CT_SZ : integer := MSG_SZ+PK_SZ;
    constant SS_SZ : integer := 32;
    constant SS_LOOPS : integer := 4;

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
    x"00099e26e7882be6a8ee9be91032597824fdc6098c580842bb7317ad624af816efeab07e39fa517ed54ce4b8c7fa1362",
    x"00065c7f6e55cfc1e490affdafeef3743dc1ee895505635385dd8b5e82764f96ab7b395ea82a1cbbba1a51d67f560cb5"
    );
    
    type bob_key_array is array(0 to 1) of std_logic_vector(8*KEY_SZ-1 downto 0);
    constant bob_keys_hex : bob_key_array :=(
    x"0102505c57d33805e406218589720aab8ffb2b878b9efa90dc137d406760550e21f856b9593be000081451d479ed2686",
    x"030303f6c2d77af80a7997ff1879323f72f60ba4eab0f165f76cba6ca646b343308546cbd51e72b88572f21c53713200"
    );
    
    
    type mont_constants_array is array(0 to 6) of std_logic_vector(8*(REG_SZ+2)-1 downto 0);
    constant mont_array_hex : mont_constants_array :=(
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --0
    x"00002d5b24bce5e210f7926c7512c7e94ca4b439d2076956c89db7b2ac5c4e2e697797bf3f4f24d05527b1e4375c6c668310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000249ad", --mont 1
    x"00005ab64979cbc421ef24d8ea258fd299496873a40ed2ad913b6f6558b89c5cd2ef2f7e7e9e49a0aa4f63c86eb8d8cd06200000000000000000000000000000000000000000000000000000000000000000000000000000000000000004935a", --mont 2
    x"000041ad830f1f3506c905261132294b5673ed2c6a6ac82a441dd47b735f9c90b56c383ccdb607c5a24f4d80c1048e181f735f1f1ee7fc814932cca8904f8751f40bfe2082a2e7065e36941472e3fd8edb010161a696452a233046449dad4058", --R^2
    x"000027503e7fb73f87c288c303336913f481da4f8bae7027b43b1406a0d20da951034cb654d1bc51ce45121a60553943dc700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000926b", --4^-1
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", --1
    x"0000305731e9751449a84d4b8efaf6aac116cf5232c7c978a3151d605c520428c3a2584753eb43f43714fe4eb83999153500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dba10" --mont 6
    );
    
    type params_array is array(0 to 30) of std_logic_vector(8*(REG_SZ+2)-1 downto 0);
    constant params_hex : params_array :=(
    x"00000000000000000000000000000000000000000000000000000000000000000027381751ecf0e4ee4defae8f9275f3e2e66b7d64c50c5689443a8710583debbedd5e4a7aec65c2f393401ccfbba0942d90fe01606c035116a50459621e1361", --R0
    x"00000000000000000000000000000000000000000000000000000000000000000031de228c1a87369f4b56d2ab00ca3ee9896e777218d06eec35bea10a3bf4d9c097ce1389a5b1d8560d8297d4d495104513e9a493548b905e5c7474fdec65ff", --R1
    x"0000000000000000000000000000000000000000000000000000000000000000004025944fefc8ef35ae2cd6def04b77aa8323f6a17739631b6ebfdd447364c8959f352e4983b1175698042793a9ba74a4ae0b71d637d8f2005075e8e99662ae", --R2
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006", --A.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A24.a Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --A24.b Unused
    x"0000158abf500b5914b3a96ced5fdb37d6dd925f2d6e4f7fea3cc16e1085754077737ea6f8cc74938d971da289dcf2435bcac1897d2627693f9bb167dc01be34ac494c60b8a0f65a28d7a31ea0d54640653a8099ce5a84e4f0168d818af02041", --PAx.a
    x"00004514f8cc94b140f24874f8b87281fa6004ca5b3637c68ac0c0bdb29838051f385fbbcc300bbb24bfbbf6710d7dc8b29acb81e429bd1bd5629ad0ecad7c90622f6bb801d0337ee6bc78a7f12fdcb09decfae8bfd643c89c3bac1d87f8b6fa", --PAx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PAy.a Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PAy.b Unused
    x"00002569d7eafb6c60b244ef49e05b5e23f73c4f44169a7e02405e90ceb680cb0756054ac0e3dce95e2950334262cc973235c2f87d89500bcd465b078bd0debdf322a2f86aedfdcfee65c09377efba0c5384dd837bedb710209fbc8ddb8c35c7", --QAx.a
    x"00001723d2bfa01a78bf4e39e3a333f8a7e0b415a17f208d3419e7591d59d8abdb7ee6d2b2dfcb21ac29a40f837983c0f057fd041ad93237704f1597d87f074f682961a38b5489d1019924f8a0ef5e4f1b2e64a7ba536e219f5090f76276290e", --QAx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QAy.a Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QAy.b Unused
    x"000050e30c2c06494249bc4a144eb5f31212bd05a2af0cb3064c322fc3604fc5f5fe3a08fb3a02b05a48557e15c992254ffc8910b72b8e1328b4893cdcfbfc003878881ce390d909e39f83c5006e0ae979587775443483d13c65b107fada5165", --QPAx.a
    x"00006066e07f3c0d964e8bc963519fac8397df477aea9a067f3be343bc53c883af29ccf008e5a30719a29357a8c33eb3600cd078af1c40ed5792763a4d213ebde44cc623195c387e0201e7231c529a15af5ab743ee9e7c9c37af3051167525bb", --QPAx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPAy.a Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPAy.b Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBx.a
    x"0000605d4697a245c394b98024a5554746dc12ff56d0c6f15d2f48123b6d9c498eee98e8f7cd6e216e2f1ff7ce0c969cca29caa2faa57174ef985ac0a504260018760e9fdf67467e20c13982ff5b49b8beab05f6023af873f827400e453432fe", --PBx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBy.a Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --PBy.b Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBx.a
    x"00005bf9544781803cbd7e0ea8b96d934c5cbca970f9cc327a0a7e4dad931ec29baa8a854b8a9fde5409af96c5426fa375d99c68e9ae714172d7f04502d45307fa4839f39a28338bbafd54a461a535408367d5132e6aa0d3da6973360f8cd0f1", --QBx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBy.a Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QBy.b Unused
    x"00005ac57eafd6cc7569e8b53a148721953262c5b404c143380adcc184b6c21f0cafe095b7e9c79ca88791f9a72f1b2f3121829b2622515b694a16875ed637f421b539e66f2fef1ce8dcefc8aea608055e9c44077266ab64611bf851ba06c821", --QPBx.a
    x"000055e5124a05d4809585f67fe9ea1f02a06cd411f38588bb631bf789c3f98d1c3325843bb53d9b011d8bd1f682c0e4d8a5e723364364e40dad1b7a476716ac7d1ba705ccdd680bfd4fe4739cc21a9a59ed544b82566bf633e8950186a79fe3", --QPBx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --QPBy.a Unused
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"); --QPBy.b Unused

    type kat1_results_array is array(0 to 35) of std_logic_vector(8*(REG_SZ+2)-1 downto 0); --For KAT0 only
    constant kat1_results_hex : kat1_results_array :=(
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA.b
    x"000002e3adc5049739f6b84a47c6bbf6bc414cfbeb299d5d871acc7e92bec52d97feb0c53ccab0e80997ccd6ad992303898510e7d605bf4ce0bf2dbf601c6be2c658a04b7cf83c6d50c962117a8b1028714338ff826948a8c2dd5e1148f0beaf", --j(EAB).a
    x"00002e021455fad7ce37fa75a6a52022cde5ca475a17023249d504fd66b89dce16cea9fb3d192c63f9323132dacd8ed66f2b1ae7005090e631616ffbadddc7feab61954b9ed08ec7d7ec2619b3a0ae89ae89573ed54dd7d79e2d74711ccaf7ea", --j(EAB).b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA24.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EA24.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB.b
    x"000002e3adc5049739f6b84a47c6bbf6bc414cfbeb299d5d871acc7e92bec52d97feb0c53ccab0e80997ccd6ad992303898510e7d605bf4ce0bf2dbf601c6be2c658a04b7cf83c6d50c962117a8b1028714338ff826948a8c2dd5e1148f0beaf", --j(EBA).a
    x"00002e021455fad7ce37fa75a6a52022cde5ca475a17023249d504fd66b89dce16cea9fb3d192c63f9323132dacd8ed66f2b1ae7005090e631616ffbadddc7feab61954b9ed08ec7d7ec2619b3a0ae89ae89573ed54dd7d79e2d74711ccaf7ea", --j(EBA).b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB24.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --EB24.b
    x"000010852f8cb0150dacc773765c7d62602ffe62105b9984e82e9d7e70db3e5462e894a1abb86ac7f661feef934cf4a2422377b892da07516cc8d67591edb05e4befebaa63162e17a52f4111dce2f0ac9c8638e30d21949c8536cd21408b6517", --phiPBx.a
    x"00000b41c8048029614f36f2549bc5865021ce1cb9743573c4b0a76da3e67243dc311d2d7ea9b3285853e4d0a55ac6c653e82ce668146f86a986eab9c98161fb702adabee053549bfd903bc95e7983f5c13e1dec261bf012e32e0b63c44bd266", --phiPBx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPBy.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPBy.b
    x"00004fe9b0d94b542dd8f462368af54fa44bfb181aa3544da678e463bb5308116a5c76892f2e2f1dc47fd536a3f18602e34a78dd70680ecbd190c85ed8eb26270edeeeffc2580a936dd0f2e54f3eabfec99b591c5f339fbcdf0acb55852d7d44", --phiQBx.a
    x"00001a3eb4efc89af47a58adce946abdd05b87a529642cb4393f88bc5c81cf3ea7f3ac32fe6bb8fea1c44ec672a9584250c1ce083a37d65af7c0ab6a436b1b585c50fe47a52cedbe89097075fd86734579855acbd1f67368d42ab3b1639423dc", --phiQBx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQBy.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQBy.b
    x"0000409c23b0d1da974b9cf71e6c0cd5e3db13aee0e66eb25828b2ed5e7e54141b995f229524b1c8c2c942cfe04605743408807c5f8235323dceecb849b6d1fea9392f6bb37e832ca45033780ba8fb87ce960e562abe1df3cb1c26df0bf3ccc5", --phiQPBx.a
    x"00006376a47e851540e1ddb1ba6f9423f577922dab22d6831e8309baefe769d3c349192fb1bedb036027045553d2c34b03eaf7d3977067df47c016ce93048542a4ac2c0a0ce587c9ec348893c8281a4aa057b362215f4b08f6d5274d4ebc8ac8", --phiQPBx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPBy.a not used
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPBy.b not used
    x"00000eabceb6140563946ecf44d7fe940a87f2c904710b3c34c773aee78ae8ccf25660d080392497261c7c611203c515a27d3f6a424db13ede44071a090468de21b989d06e5efcfec76583ba5090ff682567fdf0c42dcd02b0acc38185527a9a", --phiPAx.a
    x"000037c189d37593e03c199af8d78605f966b6164a3a3564a290f60bddfd8c97f51d83070a9208e40bb0de1536927b518219a57b7ea2f1a74bc777655a1526fd631fc5ff58d0d902b2d867a0f2c1063c1369b15b7b07d886fe8b410dec58a7e1", --phiPAx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPAy.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiPAy.b
    x"0000639524c18ef7801f2211f6ef904b0324f143d90ee63dcb88a3c597f2098d980a24b20f4435d5c34346a13e4752406806af2aa3e4de25f47b51bd0168f9cc3346a8ae5a2fd9340ad54c8797a6d80337604f51bfa6d4717287800f8ec92563", --phiQAx.a
    x"000066e980bc94c1140f66af72d38ec57f1438e61990b07c4d336ee2e483bf7c17e78d309f0e3333ae0125c80f3cf755c2c8c491bdab525d66ed3d773091ebf9b5e893fabbc8d98c9dd8658d2487c58bbe5c47106020d8e531b967fab63b7364", --phiQAx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQAy.a
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQAy.b
    x"0000355104dcf2039eab50c9a741967259015a7fc4bdfd06af522b1b917438694b82be07e86134d0868546b2bb80889e4020025f11433dc2f46114b357c205c37791c9637f6da95e82ddbc62e476001ae58b9ebf9de93d3fdcf13eb36ab54012", --phiQPAx.a
    x"0000294fa83e537e01e7d3661bcbbb3b94f1beba14268b86e06f3e952f1a74f6e1665a65b1032ea206443af913c7cd5b5ab80719f29c21d3031a6a344ea9e20c7ded937a97f4ddf9e64a2e126fd897fb1043615dbdbf487e3d066b63f605a138", --phiQPAx.b
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", --phiQPAy.a not used
    x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"); --phiQPAy.b not used)
    
    type secret_msg_alice_array is array(0 to 1) of std_logic_vector(8*MSG_SZ-1 downto 0);
    constant secret_msg_alice_array_hex : secret_msg_alice_array :=(
    x"2d7f73369973cd2d0348b1cc251ad82fdd1a6bdbe4106d0caa9476b0a035997c",
    x"d926f38a65787a0e173fa91081ee6c40f33731730bfca67b1c8c1d2a49930bd6");
 
    type secret_msg_bob_array is array(0 to 1) of std_logic_vector(8*MSG_SZ-1 downto 0);
    constant secret_msg_bob_array_hex : secret_msg_bob_array :=(
    x"4d42999c83df029efefcc84fab77ad7c78568d676708ca46217761a93b565562",
    x"e5fdcb363c0aa3bcf8a6b7b17619a9f73a70c40de7244c53c8dc54b5d1610c0b");   
 
    signal public_key : std_logic_vector(PK_SZ*8-1 downto 0) := (others => '0');
    signal secret_key : std_logic_vector(SK_SZ*8-1 downto 0) := (others => '0');
    signal cipher_text : std_logic_vector(CT_SZ*8-1 downto 0) := (others => '0');
    signal shared_secretA : std_logic_vector(SS_SZ*8-1 downto 0) := (others => '0');
    signal shared_secretB : std_logic_vector(SS_SZ*8-1 downto 0) := (others => '0');  
    
    type public_key_array is array(0 to 1) of std_logic_vector(PK_SZ*8-1 downto 0);
    constant public_key_kat : public_key_array :=(
    x"355104dcf2039eab50c9a741967259015a7fc4bdfd06af522b1b917438694b82be07e86134d0868546b2bb80889e4020025f11433dc2f46114b357c205c37791c9637f6da95e82ddbc62e476001ae58b9ebf9de93d3fdcf13eb36ab54012294fa83e537e01e7d3661bcbbb3b94f1beba14268b86e06f3e952f1a74f6e1665a65b1032ea206443af913c7cd5b5ab80719f29c21d3031a6a344ea9e20c7ded937a97f4ddf9e64a2e126fd897fb1043615dbdbf487e3d066b63f605a138639524c18ef7801f2211f6ef904b0324f143d90ee63dcb88a3c597f2098d980a24b20f4435d5c34346a13e4752406806af2aa3e4de25f47b51bd0168f9cc3346a8ae5a2fd9340ad54c8797a6d80337604f51bfa6d4717287800f8ec9256366e980bc94c1140f66af72d38ec57f1438e61990b07c4d336ee2e483bf7c17e78d309f0e3333ae0125c80f3cf755c2c8c491bdab525d66ed3d773091ebf9b5e893fabbc8d98c9dd8658d2487c58bbe5c47106020d8e531b967fab63b73640eabceb6140563946ecf44d7fe940a87f2c904710b3c34c773aee78ae8ccf25660d080392497261c7c611203c515a27d3f6a424db13ede44071a090468de21b989d06e5efcfec76583ba5090ff682567fdf0c42dcd02b0acc38185527a9a37c189d37593e03c199af8d78605f966b6164a3a3564a290f60bddfd8c97f51d83070a9208e40bb0de1536927b518219a57b7ea2f1a74bc777655a1526fd631fc5ff58d0d902b2d867a0f2c1063c1369b15b7b07d886fe8b410dec58a7e1",
    x"5b57824c507e2b92ecca8d4e39785c40085838e81a1b4f6aedfae4dd3e98151661d5d76679d2131758f863d265248243a068b4ce9c6d254bc9721e904dd186b9d404a7383ff74bb3b936412b0a4b5e3dccb6e343092315e8de37e990bc4401c666e03bcaa720774d4e1acfc570d899de46bb2c40b64ccc016a397f01f5d3e6895f149221e5cd9260999afc15248a3578ad281e0a0072023b8252fb5a7f11b8d960e82cb83094d095733cc1ea9c5404d671aa68943fa0b5034d375e3f5095d0a73787f66be9f63777fae3781f57734354beb1f7883c151723df186b55ea7edb6a07587c3f8be75f96f54fcc8b1605941340acb0e73803bfa7fef65d9c5a8e75026eeb951e9ff0b28dba8f7f24c4cce005b8845b2f3cd2c79a496e58fdd79da4119306142f094f65b6f339d28e13e4e7b5b52ee607c9e1a065708d6aef6e4d9040397403da94b1c70399dcbe48db4c7621bc1cc1c07b108363a607219a729aced055d270096c21ac6d9c4659418306b5a0b1a2af87a62f96672e586b9c56af93401669846a99fdd7646ec85fd0363184a7bf8a6e1c9e2941dd1d171b6b464d9128ee9096962b82afcb604768c07a86ced281f8f3318a3d91b7e78ca4af6d8c3b92f3107d11477fcf2523f64ca47569b31014f26e3fc7e14dda22231fe4800ee434a7dc6ccf181748671ab1112abcc6fc94bc4d153c5b89e62e3018067b0f44caa2f256e4b4619b93a0c221ce54df9b7266171943f2da9f307edec3298a937bc84b9a8f2d3935ba18dd636166d626bae20123d1e0eb");    
    
    type secret_key_array is array(0 to 1) of std_logic_vector(SK_SZ*8-1 downto 0);
    constant secret_key_kat : secret_key_array :=(
    x"355104dcf2039eab50c9a741967259015a7fc4bdfd06af522b1b917438694b82be07e86134d0868546b2bb80889e4020025f11433dc2f46114b357c205c37791c9637f6da95e82ddbc62e476001ae58b9ebf9de93d3fdcf13eb36ab54012294fa83e537e01e7d3661bcbbb3b94f1beba14268b86e06f3e952f1a74f6e1665a65b1032ea206443af913c7cd5b5ab80719f29c21d3031a6a344ea9e20c7ded937a97f4ddf9e64a2e126fd897fb1043615dbdbf487e3d066b63f605a138639524c18ef7801f2211f6ef904b0324f143d90ee63dcb88a3c597f2098d980a24b20f4435d5c34346a13e4752406806af2aa3e4de25f47b51bd0168f9cc3346a8ae5a2fd9340ad54c8797a6d80337604f51bfa6d4717287800f8ec9256366e980bc94c1140f66af72d38ec57f1438e61990b07c4d336ee2e483bf7c17e78d309f0e3333ae0125c80f3cf755c2c8c491bdab525d66ed3d773091ebf9b5e893fabbc8d98c9dd8658d2487c58bbe5c47106020d8e531b967fab63b73640eabceb6140563946ecf44d7fe940a87f2c904710b3c34c773aee78ae8ccf25660d080392497261c7c611203c515a27d3f6a424db13ede44071a090468de21b989d06e5efcfec76583ba5090ff682567fdf0c42dcd02b0acc38185527a9a37c189d37593e03c199af8d78605f966b6164a3a3564a290f60bddfd8c97f51d83070a9208e40bb0de1536927b518219a57b7ea2f1a74bc777655a1526fd631fc5ff58d0d902b2d867a0f2c1063c1369b15b7b07d886fe8b410dec58a7e10102505c57d33805e406218589720aab8ffb2b878b9efa90dc137d406760550e21f856b9593be000081451d479ed26862d7f73369973cd2d0348b1cc251ad82fdd1a6bdbe4106d0caa9476b0a035997c",
    x"5b57824c507e2b92ecca8d4e39785c40085838e81a1b4f6aedfae4dd3e98151661d5d76679d2131758f863d265248243a068b4ce9c6d254bc9721e904dd186b9d404a7383ff74bb3b936412b0a4b5e3dccb6e343092315e8de37e990bc4401c666e03bcaa720774d4e1acfc570d899de46bb2c40b64ccc016a397f01f5d3e6895f149221e5cd9260999afc15248a3578ad281e0a0072023b8252fb5a7f11b8d960e82cb83094d095733cc1ea9c5404d671aa68943fa0b5034d375e3f5095d0a73787f66be9f63777fae3781f57734354beb1f7883c151723df186b55ea7edb6a07587c3f8be75f96f54fcc8b1605941340acb0e73803bfa7fef65d9c5a8e75026eeb951e9ff0b28dba8f7f24c4cce005b8845b2f3cd2c79a496e58fdd79da4119306142f094f65b6f339d28e13e4e7b5b52ee607c9e1a065708d6aef6e4d9040397403da94b1c70399dcbe48db4c7621bc1cc1c07b108363a607219a729aced055d270096c21ac6d9c4659418306b5a0b1a2af87a62f96672e586b9c56af93401669846a99fdd7646ec85fd0363184a7bf8a6e1c9e2941dd1d171b6b464d9128ee9096962b82afcb604768c07a86ced281f8f3318a3d91b7e78ca4af6d8c3b92f3107d11477fcf2523f64ca47569b31014f26e3fc7e14dda22231fe4800ee434a7dc6ccf181748671ab1112abcc6fc94bc4d153c5b89e62e3018067b0f44caa2f256e4b4619b93a0c221ce54df9b7266171943f2da9f307edec3298a937bc84b9a8f2d3935ba18dd636166d626bae20123d1e0eb030303f6c2d77af80a7997ff1879323f72f60ba4eab0f165f76cba6ca646b343308546cbd51e72b88572f21c53713200d926f38a65787a0e173fa91081ee6c40f33731730bfca67b1c8c1d2a49930bd6");

    type cipher_text_array is array(0 to 1) of std_logic_vector(CT_SZ*8-1 downto 0);
    constant cipher_text_kat : cipher_text_array :=(
    x"12c4473669f23a75d2b8341b1a6a217c0e904813c87e520e5e50e19ec2aac137409c23b0d1da974b9cf71e6c0cd5e3db13aee0e66eb25828b2ed5e7e54141b995f229524b1c8c2c942cfe04605743408807c5f8235323dceecb849b6d1fea9392f6bb37e832ca45033780ba8fb87ce960e562abe1df3cb1c26df0bf3ccc56376a47e851540e1ddb1ba6f9423f577922dab22d6831e8309baefe769d3c349192fb1bedb036027045553d2c34b03eaf7d3977067df47c016ce93048542a4ac2c0a0ce587c9ec348893c8281a4aa057b362215f4b08f6d5274d4ebc8ac84fe9b0d94b542dd8f462368af54fa44bfb181aa3544da678e463bb5308116a5c76892f2e2f1dc47fd536a3f18602e34a78dd70680ecbd190c85ed8eb26270edeeeffc2580a936dd0f2e54f3eabfec99b591c5f339fbcdf0acb55852d7d441a3eb4efc89af47a58adce946abdd05b87a529642cb4393f88bc5c81cf3ea7f3ac32fe6bb8fea1c44ec672a9584250c1ce083a37d65af7c0ab6a436b1b585c50fe47a52cedbe89097075fd86734579855acbd1f67368d42ab3b1639423dc10852f8cb0150dacc773765c7d62602ffe62105b9984e82e9d7e70db3e5462e894a1abb86ac7f661feef934cf4a2422377b892da07516cc8d67591edb05e4befebaa63162e17a52f4111dce2f0ac9c8638e30d21949c8536cd21408b65170b41c8048029614f36f2549bc5865021ce1cb9743573c4b0a76da3e67243dc311d2d7ea9b3285853e4d0a55ac6c653e82ce668146f86a986eab9c98161fb702adabee053549bfd903bc95e7983f5c13e1dec261bf012e32e0b63c44bd266",
    x"9a44125848d4d9fd92e5e8ff2897ab032379133e70ef8edf5314629d7671b12a56e49fbb810ab314da4252295b3df020444b4aed04d24fff17fdea56093c7e341f9ab06bb0d5250050ba228fdec9bebdf56adb5a41c5b1abca228dc3022fb90cc7eec54af90640edd2d0b6b50a9c1739bc89c33ab0ba4f71a9959705cc42439015b54eea8c8de1e4886d2d3824eecdb55884d7fc031811cc454eccfae8cf574300d7e51a95dcd3572840fe2f86f3a1ce91090d8c8bcda0c8fda596c3c52bcc45bc0232f17a1404fe4aaa627ee7945a327269c9db12e41186b636140904c6323b111e13088f69f44311ae4c26664b1e5cc89f37bdf59d5f003b98150ed47bb360f98da6716530c552665034cdde328cc7e097c051951ae88a3cb7cff75731e65b5b4b206f2cd1dc93b83c64c50786bdfef33769a54cbcc0e80a8730d5dc4e5c8cd105bc2251750dcecf54f8c9e1fc13ea2b8076173fe4b851eba48802399dd9688334d992316bf55c36b9d865c38838d7f30d31e5901b7dda8e32a4d4238929d35196197b7456ed2b60f0571d4d423eb343bd23a86466d0643982e73e292e89d6494cadaca3c414d518ca5ffc1956a15d57fd69ae95e973bcaab55c766e149612350f013e76618b074b19b53f295e5ea34f379ec94c89fc95d246c3cbe8e93acc9a5982c069bc1d386070d3c74ea6d4087e0474809464561b791a13e0c17a4935a50644035f523f0d951083b16b53d623428ad1535617e78eb0e8df54031608a28db48dcc7d1d347c9f6a7fbed23f500a7368e01d8d4c4da450f09fe4fdf2d6cf96c6beaf4de8a2c2dfd77fa07af885b253971ed1");
    
    type shared_secret_array is array(0 to 1) of std_logic_vector(SS_SZ*8-1 downto 0);
    constant shared_secret_kat : shared_secret_array :=(
    x"86f7a7b875aa0a1da44a60bfeb351010da58854d4d043c11505ca0e89545e9fe",
    x"bcc07e57a6a6834f746507df1efde65af289b69d2da7b53562d89f09318df6a8");
    
    type invalid_shared_secret_array is array(0 to 1) of std_logic_vector(SS_SZ*8-1 downto 0); --For when decap ciphertext does not match
    constant invalid_shared_secret_kat : invalid_shared_secret_array :=(
    x"b4e75484a79f4679072b7e0ab73249e855b077adedd11022ea899dd20b2cf2bb",
    x"d8eba3c2926a082de07a27440d125d4427527bd0f52acb346c8ab8349eff62ee");    
    
    signal do_read1 : std_logic_vector(8*(REG_SZ+2)-1 downto 0);
    signal do_read2 : std_logic_vector(8*(REG_SZ+2)-1 downto 0);
    signal addr_part_1 : std_logic_vector(7 downto 0);
    signal w_one_8     : std_logic_vector(7 downto 0) := "00000001";
    signal w_addr_inc : std_logic_vector(2 downto 0);
    signal w_one_3      : std_logic_vector(2 downto 0) := "001";
    signal combine_key : std_logic_vector(8*(REG_SZ+2)-1 downto 0);

begin

    -- 200 MHz clock
    oscillator : process
    begin
        clk <= '0';
        wait for PERIOD/2;
        clk <= '1';
        wait for PERIOD/2;
    end process oscillator;   

    uut : sike_p751
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
            hwrite(outline,do_read2(751 downto 0));
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
