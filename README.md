# Low-Level Pac-Man

## Project Description

This project is a custom **Pac-Man-inspired FPGA game** developed for ECE241 on the **DE1-SoC**. The game recreates the core mechanics of the original Pac-Man arcade game while using custom-designed pixel art, VGA graphics, keyboard controls, collision detection, scoring, and FPGA-based game logic.

The player controls Pac-Man through a maze, collecting coins while avoiding a moving ghost. The game includes multiple game states, including a **GAME WON** screen after all three large coins are collected and a **GAME OVER** screen when Pac-Man collides with the ghost. Unfortunately, the movement of the ghost could not be properly implemented within the time limit, and so the finished game has only Pac-Man and the 3 coins. The unfinished, bugged version of the code is still available.

## Features

- Control Pac-Man using **WASD** keyboard controls
- Move Pac-Man in all four directions
- Move through a custom-designed maze
- Prevent Pac-Man from moving through maze walls
- Wrap around to the opposite side of the screen when reaching an edge
- Collect **three large coins**
- Collect multiple smaller decorative coins
- Automatically remove large coins after collision
- Increase the score when collecting a large coin
- Display the score on the **HEX display**
- Win the game after collecting all three large coins
- Display a **GAME WON** screen
- Navigate a moving ghost with a predefined path
- Detect collisions between Pac-Man and the ghost
- Trigger a **GAME OVER** screen after ghost collision
- Display Pac-Man, the ghost, coins, and maze using custom pixel art
- Allow Pac-Man and the ghost to move simultaneously
- Smoothly update Pac-Man's movement on the VGA display

## Implementation

### VGA Graphics

The game uses the DE1-SoC's **VGA display** to render the maze and game objects. A static maze background is combined with moveable objects such as Pac-Man, the ghost, and coins.

Custom pixel art was created for the game's visual elements, including Pac-Man, coins, the ghost, the maze, and the GAME WON / GAME OVER screens.

### Pac-Man Movement

Pac-Man's movement is controlled through a **PS/2 keyboard interface**. The keyboard logic was configured so that only the **W, A, S, and D** keys control movement.

A movement FSM determines Pac-Man's current direction and controls whether movement is enabled based on the surrounding maze.

### Collision Detection

Collision logic was implemented for:

- Maze walls
- Large coins
- Ghost

Maze collision detection prevents Pac-Man from moving through walls. Coin collision detection removes coins immediately after they are collected and updates the score. Ghost collision detection triggers the GAME OVER state.

### Game Logic

The game uses FPGA logic to coordinate movement, collisions, scoring, and game states.

The score is updated as large coins are collected. Once all three large coins have been collected, the game transitions to the GAME WON screen. A collision between Pac-Man and the ghost transitions the game to the GAME OVER state.

### Ghost Movement

The ghost follows a predefined path through the maze. Additional logic allows the ghost and Pac-Man to move at the same time while checking for collisions between them.

### Simulation & Debugging

**ModelSim** testbenches were created to simulate portions of the design and verify the behavior of the FPGA logic before testing on the DE1-SoC.

Several implementation issues were identified and fixed during development, including keyboard input problems, incorrect maze coordinates, coin collision timing, game-state transitions, and ghost path coordinates.

## Tools & Technologies

- **Verilog** — FPGA hardware and game logic
- **Quartus Prime Lite Edition** — FPGA development and synthesis
- **ModelSim** — simulation and testbench verification
- **DE1-SoC** — FPGA development board
- **VGA** — graphics output
- **PS/2 Keyboard** — player input
- **HEX Display** — score output
- **FPGA hardware** — movement, collision, scoring, and game-state logic

## Author

**Ireen Cheralody**  
University of Toronto — Computer Engineering + PEY Co-op
