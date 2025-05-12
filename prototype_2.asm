                                                           .MODEL SMALL 

; Define macro for line gap (newline)
line_gap macro a,b
    mov dl,a
    mov ah,2
    int 21h
    mov dl,b
    mov ah,2
    int 21h
endm 

.STACK 100H

.DATA
name_var db 10 dup(0)     ; Name variable (max 10 chars)
pass db 10 dup(0)         ; Password storage
key db 0                  ; Key for encryption and decryption
attempts db 0             ; Number of failed attempts
temp db 0                 ; Temporary variable for calculations
pass_len db 0             ; Password length

; Main menu messages
main_msg1 db "1.Encrypt$"
main_msg2 db "2.Decrypt$"
main_msg3 db "3.Generate Password$"  ; New option for password generator
main_msg4 db "4.Exit$"               ; Exit is now option 4
input db "Enter: $"
en_msg1 db "Encrypting...$"
d_msg1 db "Decrypting...$"
gen_msg db "Generating Password...$"
back_msg db "0. Go back to main$" 

; User prompts
prompt1 db "Enter name (max 10 chars): $"
prompt2 db 0Dh,0Ah,"Enter password: $"
prompt3 db 0Dh,0Ah,"Enter 1-char key: $"
prompt4 db 0Dh,0Ah,"Enter key to decrypt: $"
prompt5 db 0Dh,0Ah,"Decrypted password: $"
enc_msg db 0Dh,0Ah,"Encrypted password (hex): $"
wrong_msg db 0Dh,0Ah,"Incorrect key! Access denied.$"
access_den db 0Dh,0Ah,"Too many attempts. Access blocked.$"

; Password generator messages and variables
prompt_msg      DB 'Enter password length (8, 10, or 12): $'
error_msg       DB 'Password length must be 8, 10, or 12 characters.$'
password_msg    DB 'Generated password: $'
newline         DB 0DH, 0AH, '$'
use_pass_msg    DB 'Do you want to use this password? (1.Yes/2.No): $'

; Password generator variables
password_length DB ?             ; Length of password to generate
password_buffer DB 15 DUP(?)     ; Buffer to store generated password

; Character sets for password generator
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
    ; initialize DS
    MOV AX,@DATA 
    MOV DS,AX
    
main_menu:
    ; Clear screen
    mov ax, 0003h
    int 10h
    
    ; Display main menu
    lea dx,main_msg1 
    mov ah,9 
    int 21h
    
    line_gap 10,13
    
    lea dx,main_msg2 
    mov ah,9 
    int 21h
    
    line_gap 10,13
    
    lea dx,main_msg3     ; Display option 3 (Generate Password)
    mov ah,9 
    int 21h
    
    line_gap 10,13
    
    lea dx,main_msg4     ; Display option 4 (Exit)
    mov ah,9 
    int 21h
    
    line_gap 10,13
    
    lea dx,input 
    mov ah,9 
    int 21h
    
    mov ah,1 
    int 21h
    sub al,30h
    
    cmp al,1 
    je Encrypt 
    
    cmp al,2 
    je Dcrypt
    
    cmp al,3
    je Generate_Password  ; Jump to password generator if option 3
    
    cmp al,4              ; Exit is now option 4
    je exit
    
    jmp main_menu         ; Invalid input, go back to main menu
    
Encrypt:
    ; Clear screen
    mov ax, 0003h
    int 10h
    
    lea dx,en_msg1 
    mov ah,9 
    int 21h
    
    line_gap 10,13 
    
    ; Ask for name
    lea dx, prompt1
    mov ah, 09h
    int 21h

    ; Get name input
    mov si, offset name_var
    mov cx, 10
get_name:
    mov ah, 01h
    int 21h
    cmp al, 13            ; Enter key (carriage return)?
    je end_name
    mov [si], al
    inc si
    loop get_name
end_name:
    mov byte ptr [si], '$'   ; Terminate the string

    ; Ask for password
    lea dx, prompt2
    mov ah, 09h
    int 21h
    
    ; Get password input with asterisk display
    mov si, offset pass
    mov cx, 10
    mov byte ptr [pass_len], 0  ; Initialize password length
get_password:
    mov ah, 01h
    int 21h
    cmp al, 13            ; Enter key (carriage return)?
    je end_password
    mov [si], al          ; Store the actual character
    inc si
    inc byte ptr [pass_len]  ; Increment password length
    
    ; Display asterisk instead of actual character
    ;mov dl, '*'
    ;mov ah, 02h
    ;int 21h
    
    loop get_password
end_password:
    mov byte ptr [si], 0   ; Null-terminate the password

    ; Ask for encryption key
    lea dx, prompt3
    mov ah, 09h
    int 21h
    mov ah, 01h
    int 21h
    mov [key], al

    ; Encrypt the password
    mov si, offset pass
    mov cl, [pass_len]   ; Load password length into CL
    
encrypt_loop:
    cmp cl, 0
    je encrypt_done
    mov al, [si]         ; Get character
    xor al, [key]        ; Encrypt using XOR
    mov [si], al         ; Store encrypted character
    inc si
    dec cl
    jmp encrypt_loop
    
encrypt_done:
    ; Display encrypted password message
    lea dx, enc_msg
    mov ah, 09h
    int 21h

    ; Show encrypted password in hex
    mov si, offset pass
    mov cl, [pass_len]   ; Use stored password length
show_hex:
    cmp cl, 0
    je show_done
    mov al, [si]
    call show_hex_byte
    inc si
    dec cl
    jmp show_hex
    
show_done:
    ; Add new line
    line_gap 13, 10
    
    ; Show option to go back
    lea dx, back_msg
    mov ah, 9
    int 21h
    
    line_gap 10, 13
    
    lea dx, input
    mov ah, 9
    int 21h
    
    mov ah, 1
    int 21h
    sub al, 30h
    
    cmp al, 0
    je main_menu  ; Go back to main menu if input is 0
    
    jmp Encrypt   ; Otherwise stay in Encrypt menu
    
Dcrypt:
    ; Clear screen
    mov ax, 0003h
    int 10h
    
    ; Display the saved name at the top
    lea dx, name_var
    mov ah, 09h
    int 21h
    
    ; Add a new line
    line_gap 13, 10
    line_gap 13, 10
    
    lea dx, d_msg1 
    mov ah, 9 
    int 21h
    
    line_gap 10, 13
    
    lea dx, prompt4
    mov ah, 09h
    int 21h

    mov ah, 01h
    int 21h
    cmp al, [key]
    je correct_key

    ; Wrong key
    inc byte ptr [attempts]
    cmp byte ptr [attempts], 3
    jae access_blocked
    lea dx, wrong_msg
    mov ah, 09h
    int 21h
    jmp Dcrypt

access_blocked:
    lea dx, access_den
    mov ah, 09h
    int 21h
    jmp exit

correct_key:
    ; Display decryption success message
    lea dx, prompt5
    mov ah, 09h
    int 21h

    ; Decrypt and display the password
    mov si, offset pass
    mov cl, [pass_len]   ; Use stored password length
decrypt_loop:
    cmp cl, 0
    je decrypt_done
    mov al, [si]
    xor al, [key]        ; Decrypt using XOR
    mov dl, al           ; Move to DL for printing
    mov ah, 02h
    int 21h
    inc si
    dec cl
    jmp decrypt_loop

decrypt_done:
    ; Add new line
    line_gap 13, 10
    
    ; Show option to go back
    lea dx, back_msg
    mov ah, 09h
    int 21h
    
    line_gap 10, 13
    
    lea dx, input
    mov ah, 09h
    int 21h
    
    mov ah, 01h
    int 21h
    sub al, 30h
    
    cmp al, 0
    je main_menu  ; Go back to main menu if input is 0
    
    jmp Dcrypt    ; Otherwise stay in Decrypt menu

Generate_Password:
    ; Clear screen
    mov ax, 0003h
    int 10h
    
    lea dx, gen_msg
    mov ah, 9
    int 21h
    
    line_gap 10, 13
    
    ; Display prompt for password length
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
    
    ; Invalid length, display error and go back to main menu
    LEA DX, error_msg
    MOV AH, 09h
    INT 21h
    
    ; Wait for a key press before returning to main menu
    mov ah, 01h
    int 21h
    
    JMP main_menu
    
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
    
    ; Add a null terminator to the password buffer
    MOV byte ptr [DI], 0
    
    ; Print newline
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    ; Ask if user wants to use this password
    LEA DX, use_pass_msg
    MOV AH, 09h
    INT 21h
    
    MOV AH, 01h
    INT 21h
    SUB AL, '0'
    
    CMP AL, 1
    JNE skip_using_password
    
    ; Use this password for encryption
    ; Copy from password_buffer to pass
    LEA SI, password_buffer
    LEA DI, pass
    MOV CL, password_length
    MOV [pass_len], CL
copy_password:
    MOV AL, [SI]
    MOV [DI], AL
    INC SI
    INC DI
    DEC CL
    JNZ copy_password
    
    ; Null-terminate the password
    MOV byte ptr [DI], 0
    
    ; Print confirmation message
    line_gap 13, 10
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
skip_using_password:
    ; Show option to go back
    LEA DX, back_msg
    MOV AH, 09h
    INT 21h
    
    line_gap 10, 13
    
    LEA DX, input
    MOV AH, 09h
    INT 21h
    
    MOV AH, 01h
    INT 21h
    SUB AL, 30h
    
    CMP AL, 0
    JE main_menu  ; Go back to main menu if input is 0
    
    JMP Generate_Password  ; Otherwise stay in Generate Password menu

exit:
    ; exit to DOS
    MOV AX,4C00H 
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

; Convert and display a byte in hexadecimal
show_hex_byte PROC
    push ax
    push bx
    push dx
    
    ; High nibble
    mov ah, 0
    mov bl, al
    shr bl, 4
    call print_hex_digit

    ; Low nibble
    mov bl, al
    and bl, 0Fh
    call print_hex_digit

    ; Space after hex byte
    mov dl, ' '
    mov ah, 02h
    int 21h
    
    pop dx
    pop bx
    pop ax
    ret
show_hex_byte ENDP

; Display a single hex digit in BL
print_hex_digit PROC
    cmp bl, 9
    jbe belowA
    add bl, 7      ; Convert 10-15 to 'A'-'F'
belowA:
    add bl, '0'
    mov dl, bl
    mov ah, 02h
    int 21h
    ret
print_hex_digit ENDP

END MAIN