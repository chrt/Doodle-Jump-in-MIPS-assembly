#####################################################################
#
# CSC258H1F Fall 2020 Assembly Final Project
# University of Toronto, St. George
#
# Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
#####################################################################

.eqv	COLOR_OF_PLATFORMS		0xff8000
.eqv	DISPLAY_ADDRESS			0x10008000
.eqv	ARRAY_SIZE			16384
.eqv	DISPLAY_ADDRESS_END		0x1000C000
.eqv	INITIAL_VELOCITY_Y		-60
.eqv	ACCELERATION_Y			4
.eqv	SHIFT				4
.eqv	MIN_Y				20
.eqv	MUSIC_NOTE_DURATION		1200  # ms
.eqv	MUSIC_NOTE_DURATION_FAILURE	1000
.eqv	MUSICAL_INSTRUMENT		8  # Chromatic Percussion
.eqv	VOLUME				100  # 0 - 127
.eqv	MUSIC_SIZE			64  # 16 * 4 = 64
.eqv	MUSIC_SIZE_FAILURE		16

# Notes for music
.eqv	F3	53
.eqv	F3s	54
.eqv	G3	55
.eqv	G3s	56
.eqv	A3	57
.eqv	A3s	58
.eqv	B3	59
.eqv	B3s	60
.eqv	C4	60
.eqv	C4s	61
.eqv	D4	62
.eqv	D4s	63
.eqv	E4	64
.eqv	E4s	65
.eqv	F4	65
.eqv	F4s	66
.eqv	G4	67
.eqv	G4s	68
.eqv	A4	69
.eqv	A4s	70
.eqv	B4	71
.eqv	B4s	72
.eqv	C5	72
.eqv	C5s	73
.eqv	D5	74
.eqv	D5s	75
.eqv	E5	76
.eqv	E5s	77
.eqv	F5	77
.eqv	F5s	78

.macro	index (%result, %column, %row)
	# %result = (%column + %row * 64) * 4
	# %result != %column
	sll %result, %row, 6
	add %result, %result, %column
	sll %result, %result, 2
.end_macro

.macro random_i (%upper_bound)
	# 0 <= result ($a0) < %upper_bound
	li $v0, 42
	li $a0, 0
	li $a1, %upper_bound
	syscall
.end_macro

.macro random (%upper_bound)
	li $v0, 42
	li $a0, 0
	move $a1, %upper_bound
	syscall
.end_macro

.macro push (%register)
	addi $sp, $sp, -4
	sw %register, ($sp)
.end_macro

.macro pop (%register)
	lw %register, ($sp)
	addi $sp, $sp, 4
.end_macro

# Map generator:
# The vertical distance to the next platform is uniformly distributed on (d-10, d],
# where d = max(28, 18 + $s0 / 8)
# The horizontal position is uniformly distributed
# The length of a platform = max(7, 15 - $s0 / 8)

.macro vertical_distance_to_the_next (%result, %label)
	sra %result, $s0, 3
	addi %result, %result, 18
	ble %result, 28, %label
	li %result, 28
	%label :
	random_i (10)
	sub %result, %result, $a0
.end_macro

.macro length (%result, %tmp, %label)
	sra %tmp, $s0, 3
	li %result, 15
	sub %result, %result, %tmp
	bge %result, 7, %label
	li %result, 7
	%label :
.end_macro

.data
	canvas: .space 16384
	background: .word 0x7ebfff:4096 # TODO
	platforms: .word 0:4096
	doodler_left: .word 0xffff00:49
	doodler_right: .word 0xffff00:49
	music: .word	F5s, E5, D5, C5s, B4, A4, B4, C5s,
			D5, C5s, B4, A4, G4, D4, G4, A4
	failure: .word	D5, C5s, C5, B4

.text
	# Register usage:
	# $s0	the number of collisions
	# $s1	x-coordinate of the Doodler
	# $s2	y-coordinate of the Doodler << SHIFT
	# $s3	velocity-x
	# $s4	velocity-y
	# $s5	vertical distance to the next platform
	# $s6	the index of the note to be played
	# $s7	doodler facing left / right

.globl main
main:
	# Init the arrays and the s-registers
	jal init
	jal reset

	main_loop:
		# Sleep for 40 ms
		sleep:
		li $v0, 32
		li $a0, 40
		syscall

		# Redraw the screen if necessary
		sra $a0, $s2, SHIFT  # $a0 = old y
		add $s2, $s2, $s4
		sra $a1, $s2, SHIFT  # $a1 = new y
		bne $a0, $a1, redraw
		bnez $s3, redraw
		j redraw_end
		redraw:
			add $t1, $s3, 64
			add $s1, $s1, $t1
			wrap:
				blt $s1, 64, wrap_end
				addi $s1, $s1, -64
				j wrap
			wrap_end:

			bgez $s4, detect_collision
			bgt $a1, MIN_Y, main_draw
			sub $a0, $a0, $a1
			sub $s2, $s2, $s4
			jal scroll
			j main_draw
			detect_collision:
				jal collision_detection
				bltz $v0, retry
			main_draw:
			move $a0, $s7
			jal draw
		redraw_end:

		# Receive keyboard input
		# Update (v_x, v_y) based on keyboard input and collision
		lw $t9, 0xffff0000
		beq $t9, 1, keyboard_input
		li $s3, 0
		j keyboard_input_end
		keyboard_input:
			lw $t9, 0xffff0004
			beq $t9, 'j', go_left
			li $s3, 1
			la $s7, doodler_right
			j keyboard_input_end
			go_left:
				li $s3, -1
				la $s7, doodler_left
		keyboard_input_end:

		blez $s4, accelerate
		sra $t0, $s2, SHIFT
		index ($t0, $s1, $t0)
		lw $t0, platforms($t0) # $t0 is (x, y)
		beqz $t0, accelerate
		# Collision
		li $s4, INITIAL_VELOCITY_Y
		addi $s0, $s0, 1
		jal play_music
		j sleep
		# No collision
		accelerate:
			addi $s4, $s4, ACCELERATION_Y

		j main_loop

	# Exit
	retry:
	jal ask_retry
	beqz $v0, exit
	jal reset
	j main_loop
	exit:
	li $t0, DISPLAY_ADDRESS
	la $t1, background
	bye:
		lw $t2, ($t1)
		sw $t2, ($t0)
		addi $t0, $t0, 4
		addi $t1, $t1, 4
		blt $t0, DISPLAY_ADDRESS_END, bye
	li $v0, 10
	syscall

ask_retry:
	push ($ra)
	li $t0, 0
	failure_music:
		li $v0, 33
		lw $a0, failure($t0)
		li $a1, MUSIC_NOTE_DURATION_FAILURE
		li $a2, MUSICAL_INSTRUMENT
		li $a3, VOLUME
		syscall
		addi $t0, $t0, 4
		blt $t0, MUSIC_SIZE_FAILURE, failure_music
	li $a1, 25
	li $a0, 7
	jal print_R
	li $a0, 12
	jal print_E
	li $a0, 17
	jal print_T
	li $a0, 23
	jal print_R
	li $a0, 28
	jal print_Y
	li $a0, 40
	jal print_Y
	li $a0, 46
	jal print_slash
	li $a0, 52
	jal print_N

	wait_for_input:
		lw $t9, 0xffff0000
		beq $t9, 1, yes_or_no
		li $v0, 32
		li $a0, 100
		syscall
		j wait_for_input
	yes_or_no:
		lw $t9, 0xffff0004
		beq $t9, 'Y', yes
		beq $t9, 'y', yes
		li $v0, 0
		j yes_or_no_end
		yes:
			li $v0, 1
	yes_or_no_end:
	pop ($ra)
	jr $ra

add_platform:
	# $a0	x-coordinate of the upper left corner
	# $a1	y-coordinate of the upper left corner
	# $a2	the length of the platform

	index ($t0, $a0, $a1)

	sll $t1, $a2, 2
	add $t1, $t1, $t0

	add_platform_loop:
		beq $t0, $t1, add_platform_exit
		li $t3, COLOR_OF_PLATFORMS
		sw $t3, platforms($t0)
		addi $t0, $t0, 4
		j add_platform_loop

	add_platform_exit:
	jr $ra

random_platforms:
	# a0	from
	# a1	to
	move $t0, $a1
	move $t4, $a0
	push ($ra)
	length ($t2, $t3, random_platforms_length)
	li $t3, 65
	sub $t3, $t3, $t2
	init_map:
		addi $s5, $s5, -1
		bgtz $s5, init_map_next
		random ($t3)  # produce $a0
		move $a1, $t0
		move $a2, $t2
		push ($t0)
		push ($t2)
		push ($t3)
		push ($t4)
		jal add_platform
		pop ($t4)
		pop ($t3)
		pop ($t2)
		pop ($t0)
		vertical_distance_to_the_next($s5, next_platform)
		init_map_next:
		addi $t0, $t0, -1
		bge $t0, $t4, init_map
	init_map_end:
	pop ($ra)
	jr $ra

init:
	la $t0, background
	addi $t1, $t0, 256
	addi $t3, $t0, ARRAY_SIZE
	init_background_loop:
		lw $t2, ($t0)
		addi $t2, $t2, -0x020100
		sw $t2, ($t1)
		addi $t0, $t0, 4
		addi $t1, $t1, 4
		blt $t1, $t3, init_background_loop
	li $t0, 0
	li $t1, 24
	li $t2, 0xffffff
	init_doodler_loop:
		beq $t0, 196, init_doodler_loop_end
		sw $t2, doodler_left($t0)
		sw $t2, doodler_left($t1)
		sw $t2, doodler_right($t0)
		sw $t2, doodler_right($t1)
		add $t0, $t0, 28
		add $t1, $t1, 28
		j init_doodler_loop
	init_doodler_loop_end:
	# legs
	sw $t2, doodler_left+176
	sw $t2, doodler_left+180
	sw $t2, doodler_right+180
	sw $t2, doodler_right+184
	# black eyes
	sw $0, doodler_left+36
	sw $0, doodler_left+44
	sw $0, doodler_right+36
	sw $0, doodler_right+44
	# red beak
	li $t0, 0xff0000
	sw $t0, doodler_left+84
	sw $t0, doodler_left+88
	sw $t0, doodler_left+92
	sw $t0, doodler_left+96
	sw $t0, doodler_right+96
	sw $t0, doodler_right+100
	sw $t0, doodler_right+104
	sw $t0, doodler_right+108
	jr $ra

reset:
	push ($ra)

	li $s1, 30
	li $s2, 62
	sll $s2, $s2, SHIFT
	li $s3, 0
	li $s4, INITIAL_VELOCITY_Y
	li $s5, 16
	li $s6, 0
	la $s7, doodler_left

	li $t0, 0
	reset_loop:
		sw $0, platforms($t0)
		addi $t0, $t0, 4
		blt $t0, ARRAY_SIZE, reset_loop

	li $a0, 25
	li $a1, 62
	length ($a2, $t0, init_length)
	jal add_platform

	li $a0, 0
	li $a1, 61
	jal random_platforms

	pop ($ra)
	jr $ra

draw:
	# $a0	address of the Doodler
	# background < environment < the Doodler

	li $t0, 0
	draw_background_and_platforms:
		# exit condition
		beq $t0, ARRAY_SIZE, draw_loop_end
		# loop body
		lw $t1, platforms($t0)
		beqz $t1, draw_background
		j draw_unit
		draw_background:
			lw $t1, background($t0)
		draw_unit:
			sw $t1, canvas($t0)
		# increment
		addi $t0, $t0, 4
		j draw_background_and_platforms
	draw_loop_end:

	# draw the Doodler
	li $t2, -7  # dy

	draw_doodler_y:
		beqz $t2, draw_doodler_end
		li $t1, -3  # dx
		draw_doodler_x:
			beq $t1, 4, draw_doodler_x_end
			add $t4, $s1, $t1  # x
			sra $t5, $s2, SHIFT
			add $t5, $t5, $t2  # y
			sll $t5, $t5, 6
			add $t4, $t4, $t5
			sll $t4, $t4, 2  # (x + 64 * y) * 4
			lw $t5, ($a0)
			beq $t5, 0xffffff, draw_doodler_x_skip
			sw $t5, canvas($t4)
			draw_doodler_x_skip:
			add $t1, $t1, 1
			add $a0, $a0, 4
			j draw_doodler_x
		draw_doodler_x_end:
		add $t2, $t2, 1
		j draw_doodler_y

	draw_doodler_end:

	# copy canvas to screen
	li $t0, DISPLAY_ADDRESS
	la $t2, canvas
	display_loop:
		beq $t0, DISPLAY_ADDRESS_END, display_exit
		lw $t3, ($t2)
		sw $t3, ($t0)
		addi $t0, $t0, 4
		addi $t2, $t2, 4
		j display_loop
	display_exit:
	jr $ra

collision_detection:
	li $v0, 0
	collision_detection_loop:
		bgt $a0, $a1, collision_detection_end
		bgt $a0, 63, out_of_range
		index ($t0, $s1, $a0)
		lw $t1, platforms($t0)
		bnez $t1, collision_detected
		addi $a0, $a0, 1
		j collision_detection_loop
	collision_detected:
		sll $s2, $a0, SHIFT
		li $v0, 1
		j collision_detection_end
	out_of_range:
		li $v0, -1
collision_detection_end:
	jr $ra

scroll:
	# $a0	the number of new rows
	push ($ra)

	la $t0, platforms
	sll $t4, $a0, 8  # 64 * 4 = 2^8
	addi $t1, $t0, ARRAY_SIZE
	scroll_loop:
		addi $t1, $t1, -4
		sub $t2, $t1, $t4
		blt $t2, $t0, scroll_loop_end
		# ($t2) -> ($t1)
		lw $t3, ($t2)
		sw $t3, ($t1)
		j scroll_loop
	scroll_loop_end:

	scroll_clear:
		sw $0, ($t1)
		addi $t1, $t1, -4
		bge $t1, $t0, scroll_clear

	move $a1, $a0
	li $a0, 0
	jal random_platforms

	pop ($ra)
	jr $ra

play_music:
	li $v0, 31
	lw $a0, music($s6)
	li $a1, MUSIC_NOTE_DURATION
	li $a2, MUSICAL_INSTRUMENT
	li $a3, VOLUME
	syscall
	addi $s6, $s6, 4
	bne $s6, MUSIC_SIZE, play_music_exit
	li $s6, 0
play_music_exit:
	jr $ra

print_R:
	li $t0, DISPLAY_ADDRESS
	index ($t1, $a0, $a1)
	add $t0, $t0, $t1
	sw $0, ($t0)
	sw $0, 4($t0)
	sw $0, 8($t0)
	sw $0, 12($t0)
	sw $0, 256($t0)
	sw $0, 268($t0)
	sw $0, 512($t0)
	sw $0, 516($t0)
	sw $0, 520($t0)
	sw $0, 524($t0)
	sw $0, 768($t0)
	sw $0, 776($t0)
	sw $0, 1024($t0)
	sw $0, 1036($t0)
	jr $ra

print_E:
	li $t0, DISPLAY_ADDRESS
	index ($t1, $a0, $a1)
	add $t0, $t0, $t1
	sw $0, ($t0)
	sw $0, 4($t0)
	sw $0, 8($t0)
	sw $0, 12($t0)
	sw $0, 256($t0)
	sw $0, 512($t0)
	sw $0, 516($t0)
	sw $0, 520($t0)
	sw $0, 524($t0)
	sw $0, 768($t0)
	sw $0, 1024($t0)
	sw $0, 1028($t0)
	sw $0, 1032($t0)
	sw $0, 1036($t0)
	jr $ra

print_T:
	li $t0, DISPLAY_ADDRESS
	index ($t1, $a0, $a1)
	add $t0, $t0, $t1
	sw $0, ($t0)
	sw $0, 4($t0)
	sw $0, 8($t0)
	sw $0, 12($t0)
	sw $0, 16($t0)
	sw $0, 264($t0)
	sw $0, 520($t0)
	sw $0, 776($t0)
	sw $0, 1032($t0)
	jr $ra

print_Y:
	li $t0, DISPLAY_ADDRESS
	index ($t1, $a0, $a1)
	add $t0, $t0, $t1
	sw $0, ($t0)
	sw $0, 16($t0)
	sw $0, 260($t0)
	sw $0, 268($t0)
	sw $0, 520($t0)
	sw $0, 776($t0)
	sw $0, 1032($t0)
	jr $ra

print_slash:
	li $t0, DISPLAY_ADDRESS
	index ($t1, $a0, $a1)
	add $t0, $t0, $t1
	sw $0, 16($t0)
	sw $0, 268($t0)
	sw $0, 520($t0)
	sw $0, 772($t0)
	sw $0, 1024($t0)
	jr $ra

print_N:
	li $t0, DISPLAY_ADDRESS
	index ($t1, $a0, $a1)
	add $t0, $t0, $t1
	sw $0, ($t0)
	sw $0, 16($t0)
	sw $0, 256($t0)
	sw $0, 260($t0)
	sw $0, 272($t0)
	sw $0, 512($t0)
	sw $0, 520($t0)
	sw $0, 528($t0)
	sw $0, 768($t0)
	sw $0, 780($t0)
	sw $0, 784($t0)
	sw $0, 1024($t0)
	sw $0, 1040($t0)
	jr $ra
