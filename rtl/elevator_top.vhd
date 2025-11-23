
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity elevator_top is
    Generic (
        NUM_FLOORS : integer := 10;
        CLK_FREQ   : integer := 50000000
    );
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        
        -- Floor request interface
        floor_request : in  STD_LOGIC_VECTOR(3 downto 0);  -- 4 switches
        request_btn   : in  STD_LOGIC;                      -- Push button
        
        -- Outputs
        ssd_out       : out STD_LOGIC_VECTOR(6 downto 0);  -- Seven segment display
        door_open_led : out STD_LOGIC;                      -- LED for door status
        moving_up_led : out STD_LOGIC;                      -- LED for up movement
        moving_down_led : out STD_LOGIC;                    -- LED for down movement
        
        -- Debug: Request status LEDs (10 LEDs for 10 floors)
        request_leds  : out STD_LOGIC_VECTOR(NUM_FLOORS-1 downto 0)
    );
end elevator_top;

architecture Structural of elevator_top is
    signal current_floor : STD_LOGIC_VECTOR(3 downto 0);
    signal door_open     : STD_LOGIC;
    signal moving_up     : STD_LOGIC;
    signal moving_down   : STD_LOGIC;
    signal requests      : STD_LOGIC_VECTOR(NUM_FLOORS-1 downto 0);
    
    component elevator_ctrl is
        Generic (
            NUM_FLOORS : integer := 10;
            CLK_FREQ   : integer := 50000000
        );
        Port (
            clk           : in  STD_LOGIC;
            reset         : in  STD_LOGIC;
            floor_request : in  STD_LOGIC_VECTOR(3 downto 0);
            request_btn   : in  STD_LOGIC;
            current_floor : out STD_LOGIC_VECTOR(3 downto 0);
            door_open     : out STD_LOGIC;
            moving_up     : out STD_LOGIC;
            moving_down   : out STD_LOGIC;
            requests_out  : out STD_LOGIC_VECTOR(NUM_FLOORS-1 downto 0)
        );
    end component;
    
    component ssd is
        Port (
            bin_in  : in  STD_LOGIC_VECTOR(3 downto 0);
            ssd_out : out STD_LOGIC_VECTOR(6 downto 0)
        );
    end component;
    
begin
    -- Elevator controller instantiation
    ctrl: elevator_ctrl
        generic map (
            NUM_FLOORS => NUM_FLOORS,
            CLK_FREQ   => CLK_FREQ
        )
        port map (
            clk           => clk,
            reset         => reset,
            floor_request => floor_request,
            request_btn   => request_btn,
            current_floor => current_floor,
            door_open     => door_open,
            moving_up     => moving_up,
            moving_down   => moving_down,
            requests_out  => requests
        );
    
    -- Seven segment display instantiation
    display: ssd
        port map (
            bin_in  => current_floor,
            ssd_out => ssd_out
        );
    
    -- LED outputs
    door_open_led <= door_open;
    moving_up_led <= moving_up;
    moving_down_led <= moving_down;
    request_leds <= requests;
    
end Structural;