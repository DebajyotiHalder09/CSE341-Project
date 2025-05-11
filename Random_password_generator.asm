.MODEL SMALL
.STACK 100H
.DATA
    ; Messages
    prompt_msg      DB 'Enter password length (8, 10, or 12): $'
    error_msg       DB 'Password length must be 8, 10, or 12 characters.$'
    password_msg    DB 'Generated password: $'
    newline         DB 0DH, 0AH, '$'
    
    ; Variables
    input_buffer    DB 3 DUP(?)      ; Buffer for user input
    password_length DB ?             ; Length of password to generate
    password_buffer DB 15 DUP(?)     ; Buffer to store generated password
    
    ; Character sets
    alphabet        DB 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    alphabet_len    EQU $ - alphabet
    
    digits          DB '0123456789'
    digits_len      EQU $ - digits
    
    special_chars   DB '!@#$%^&*()_+-=[]{}|;:,.<>?/~`'
    special_len     EQU $ - special_chars
    
    all_chars       DB 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?/~`'
    all_chars_len   EQU $ - all_chars
    
    seed            DW 1234h         ; Random seed

.CODE
MAIN PROC
    ; Initialize DS
    MOV AX, @DATA
    MOV DS, AX
    
    ; Display prompt
    LEA DX, prompt_msg
    MOV AH, 09h
    INT 21h
    
    ; Read user input for password length
    MOV AH, 01h           ; Read a character
    INT 21h
    SUB AL, '0'           ; Convert ASCII to number
    MOV password_length, AL
    
    ; Print newline
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    ; Validate length (must be 8, 10, or 12)
    CMP password_length, 8
    JE valid_length
    CMP password_length, 10
    JE valid_length
    CMP password_length, 12
    JE valid_length
    
    ; Invalid length, display error and exit
    LEA DX, error_msg
    MOV AH, 09h
    INT 21h
    JMP exit_program
    
valid_length:
    ; Display password message
    LEA DX, password_msg
    MOV AH, 09h
    INT 21h
    
    ; Initialize counter for password generation
    XOR CX, CX
    MOV CL, password_length
    LEA DI, password_buffer
    
generate_loop:
    PUSH CX                 ; Save loop counter
    
    ; Get a random number
    CALL random_number
    
    ; Use random number to select a character from all_chars
    XOR DX, DX              ; Clear DX for division
    MOV CX, all_chars_len   ; Divisor = length of character set
    DIV CX                  ; Divide AX by CX, remainder in DX
    
    ; Get the character at index DX
    MOV BX, DX
    MOV AL, all_chars[BX]
    
    ; Store the character in the password buffer
    MOV [DI], AL
    INC DI
    
    ; Display the character
    MOV DL, AL
    MOV AH, 02h
    INT 21h
    
    POP CX                  ; Restore loop counter
    LOOP generate_loop
    
    ; Print newline
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
exit_program:
    ; Exit to DOS
    MOV AX, 4C00H
    INT 21H

MAIN ENDP

; Function to generate a pseudo-random number in AX
random_number PROC
    PUSH BX
    PUSH CX
    PUSH DX
    
    ; Simple Linear Congruential Generator
    ; new_seed = (a * seed + c) mod m
    ; Using constants: a=25173, c=13849, m=65536
    MOV AX, seed
    MOV BX, 25173       ; Multiplier a
    MUL BX              ; DX:AX = AX * BX
    ADD AX, 13849       ; Add constant c
    ; mod 65536 happens automatically in 16-bit register
    MOV seed, AX        ; Save new seed
    
    POP DX
    POP CX
    POP BX
    RET
random_number ENDP

END MAIN