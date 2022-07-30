# Doodle Jump in MIPS assembly

Doodle Jump in MIPS assembly language with sound effects, pleasant and soothing. This was my final project for CSC258H1F Fall 2020, University of Toronto.

https://github.com/chrt/Doodle-Jump-in-MIPS-assembly/blob/main/demo.mp4

## Features

1. Game over / retry

2. Verticle centering

3. Dynamic increase in difficulty (speed, obstacles, shapes etc.) as the game progresses
   
   The difficulty of the game is increased by decreasing the length of the platforms and the average vertical distance between two adjacent platforms. It is guaranteed that progressing is always possible.

4. Realistic physics

   If the game runs so slowly that it is hard to see the realistic physics, restart the simulator may be helpful.

5. Aesthetics

   - Beautiful color combination
   - Color gradient in the background
   - The character facing left or right

6. Sound effects

   - Canon in D
   - Game over :frowning_face:

7. Fluency

   - Each frame is drawn in one pass
   - No flashing

## How to run

1. Open the source code in [MARS](http://courses.missouristate.edu/kenvollmar/mars/) (MIPS Assembler and Runtime Simulator)
2. Assemble
3. Tools -> Bitmap Display
   1. Configuration
      - Unit width in pixels: 4
      - Unit height in pixels: 4
      - Display width in pixels: 256
      - Display height in pixels: 256
      - Base Address for Display: 0x10008000 ($gp)
   2. Connect to MIPS
4. Tools -> Keyboard and Display MMIO Simulator
   1. Connect to MIPS
   2. Make sure to input in the KEYBOARD text field when the game runs
5. Run the current program
   1. `j` to move left and `k` to move right
   2. `y` to restart and `n` to exit when the game is over
