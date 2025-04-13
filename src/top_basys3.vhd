library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


-- Lab 4
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(15 downto 0);
        btnU    :   in std_logic; -- master_reset
        btnL    :   in std_logic; -- clk_reset
        btnR    :   in std_logic; -- fsm_reset
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is

    -- signal declarations
    signal w_clk_fsm : std_logic;
    signal w_clk_tdm : std_logic;
    signal w_btn_fsm : std_logic;
    signal w_btn_clk : std_logic;
    signal w_floor1 : std_logic_vector (3 downto 0);
    signal w_floor2 : std_logic_vector (3 downto 0);
    signal w_data : std_logic_vector (3 downto 0);
  
	-- component declarations
    component sevenseg_decoder is
        port (
            i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component sevenseg_decoder;
    
    component elevator_controller_fsm is
		Port (
            i_clk        : in  STD_LOGIC;
            i_reset      : in  STD_LOGIC;
            is_stopped   : in  STD_LOGIC;
            go_up_down   : in  STD_LOGIC;
            o_floor : out STD_LOGIC_VECTOR (3 downto 0)		   
		 );
	end component elevator_controller_fsm;
	
	component TDM4 is
		generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
        Port ( i_clk		: in  STD_LOGIC;
           i_reset		: in  STD_LOGIC; -- asynchronous
           i_D3 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D2 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D1 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D0 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_data		: out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_sel		: out STD_LOGIC_VECTOR (3 downto 0)	-- selected data line (one-cold)
	   );
    end component TDM4;
     
	component clock_divider is
        generic ( constant k_DIV : natural := 2	); -- How many clk cycles until slow clock toggles
                                                   -- Effectively, you divide the clk double this 
                                                   -- number (e.g., k_DIV := 2 --> clock divider of 4)
        port ( 	i_clk    : in std_logic;
                i_reset  : in std_logic;		   -- asynchronous
                o_clk    : out std_logic		   -- divided (slow) clock
        );
    end component clock_divider;
    
    constant k_clock_divs1	: natural	:= 25000000;
    constant k_clock_divs2	: natural	:= 50000;
	
begin
	-- PORT MAPS ----------------------------------------
	
	sevenseg_decoder_inst : sevenseg_decoder
	port map(
	   i_Hex(3) => w_data(3),
	   i_Hex(2) => w_data(2),
	   i_Hex(1) => w_data(1),
	   i_Hex(0) => w_data(0),
	   o_seg_n(6) => seg(6),
	   o_seg_n(5) => seg(5),
	   o_seg_n(4) => seg(4),
	   o_seg_n(3) => seg(3),
	   o_seg_n(2) => seg(2),
	   o_seg_n(1) => seg(1),
	   o_seg_n(0) => seg(0)
	);
	
	
	elevator_controller_fsm_1: elevator_controller_fsm
	port map(
	   is_stopped => sw(0),
	   go_up_down => sw(1),
	   i_reset => w_btn_fsm,
	   i_clk => w_clk_fsm,
	   o_floor(3) => w_floor1(3),
	   o_floor(2) => w_floor1(2),
	   o_floor(1) => w_floor1(1),
	   o_floor(0) => w_floor1(0)
	);
	
	elevator_controller_fsm_2: elevator_controller_fsm
	port map(
	   is_stopped => sw(14),
	   go_up_down => sw(15),
	   i_reset => w_btn_fsm,
	   i_clk => w_clk_fsm,
	   o_floor(3) => w_floor2(3),
	   o_floor(2) => w_floor2(2),
	   o_floor(1) => w_floor2(1),
	   o_floor(0) => w_floor2(0)
	);
	
	clkdiv1 : clock_divider 		--instantiation of clock_divider to take 
        generic map ( k_DIV => k_clock_divs1 ) -- 2 Hz clock from 100 MHz
        port map (						  
            i_clk   => clk,
            i_reset => w_btn_clk,
            o_clk   => w_clk_fsm
        );
        
    clkdiv2 : clock_divider 		--instantiation of clock_divider to take 
        generic map ( k_DIV => k_clock_divs2 ) -- 1 Hz clock from 100 MHz
        port map (						  
            i_clk   => clk,
            i_reset => w_btn_clk,
            o_clk   => w_clk_tdm
        );
        
    tdm_inst : TDM4
	port map(
	   i_clk => w_clk_tdm,
	   i_reset => btnU,
	   i_D3 => x"F",
	   i_D2 => w_floor2,
	   i_D1 => x"F",
	   i_D0 => w_floor1,
	   o_sel => an,
	   o_data => w_data
	);    
    	
	
	-- CONCURRENT STATEMENTS ----------------------------
	
	-- LED 15 gets the FSM slow clock signal. The rest are grounded.
	led(15) <= w_clk_fsm;
	led(14 downto 0) <= (others => '0');
	-- leave unused switches UNCONNECTED. Ignore any warnings this causes.
	
	-- reset signals
	w_btn_fsm <= btnU or btnR;
	w_btn_clk <= btnU or btnL;
	
end top_basys3_arch;
