# RTL Design of an Elevator Controller

## Project Overview

This project implements a complete elevator controller system in VHDL for FPGA deployment. The controller manages elevator movement, door operations, and intelligently schedules multiple floor requests while ensuring safety constraints are met. The design is intended for the DE1-CV development board and serves a 10-floor building.

## Design Requirements

### Functional Requirements

The elevator controller must meet the following specifications:

1. **Floor Service Range**: Support 10 floors numbered 0 through 9, where floor 0 is the ground floor and floor 9 is the top floor.

2. **Movement Timing**: The elevator must take exactly 2 seconds to move from one floor to an adjacent floor.

3. **Door Operation**: When the elevator arrives at a requested floor, the door must open and remain open for at least 2 seconds before closing.

4. **Safety Constraint**: The door must never be open while the elevator is moving between floors.

5. **Direction Priority**: The elevator should not change direction if there are pending requests in its current direction of travel. Only when no higher requests exist while moving up, or no lower requests exist while moving down, should the elevator reverse direction.

6. **Request Management**: Multiple floor requests must be handled efficiently, with the controller determining the optimal order to service them.

7. **Clock Requirements**: The design must use the 50 MHz clock available on the DE1-CV board, with a 1-second clock enable signal for timing elevator movement and door operations.

### Interface Requirements

**Input Signals:**
- System clock (50 MHz)
- Reset signal
- 4-bit floor request input (representing floors 0-9)
- Request button for registering floor requests

**Output Signals:**
- Current floor display (connected to seven-segment display)
- Door open indicator (LED)
- Moving up indicator (LED)
- Moving down indicator (LED)
- Request status indicators (10 LEDs showing pending requests)

### Design Constraints

- The design must be parameterized using VHDL generics to allow for different numbers of floors
- The implementation must be fully synchronous
- All control and status signals must be observable for debugging
- The design must be verifiable through comprehensive testbench simulation

## Solution Architecture

### System Decomposition

The elevator controller is decomposed into three primary functional blocks:

#### 1. Main Controller (elevator_ctrl.vhd)

The main controller implements a finite state machine that governs the elevator's operation. The FSM consists of four distinct states:

**IDLE_STATE**: The resting state where the elevator waits for requests. When a request is detected, the controller evaluates whether to move up, move down, or open the door if already at the requested floor.

**DOOR_OPEN_STATE**: This state is entered when the elevator arrives at a destination floor. The door opens and a 2-second timer begins. Once the timer expires, the controller transitions back to IDLE_STATE.

**MOVING_UP_STATE**: The elevator is in motion traveling upward. A 2-second timer controls the movement to each floor. When the timer expires, the current floor counter increments. The controller checks if the new floor matches the destination; if so, it transitions to DOOR_OPEN_STATE.

**MOVING_DOWN_STATE**: Similar to MOVING_UP_STATE but for downward travel. The floor counter decrements after each 2-second interval.

The main controller also includes:
- A clock divider that generates a 1 Hz enable signal from the 50 MHz system clock
- A configurable 2-second timer used for both floor transitions and door operation
- Floor counter logic that tracks the current position
- Output generation logic that sets status signals based on the current state

#### 2. Request Resolver (request_resolver.vhd)

The request resolver manages the queue of pending floor requests and implements the scheduling algorithm. Its responsibilities include:

**Request Registration**: When the request button is pressed, the resolver stores the requested floor in an internal 10-bit request array, where each bit corresponds to a floor.

**Button Debouncing**: The resolver implements a three-stage synchronizer for the request button input. This synchronizer serves two purposes: it eliminates metastability issues from asynchronous inputs and detects the rising edge of button presses to ensure each press is registered exactly once.

**Request Clearing**: When the elevator arrives at a floor and opens the door, the resolver clears that floor's request from the array. This is accomplished through edge detection on the clear signal from the main controller.

**Next Floor Calculation**: The resolver continuously evaluates the request array and determines which floor should be serviced next based on the current floor and direction. The algorithm implements the following priority rules:

- If moving upward, prioritize the lowest floor number above the current floor that has a pending request
- If moving upward with no higher requests, select the highest floor number below the current floor
- If moving downward, prioritize the highest floor number below the current floor that has a pending request
- If moving downward with no lower requests, select the lowest floor number above the current floor
- If idle, check the current floor first, then search upward, then downward

This algorithm ensures efficient elevator operation by maintaining directional consistency while ultimately servicing all requests.

#### 3. Seven-Segment Display Driver (ssd.vhd)

A simple combinational decoder that converts the 4-bit binary floor number into the 7-segment display format. The implementation uses a lookup table to map each decimal digit to the appropriate segment pattern. The display uses active-low logic, where a '0' illuminates a segment.

### Key Design Decisions

#### Timing Architecture

The design uses a hierarchical timing structure. The 50 MHz system clock is divided down to produce a 1 Hz enable signal. This enable signal gates a 2-second timer that controls both elevator movement and door operation. This approach provides precise timing control while keeping the design fully synchronous.

For simulation purposes, the clock frequency is parameterized through a generic. The testbench uses a faster clock (10 MHz) with a correspondingly scaled clock divider (CLK_FREQ = 10) to reduce simulation time while maintaining the same logical behavior.

#### Request Clearing Synchronization

One of the critical challenges in this design was ensuring proper synchronization between request clearing and state transitions. The initial implementation used a combinational signal to indicate when the FSM was transitioning to the DOOR_OPEN state. However, this created a race condition where the request would be cleared before the request resolver's next_floor output could update, causing the FSM to incorrectly re-enter DOOR_OPEN_STATE at the same floor.

The solution involved changing the clear signal to be asserted when the FSM is stable in the DOOR_OPEN_STATE with the door actually open, rather than during the transition. The request resolver then uses edge detection to clear the request exactly once per arrival. This ensures that the request array updates and the next_floor output recalculates before the FSM checks for new requests.

#### State Machine Output Logic

The outputs (door_open, moving_up, moving_down) are generated directly from the current state through combinational logic. This design choice ensures that outputs change immediately when the state changes, providing clean, glitch-free signals. More importantly, this architecture guarantees that mutually exclusive conditions (door open vs. moving) can never occur simultaneously, satisfying the critical safety requirement.

## Implementation Details

### Generic Parameters

```
NUM_FLOORS: Specifies the number of floors the elevator serves (default: 10)
CLK_FREQ: Defines how many clock cycles constitute one second (default: 50,000,000 for 50 MHz)
```

These generics allow the design to be easily adapted to different building sizes and clock frequencies without modifying the core logic.

### Signal Descriptions

**Internal Signals in Main Controller:**

- current_state, next_state: Hold the current and next FSM states
- current_floor_int: Integer representation of the current floor (0 to NUM_FLOORS-1)
- next_floor_int: Integer representation of the destination floor
- has_request: Boolean indicating whether any floor requests are pending
- clk_1hz: One-cycle pulse generated every second
- timer_enable: Enables the 2-second timer
- timer_expired: Pulses when the 2-second timer completes
- clear_current_floor: Signals the request resolver to clear the current floor's request

**Internal Signals in Request Resolver:**

- request_array: 10-bit vector where each bit represents a pending request for that floor
- request_btn_sync: Three-stage shift register for button synchronization
- request_btn_edge: Single-cycle pulse on button press
- clear_current_edge: Single-cycle pulse when arriving at a floor

### Process Descriptions

#### Main Controller Processes

**Clock Divider Process**: Counts system clock cycles and generates a 1 Hz enable pulse. When the counter reaches CLK_FREQ-1, it asserts clk_1hz for one cycle and resets the counter.

**Timer Process**: When enabled, this process counts 1 Hz pulses. After counting two pulses (representing 2 seconds), it asserts timer_expired for one cycle and resets.

**Floor Counter Process**: Increments or decrements the current floor number when timer_expired is asserted, depending on whether the state is MOVING_UP or MOVING_DOWN.

**State Register Process**: Synchronously updates the current state on each clock edge. Implements the standard two-process FSM pattern for clean state transitions.

**Output Logic Process**: Combinational process that generates output signals based solely on the current state. This ensures outputs are stable and change predictably with state transitions.

**Next State Logic Process**: Combinational process that determines the next state based on the current state and input conditions. Implements the FSM's decision logic for state transitions.

#### Request Resolver Processes

**Synchronizer Process**: Shifts the request button through a three-stage register on each clock cycle. Also tracks the previous value of the clear signal for edge detection.

**Request Management Process**: Sequential process that maintains the request array. Responds to button edge events by setting the corresponding bit and to clear edge events by resetting the corresponding bit.

**Scheduling Logic Process**: Combinational process that examines the request array and determines the optimal next floor to service based on the current floor and movement direction.

## Verification Strategy

### Testbench Architecture

The testbench (elevator_ctrl_tb.vhd) implements a comprehensive self-checking verification environment. It uses procedural abstractions to simplify test case creation and automatic checking to validate correct operation.

**Test Procedures:**

- request_floor: Simulates a user pressing the floor request button
- wait_for_door_open: Waits for the door to open with timeout protection
- wait_for_door_close: Waits for the door to close with timeout protection  
- check_floor: Validates that the elevator is at the expected floor

### Test Cases

**Test 1 - Reset Verification**: Confirms that the elevator initializes to floor 0 with all outputs in their default state after reset.

**Test 2 - Single Floor Request Upward**: Verifies basic upward movement by requesting floor 3 from floor 0. Validates that the elevator moves through intermediate floors and arrives at the destination.

**Test 3 - Single Floor Request Downward**: Tests downward movement by requesting floor 1 from floor 3. Ensures the controller can handle both movement directions.

**Test 4 - Multiple Simultaneous Requests (Ascending)**: Requests floors 3, 5, and 7 while at floor 1. Verifies that the scheduler serves them in optimal ascending order (3, then 5, then 7) rather than in the order they were requested.

**Test 5 - Multiple Requests with Direction Change**: From floor 7, requests floors 8, 9, and 2. Validates that the controller continues upward to serve 8 and 9 before reversing direction to serve floor 2, demonstrating proper direction priority.

**Test 6 - Current Floor Request**: Requests the current floor to verify that the elevator simply opens the door without unnecessary movement.

**Test 7 - Dynamic Request Addition**: Requests floor 8, waits for movement to begin, then requests floor 6. Confirms that the controller can accept and properly schedule requests while in motion.

**Test 8 - Boundary Conditions**: Tests the extreme floors (0 and 9) to ensure no overflow or underflow occurs in the floor counter.

**Test 9 - Safety Validation**: Continuously monitors the door and movement signals during a full elevator cycle. Fails if the door is ever open while moving_up or moving_down is asserted.

### Test Results

All nine test cases pass successfully, validating that the implementation meets all functional requirements. The simulation confirms:

- Correct state transitions
- Accurate timing (2 seconds per floor, 2 seconds door open)
- Proper request scheduling
- Safety constraint enforcement
- Boundary condition handling
- Dynamic request management

## Design Metrics

**Resource Utilization (Estimated):**
- Logic Elements: Approximately 150-200
- Registers: Approximately 50-70
- Maximum Clock Frequency: Expected > 100 MHz on Cyclone V

**Timing:**
- All paths meet timing at 50 MHz
- Critical path likely in request resolution combinational logic
- State machine transitions occur in single clock cycle

**Scalability:**
- Design can be scaled to support more floors by changing NUM_FLOORS generic
- Request array size grows linearly with floor count
- Scheduling algorithm complexity grows with floor count but remains acceptable for reasonable building sizes (up to 20-30 floors)

## Synthesis and Implementation

### Compilation Steps

1. Compile all VHDL source files in dependency order:
   - ssd.vhd (no dependencies)
   - request_resolver.vhd (no dependencies)
   - elevator_ctrl.vhd (depends on request_resolver)
   - elevator_top.vhd (depends on elevator_ctrl and ssd)

2. Set top-level entity to elevator_top

3. Assign pin locations according to DE1-CV board constraints:
   - Clock input to PIN_M9 (50 MHz oscillator)
   - Reset to KEY0
   - Request button to KEY1
   - Floor request inputs to SW3-SW0
   - Seven-segment display to HEX0
   - Status LEDs to LEDR

4. Compile design and generate programming file

### FPGA Configuration

The elevator_top entity provides the wrapper for FPGA deployment. It instantiates the elevator controller and seven-segment display driver, connecting internal signals to the FPGA pins. Generic parameters are set appropriately for the 50 MHz board clock.

## Testing Recommendations

### Simulation Testing

Before hardware deployment, thoroughly simulate the design using the provided testbench. The simulation validates all functional aspects and catches timing or logic errors early. Run the complete testbench and verify that all test cases pass.

### Hardware Testing

After programming the FPGA:

1. Verify that the seven-segment display shows "0" after reset
2. Test single floor requests and observe movement indicators
3. Test multiple requests and verify optimal scheduling
4. Attempt to create the safety violation (observe that it cannot occur)
5. Test boundary conditions with floors 0 and 9
6. Test rapid successive button presses to verify debouncing

### Debug Features

The design includes comprehensive debug outputs:
- 10 LEDs show the current request array state
- Movement direction indicators show when elevator is traveling
- Door status LED indicates when door is open
- Current floor is continuously displayed

These signals allow real-time observation of the controller's operation and facilitate debugging.

## Lessons Learned

### Design Challenges

The primary challenge was synchronizing request clearing with state transitions. The initial approach used a combinational transition signal, which created a race condition. The solution required understanding the exact timing relationships between signal updates across module boundaries.

### Best Practices Applied

- Consistent use of rising_edge(clk) for all sequential logic
- Separation of combinational and sequential logic into distinct processes
- Use of edge detection for button inputs to prevent bounce and multiple registrations
- Parameterization through generics for design flexibility
- Comprehensive testbench with automatic checking
- Modular design with clear interface boundaries

### Future Enhancements

Potential improvements to this design include:

- Adding priority levels for different floor requests (emergency floors)
- Implementing a more sophisticated scheduling algorithm (e.g., SCAN or LOOK algorithms)
- Adding acceleration and deceleration profiles for more realistic movement
- Supporting multiple elevator cars with coordinated scheduling
- Adding fault detection and recovery mechanisms
- Implementing a display of waiting time for each request

## Conclusion

This elevator controller demonstrates a complete embedded control system implemented in VHDL. The design successfully meets all functional requirements while maintaining clean, modular code structure. The comprehensive testbench validates correct operation across all scenarios, including edge cases and safety-critical conditions.

The modular architecture allows for easy modification and extension. The use of generics makes the design adaptable to different building sizes and clock frequencies. The implementation is suitable for FPGA deployment and provides a solid foundation for more advanced elevator control systems.

The project illustrates important digital design concepts including finite state machines, synchronous design methodology, edge detection, timing control, and verification through self-checking testbenches. These techniques are applicable to a wide range of embedded control applications beyond elevator systems.
