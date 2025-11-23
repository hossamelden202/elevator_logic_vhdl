library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity request_resolver is
    Generic (
        NUM_FLOORS : integer := 10
    );
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        
        floor_request : in  STD_LOGIC_VECTOR(3 downto 0);
        request_btn   : in  STD_LOGIC;
        clear_current : in  STD_LOGIC;  -- Clear current floor request
        
        current_floor : in  STD_LOGIC_VECTOR(3 downto 0);
        moving_up     : in  STD_LOGIC;
        moving_down   : in  STD_LOGIC;
        
        next_floor    : out STD_LOGIC_VECTOR(3 downto 0);
        has_request   : out STD_LOGIC;
        requests      : out STD_LOGIC_VECTOR(NUM_FLOORS-1 downto 0)
    );
end request_resolver;

architecture Behavioral of request_resolver is
    signal request_array : STD_LOGIC_VECTOR(NUM_FLOORS-1 downto 0) := (others => '0');
    signal request_btn_sync : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal request_btn_edge : STD_LOGIC;
    
    signal clear_current_prev : STD_LOGIC := '0';
    signal clear_current_edge : STD_LOGIC;
    
    signal curr_floor_int : integer range 0 to NUM_FLOORS-1;
    
begin
    curr_floor_int <= to_integer(unsigned(current_floor));
    requests <= request_array;
    
    -- Synchronize and edge detect the request button
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                request_btn_sync <= "000";
                clear_current_prev <= '0';
            else
                request_btn_sync <= request_btn_sync(1 downto 0) & request_btn;
                clear_current_prev <= clear_current;
            end if;
        end if;
    end process;
    
    request_btn_edge <= '1' when request_btn_sync(2 downto 1) = "01" else '0';
    clear_current_edge <= '1' when clear_current = '1' and clear_current_prev = '0' else '0';
    
    -- Request registration and clearing
    process(clk)
        variable floor_num : integer range 0 to NUM_FLOORS-1;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                request_array <= (others => '0');
            else
                -- Clear request when we arrive at floor (on rising edge of clear signal)
                if clear_current_edge = '1' then
                    request_array(curr_floor_int) <= '0';
                end if;

                -- Register new request on button edge
                if request_btn_edge = '1' then
                    floor_num := to_integer(unsigned(floor_request));
                    if floor_num < NUM_FLOORS then
                        request_array(floor_num) <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Request resolution logic
    -- Priority: Continue in current direction, then reverse
    process(request_array, current_floor, moving_up, moving_down)
        variable found : boolean;
        variable next_floor_int : integer range 0 to NUM_FLOORS-1;
    begin
        has_request <= '0';
        next_floor_int := curr_floor_int;
        found := false;
        
        -- Check if any requests exist
        if request_array /= (NUM_FLOORS-1 downto 0 => '0') then
            has_request <= '1';
            
            -- If moving up, check higher floors first
            if moving_up = '1' then
                -- Check floors above current
                for i in curr_floor_int+1 to NUM_FLOORS-1 loop
                    if request_array(i) = '1' and not found then
                        next_floor_int := i;
                        found := true;
                    end if;
                end loop;
                
                -- If no higher requests, check lower floors
                if not found then
                    for i in 0 to curr_floor_int-1 loop
                        if request_array(i) = '1' and not found then
                            next_floor_int := i;
                            found := true;
                        end if;
                    end loop;
                end if;
                
            -- If moving down, check lower floors first
            elsif moving_down = '1' then
                -- Check floors below current
                for i in curr_floor_int-1 downto 0 loop
                    if request_array(i) = '1' and not found then
                        next_floor_int := i;
                        found := true;
                    end if;
                end loop;
                
                -- If no lower requests, check higher floors
                if not found then
                    for i in curr_floor_int+1 to NUM_FLOORS-1 loop
                        if request_array(i) = '1' and not found then
                            next_floor_int := i;
                            found := true;
                        end if;
                    end loop;
                end if;
                
            -- If idle, find nearest request (check current floor first!)
            else
                -- Check current floor first
                if request_array(curr_floor_int) = '1' then
                    next_floor_int := curr_floor_int;
                    found := true;
                end if;
                
                -- Check above
                if not found then
                    for i in curr_floor_int+1 to NUM_FLOORS-1 loop
                        if request_array(i) = '1' and not found then
                            next_floor_int := i;
                            found := true;
                        end if;
                    end loop;
                end if;
                
                -- Then check below
                if not found then
                    for i in curr_floor_int-1 downto 0 loop
                        if request_array(i) = '1' and not found then
                            next_floor_int := i;
                            found := true;
                        end if;
                    end loop;
                end if;
            end if;
        end if;
        
        next_floor <= std_logic_vector(to_unsigned(next_floor_int, 4));
    end process;
    
end Behavioral;