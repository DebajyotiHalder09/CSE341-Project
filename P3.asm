.MODEL SMALL

; Define constants for array sizes
MAX_USERS EQU 5
MAX_NAME_LEN EQU 10
MAX_PASS_LEN EQU 10

; Define macro for line gap (newline)
line_gap macro
    mov dl, 10
    mov ah, 2
    int 21h
    mov dl, 13
    mov ah, 2
    int 21h
endm

.STACK 100H

.DATA
; Arrays to store user data
names db MAX_USERS * MAX_NAME_LEN dup('$')
passwords db MAX_USERS * MAX_PASS_LEN dup(0)
keys db MAX_USERS dup(0)
password_lengths db MAX_USERS dup(0)

current_user_count db 0
temp_username db MAX_NAME_LEN dup('$')
user_found_idx db 0FFh

; Password generator variables
password_length DB ?
password_buffer DB 15 DUP(?)

; Character sets for password generator
alphabet DB 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
alphabet_len EQU $ - alphabet
digits DB '0123456789'
digits_len EQU $ - digits
special_chars DB '!@#$%^&*()_+-=[]{}|;:,.<>?/~`'
special_len EQU $ - special_chars
all_chars DB 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?/~`'
all_chars_len EQU $ - all_chars
seed DW 1234h

; New data for strength analyzer
pass_strength_strong db 0Dh,0Ah,"Password strength: STRONG!$"
pass_strength_weak db 0Dh,0Ah,"Password strength: WEAK!$"
pass_strength_weak_both_reasons db 0Dh,0Ah,"- The password is not of length 10 and doesn't contain any special characters (@#?$%&*).$"
analyze_prompt db 0Dh,0Ah,"Press ENTER to analyze password strength.$"

; All strings
main_msg1 db "1. Add User$"
main_msg2 db "2. Show Password$"
main_msg3 db "3. Generate Password$"
main_msg4 db "4. Exit$"
input_prompt db "Enter: $"
gen_msg db "Generating Password...$"

enter_name_prompt db 0Dh,0Ah,"Enter name (max 10 chars): $"
enter_pass_prompt db 0Dh,0Ah,"Enter password (max 10 chars): $"
enter_key_prompt db 0Dh,0Ah,"Enter 1-char key: $"
vault_full_msg db 0Dh,0Ah,"Vault is full! Cannot add more users.$"
user_added_msg db 0Dh,0Ah,"User added successfully!$"
enc_password_msg db 0Dh,0Ah,"Encrypted password (hex): $"
user_not_found_msg db 0Dh,0Ah,"Username not found!$"
enter_dec_key_prompt db 0Dh,0Ah,"Enter decryption key: $"
incorrect_key_msg db 0Dh,0Ah,"Incorrect key! Access denied.$"
decrypted_pass_msg db 0Dh,0Ah,"Decrypted password: $"
no_users_msg db 0Dh,0Ah,"No users added yet.$"
invalid_input_msg db 0Dh,0Ah,"Invalid input. Please try again.$"

; Password generator messages
prompt_msg DB 'Enter password length (8, 10, or 12): $'
error_msg DB 'Password length must be 8, 10, or 12 characters.$'
password_msg DB 'Generated password: $'
newline DB 0DH, 0AH, '$'
use_pass_msg DB 'Do you want to use this password? (1.Yes/2.No): $'
back_msg db "0. Go back to main$"

.CODE
MAIN PROC
    ; initialize DS
    MOV AX,@DATA
    MOV DS,AX

main_menu:
    ; Clear screen
    mov ax, 0003h
    int 10h

    ; Display main menu options
    lea dx, main_msg1
    mov ah, 9
    int 21h
    line_gap

    lea dx, main_msg2
    mov ah, 9
    int 21h
    line_gap

    lea dx, main_msg3
    mov ah, 9
    int 21h
    line_gap

    lea dx, main_msg4
    mov ah, 9
    int 21h
    line_gap

    ; Prompt for user input
    lea dx, input_prompt
    mov ah, 9
    int 21h

    ; Read user choice
    mov ah, 1
    int 21h
    sub al, 30h ; Convert ASCII digit to number

    ; Check user choice and jump
    cmp al, 1
    je AddUser

    cmp al, 2
    je ShowPassword

    cmp al, 3
    je Generate_Password

    cmp al, 4
    je exit

    ; If input is not 1-4, display error and loop back
    lea dx, invalid_input_msg
    mov ah, 9
    int 21h
    line_gap
    mov ah, 1
    int 21h
    jmp main_menu

AddUser:
    ; Clear screen
    mov ax, 0003h
    int 10h

    ; Check if the vault is full
    mov al, [current_user_count]
    cmp al, MAX_USERS
    je vault_full_handler

    ; Calculate base offset for current user's data
    mov bl, [current_user_count]
    mov al, MAX_NAME_LEN
    mul bl
    mov di, ax

    ; --- Get Name Input ---
    lea dx, enter_name_prompt
    mov ah, 9
    int 21h

    mov si, offset names
    add si, di
    mov cx, MAX_NAME_LEN

get_name_input_loop:
    mov ah, 01h
    int 21h

    cmp al, 13
    je end_name_input

    cmp cx, 0
    je skip_store_name_char

    mov [si], al
    inc si
    dec cx
    jmp get_name_input_loop

skip_store_name_char:
    jmp get_name_input_loop

end_name_input:
    mov byte ptr [si], '$'

    ; --- Get Password Input ---
    lea dx, enter_pass_prompt
    mov ah, 9
    int 21h

    mov si, offset passwords
    add si, di
    mov cx, MAX_PASS_LEN
    mov bx, 0

get_password_input_loop:
    mov ah, 01h
    int 21h

    cmp al, 13
    je end_password_input

    cmp cx, 0
    je skip_store_pass_char

    mov [si], al
    inc si
    inc bx
    dec cx
    jmp get_password_input_loop

skip_store_pass_char:
    jmp get_password_input_loop

end_password_input:
    mov byte ptr [si], 0

    ; Store actual password length
    mov al, [current_user_count]
    mov ah, 0
    mov si, offset password_lengths
    add si, ax
    mov [si], bl

    ; --- Prompt for Password Strength Analysis ---
    lea dx, analyze_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    line_gap

    ; --- Password Strength Analyzer ---
    push bp
    push si
    push di
    push bx

    mov bp, sp
    mov al, 0
    mov ah, 0

    ; --- Check Length ---
    mov bl, [bp + 0]
    cmp bl, MAX_PASS_LEN
    jne length_is_weak_handler
    mov ah, 1
    jmp start_special_char_analysis_logic

length_is_weak_handler:
    mov ah, 0

start_special_char_analysis_logic:
    ; --- Check Special Character ---
    mov di, offset passwords
    add di, [bp + 2]
    mov cl, [bp + 0]

    cmp cl, 0
    je special_char_check_done

outer_loop_pass_chars:
    cmp cl, 0
    je special_char_check_done

    mov ch, [di]

    push di
    push cx
    
    mov si, offset special_chars
    
inner_loop_special_chars:
    mov dl, [si]
    cmp dl, 0
    je no_match_in_special_chars_list

    cmp ch, dl
    je found_special_char_in_pass

    inc si
    jmp inner_loop_special_chars

no_match_in_special_chars_list:
    pop cx
    pop di
    inc di
    dec cl
    jmp outer_loop_pass_chars

found_special_char_in_pass:
    mov al, 1
    pop cx
    pop di
    jmp special_char_check_done

special_char_check_done:
    cmp ah, 1
    jne password_is_weak

    cmp al, 1
    jne password_is_weak

    jmp password_is_strong

password_is_weak:
    lea dx, pass_strength_weak
    mov ah, 9
    int 21h
    line_gap

    lea dx, pass_strength_weak_both_reasons
    mov ah, 9
    int 21h
    line_gap

    pop bx
    pop di
    pop si
    pop bp
    
    jmp return_to_main_menu_after_strength_check

password_is_strong:
    lea dx, pass_strength_strong
    mov ah, 9
    int 21h
    line_gap
    jmp continue_add_user_flow

return_to_main_menu_after_strength_check:
    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    line_gap

    jmp main_menu

continue_add_user_flow:
    pop bx
    pop di
    pop si
    pop bp

    ; --- Get Key Input ---
    lea dx, enter_key_prompt
    mov ah, 9
    int 21h

    mov ah, 01h
    int 21h

    push ax

    mov bl, [current_user_count]
    mov al, bl
    mov ah, 0
    mov si, offset keys
    add si, ax

    pop ax

    mov [si], al
    mov ch, al

    ; --- Encrypt the Password ---
    mov al, [current_user_count]
    mov ah, 0
    mov si, ax
    mov cl, [password_lengths + si]

    mov si, offset passwords
    add si, di

encrypt_password_loop:
    cmp cl, 0
    je encrypt_password_done

    mov bl, [si]
    xor bl, ch
    mov [si], bl
    inc si
    dec cl
    jmp encrypt_password_loop
    
encrypt_password_done:
    ; Display encrypted password message
    lea dx, enc_password_msg
    mov ah, 09h
    int 21h
    line_gap

    ; Reload password length for display loop
    mov al, [current_user_count]
    mov ah, 0
    mov si, ax
    mov cl, [password_lengths + si]

    mov si, offset passwords
    add si, di

show_encrypted_password_loop:
    cmp cl, 0
    je show_encrypted_password_done

    mov al, [si]
    call show_hex_byte
    inc si
    dec cl
    jmp show_encrypted_password_loop

show_encrypted_password_done:
    line_gap

    inc byte ptr [current_user_count]

    lea dx, user_added_msg
    mov ah, 9
    int 21h
    line_gap

    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    jmp main_menu

vault_full_handler:
    lea dx, vault_full_msg
    mov ah, 9
    int 21h
    line_gap
    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    jmp main_menu

ShowPassword:
    ; Clear screen
    mov ax, 0003h
    int 10h

    cmp byte ptr [current_user_count], 0
    je no_users_added

    lea dx, enter_name_prompt
    mov ah, 9
    int 21h

    mov si, offset temp_username
    mov cx, MAX_NAME_LEN
    mov bx, 0

get_username_input_loop:
    mov ah, 01h
    int 21h

    cmp al, 13
    je end_username_input

    cmp bx, MAX_NAME_LEN
    jge skip_store_user_char

    mov [si], al
    inc si
    inc bx
    jmp get_username_input_loop
skip_store_user_char:
    jmp get_username_input_loop
end_username_input:
    mov byte ptr [si], '$'

    ; Search for username in names array
    mov byte ptr [user_found_idx], 0FFh
    mov bl, 0

search_user_loop:
    cmp bl, [current_user_count]
    jge user_search_done

    mov al, MAX_NAME_LEN
    mul bl
    mov di, ax

    push bx
    push di

    mov si, offset temp_username
    mov di, offset names
    add di, ax

    mov cx, MAX_NAME_LEN

compare_name_chars_loop:
    mov al, [si]
    mov ah, [di]

    cmp al, '$'
    je check_stored_name_end
    cmp ah, '$'
    je check_input_name_end

    cmp al, ah
    jne name_mismatch

    inc si
    inc di
    loop compare_name_chars_loop

    jmp name_match

name_mismatch:
    pop di
    pop bx
    inc bl
    jmp search_user_loop

check_stored_name_end:
    cmp ah, '$'
    je name_match
    jmp name_mismatch

check_input_name_end:
    cmp al, '$'
    je name_match
    jmp name_mismatch

name_match:
    pop di
    pop bx
    mov [user_found_idx], bl
    jmp user_search_done

user_search_done:
    cmp byte ptr [user_found_idx], 0FFh
    je username_not_found

    mov bl, [user_found_idx]

    lea dx, enter_dec_key_prompt
    mov ah, 9
    int 21h
    mov ah, 01h
    int 21h

    mov bh, al

    mov al, bl
    mov ah, 0
    mov si, offset keys
    add si, ax

    cmp bh, [si]
    jne incorrect_key_handler

    lea dx, decrypted_pass_msg
    mov ah, 9
    int 21h
    line_gap

    mov al, MAX_PASS_LEN
    mul bl
    mov di, ax

    mov al, bl
    mov ah, 0
    mov si, offset password_lengths
    add si, ax
    mov cl, [si]

    mov al, bl
    mov ah, 0
    mov si, offset keys
    add si, ax
    mov ch, [si]

    mov si, offset passwords
    add si, di

decrypt_and_display_loop:
    cmp cl, 0
    je decrypt_display_done

    mov bl, [si]
    xor bl, ch
    mov dl, bl
    mov ah, 02h
    int 21h

    inc si
    dec cl
    jmp decrypt_and_display_loop

decrypt_display_done:
    line_gap

    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    jmp main_menu

incorrect_key_handler:
    lea dx, incorrect_key_msg
    mov ah, 9
    int 21h
    line_gap
    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    jmp main_menu

username_not_found:
    lea dx, user_not_found_msg
    mov ah, 9
    int 21h
    line_gap
    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    jmp main_menu

no_users_added:
    lea dx, no_users_msg
    mov ah, 9
    int 21h
    line_gap
    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    jmp main_menu

Generate_Password:
    ; Clear screen
    mov ax, 0003h
    int 10h
    
    lea dx, gen_msg
    mov ah, 9
    int 21h
    
    line_gap
    
    ; Display prompt for password length
    LEA DX, prompt_msg
    MOV AH, 09h
    INT 21h
    
    ; Read user input for password length
    MOV AH, 01h
    INT 21h
    SUB AL, '0'
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
    PUSH CX
    
    ; Get a random number
    CALL random_number
    
    ; Use random number to select a character from all_chars
    XOR DX, DX
    MOV CX, all_chars_len
    DIV CX
    
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
    
    POP CX
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
    
    ; Check if vault is full before adding a user
    mov al, [current_user_count]
    cmp al, MAX_USERS
    je vault_full_from_generator
    
    ; Use generated password - redirect to AddUser but first store the password
    ; Calculate base offset for current user's data
    mov bl, [current_user_count]
    mov al, MAX_NAME_LEN
    mul bl
    mov di, ax
    
    ; Prompt for name input since we're using the password
    line_gap
    lea dx, enter_name_prompt
    mov ah, 9
    int 21h
    
    mov si, offset names
    add si, di
    mov cx, MAX_NAME_LEN
    
get_name_for_gen_pass:
    mov ah, 01h
    int 21h
    
    cmp al, 13
    je end_name_for_gen_pass
    
    cmp cx, 0
    je skip_name_char_for_gen_pass
    
    mov [si], al
    inc si
    dec cx
    jmp get_name_for_gen_pass
    
skip_name_char_for_gen_pass:
    jmp get_name_for_gen_pass
    
end_name_for_gen_pass:
    mov byte ptr [si], '$'
    
    ; Copy the generated password to the password array
    lea si, password_buffer
    mov di, offset passwords
    mov al, [current_user_count]
    mov ah, 0                ; Zero-extend to 16 bits
    mov bl, MAX_PASS_LEN
    mul bl                   ; AX = AL * BL
    add di, ax
    
    mov cl, password_length
    mov ch, 0
    
copy_generated_password:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    loop copy_generated_password
    
    ; Store the password length
    mov al, [current_user_count]
    mov ah, 0
    mov si, offset password_lengths
    add si, ax
    mov al, password_length
    mov [si], al
    
    ; Continue with key input
    lea dx, enter_key_prompt
    mov ah, 9
    int 21h
    
    mov ah, 01h
    int 21h
    push ax
    
    mov bl, [current_user_count]
    mov al, bl
    mov ah, 0
    mov si, offset keys
    add si, ax
    
    pop ax
    mov [si], al
    mov ch, al
    
    ; Encrypt the password
    mov al, [current_user_count]
    mov ah, 0
    mov si, ax
    mov cl, [password_lengths + si]
    
    mov al, MAX_PASS_LEN
    mul bl
    mov di, ax
    
    mov si, offset passwords
    add si, di
    
encrypt_generated_password:
    cmp cl, 0
    je encrypt_generated_done
    
    mov bl, [si]
    xor bl, ch
    mov [si], bl
    inc si
    dec cl
    jmp encrypt_generated_password
    
encrypt_generated_done:
    ; Display encrypted password message
    lea dx, enc_password_msg
    mov ah, 09h
    int 21h
    line_gap
    
    ; Reload password length for display loop
    mov al, [current_user_count]
    mov ah, 0
    mov si, ax
    mov cl, [password_lengths + si]
    
    mov al, MAX_PASS_LEN
    mul bl
    mov di, ax
    
    mov si, offset passwords
    add si, di
    
show_encrypted_generated:
    cmp cl, 0
    je show_encrypted_generated_done
    
    mov al, [si]
    call show_hex_byte
    inc si
    dec cl
    jmp show_encrypted_generated
    
show_encrypted_generated_done:
    line_gap
    
    ; Increment user count
    inc byte ptr [current_user_count]
    
    ; Display success message
    lea dx, user_added_msg
    mov ah, 9
    int 21h
    line_gap
    
    jmp generator_done
    
vault_full_from_generator:
    lea dx, vault_full_msg
    mov ah, 9
    int 21h
    line_gap
    
skip_using_password:
    ; Show option to go back
    LEA DX, back_msg
    MOV AH, 09h
    INT 21h
    
    line_gap
    
    LEA DX, input_prompt
    MOV AH, 09h
    INT 21h
    
    MOV AH, 01h
    INT 21h
    SUB AL, 30h
    
    CMP AL, 0
    JE main_menu
    
    JMP Generate_Password
    
generator_done:
    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    jmp main_menu
    
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
    MOV AX, seed
    MOV BX, 25173
    MUL BX
    ADD AX, 13849
    MOV seed, AX
    
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
    add bl, 7
belowA:
    add bl, '0'
    mov dl, bl
    mov ah, 02h
    int 21h
    ret
print_hex_digit ENDP

END MAIN 