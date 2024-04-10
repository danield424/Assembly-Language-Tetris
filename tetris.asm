################ CSC258H1F Winter 2024 Assembly Final Project ##################
# This file contains my implementation of Tetris.
#
# Student 1: Daniel Du, 1008901182
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################
    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

BACKGROUND:
    .word 0x242525
WALL_COLOUR:
    .word 0x343535
GRID_1:
    .word 0x000000
GRID_2:
    .word 0x202020

WHITE: #gameField value 1
    .word 0xDDDDDD
BLUE: #gameField value 2
    .word 0x0000FF
PURPLE: #gameField value 3
    .word 0x9D0AE1
ORANGE: #gameField value 4
    .word 0xF16E00
RED: #gameField value 5
    .word 0xff0000
YELLOW: #gameField value 6
    .word 0xF7D500
CYAN: #gameField value 7
    .word 0x0BCEE9
GREEN: #gameField value 8
    .word 0x0EE70C
    
colour_table: # colour palette
    .word 0x000000       # 0
    .word 0xDDDDDD       # WHITE
    .word 0x0000FF       # BLUE
    .word 0x9D0AE1       # PURPLE
    .word 0xF16E00       # ORANGE
    .word 0xFF0000       # RED
    .word 0xF7D500       # YELLOW
    .word 0x0BCEE9       # CYAN
    .word 0x0EE70C       # GREEN
##############################################################################
# Mutable Data
##############################################################################
gameField: .space 434 
# possible fillings:
# 0 - empty
# 1 - white
# 2 - blue, tetromino 0L
# 3 - purple, tetromino 1J
# 4 - orange, tetromino 2I
# 5 - red, tetromino 3O
# 6 - yellow, tetromino 4T
# 7 - cyan, tetromino 5S
# 8 - lightgreen, tetromino 6Z
padding:   .byte 0, 0  # add 2 bytes of padding to realign

tetromino_x:
    .word 7
tetromino_y:
    .word 0
tetromino_state:
    .word 0
    
blockX: .space 16  # 4 x coordinates of 4 blocks
blockY: .space 16  # y

gravityCounter: # used to track gravity.
    .word 0
clearedRows: # tracking the number of cleared rows
    .word 0         
##############################################################################
# Code
##############################################################################
	.text
	.globl main

	# Run the Tetris game.
main: # Initialization
# sleep_at_start:
    # li $a0, 500                      # sleep for 10ms
    # li $v0, 32                      # syscall for sleeping
    # syscall
    jal clear_screen
    jal draw_walls
    jal draw_grid
    jal setup_game_field
    jal insert_tetromino

#################################
# GAME LOOP THAT CHECKS EVERYTHING.
# Always goes to calculate_block_positions

game_loop:
    lw $t0, ADDR_KBRD # keyboard address
    lw $t8, 0($t0)    # key press status
    beqz $t8, gravity
    
    lw $a0, 4($t0)                 # load the key code of the pressed key
    
    # $t9 are ASCII values
    # 'a'
    li $t9, 0x61             
    beq $a0, $t9, move_left
    
    # 'd'
    li $t9, 0x64                
    beq $a0, $t9, move_right
    
    # 's'
    li $t9, 0x73               
    beq $a0, $t9, move_down_press
    
    # 'w'
    li $t9, 0x77        
    beq $a0, $t9, rotate
    
    # 'q'
    li $t9, 0x71 
    beq $a0, $t9, quit_game
    
    # 'p'
    li $t9, 0x70
    beq $a0, $t9, pause
  
# this only runs when the key is pressed to produce audio.
move_down_press:
    # sound parameters
    li $a0, 60     # middle c pitch
    li $a1, 125    # milliseconds
    li $a2, 0      # piano
    li $a3, 127    # volume 0-127
    li $v0, 31     # syscall for MIDI
    syscall
    j apply_gravity 
    
gravity:
    li $a0, 10          # sleep for 10ms
    li $v0, 32          # syscall for sleeping
    syscall
    # increment gravity counter
    lw $t1, gravityCounter
    addiu $t1, $t1, 1
    sw $t1, gravityCounter
    # move tetromino down if $t2 # of ticks have passed
    li $t2, 30 # this is the base speed.
    lw $t3, clearedRows # number of rows cleared
    li $t4, 3 # rows cleared per speed increase
    div $t3, $t4 
    mflo $t3 # t3 has the # of speed increases so far
    sll $t3, $t3, 2 # multiply it by 8
    sub $t2, $t2, $t3 # decrease the number of ticks needed in $t2   
    bge $t1, $t2, apply_gravity
    j calculate_block_positions

apply_gravity:
    # reset gravity counter
    sw $zero, gravityCounter
    j move_down                     # Move tetromino down
    
    # our main code runs through calculate_block_positions to update the screen.
    j calculate_block_positions

#################################
# INITIALIZATION CODE
return_to_main: 
    jr $ra

# Draws background.
clear_screen:
    # initialize by loading base address, background colour, total # of units, accumulator
    lw $t0, ADDR_DSPL
    lw $t1, BACKGROUND
    li $t2, 1024
    li $t5, 0
clear_loop:
    # loop over all units at addresses and colour them
    sw $t1, 0($t0)
    addiu $t0, $t0, 4
    addiu $t5, $t5, 1
    bne $t5, $t2, clear_loop
    j return_to_main

# Draws walls
draw_walls:
    # initialize by loading base address, wall colour, wall dimensions, accumulator
    lw $t0, ADDR_DSPL
    lw $t6, WALL_COLOUR
    li $t2, 32 # units in a row
    li $t3, 31 # last index
    li $t1, 0  # row counter
draw_vertical_walls:
    # draw left and right walls at the memory address and then draw bottom
    bgt $t1, $t3, draw_bottom  # bottom wall when all rows are done
    # left (x=0)
    mul $t5, $t1, $t2  # multiply to get offset for the row
    sll $t5, $t5, 2    # shift left (x4) for bytes.
    add $t7, $t0, $t5  # get memory address from t0
    sw $t6, 0($t7)     # draw in the colour.
    # right (x=14)
    li $t8, 56         # byte offset for 14 units (56 bytes)
    add $t9, $t7, $t8  # shift $t7 by 56 bytes
    sw $t6, 0($t9)     # draw in colour
    addi $t1, $t1, 1   # count
    j draw_vertical_walls
draw_bottom:
    li $t1, 0              # column counter
    li $t2, 14              # drawing 14 in total
    sll $t5, $t3, 7        # bottom row offset (128)
    add $t0, $t0, $t5      # adjust t0 to start of bottom row    
draw_bottom_loop:
    # same idea as earlier loop
    bgt $t1, $t2, return_to_main  # done when t1 > t2
    sll $t9, $t1, 2  
    add $t8, $t0, $t9
    sw $t6, 0($t8)
    addiu $t1, $t1, 1
    j draw_bottom_loop 

# Draws game grid
draw_grid:
    # initialize address, colours, dimensions
    lw $t0, ADDR_DSPL 
    lw $t8, GRID_1   
    lw $t9, GRID_2  
    li $t1, 0  # starting rows and columns
    li $t2, 1 
    li $t3, 14
    li $t4, 31 
    li $t7, 32 # units in row
draw_grid_rows:
    blt $t1, $t4, draw_grid_columns  # check if rows are done
    j return_to_main # done
draw_grid_columns:
    blt $t2, $t3, draw_colour  # draw columns
    j update_row_index   # go to next row
draw_colour:
    add $t5, $t1, $t2           # get index
    andi $t5, $t5, 1            # check if even or odd
    beqz $t5, draw_lightgrey 
    j draw_darkgrey 
draw_lightgrey:
    # find offsets for row, column, to draw the colour. then go to next column
    mul $t6, $t1, $t7  
    add $t6, $t6, $t2  
    sll $t6, $t6, 2  
    add $t6, $t0, $t6 
    sw $t8, 0($t6) 
    j update_column_index # skip over next section
draw_darkgrey:
    # same idea
    mul $t6, $t1, $t7 
    add $t6, $t6, $t2 
    sll $t6, $t6, 2  
    add $t6, $t0, $t6 
    sw $t9, 0($t6) 
update_column_index:
    # go to next column
    addi $t2, $t2, 1
    j draw_grid_columns 
update_row_index:
    # go to next row
    addi $t1, $t1, 1
    li $t2, 1   # reset column to first column
    j draw_grid_rows 

# sets up gameField array, with 5 random rows generated in white.
setup_game_field:
    la $t0, gameField         # load the address of the gameField array
    li $t8, 364               # initialize all except bottom 5 rows.
    li $t9, 0                 # empty value
clear_field_loop:
    beqz $t8, random_5_rows   # if t8 = 0 we finished iterating
    sb $t9, 0($t0)            # set cell to empty.
    addiu $t0, $t0, 1
    addiu $t8, $t8, -1
    j clear_field_loop
random_5_rows:  
    la $t0, gameField + 364   # start at this index to cover bottom 5 rows
    li $t8, 70 # total number of squares we r filling in
    li $t7, 0
random_loop:
    beqz $t8, colour_rows
    addiu $t1, $t7, 364
    # this part of the code is necessary so that we avoid colouring in the left sided wall by skipping those indices. 
    div $t1, $t1, 14
    mfhi $t2
    beq $t2, 0, skip_index
    # generate random integer:
    li $a0, 0          # always just use a0 = 0
    li $a1, 2          # upper limit for random number generation (0 to 1)
    li $v0, 42         # syscall 42 gives us the range.
    syscall 
    move $t9, $a0
    # save random integer in gameField
    sb $t9, 0($t0)
skip_index:
    addiu $t0, $t0, 1
    addiu $t7, $t7, 1
    addiu $t8, $t8, -1
    j random_loop

# Colours in the bottom 5 rows we just set up 
colour_rows:
    la $t0, gameField
    lw $t1, ADDR_DSPL 
    li $t2, 0                 # gameField index
    li $t7, 0                 # iteration counter
    lw $t8, WHITE 
update_loop:
    li $t9, 434               # total cells in gameField
    beq $t7, $t9, end_update
    lb $a0, 0($t0)            # load the value of the current cell from gameField
    beqz $a0, next_cell       # skip cell if value is 0 (empty)
    div $t2, $t7, 14          # dividing index by 14 to find row #
    mflo $a1                  # quotient: row, store in $a1
    mfhi $a2                  # remainder: column index
    # calculate display offset
    mul $a1, $a1, 32          # row offset in units 
    add $a1, $a1, $a2         # add column offset to get total offset in units
    sll $a1, $a1, 2           # x4 to get bytes
    # update the display at calculated address
    add $a1, $t1, $a1         # calculate memory address for the cell
    sw $t8, 0($a1)            # colour it
next_cell:
    addiu $t0, $t0, 1   
    addiu $t7, $t7, 1     
    j update_loop    
end_update:
    j return_to_main

#################################
# INSERTING A TETROMINO 
# RECORDS BRICK OUTLINES - i.e. the maxes and mins. not specific blocks
# After this, we go through game_loop

insert_tetromino:
    # generate random integer:
    li $a0, 0          # always just use a0 = 0
    li $a1, 7          # upper limit for random number generation (0 to 6)
    li $v0, 42         # syscall 42 gives us the range.
    syscall 
    move $s3, $a0
insert_tetromino_setup:
    # initialization/setup
    lw $t0, ADDR_DSPL 
    lw $t1, tetromino_y #y_up
    lw $t2, tetromino_x #x_left
    lw $t4, tetromino_state
    li $t7, 32
    
    # adjust the stack make room for xleftright and yupdown (4 values from 0-16)
    # also we add rotation left shift (Lshift) and Rshift for our later rotation_check.
    addiu $sp, $sp, -24
# for each pixel, find offsets, get memory address and colour, then move to next col/row
    beq $s3, 0, insert_tetrominoL
    beq $s3, 1, insert_tetrominoJ
    beq $s3, 2, insert_tetrominoI
    beq $s3, 3, insert_tetrominoO
    beq $s3, 4, insert_tetrominoT
    beq $s3, 5, insert_tetrominoS
    beq $s3, 6, insert_tetrominoZ

insert_tetrominoL:
    lw $t6, BLUE
    # initializing 
    addiu $t9, $t2, 0       # width 2
    sw $t9, 0($sp)          # store xleft on the stack
    addiu $t9, $t2, 1       
    sw $t9, 4($sp)          # store xright
    addiu $t9, $t1, 0       # height 3
    sw $t9, 8($sp)          # store yup
    addiu $t9, $t1, 2       
    sw $t9, 12($sp)         # store ydown
    
    li $t9, 1
    sw $t9, 16($sp)  # rotating to the next state here will shift xleft left by 1     
    li $t9, 0
    sw $t9, 20($sp)  # rotating to the next state here will shift xright right by 0
    
    # state for each orientation
    beq $t4, 0, draw_Lstate_0
    beq $t4, 1, draw_Lstate_1
    beq $t4, 2, draw_Lstate_2
    beq $t4, 3, draw_Lstate_3

draw_Lstate_0:
    # draw first three pixels of the L-shape vertically
    li $t3, 0  # pixel counter
draw_Lvertical_pixels0:
    bgt $t3, 2, draw_Lhorizontal_pixel0 # after drawing 3 verts
    mul $t5, $t1, $t7  # calculate row starting index
    add $t5, $t5, $t2  # add column index
    sll $t5, $t5, 2    # x4 to get byte
    add $t5, $t0, $t5  # get the memory address from t0
    sw $t6, 0($t5)     # colouring pixel
    addiu $t1, $t1, 1  # doing next row
    addiu $t3, $t3, 1  # incrementing pixel counter
    j draw_Lvertical_pixels0 
draw_Lhorizontal_pixel0:
    # adjust back by 1 to draw horizontal pixel at the last vertical pixel's row, go to next col
    addiu $t1, $t1, -1
    addiu $t2, $t2, 1 # move right 1 column
    mul $t5, $t1, $t7     
    add $t5, $t5, $t2  
    sll $t5, $t5, 2   
    add $t5, $t0, $t5 
    sw $t6, 0($t5)
draw_Lcomplete0:
    j game_loop
    
draw_Lstate_1:
    # reset counter for drawing three horizontal pixels
    li $t3, 0  
    addiu $t1, $t1, 1 # shift y down by 1
draw_Lhorizontal_pixels1:
    bge $t3, 3, draw_Lvertical_pixel1  # after drawing 3 horizontal pixels, draw the vertical one below the first
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    addiu $t5, $t5, -1
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Lhorizontal_pixels1 
draw_Lvertical_pixel1:
    # adjust back to draw vertical pixel below the first horizontal pixel
    addiu $t2, $t2, -4  # move back to the first pixel's column
    addiu $t1, $t1, 1   # move down one row 
    mul $t5, $t1, $t7   
    add $t5, $t5, $t2 
    sll $t5, $t5, 2   
    add $t5, $t0, $t5  
    sw $t6, 0($t5) 
draw_Lcomplete1:
    # adjusting stack values!!
    lw $t9, 0($sp)          # width 2, goes left 1
    addiu $t9, $t9, -1
    sw $t9, 0($sp)          # store xleft on the stack
    # xright stays the same 
    lw $t9, 8($sp)
    addiu $t9, $t9, 1       # height goes down to 2
    sw $t9, 8($sp)          # Store yup on the stack
    # ydown stays the same
    li $t9, 0
    sw $t9, 16($sp)   
    li $t9, -1
    sw $t9, 20($sp)
    j game_loop 
    
draw_Lstate_2:
    # draw two horizontal pixels at the top
    li $t3, 0
    addiu $t2, $t2, -1 
draw_Lhorizontal_pixels2:
    bge $t3, 2, draw_Lvertical_pixels2  
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Lhorizontal_pixels2
draw_Lvertical_pixels2:
    addiu $t2, $t2, -1  
    addiu $t1, $t1, 1   
    li $t3, 0  
draw_Lvertical2:
    bge $t3, 2, draw_Lcomplete2  
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t1, $t1, 1
    addiu $t3, $t3, 1
    j draw_Lvertical2
draw_Lcomplete2:
    # adjusting stack values
    # xleft shift by 1 
    lw $t9, 0($sp)       
    addiu $t9, $t9, -1
    sw $t9, 0($sp)    
    # xright
    lw $t9, 4($sp)          # width goes from 3 to 2
    addiu $t9, $t9, -1
    sw $t9, 4($sp)          # store xright on the stack
    
    li $t9, 0
    sw $t9, 16($sp)  
    li $t9, 1
    sw $t9, 20($sp)
    j game_loop
    
draw_Lstate_3:
    li $t3, 0
draw_Lvertical3:
    # single vertical pixel at the top
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    addiu $t5, $t5, 1 # shift right by 1
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5)
    addiu $t1, $t1, 1
    addiu $t2, $t2, -1  # move one column to the left to align next pixels
draw_Lhorizontal_pixels3:
    bge $t3, 3, draw_Lcomplete3
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5)
    addiu $t2, $t2, 1
    addiu $t3, $t3, 1
    j draw_Lhorizontal_pixels3
draw_Lcomplete3:
    # adjusting stack values
    # xleft shift by 1 
    lw $t9, 0($sp)          
    addiu $t9, $t9, -1
    sw $t9, 0($sp)           
    #xright no change from init
    lw $t9, 12($sp)
    addiu $t9, $t9, -1       # height goes down to 2
    sw $t9, 12($sp)          # Store ydown on the stack
    # yup stays the same
    
    li $t9, -1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    j game_loop
    
insert_tetrominoJ:
    lw $t6, PURPLE
    # initializing 
    addiu $t9, $t2, 0       
    sw $t9, 0($sp)          # store xleft
    addiu $t9, $t2, 1       
    sw $t9, 4($sp)          # store xright
    addiu $t9, $t1, 0      
    sw $t9, 8($sp)          # store yup
    addiu $t9, $t1, 2       
    sw $t9, 12($sp)         # store ydown
    
    li $t9, 0
    sw $t9, 16($sp)  
    li $t9, 1
    sw $t9, 20($sp)
    # state for each orientation
    beq $t4, 0, draw_Jstate_0
    beq $t4, 1, draw_Jstate_1
    beq $t4, 2, draw_Jstate_2
    beq $t4, 3, draw_Jstate_3
draw_Jstate_0:
    li $t3, 0  # pixel counter
draw_Jvertical_pixels0:
    bgt $t3, 2, draw_Jhorizontal_pixel0 # after drawing 3 verts
    mul $t5, $t1, $t7  # calculate row starting index
    add $t5, $t5, $t2  # add column index
    addiu $t5, $t5, 1  # INCREMENT BY 1 FOR J
    sll $t5, $t5, 2    # x4 to get byte
    add $t5, $t0, $t5  # get the memory address from t0
    sw $t6, 0($t5)     # colouring pixel
    addiu $t1, $t1, 1  # doing next row
    addiu $t3, $t3, 1  # incrementing pixel counter
    j draw_Jvertical_pixels0 
draw_Jhorizontal_pixel0:
    # adjust back by 1 to draw horizontal pixel at the last vertical pixel's row, go to next col
    addiu $t1, $t1, -1
    mul $t5, $t1, $t7     
    add $t5, $t5, $t2  
    sll $t5, $t5, 2   
    add $t5, $t0, $t5 
    sw $t6, 0($t5)
draw_Jcomplete0:
    j game_loop
    
draw_Jstate_1:
    li $t3, 0  
    addiu $t1, $t1, 1 # shift y down by 1
    addiu $t2, $t2, 1 # shift x right by 1
draw_Jhorizontal_pixels1:
    bge $t3, 3, draw_Jvertical_pixel1  # after drawing 3 horizontal pixels, draw the vertical one below the first
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    addiu $t5, $t5, -1
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Jhorizontal_pixels1 
draw_Jvertical_pixel1:
    # adjust back to draw vertical pixel below the first horizontal pixel
    addiu $t2, $t2, -4  # move back to the first pixel's column
    addiu $t1, $t1, -1   # move up one row 
    mul $t5, $t1, $t7   
    add $t5, $t5, $t2 
    sll $t5, $t5, 2   
    add $t5, $t0, $t5  
    sw $t6, 0($t5) 
draw_Jcomplete1:
    # adjusting stack values!!
    lw $t9, 4($sp)
    addiu $t9, $t9, 1
    sw $t9, 4($sp)          # updated xright 
    lw $t9, 12($sp)
    addiu $t9, $t9, -1 
    sw $t9, 12($sp)          # updated ydown
    
    li $t9, -1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    j game_loop 
    
draw_Jstate_2:
    li $t3, 0
    addiu $t2, $t2, 1 # shift x right by 1
draw_Jhorizontal_pixels2:
    bge $t3, 2, draw_Jvertical_pixels2  
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Jhorizontal_pixels2
draw_Jvertical_pixels2:
    addiu $t2, $t2, -2  
    addiu $t1, $t1, 1   
    li $t3, 0  
draw_Jvertical2:
    bge $t3, 2, draw_Jcomplete2  
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t1, $t1, 1
    addiu $t3, $t3, 1
    j draw_Jvertical2
draw_Jcomplete2:
    # adjusting stack values
    # xleft shift by 1 
    lw $t9, 0($sp)       
    addiu $t9, $t9, 1
    sw $t9, 0($sp)    
    # x right shift by 1
    lw $t9, 4($sp)         
    addiu $t9, $t9, 1
    sw $t9, 4($sp)
    
    li $t9, 1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    j game_loop
    
draw_Jstate_3:
    li $t3, 0
    addiu $t1, $t1, 2
    addiu $t2, $t2, 1
draw_Jvertical3:
    # single vertical pixel at the bottom
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    addiu $t5, $t5, 4
    sw $t6, 0($t5)
    addiu $t1, $t1, -1
    addiu $t2, $t2, 1  # move one column to the left to align next pixels
draw_Jhorizontal_pixels3:
    bge $t3, 3, draw_Jcomplete3
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5)
    addiu $t2, $t2, -1
    addiu $t3, $t3, 1
    j draw_Jhorizontal_pixels3
draw_Jcomplete3:
    # adjusting stack values
    # xright shift by 1 
    lw $t9, 4($sp)          
    addiu $t9, $t9, 1
    sw $t9, 4($sp)           
    # yup shift by 1
    lw $t9, 8($sp)
    addiu $t9, $t9, 1     
    sw $t9, 8($sp)     
    
    li $t9, 0
    sw $t9, 16($sp)  
    li $t9, -1
    sw $t9, 20($sp)
    j game_loop
    
insert_tetrominoI:
    lw $t6, ORANGE
    # initializing 
    addiu $t9, $t2, 0       
    sw $t9, 0($sp)          # store xleft
    addiu $t9, $t2, 3       
    sw $t9, 4($sp)          # store xright
    addiu $t9, $t1, 0      
    sw $t9, 8($sp)          # store yup    
    sw $t9, 12($sp)         # store ydown
    
    li $t9, -1
    sw $t9, 16($sp)  
    li $t9, -2
    sw $t9, 20($sp)
    # state for each orientation
    beq $t4, 0, draw_Istate_0
    beq $t4, 1, draw_Istate_1
    beq $t4, 2, draw_Istate_0
    beq $t4, 3, draw_Istate_1
draw_Istate_0:
    li $t3, 0  # pixel counter
draw_Ihorizontal_pixels0:
    bge $t3, 4, draw_Icomplete0
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Ihorizontal_pixels0
draw_Icomplete0:
    j game_loop
draw_Istate_1:
    li $t3, 0
    addiu $t2, $t2, 1 # shift x right by 1 
draw_Ivertical1:
    bge $t3, 4, draw_Icomplete1  
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t1, $t1, 1
    addiu $t3, $t3, 1
    j draw_Ivertical1
draw_Icomplete1:
    # xleft shift by 1 
    lw $t9, 0($sp)       
    addiu $t9, $t9, 1
    sw $t9, 0($sp)    
    # x right shift by 2
    lw $t9, 4($sp)         
    addiu $t9, $t9, -2
    sw $t9, 4($sp)
    # ydown 
    lw $t9, 12($sp)         
    addiu $t9, $t9, 3
    sw $t9, 12($sp)
    
    li $t9, 1
    sw $t9, 16($sp)  
    li $t9, 2
    sw $t9, 20($sp)
    j game_loop

insert_tetrominoO:
    lw $t6, RED
    # initializing 
    addiu $t9, $t2, 0       
    sw $t9, 0($sp)          # store xleft
    addiu $t9, $t2, 1       
    sw $t9, 4($sp)          # store xright
    addiu $t9, $t1, 0      
    sw $t9, 8($sp)          # store yup 
    addiu $t9, $t1, 1 
    sw $t9, 12($sp)         # store ydown
    
    li $t9, 0
    sw $t9, 16($sp)  
    sw $t9, 20($sp)
    
draw_O:
    li $t3, 0
draw_Oloop:
    bge $t3, 2, draw_Ocomplete
    mul $t5, $t1, $t7
    add $t8, $t5, $t2
    addiu $t4, $t8, 1
    sll $t8, $t8, 2 
    add $t8, $t0, $t8
    sw $t6, 0($t8) 
    sll $t4, $t4, 2 
    add $t4, $t0, $t4
    sw $t6, 0($t4) 
    addiu $t3, $t3, 1
    addiu $t1, $t1, 1
    j draw_Oloop
draw_Ocomplete:
    j game_loop

insert_tetrominoT:
    lw $t6, YELLOW
    # initializing 
    addiu $t9, $t2, 0       
    sw $t9, 0($sp)          # store xleft
    addiu $t9, $t2, 1       
    sw $t9, 4($sp)          # store xright
    addiu $t9, $t1, 0      
    sw $t9, 8($sp)          # store yup
    addiu $t9, $t1, 2       
    sw $t9, 12($sp)         # store ydown
    
    li $t9, 0
    sw $t9, 16($sp)  
    li $t9, 1
    sw $t9, 20($sp)
 
    beq $t4, 0, draw_Tstate_0
    beq $t4, 1, draw_Tstate_1
    beq $t4, 2, draw_Tstate_2
    beq $t4, 3, draw_Tstate_3
draw_Tstate_0:
    li $t3, 0  
draw_Tvertical_pixels0:
    bgt $t3, 2, draw_Thorizontal_pixel0 
    mul $t5, $t1, $t7  
    add $t5, $t5, $t2  
    addiu $t5, $t5, 1  
    sll $t5, $t5, 2   
    add $t5, $t0, $t5  
    sw $t6, 0($t5)   
    addiu $t1, $t1, 1 
    addiu $t3, $t3, 1  
    j draw_Tvertical_pixels0 
draw_Thorizontal_pixel0:
    addiu $t1, $t1, -2
    mul $t5, $t1, $t7     
    add $t5, $t5, $t2  
    sll $t5, $t5, 2   
    add $t5, $t0, $t5 
    sw $t6, 0($t5)
draw_Tcomplete0:
    j game_loop
    
draw_Tstate_1:
    li $t3, 0  
    addiu $t1, $t1, 1 # shift y down by 1
    addiu $t2, $t2, 1 # shift x right by 1
draw_Thorizontal_pixels1:
    bge $t3, 3, draw_Tvertical_pixel1  # after drawing 3 horizontal pixels, draw the vertical one below the first
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    addiu $t5, $t5, -1
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Thorizontal_pixels1 
draw_Tvertical_pixel1:
    # adjust back to draw vertical pixel below the first horizontal pixel
    addiu $t2, $t2, -3  # move back to the first pixel's column
    addiu $t1, $t1, -1   # move up one row 
    mul $t5, $t1, $t7   
    add $t5, $t5, $t2 
    sll $t5, $t5, 2   
    add $t5, $t0, $t5  
    sw $t6, 0($t5) 
draw_Tcomplete1:
    # adjusting stack values!!
    lw $t9, 4($sp)
    addiu $t9, $t9, 1
    sw $t9, 4($sp)          # updated xright 
    lw $t9, 12($sp)
    addiu $t9, $t9, -1 
    sw $t9, 12($sp)          # updated ydown
    
    li $t9, -1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    j game_loop 
    
draw_Tstate_2:
    li $t3, 0 
draw_Tvertical_pixels2:
    bgt $t3, 2, draw_Thorizontal_pixel2
    mul $t5, $t1, $t7 
    add $t5, $t5, $t2 
    addiu $t5, $t5, 1  
    sll $t5, $t5, 2    
    add $t5, $t0, $t5  
    sw $t6, 0($t5)    
    addiu $t1, $t1, 1  
    addiu $t3, $t3, 1  
    j draw_Tvertical_pixels2 
draw_Thorizontal_pixel2:
    addiu $t1, $t1, -2
    mul $t5, $t1, $t7     
    add $t5, $t5, $t2
    addiu $t5, $t5, 2
    sll $t5, $t5, 2 
    add $t5, $t0, $t5 
    sw $t6, 0($t5)
draw_Tcomplete2:
    # adjusting stack values
    # xleft shift by 1 
    lw $t9, 0($sp)       
    addiu $t9, $t9, 1
    sw $t9, 0($sp)    
    # x right shift by 1
    lw $t9, 4($sp)         
    addiu $t9, $t9, 1
    sw $t9, 4($sp)
    
    li $t9, 1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    j game_loop
    
draw_Tstate_3:
    li $t3, 0  
    addiu $t1, $t1, 1 # shift y down by 1
    addiu $t2, $t2, 1 # shift x right by 1
draw_Thorizontal_pixels3:
    bge $t3, 3, draw_Tvertical_pixel3  # after drawing 3 horizontal pixels, draw the vertical one below the first
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    addiu $t5, $t5, -1
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Thorizontal_pixels3 
draw_Tvertical_pixel3:
    addiu $t2, $t2, -3  
    addiu $t1, $t1, 1  
    mul $t5, $t1, $t7   
    add $t5, $t5, $t2 
    sll $t5, $t5, 2   
    add $t5, $t0, $t5  
    sw $t6, 0($t5) 
draw_Tcomplete3:
    # adjusting stack values
    # xright shift by 1 
    lw $t9, 4($sp)          
    addiu $t9, $t9, 1
    sw $t9, 4($sp)           
    # yup shift by 1
    lw $t9, 8($sp)
    addiu $t9, $t9, 1     
    sw $t9, 8($sp)  
    
    li $t9, 0
    sw $t9, 16($sp)  
    li $t9, -1
    sw $t9, 20($sp)
    j game_loop


insert_tetrominoS:
    lw $t6, CYAN
    addiu $t9, $t2, 0  
    sw $t9, 0($sp)
    addiu $t9, $t2, 1       
    sw $t9, 4($sp)      
    addiu $t9, $t1, 0   
    sw $t9, 8($sp)    
    addiu $t9, $t1, 2       
    sw $t9, 12($sp)  
    
    li $t9, 1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    beq $t4, 0, draw_Sstate_0
    beq $t4, 1, draw_Sstate_1
    beq $t4, 2, draw_Sstate_0
    beq $t4, 3, draw_Sstate_1

draw_Sstate_0:
    li $t3, 0
draw_Spixels0a:
    bge $t3, 2, draw_Spixels0b 
    mul $t5, $t1, $t7 
    add $t5, $t5, $t2
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t1, $t1, 1 
    addiu $t3, $t3, 1
    j draw_Spixels0a
draw_Spixels0b:
    addiu $t1, $t1, -1 # move up 1 column
    addiu $t2, $t2, 1 # move right 1 column
    li $t3, 0
draw_S0loop:
    bge $t3, 2, draw_Scomplete0
    mul $t5, $t1, $t7 
    add $t5, $t5, $t2
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t1, $t1, 1 
    addiu $t3, $t3, 1
    j draw_S0loop 
draw_Scomplete0:
    j game_loop
    
draw_Sstate_1:
    li $t3, 0
draw_Svertical1:
    mul $t5, $t1, $t7  
    add $t5, $t5, $t2
    addiu $t4, $t5, 1
    sll $t5, $t5, 2
    sll $t4, $t4, 2
    add $t5, $t0, $t5
    add $t4, $t0, $t4
    sw $t6, 0($t4)
    sw $t6, 0($t5)
    addiu $t1, $t1, 1
    addiu $t2, $t2, -1  # move one column to the left to align next pixels
draw_Shorizontal_pixels1:
    bge $t3, 2, draw_Scomplete1
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5)
    addiu $t2, $t2, 1
    addiu $t3, $t3, 1
    j draw_Shorizontal_pixels1
draw_Scomplete1:
# same as L3
    lw $t9, 0($sp)          
    addiu $t9, $t9, -1
    sw $t9, 0($sp)           
    lw $t9, 12($sp)
    addiu $t9, $t9, -1     
    sw $t9, 12($sp)   
    
    li $t9, -1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    j game_loop

insert_tetrominoZ:
    lw $t6, GREEN
    addiu $t9, $t2, 0  
    sw $t9, 0($sp)
    addiu $t9, $t2, 1       
    sw $t9, 4($sp)      
    addiu $t9, $t1, 0   
    sw $t9, 8($sp)    
    addiu $t9, $t1, 2       
    sw $t9, 12($sp)  
    
    li $t9, 1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    beq $t4, 0, draw_Zstate_0
    beq $t4, 1, draw_Zstate_1
    beq $t4, 2, draw_Zstate_0
    beq $t4, 3, draw_Zstate_1

draw_Zstate_0:
    li $t3, 0
draw_Zpixels0a:
    bge $t3, 2, draw_Zpixels0b
    mul $t5, $t1, $t7
    add $t5, $t5, $t2  
    addiu $t5, $t5, 1  
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5)
    addiu $t1, $t1, 1 
    addiu $t3, $t3, 1
    j draw_Zpixels0a
draw_Zpixels0b:
    addiu $t1, $t1, -1 # move down 1 row
    addiu $t2, $t2, -1 # move left 1 column
    li $t3, 0
draw_Z0loop:
    bge $t3, 2, draw_Zcomplete0
    mul $t5, $t1, $t7
    add $t5, $t5, $t2  
    addiu $t5, $t5, 1  
    sll $t5, $t5, 2
    add $t5, $t0, $t5
    sw $t6, 0($t5)
    addiu $t1, $t1, 1 
    addiu $t3, $t3, 1
    j draw_Z0loop
draw_Zcomplete0:
    j game_loop
    
draw_Zstate_1:
    li $t3, 0
    addiu $t1, $t1, 1 # shift y down by 1
    addiu $t2, $t2, 1 # shift x right by 2
draw_Zpixels1a:
    bge $t3, 2, draw_Zpixels1b
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    addiu $t5, $t5, -1
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Zpixels1a
draw_Zpixels1b:
    li $t3, 0
    addiu $t1, $t1, -1
    addiu $t2, $t2, -3
draw_Z1loop:
    bge $t3, 2, draw_Zcomplete1
    mul $t5, $t1, $t7
    add $t5, $t5, $t2
    addiu $t5, $t5, -1
    sll $t5, $t5, 2 
    add $t5, $t0, $t5
    sw $t6, 0($t5) 
    addiu $t2, $t2, 1 
    addiu $t3, $t3, 1 
    j draw_Z1loop
draw_Zcomplete1:
    lw $t9, 0($sp)
    addiu $t9, $t9, -1
    sw $t9, 0($sp)   
    lw $t9, 12($sp)
    addiu $t9, $t9, -1 
    sw $t9, 12($sp)
    li $t9, -1
    sw $t9, 16($sp)  
    li $t9, 0
    sw $t9, 20($sp)
    j game_loop

#################################
# MAIN GAME SCREEN UPDATES
# Order: 
# 1) Calculate block_positions (7 different). 
# 2) Check if hit bottom
# 3) Check if hit other tetromino
# 4a) If 2 and 3 are NO, go back to game loop.
# 4b) If 2 or 3, mark the indices to be filled with the correct gameField value.
# 5) Do the actual colouring of the gameField values
# 6) check if any lines need to be cleared 
# 7) If 6, shift all rows above the line(s) down.
# 8) reset tetromino position and generate a new tetromino, which feeds into game_loop.

#################################
# CALCULATE 4 BLOCK POSITIONS. 7 different
calculate_block_positions:
    lw $t6, 0($sp)  # xleft
    lw $t7, 4($sp)  # xright
    lw $t8, 8($sp)  # yup
    lw $t9, 12($sp) # ydown
    la $a0, blockX
    la $a1, blockY
    lw $t3, tetromino_state
    beq $s3, 0, calculate_L
    beq $s3, 1, calculate_J
    beq $s3, 2, calculate_I
    beq $s3, 3, calculate_O
    beq $s3, 4, calculate_T
    beq $s3, 5, calculate_S
    beq $s3, 6, calculate_Z

calculate_L:
    beq $t3, 0, calculate_L0
    beq $t3, 1, calculate_L1
    beq $t3, 2, calculate_L2
    beq $t3, 3, calculate_L3
calculate_L0:
    # Block 1 - Top block
    sw $t6, 0($a0)  # store x for block 1
    sw $t8, 0($a1)  # store y for block 1
    # Block 2
    sw $t6, 4($a0)  # store x for block 2
    addiu $t4, $t8, 1  # y + 1
    sw $t4, 4($a1)  # store y for block 2
    # Block 3
    sw $t6, 8($a0) 
    sw $t9, 8($a1) 
    # Block 4 
    sw $t7, 12($a0)  
    sw $t9, 12($a1) 
    j check_touch_bottom
calculate_L1:
    # Block 1 
    sw $t7, 0($a0) 
    sw $t8, 0($a1)
    # Block 2
    addiu $t4, $t6, 1  # xleft + 1
    sw $t4, 4($a0) 
    sw $t8, 4($a1) 
    # Block 3
    sw $t6, 8($a0)  # xleft block 3
    sw $t8, 8($a1)  # yup block 3
    # Block 4 - bottom left
    sw $t6, 12($a0)  # xleft block 4
    sw $t9, 12($a1)  # ydown block 4
    j check_touch_bottom
calculate_L2:
    # Block 1 - bottom block
    sw $t7, 0($a0)  
    sw $t9, 0($a1)  
    # Block 2
    sw $t7, 4($a0)  
    addiu $t4, $t8, 1  # y + 1
    sw $t4, 4($a1)  
    # Block 3
    sw $t7, 8($a0)  # xright block 3
    sw $t8, 8($a1)  # yup block 3
    # Block 4 - bottom left
    sw $t6, 12($a0)  # xleft block 4
    sw $t8, 12($a1)  # yup block 4
    j check_touch_bottom
calculate_L3:
    # Block 1 - left
    sw $t6, 0($a0) 
    sw $t9, 0($a1) 
    # Block 2
    addiu $t4, $t6, 1  # xleft + 1
    sw $t4, 4($a0) 
    sw $t9, 4($a1)
    # Block 3
    sw $t7, 8($a0)  # xright block 3
    sw $t9, 8($a1)  # yup block 3
    # Block 4 - bottom left
    sw $t7, 12($a0)  # xright block 4
    sw $t8, 12($a1)  # yup block 4
    j check_touch_bottom   

calculate_J:
    beq $t3, 0, calculate_J0
    beq $t3, 1, calculate_J1
    beq $t3, 2, calculate_J2
    beq $t3, 3, calculate_J3
calculate_J0:
    # Block 1
    sw $t7, 0($a0) 
    sw $t8, 0($a1) 
    # Block 2
    sw $t7, 4($a0)  
    addiu $t4, $t8, 1 
    sw $t4, 4($a1)
    # Block 3
    sw $t7, 8($a0) 
    sw $t9, 8($a1) 
    # Block 4
    sw $t6, 12($a0) 
    sw $t9, 12($a1) 
    j check_touch_bottom
calculate_J1:
    # Block 1
    sw $t7, 0($a0) 
    sw $t9, 0($a1)  
    # Block 2
    addiu $t4, $t6, 1 
    sw $t4, 4($a0)  
    sw $t9, 4($a1) 
    # Block 3
    sw $t6, 8($a0) 
    sw $t9, 8($a1) 
    # Block 4 
    sw $t6, 12($a0) 
    sw $t8, 12($a1) 
    j check_touch_bottom
calculate_J2:
    # Block 1
    sw $t7, 0($a0) 
    sw $t8, 0($a1)  
    # Block 2
    addiu $t4, $t8, 1 
    sw $t6, 4($a0)  
    sw $t4, 4($a1) 
    # Block 3
    sw $t6, 8($a0) 
    sw $t9, 8($a1) 
    # Block 4
    sw $t6, 12($a0) 
    sw $t8, 12($a1) 
    j check_touch_bottom
calculate_J3:
    # Block 1
    sw $t7, 0($a0) 
    sw $t8, 0($a1)  
    # Block 2
    addiu $t4, $t6, 1 
    sw $t4, 4($a0)  
    sw $t8, 4($a1) 
    # Block 3
    sw $t6, 8($a0) 
    sw $t8, 8($a1) 
    # Block 4 - bottom right
    sw $t7, 12($a0) 
    sw $t9, 12($a1) 
    j check_touch_bottom 

calculate_I:
    beq $t3, 0, calculate_I0
    beq $t3, 1, calculate_I1
    beq $t3, 2, calculate_I0
    beq $t3, 3, calculate_I1
calculate_I0:
    # Block 1
    sw $t6, 0($a0) 
    sw $t8, 0($a1) 
    # Block 2
    addiu $t4, $t6, 1 
    sw $t4, 4($a0)  
    sw $t8, 4($a1)
    # Block 3
    addiu $t4, $t6, 2
    sw $t4, 8($a0) 
    sw $t8, 8($a1) 
    # Block 4
    sw $t7, 12($a0) 
    sw $t8, 12($a1) 
    j check_touch_bottom
calculate_I1:
    # Block 1
    sw $t6, 0($a0) 
    sw $t8, 0($a1) 
    # Block 2
    addiu $t4, $t8, 1 
    sw $t6, 4($a0)  
    sw $t4, 4($a1)
    # Block 3
    addiu $t4, $t8, 2
    sw $t6, 8($a0) 
    sw $t4, 8($a1) 
    # Block 4
    sw $t6, 12($a0) 
    sw $t9, 12($a1) 
    j check_touch_bottom

calculate_O:
    # Block 1
    sw $t6, 0($a0) 
    sw $t8, 0($a1) 
    # Block 2
    sw $t7, 4($a0)  
    sw $t8, 4($a1)
    # Block 3
    sw $t6, 8($a0) 
    sw $t9, 8($a1) 
    # Block 4
    sw $t7, 12($a0) 
    sw $t9, 12($a1) 
    j check_touch_bottom

calculate_T:
    beq $t3, 0, calculate_T0
    beq $t3, 1, calculate_T1
    beq $t3, 2, calculate_T2
    beq $t3, 3, calculate_T3
calculate_T0:
    # Block 1
    sw $t7, 0($a0) 
    sw $t8, 0($a1) 
    # Block 2
    sw $t7, 4($a0)  
    addiu $t4, $t8, 1 
    sw $t4, 4($a1)
    # Block 3
    sw $t7, 8($a0) 
    sw $t9, 8($a1) 
    # Block 4
    sw $t6, 12($a0) 
    sw $t4, 12($a1) 
    j check_touch_bottom
calculate_T1:
    # Block 1
    sw $t7, 0($a0) 
    sw $t9, 0($a1)  
    # Block 2
    addiu $t4, $t6, 1 
    sw $t4, 4($a0)  
    sw $t9, 4($a1) 
    # Block 3
    sw $t6, 8($a0) 
    sw $t9, 8($a1) 
    # Block 4 
    sw $t4, 12($a0) 
    sw $t8, 12($a1) 
    j check_touch_bottom
calculate_T2:
    # Block 1
    sw $t6, 0($a0) 
    sw $t8, 0($a1)  
    # Block 2
    addiu $t4, $t8, 1 
    sw $t6, 4($a0)  
    sw $t4, 4($a1) 
    # Block 3
    sw $t6, 8($a0) 
    sw $t9, 8($a1) 
    # Block 4
    sw $t7, 12($a0) 
    sw $t4, 12($a1) 
    j check_touch_bottom
calculate_T3:
    # Block 1
    sw $t7, 0($a0) 
    sw $t8, 0($a1)  
    # Block 2
    addiu $t4, $t6, 1 
    sw $t4, 4($a0)  
    sw $t8, 4($a1) 
    # Block 3
    sw $t6, 8($a0) 
    sw $t8, 8($a1) 
    # Block 4
    sw $t4, 12($a0) 
    sw $t9, 12($a1) 
    j check_touch_bottom

calculate_S:
    beq $t3, 0, calculate_S0
    beq $t3, 1, calculate_S1
    beq $t3, 2, calculate_S0
    beq $t3, 3, calculate_S1
calculate_S0:
    # Block 1
    sw $t6, 0($a0) 
    sw $t8, 0($a1)  
    # Block 2
    addiu $t4, $t8, 1 
    sw $t6, 4($a0)  
    sw $t4, 4($a1) 
    # Block 3
    sw $t7, 8($a0) 
    sw $t4, 8($a1) 
    # Block 4
    sw $t7, 12($a0) 
    sw $t9, 12($a1) 
    j check_touch_bottom
calculate_S1:
    # Block 1
    sw $t6, 0($a0) 
    sw $t9, 0($a1)  
    # Block 2
    addiu $t4, $t6, 1 
    sw $t4, 4($a0)  
    sw $t9, 4($a1) 
    # Block 3
    sw $t4, 8($a0) 
    sw $t8, 8($a1) 
    # Block 4
    sw $t7, 12($a0) 
    sw $t8, 12($a1) 
    j check_touch_bottom
    
calculate_Z:
    beq $t3, 0, calculate_Z0
    beq $t3, 1, calculate_Z1
    beq $t3, 2, calculate_Z0
    beq $t3, 3, calculate_Z1
calculate_Z0:
    # Block 1
    sw $t7, 0($a0) 
    sw $t8, 0($a1)  
    # Block 2
    addiu $t4, $t8, 1 
    sw $t7, 4($a0)  
    sw $t4, 4($a1) 
    # Block 3
    sw $t6, 8($a0) 
    sw $t4, 8($a1) 
    # Block 4
    sw $t6, 12($a0) 
    sw $t9, 12($a1) 
    j check_touch_bottom
calculate_Z1:
    # Block 1
    sw $t6, 0($a0) 
    sw $t8, 0($a1)  
    # Block 2
    addiu $t4, $t6, 1 
    sw $t4, 4($a0)  
    sw $t9, 4($a1) 
    # Block 3
    sw $t4, 8($a0) 
    sw $t8, 8($a1) 
    # Block 4
    sw $t7, 12($a0) 
    sw $t9, 12($a1) 
    j check_touch_bottom

#################################
# 2) check if we touch bottom
check_touch_bottom:
    lw $t3, 12($sp)          # load ydown value
    li $t2, 30               
    bge $t3, $t2, mark_tetromino
    j collision_check
# 3) check for other tetromino collision
collision_check:
    # setup for collision check
    la $t0, gameField    
    li $t5, 14              # width of the game field
    # BLOCK 1
    lw $t1, 0($a0)          # x
    lw $t2, 0($a1)          # y 
    addiu $t2, $t2, 1       # increment y to cell below
    mul $t8, $t2, $t5       # y * width
    add $t1, $t8, $t1       # add x to get the final index
    add $t1, $t0, $t1       # get memory addresss
    lb $t9, 0($t1)          # load value to check if filled
    bnez $t9, mark_tetromino  # if filled, generate new tetromino
    # BLOCK 2
    lw $t1, 4($a0)        
    lw $t2, 4($a1)         
    addiu $t2, $t2, 1       
    mul $t8, $t2, $t5     
    add $t1, $t8, $t1    
    add $t1, $t0, $t1    
    lb $t9, 0($t1)       
    bnez $t9, mark_tetromino 
    # BLOCK 3
    lw $t1, 8($a0)      
    lw $t2, 8($a1)         
    addiu $t2, $t2, 1     
    mul $t8, $t2, $t5      
    add $t1, $t8, $t1     
    add $t1, $t0, $t1    
    lb $t9, 0($t1)      
    bnez $t9, mark_tetromino 
    # BLOCK 4
    lw $t1, 12($a0)         
    lw $t2, 12($a1)      
    addiu $t2, $t2, 1     
    mul $t8, $t2, $t5     
    add $t1, $t8, $t1    
    add $t1, $t0, $t1    
    lb $t9, 0($t1)     
    bnez $t9, mark_tetromino  
    
    j game_loop          # continue game if not touching bottom
    
# 4) Mark indices to be filled with correct gameField value
mark_tetromino:
    # convert indices
    la $t0, gameField
    li $t7, 14         # width of the game field
    move $t3, $s3
    addiu $t3, $t3, 2 # increment by 2 to get correct colour from colour palette
    # for each of the four blocks, convert x, y to index and mark in gameField
    # Block 1
    lw $t1, 0($a0)    # x 
    lw $t2, 0($a1)    # y 
    mul $t2, $t2, $t7  # y * width
    add $t1, $t1, $t2  # index + x
    add $t1, $t0, $t1
    sb $t3, 0($t1)     # store in gamefield

    # Block 2
    lw $t1, 4($a0)    # x for block 2
    lw $t2, 4($a1)    # y for block 2
    mul $t2, $t2, $t7
    add $t1, $t1, $t2
    add $t1, $t0, $t1
    sb $t3, 0($t1)

    # Block 3
    lw $t1, 8($a0)    # x for block 3
    lw $t2, 8($a1)    # y for block 3
    mul $t2, $t2, $t7
    add $t1, $t1, $t2
    add $t1, $t0, $t1
    sb $t3, 0($t1)

    # Block 4
    lw $t1, 12($a0)    # x for block 4
    lw $t2, 12($a1)    # y for block 4
    mul $t2, $t2, $t7
    add $t1, $t1, $t2
    add $t1, $t0, $t1
    sb $t3, 0($t1)

    # steps 5 and 6/7 from earlier
    jal update_display
    jal clear_lines
    j new_tetromino

# fill in the correct colour
update_display:
    la $t0, gameField       
    lw $t1, ADDR_DSPL        
    li $t2, 0                 # counter for cells (index in gameField)
    li $t7, 0                 # counter for iterating through gameField
update_loop:
    li $t9, 434               # total cells 
    beq $t7, $t9, end_update  # if all cells have been checked, end update
    lb $a0, 0($t0)            # load current cell
    beqz $a0, skip_cell       # skip if empty
    
    # determine colour based on $a0 value
    la $t8, colour_table      # load colour palette
    sll $a0, $a0, 2           # x4 for byte
    add $t8, $t8, $a0         # calculate the memory address of the colour
    lw $t4, 0($t8)            # 
    
    div $t2, $t7, 14          # dividing index by 14 (width) to find row; result in LO
    mflo $a1                  # quotient (row) to $a1
    mfhi $a2                  # column as remainder 
    # calculate display index
    mul $a1, $a1, 32          # row index in units 
    add $a1, $a1, $a2         # column indices
    sll $a1, $a1, 2           # byte
    # colour display if filled
    add $a1, $t1, $a1         # memory address 
    sw $t4, 0($a1)            
skip_cell:
    addiu $t0, $t0, 1      
    addiu $t7, $t7, 1    
    j update_loop        
end_update:
    jr $ra               

# Clear lines that are filled and shift above lines down 
clear_lines:
    la $t0, gameField     
    li $t1, 433      # use 433 because 0-433
    li $t2, 13       # number of cells per row to check (13x30)
    li $t6, 14       # total # including skipped check
check_rows:
    li $t3, 0                    # accu
    bltz $t1, end_check          # if $t1 is negative done checking
    # adjust $t7 to point to the 1st index of the current row 
    addiu $t7, $t1, -12         
check_current_row:
    add $t4, $t0, $t7            # calculate address
    lb $t5, 0($t4)        
    beqz $t5, next_row           # if any cell in row not filled, skip
    addiu $t3, $t3, 1       
    addiu $t7, $t7, 1          
    blt $t3, $t2, check_current_row
    #shift down if all filled.
    j shift_down
next_row:
    addiu $t1, $t1, -14       
    j check_rows                 
shift_down:
    # # # shift all rows down by one row (14 cells)
    addiu $t7, $t1, -13        
shift_loop:
    bltz $t7, update_screen    # if t6 is 0 we are done with shifting down
    add $t8, $t0, $t7          # original cell
    addiu $t4, $t7, 14          # shift one row down
    add $t5, $t0, $t4
    lb $t3, 0($t8)             # load value
    sb $t3, 0($t5)             # store value in new spot
    addiu $t7, $t7, -1         # go to prev cell
    blt $t7, $t1, shift_loop   
    j update_screen      
update_screen:
    lw $t4, clearedRows
    addiu $t4, $t4, 1       # Increment cleared rows count
    sw $t4, clearedRows
cleared_audio:
    li $a0, 84     # high c pitch
    li $a1, 125    # milliseconds
    li $a2, 0      # piano
    li $a3, 127    # volume 0-127
    li $v0, 31     # syscall for MIDI
    syscall
    j clear_lines
end_check:
    jr $ra                  

# Reset tetromino values, insert a new tetromino. loops back to game loop
new_tetromino:
    # reset tetromino position to the top and middle of the grid. reset state to 0
    li $t1, 7                # middle x position
    sw $t1, tetromino_x
    li $t1, 0                # top y position
    sw $t1, tetromino_y
    li $t1, 0
    sw $t1, tetromino_state
    # draw the new tetromino and update the screen
    j insert_tetromino

#################################
# CODE FOR KEY INPUTS
# checks to see if wasd inputs are allowed. implements p and q .

move_left:
    lw $t1, tetromino_x    # load x position 
    lw $t2, 0($sp)         # xleft
    li $t3, 1            
    bgt $t2, $t3, check_move_left # check if $t2 >= 1
    j end_move            # if not, end move
check_move_left:
    la $t5, gameField         
    li $t6, 14              
    la $a0, blockX     # first block xcoord
    la $a1, blockY     # y coord
    li $t4, 0 # loop counts to 4
check_left_loop:
    bge $t4, 4, go_left  # exit loop after 4 blocks 
    sll $t3, $t4, 2     # shift for address bytes
    add $t7, $a0, $t3  # address current block's x coordinate
    add $t8, $a1, $t3  # y
    
    lw $t7, 0($t7)     
    lw $t8, 0($t8)     
    addi $t7, $t7, -1  # x-1 for left move
    mul $t8, $t8, $t6  # y * width
    add $t8, $t8, $t7  # add x 
    add $t8, $t5, $t8  # address in gameField
    lb $t9, 0($t8)    
    bnez $t9, end_move # if nonzero, collision detected
    addiu $t4, $t4, 1
    j check_left_loop
go_left:
    addiu $t1, $t1, -1  # move left
    addiu $t2, $t2, -1  # adjust xleft
    sw $t1, tetromino_x # update tetromino_x
    sw $t2, 0($sp)      # update xleft on the stack
    j redraw_screen     # redraw tetromino
    
move_right:
    lw $t1, tetromino_x        
    lw $t2, 4($sp)      # xright
    li $t3, 13             
    bgt $t3, $t2, check_move_right # if < 14
    j end_move       
check_move_right:
    la $t5, gameField          
    li $t6, 14                
    la $a0, blockX   
    la $a1, blockY    
    li $t4, 0 
check_right_loop:
    bge $t4, 4, go_right  
    sll $t3, $t4, 2    
    add $t7, $a0, $t3  
    add $t8, $a1, $t3  
    lw $t7, 0($t7)    
    lw $t8, 0($t8)    
    addi $t7, $t7, 1  
    mul $t8, $t8, $t6 
    add $t8, $t8, $t7 
    add $t8, $t5, $t8  
    lb $t9, 0($t8)    
    bnez $t9, end_move
    addiu $t4, $t4, 1
    j check_right_loop
go_right:
    addiu $t1, $t1, 1       
    addiu $t2, $t2, 1       
    sw $t1, tetromino_x  
    sw $t2, 4($sp)           
    j redraw_screen    
    
end_move:
    j redraw_screen        # update the display without moving

move_down:
    lw $t1, tetromino_y        # current y position 
    lw $t2, 12($sp)             # ydown
    li $t3, 30              
    bgt $t3, $t2, can_move_down 
    j end_move_down           
can_move_down:
    addiu $t1, $t1, 1         
    addiu $t2, $t2, 1     
    sw $t1, tetromino_y     
    sw $t2, 12($sp)             
    j redraw_screen      
end_move_down:
    j redraw_screen    
    
rotate:
    li $a0, 64     # middle c pitch
    li $a1, 250    # milliseconds
    li $a2, 0      # piano
    li $a3, 127    # volume 0-127
    li $v0, 31     # syscall for MIDI
    syscall
initialize_rotation:
    lw $t1, tetromino_state   # current rotation 
    lw $t3, 8($sp) # yup
    lw $t4, 12($sp) # ydown
    lw $t5, 0($sp) # xleft
    lw $t6, 4($sp) # xright
    lw $t7, 16($sp) # left_shift
    lw $t8, 20($sp) # right_shift
check_rotation_boundaries:
left_check:
    li $t9, 1 
    sub $t5, $t5, $t7
    bge $t5, $t9, right_check  # if xleft >= 1, right_check
    j redraw_screen
right_check:
    li $t9, 13 
    add $t6, $t6, $t8
    bge $t9, $t6, bottom_check #if xright <= 13
    j redraw_screen
bottom_check:
    li $t9, 30 
    bgt $t9, $t8, existing_check
    j redraw_screen

existing_check:
    la $t9, gameField       
    # adjust xleft and xright considering the shift for rotation
    sub $t5, $t5, $t7         # xleft adjusted for left shift
    add $t6, $t6, $t8         # xright adjusted for right shift
    li $t0, 14
    # CHECK ALL 4 CORNERS with shift applied
    # Check 1: xleft,yup - xleft_shift
    mul $t2, $t3, $t0        # calculate yup * width
    add $t2, $t2, $t5        # add adjusted xleft to get index
    add $t2, $t9, $t2        # address
    lb $t2, 0($t2)         
    bnez $t2, redraw_screen  # if not zero, collision detected, redraw
    # Check 2: xleft,ydown - xleft_shift
    mul $t2, $t4, $t0     
    add $t2, $t2, $t5       
    add $t2, $t9, $t2      
    lb $t2, 0($t2)         
    bnez $t2, redraw_screen 
    # Check 3: xright,yup + xright_shift
    mul $t2, $t3, $t0       
    add $t2, $t2, $t6       
    add $t2, $t9, $t2        
    lb $t2, 0($t2)          
    bnez $t2, redraw_screen  
    # Check 4: xright,ydown + xright_shift
    mul $t2, $t4, $t0      
    add $t2, $t2, $t6       
    add $t2, $t9, $t2       
    lb $t2, 0($t2)          
    bnez $t2, redraw_screen

    # if all checks pass:
    j rotation_possible

rotation_possible:
    addiu $t1, $t1, 1         # move to the next state
    # division by 4 to find how many times the state wraps around. use the remainder.
    li $t2, 4
    div $t1, $t2             
    mflo $t3                 
    mul $t3, $t3, $t2      
    sub $t1, $t1, $t3      
    # $t1 is the new state.
    sw $t1, tetromino_state   # save the new state
    j redraw_screen

redraw_screen:
    # Clear the screen and redraw everything
    jal clear_screen
    jal draw_walls
    jal draw_grid
    jal update_display
    jal clear_lines
    jal insert_tetromino_setup

pause:
    jal draw_pause 
wait_for_unpause:
    # wait for p to be pressed again. make sure pressing other keys has no affect
    # (game loop is not being accessed until p is pressed again).
    # when p is pressed again, go to calculate_block_positions; not game loop
    lw $t0, ADDR_KBRD   
    lw $t1, 0($t0) 
    beqz $t1, wait_for_unpause    # no key pressed, wait
    
    lw $a0, 4($t0)    
    
    beq $a0, 0x71, quit_game
    li $t2, 0x70     
    bne $a0, $t2, wait_for_unpause # if 'p' is not pressed wait 

    jal clear_drawing
    j calculate_block_positions
    
draw_pause:
    lw $t0, ADDR_DSPL           
    lw $t1, WHITE              
    li $t2, 340                  # start index for the drawing
    li $t3, 10                   # Total rows to fill
draw_pause_rows:
    beqz $t3, end_draw_pause     # end loop after 10 rows
    # calculate addresses for  six indices in the current row
    mul $t4, $t2, 4             
    add $t5, $t0, $t4           
    sw $t1, 0($t5)              
    sw $t1, 4($t5)      
    sw $t1, 8($t5)       
    sw $t1, 20($t5)    
    sw $t1, 24($t5)       
    sw $t1, 28($t5)        
    addi $t2, $t2, 32            # move to the start index of the next row
    addi $t3, $t3, -1  
    j draw_pause_rows         
end_draw_pause:
    jr $ra              

clear_drawing:
# this code just follows the exact same logic as above
    lw $t0, ADDR_DSPL           
    lw $t1, BACKGROUND          
    li $t2, 340               
    li $t3, 10              
draw_pause_rows:
    beqz $t3, end_draw_pause     
    mul $t4, $t2, 4             
    add $t5, $t0, $t4           
    sw $t1, 0($t5)             
    sw $t1, 4($t5)             
    sw $t1, 8($t5)           
    sw $t1, 20($t5)          
    sw $t1, 24($t5)            
    sw $t1, 28($t5)           
    addi $t2, $t2, 32          
    addi $t3, $t3, -1           
    j draw_pause_rows          

quit_game:
    jal clear_screen
    li $v0, 10
    syscall
#################################
    