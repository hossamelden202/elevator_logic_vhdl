library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity elevator_ctrl is
    generic (
        NUM_FLOORS : integer := 10;
        CLK_FREQ   : integer := 10
    );
    port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        floor_request : in  STD_LOGIC_VECTOR(3 downto 0);
        request_btn   : in  STD_LOGIC;
        current_floor : out STD_LOGIC_VECTOR(3 downto 0);
        door_open     : out STD_LOGIC;
        moving_up     : out STD_LOGIC;
        moving_down   : out STD_LOGIC;
        requests_out  : out STD_LOGIC_VECTOR(NUM_FLOORS-1 downto 0);
        next_floor_out : out STD_LOGIC_VECTOR(3 downto 0);
        has_request_out: out STD_LOGIC
    );
end elevator_ctrl;

architecture Behavioral of elevator_ctrl is
    type state_type is (IDLE_STATE, DOOR_OPEN_STATE, MOVING_UP_STATE, MOVING_DOWN_STATE);
    signal current_state, next_state : state_type := IDLE_STATE;

    signal current_floor_int : integer range 0 to NUM_FLOORS-1 := 0;
    signal next_floor_slv    : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal next_floor_int    : integer range 0 to NUM_FLOORS-1 := 0;
    signal has_request       : STD_LOGIC := '0';

    signal clk_1hz, timer_enable, timer_expired : STD_LOGIC := '0';
    signal clk_count : integer range 0 to CLK_FREQ-1 := 0;
    signal seconds_count : integer range 0 to 2 := 0;

    signal door_open_reg, moving_up_reg, moving_down_reg : STD_LOGIC := '0';
    signal requests_reg : STD_LOGIC_VECTOR(NUM_FLOORS-1 downto 0) := (others => '0');
    
    -- Signal to clear current floor request when we arrive
    signal clear_current_floor : STD_LOGIC := '0';
    
begin
    current_floor <= std_logic_vector(to_unsigned(current_floor_int, 4));
    door_open     <= door_open_reg;
    moving_up     <= moving_up_reg;
    moving_down   <= moving_down_reg;
    requests_out  <= requests_reg;

    next_floor_out <= next_floor_slv;
    has_request_out <= has_request;

    next_floor_int <= to_integer(unsigned(next_floor_slv));

    -- Generate clear signal when door opens at destination
    clear_current_floor <= '1' when (current_state = DOOR_OPEN_STATE and door_open_reg = '1') else '0';

    req_resolver: entity work.request_resolver
        generic map (NUM_FLOORS => NUM_FLOORS)
        port map (
            clk           => clk,
            reset         => reset,
            floor_request => floor_request,
            request_btn   => request_btn,
            current_floor => std_logic_vector(to_unsigned(current_floor_int, 4)),
            moving_up     => moving_up_reg,
            moving_down   => moving_down_reg,
            next_floor    => next_floor_slv,
            has_request   => has_request,
            clear_current => clear_current_floor,
            requests      => requests_reg
        );

    -- 1 Hz clock generation
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                clk_count <= 0;
                clk_1hz <= '0';
            elsif clk_count = CLK_FREQ - 1 then
                clk_count <= 0;
                clk_1hz <= '1';
            else
                clk_count <= clk_count + 1;
                clk_1hz <= '0';
            end if;
        end if;
    end process;

    -- Timer process (2 seconds)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                seconds_count <= 0;
                timer_expired <= '0';
            elsif timer_enable = '0' then
                seconds_count <= 0;
                timer_expired <= '0';
            elsif clk_1hz = '1' then
                if seconds_count = 1 then
                    seconds_count <= 0;
                    timer_expired <= '1';
                else
                    seconds_count <= seconds_count + 1;
                    timer_expired <= '0';
                end if;
            else
                timer_expired <= '0';
            end if;
        end if;
    end process;

    -- Floor counter
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_floor_int <= 0;
            else
                if timer_expired = '1' then
                    if current_state = MOVING_UP_STATE and current_floor_int < NUM_FLOORS-1 then
                        current_floor_int <= current_floor_int + 1;
                    elsif current_state = MOVING_DOWN_STATE and current_floor_int > 0 then
                        current_floor_int <= current_floor_int - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- State register
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= IDLE_STATE;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    -- Output logic
    process(current_state)
    begin
        case current_state is
            when IDLE_STATE =>
                door_open_reg   <= '0';
                moving_up_reg   <= '0';
                moving_down_reg <= '0';
            when DOOR_OPEN_STATE =>
                door_open_reg   <= '1';
                moving_up_reg   <= '0';
                moving_down_reg <= '0';
            when MOVING_UP_STATE =>
                door_open_reg   <= '0';
                moving_up_reg   <= '1';
                moving_down_reg <= '0';
            when MOVING_DOWN_STATE =>
                door_open_reg   <= '0';
                moving_up_reg   <= '0';
                moving_down_reg <= '1';
        end case;
    end process;

    -- Next state logic
    process(current_state, has_request, next_floor_int, current_floor_int, timer_expired)
        variable next_floor_pos : integer range 0 to NUM_FLOORS-1;
    begin
        next_state   <= current_state;
        timer_enable <= '0';

        case current_state is
            when IDLE_STATE =>
                if has_request = '1' then
                    if next_floor_int = current_floor_int then
                        next_state <= DOOR_OPEN_STATE;
                    elsif next_floor_int > current_floor_int then
                        next_state <= MOVING_UP_STATE;
                    else
                        next_state <= MOVING_DOWN_STATE;
                    end if;
                end if;

            when DOOR_OPEN_STATE =>
                timer_enable <= '1';
                if timer_expired = '1' then
                    next_state <= IDLE_STATE;
                end if;

            when MOVING_UP_STATE =>
                timer_enable <= '1';
                -- Check if we'll reach destination after this move
                if current_floor_int < NUM_FLOORS-1 then
                    next_floor_pos := current_floor_int + 1;
                else
                    next_floor_pos := current_floor_int;
                end if;
                
                if timer_expired = '1' and next_floor_pos = next_floor_int then
                    next_state <= DOOR_OPEN_STATE;
                end if;

            when MOVING_DOWN_STATE =>
                timer_enable <= '1';
                -- Check if we'll reach destination after this move
                if current_floor_int > 0 then
                    next_floor_pos := current_floor_int - 1;
                else
                    next_floor_pos := current_floor_int;
                end if;
                
                if timer_expired = '1' and next_floor_pos = next_floor_int then
                    next_state <= DOOR_OPEN_STATE;
                end if;
        end case;
    end process;
    
end Behavioral;