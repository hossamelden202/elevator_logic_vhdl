library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity elevator_ctrl_tb is
end elevator_ctrl_tb;

architecture Behavioral of elevator_ctrl_tb is
    -- Component declaration
    component elevator_ctrl is
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
            requests_out  : out STD_LOGIC_VECTOR(9 downto 0);
            next_floor_out : out STD_LOGIC_VECTOR(3 downto 0);
            has_request_out: out STD_LOGIC
        );
    end component;
    
    -- Test parameters
    constant CLK_PERIOD : time := 100 ns;
    constant NUM_FLOORS : integer := 10;
    constant CLK_FREQ   : integer := 10;
    constant ONE_SECOND : time := CLK_PERIOD * CLK_FREQ;
    constant MOVE_TIME  : time := ONE_SECOND * 2;
    constant DOOR_TIME  : time := ONE_SECOND * 2;
    
    -- Signals
    signal clk           : STD_LOGIC := '0';
    signal reset         : STD_LOGIC := '0';
    signal floor_request : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal request_btn   : STD_LOGIC := '0';
    signal current_floor : STD_LOGIC_VECTOR(3 downto 0);
    signal door_open     : STD_LOGIC;
    signal moving_up     : STD_LOGIC;
    signal moving_down   : STD_LOGIC;
    signal requests_out  : STD_LOGIC_VECTOR(9 downto 0);
    signal next_floor_out : STD_LOGIC_VECTOR(3 downto 0);
    signal has_request_out: STD_LOGIC;
    
    -- Test control
    signal test_done : boolean := false;
    signal test_passed : boolean := true;
    
begin
    -- Clock generation
    clk_process: process
    begin
        while not test_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- DUT instantiation
    DUT: elevator_ctrl
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
            requests_out  => requests_out,
            next_floor_out => next_floor_out,
            has_request_out => has_request_out
        );
    
    -- Main test process
    test_process: process
        -- Procedure to request a floor
        procedure request_floor(
            floor : in integer;
            signal floor_req : out STD_LOGIC_VECTOR(3 downto 0);
            signal req_btn : out STD_LOGIC
        ) is
        begin
            floor_req <= std_logic_vector(to_unsigned(floor, 4));
            wait for CLK_PERIOD;
            req_btn <= '1';
            wait for CLK_PERIOD * 2;
            req_btn <= '0';
            wait for CLK_PERIOD;
        end procedure;
        
        -- Procedure to wait for door to open
        procedure wait_for_door_open(
            signal door : in STD_LOGIC;
            timeout : in time
        ) is
            variable start_time : time := now;
        begin
            wait for CLK_PERIOD;
            while door = '0' loop
                wait for CLK_PERIOD;
                if (now - start_time) > timeout then
                    report "TIMEOUT waiting for door to open at time " & time'image(now) severity error;
                    test_passed <= false;
                    exit;
                end if;
            end loop;
            report "Door opened at time " & time'image(now);
        end procedure;
        
        -- Procedure to wait for door to close
        procedure wait_for_door_close(
            signal door : in STD_LOGIC;
            timeout : in time
        ) is
            variable start_time : time := now;
        begin
            wait for CLK_PERIOD;
            while door = '1' loop
                wait for CLK_PERIOD;
                if (now - start_time) > timeout then
                    report "TIMEOUT waiting for door to close at time " & time'image(now) severity error;
                    test_passed <= false;
                    exit;
                end if;
            end loop;
            report "Door closed at time " & time'image(now);
        end procedure;
        
        -- Procedure to check current floor
        procedure check_floor(
            expected : in integer;
            signal actual : in STD_LOGIC_VECTOR(3 downto 0);
            test_name : in string
        ) is
        begin
            if to_integer(unsigned(actual)) /= expected then
                report "FAIL: " & test_name & " - Expected floor " & 
                       integer'image(expected) & ", got " & 
                       integer'image(to_integer(unsigned(actual))) severity error;
                test_passed <= false;
            else
                report "PASS: " & test_name & " - Floor is " & integer'image(expected);
            end if;
        end procedure;
        
    begin
        report "========================================";
        report "Starting Elevator Controller Testbench";
        report "========================================";
        
        -- Test 1: Reset test
        report "TEST 1: Reset Test";
        reset <= '1';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD * 2;
        check_floor(0, current_floor, "After reset");
        assert door_open = '0' report "FAIL: Door should be closed after reset" severity error;
        
        -- Test 2: Single floor request - Move up
        report "TEST 2: Single Floor Request - Move Up to Floor 3";
        wait for CLK_PERIOD * 10;
        report "Starting from floor: " & integer'image(to_integer(unsigned(current_floor)));
        request_floor(3, floor_request, request_btn);
        wait for CLK_PERIOD * 2;
        assert has_request_out = '1' report "FAIL: Should have active request" severity error;
        report "Waiting for elevator to move to floor 3...";
        wait_for_door_open(door_open, MOVE_TIME * 5);
        check_floor(3, current_floor, "Arrived at floor 3");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        -- Test 3: Single floor request - Move down
        report "TEST 3: Single Floor Request - Move Down to Floor 1";
        wait for CLK_PERIOD * 10;
        report "Current floor before request: " & integer'image(to_integer(unsigned(current_floor)));
        request_floor(1, floor_request, request_btn);
        wait for CLK_PERIOD * 5;
        report "Next floor target: " & integer'image(to_integer(unsigned(next_floor_out)));
        wait_for_door_open(door_open, MOVE_TIME * 5);
        check_floor(1, current_floor, "Arrived at floor 1");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        -- Test 4: Multiple simultaneous requests - upward direction
        report "TEST 4: Multiple Simultaneous Requests - Upward";
        report "Starting from floor: " & integer'image(to_integer(unsigned(current_floor)));
        request_floor(5, floor_request, request_btn);
        wait for CLK_PERIOD * 2;
        request_floor(7, floor_request, request_btn);
        wait for CLK_PERIOD * 2;
        request_floor(3, floor_request, request_btn);
        wait for CLK_PERIOD * 5;
        
        -- Should go to 3 first, then 5, then 7
        report "Expecting first stop at floor 3...";
        wait_for_door_open(door_open, MOVE_TIME * 5);
        check_floor(3, current_floor, "First stop at floor 3");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 10;
        
        report "Expecting second stop at floor 5...";
        wait_for_door_open(door_open, MOVE_TIME * 5);
        check_floor(5, current_floor, "Second stop at floor 5");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 10;
        
        report "Expecting third stop at floor 7...";
        wait_for_door_open(door_open, MOVE_TIME * 5);
        check_floor(7, current_floor, "Third stop at floor 7");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        -- Test 5: Multiple simultaneous requests - mixed directions
        report "TEST 5: Multiple Simultaneous Requests - Mixed Directions";
        request_floor(9, floor_request, request_btn);
        wait for CLK_PERIOD * 2;
        request_floor(2, floor_request, request_btn);
        wait for CLK_PERIOD * 2;
        request_floor(8, floor_request, request_btn);
        wait for CLK_PERIOD * 5;
        
        -- From floor 7, should go up to 8, then 9, then down to 2
        wait_for_door_open(door_open, MOVE_TIME * 5);
        check_floor(8, current_floor, "Stop at floor 8");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        wait_for_door_open(door_open, MOVE_TIME * 5);
        check_floor(9, current_floor, "Stop at floor 9");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        wait_for_door_open(door_open, MOVE_TIME * 10);
        check_floor(2, current_floor, "Stop at floor 2");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        -- Test 6: Request current floor
        report "TEST 6: Request Current Floor";
        request_floor(2, floor_request, request_btn);
        wait_for_door_open(door_open, DOOR_TIME * 2);
        check_floor(2, current_floor, "Door opens at current floor");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        -- Test 7: Add request while moving
        report "TEST 7: Add Request While Moving";
        request_floor(8, floor_request, request_btn);
        wait for MOVE_TIME;
        report "Checking if elevator is moving...";
        assert (moving_up = '1' or moving_down = '1') 
            report "FAIL: Should be moving" severity error;
        request_floor(6, floor_request, request_btn);
        
        wait_for_door_open(door_open, MOVE_TIME * 10);
        report "First stop at floor: " & integer'image(to_integer(unsigned(current_floor)));
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        wait_for_door_open(door_open, MOVE_TIME * 5);
        report "Second stop at floor: " & integer'image(to_integer(unsigned(current_floor)));
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        -- Test 8: Boundary test
        report "TEST 8: Boundary Test - Extreme Floors";
        request_floor(0, floor_request, request_btn);
        wait_for_door_open(door_open, MOVE_TIME * 15);
        check_floor(0, current_floor, "Arrived at floor 0");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        request_floor(9, floor_request, request_btn);
        wait_for_door_open(door_open, MOVE_TIME * 15);
        check_floor(9, current_floor, "Arrived at floor 9");
        wait_for_door_close(door_open, DOOR_TIME * 2);
        wait for CLK_PERIOD * 5;
        
        -- Test 9: Door safety
        report "TEST 9: Door Safety - Never Open While Moving";
        request_floor(0, floor_request, request_btn);
        wait for MOVE_TIME / 2;
        for i in 0 to 100 loop
            if (moving_up = '1' or moving_down = '1') then
                assert door_open = '0' 
                    report "FAIL: Door opened while moving!" severity error;
                if door_open = '1' then
                    test_passed <= false;
                end if;
            end if;
            wait for CLK_PERIOD;
            exit when door_open = '1' and moving_up = '0' and moving_down = '0';
        end loop;
        
        wait for MOVE_TIME * 2;
        
        report "========================================";
        if test_passed then
            report "ALL TESTS PASSED!" severity note;
        else
            report "SOME TESTS FAILED!" severity error;
        end if;
        report "========================================";
        
        test_done <= true;
        wait;
    end process;
    
end Behavioral;