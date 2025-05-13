.MODEL SMALL

; Define constants for array sizes
MAX_USERS EQU 5
MAX_NAME_LEN EQU 10
MAX_PASS_LEN EQU 10

; Define macro for line gap (newline)
; This macro effectively prints a Line Feed (10) and Carriage Return (13)
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
; Each name can have MAX_NAME_LEN characters
names db MAX_USERS * MAX_NAME_LEN dup('$') ; 5 users * 10 chars, initialized with '$' for display
; Each password can have MAX_PASS_LEN characters
passwords db MAX_USERS * MAX_PASS_LEN dup(0) ; 5 users * 10 chars, initialized with nulls
; Each key is a single character
keys db MAX_USERS dup(0)                     ; 5 users * 1 char, initialized with nulls
; Stores the actual length of each user's password
password_lengths db MAX_USERS dup(0)

current_user_count db 0                     ; Counter for registered users (0 to MAX_USERS-1)
temp_username db MAX_NAME_LEN dup('$')      ; Buffer for input username during lookup
user_found_idx db 0FFh                      ; Stores index of matched user (0-4) or 0FFh if not found

; New data for strength analyzer
special_chars db "!@#$%^&*?", 0 ; Null-terminated string of special characters
pass_strength_weak_len db 0Dh,0Ah,"- Password is not max length (10 chars).$" ; NO LONGER USED IN WEAK MESSAGE DISPLAY
pass_strength_weak_special db 0Dh,0Ah,"- Password lacks special characters (@#?$%&*).$" ; NO LONGER USED IN WEAK MESSAGE DISPLAY
pass_strength_strong db 0Dh,0Ah,"Password strength: STRONG!$"
pass_strength_weak db 0Dh,0Ah,"Password strength: WEAK!$"
pass_strength_weak_both_reasons db 0Dh,0Ah,"- The password is not of length 10 and doesn't contain any special characters (@#?$%&*).$" ; THIS MESSAGE IS NOW ALWAYS DISPLAYED FOR WEAK PASSWORDS

analyze_prompt db 0Dh,0Ah,"Press ENTER to analyze password strength.$"

; All strings use double quotes for consistency
main_msg1 db "1. Add User$"
main_msg2 db "2. Show Password$"
main_msg3 db "3. Exit$"
input_prompt db "Enter: $"

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
    je exit

    ; If input is not 1, 2, or 3, display error and loop back
    lea dx, invalid_input_msg
    mov ah, 9
    int 21h
    line_gap
    ; Wait for a key press to go back to menu, prevents rapid looping
    mov ah, 1
    int 21h
    jmp main_menu

AddUser:
    ; Clear screen
    mov ax, 0003h
    int 10h

    ; Check if the vault is full (current_user_count < MAX_USERS)
    mov al, [current_user_count]
    cmp al, MAX_USERS
    je vault_full_handler

    ; Calculate base offset for the current user's data in the arrays
    ; Offset = current_user_count * MAX_LEN
    mov bl, [current_user_count] ; BL holds the user index (0 to MAX_USERS-1)
    mov al, MAX_NAME_LEN         ; Use MAX_NAME_LEN for multiplication (since MAX_NAME_LEN = MAX_PASS_LEN)
    mul bl                       ; AX = user_index * MAX_NAME_LEN (e.g., 0, 10, 20, 30, 40)
    mov di, ax                   ; DI will store this calculated offset for names/passwords

    ; --- Get Name Input ---
    lea dx, enter_name_prompt
    mov ah, 9
    int 21h

    mov si, offset names    ; Base address of names array
    add si, di              ; Point SI to the correct user's name slot
    mov cx, MAX_NAME_LEN    ; Max length for name

get_name_input_loop:
    mov ah, 01h             ; Read character from keyboard
    int 21h

    cmp al, 13              ; Check for Enter key (Carriage Return)
    je end_name_input

    cmp cx, 0               ; Check if max length reached (CX counts down)
    je skip_store_name_char ; If max length, don't store, just wait for Enter

    mov [si], al            ; Store character at current SI
    inc si                  ; Move to next byte in buffer
    dec cx                  ; Decrement remaining length counter
    jmp get_name_input_loop

skip_store_name_char:
    ; Discard extra characters if max length is reached before Enter
    jmp get_name_input_loop

end_name_input:
    mov byte ptr [si], '$' ; Terminate the name string with '$' for display (INT 21h, AH=09h)

    ; --- Get Password Input ---
    lea dx, enter_pass_prompt
    mov ah, 9
    int 21h

    mov si, offset passwords ; Base address of passwords array
    add si, di               ; Point SI to the correct user's password slot
    mov cx, MAX_PASS_LEN     ; Max length for password
    mov bx, 0                ; BX will count the actual length of the password

get_password_input_loop:
    mov ah, 01h              ; Read character from keyboard
    int 21h

    cmp al, 13               ; Check for Enter key (Carriage Return)
    je end_password_input

    cmp cx, 0                ; Check if max length reached (CX counts down)
    je skip_store_pass_char  ; If max length, don't store, just wait for Enter

    mov [si], al             ; Store character at current SI
    inc si                   ; Move to next byte in buffer
    inc bx                   ; Increment actual password length counter
    dec cx                   ; Decrement remaining length counter
    jmp get_password_input_loop

skip_store_pass_char:
    ; Discard extra characters if max length is reached before Enter
    jmp get_password_input_loop

end_password_input:
    mov byte ptr [si], 0     ; Null-terminate the password string

    ; Store actual password length in the password_lengths array
    mov al, [current_user_count] ; User index (0-4)
    mov ah, 0                    ; Clear AH for addressing
    mov si, offset password_lengths
    add si, ax                   ; SI now points to the correct length slot for this user
    mov [si], bl                 ; Store the length (from BX)

    ; --- Prompt for Password Strength Analysis ---
    lea dx, analyze_prompt
    mov ah, 9
    int 21h
    mov ah, 1           ; Wait for any key press (presumably Enter)
    int 21h
    line_gap            ; Consume the Enter and move to the next line

    ; --- Password Strength Analyzer ---
    ; BX already contains the actual length of the password
    ; DI contains the base offset for the current user's password slot
    ; so password starts at 'passwords' + DI

    push bp                     ; Save original BP
    push si                     ; Save SI
    push di                     ; Save DI
    push bx                     ; Save BX (actual password length)

    mov bp, sp                  ; Set BP to the current SP to enable BP-relative addressing

    mov al, 0                   ; Flag for has_special_char (0 = no, 1 = yes)
    mov ah, 0                   ; Flag for is_max_length (0 = no, 1 = yes)

    ; --- Check Length ---
    mov bl, [bp + 0]            ; Get saved BX (password length) from stack (BX was pushed last, so at BP+0)
    cmp bl, MAX_PASS_LEN        ; Compare actual length (from BL) with MAX_PASS_LEN
    jne length_is_weak_handler  ; If not equal, length is weak
    mov ah, 1                   ; Set is_max_length flag to 1 (password is max length)
    jmp start_special_char_analysis_logic ; JUMP HERE AFTER SETTING FLAG

length_is_weak_handler:
    mov ah, 0                   ; Explicitly set is_max_length flag to 0

start_special_char_analysis_logic: ; This is the correct entry point for the special character check after length analysis
    ; --- Check Special Character ---
    mov di, offset passwords    ; DI points to base of passwords array
    add di, [bp + 2]            ; Add saved DI (user's password offset) from stack (DI was pushed third, so at BP+2)
    mov cl, [bp + 0]            ; CL = actual password length (from saved BX) (BX was pushed last, so at BP+0)

    cmp cl, 0                   ; If password length is 0, no special chars possible
    je special_char_check_done  ; Skip special char check if password is empty

outer_loop_pass_chars:
    cmp cl, 0
    je special_char_check_done  ; Done checking password characters

    mov ch, [di]                ; Get current password character into CH

    ; Loop through special characters
    push di                     ; Save DI (password char pointer)
    push cx                     ; Save CX (password loop counter)
    
    mov si, offset special_chars ; SI points to the list of special characters
    
inner_loop_special_chars:
    mov dl, [si]                ; Get current special character
    cmp dl, 0                   ; Check for null terminator
    je no_match_in_special_chars_list ; End of special chars list, no match for current password char

    cmp ch, dl                  ; Compare password char with special char
    je found_special_char_in_pass ; Match found!

    inc si                      ; Move to next special character
    jmp inner_loop_special_chars

no_match_in_special_chars_list:
    pop cx                      ; Restore CX
    pop di                      ; Restore DI
    inc di                      ; Move to next password character
    dec cl                      ; Decrement password character counter
    jmp outer_loop_pass_chars

found_special_char_in_pass:
    mov al, 1                   ; Set has_special_char flag to 1
    pop cx                      ; Restore CX
    pop di                      ; Restore DI
    jmp special_char_check_done ; Exit both loops (found one special char)

special_char_check_done:
    ; Now, based on AL (has_special_char) and AH (is_max_length), display final strength message

    cmp ah, 1                   ; Is password max length?
    jne password_is_weak        ; If not max length, it's weak

    cmp al, 1                   ; Does password have special character?
    jne password_is_weak        ; If not, it's weak

    ; If both conditions are met (max length AND has special char)
    jmp password_is_strong      ; Password is strong

password_is_weak:
    lea dx, pass_strength_weak
    mov ah, 9
    int 21h
    line_gap

    ; Display the combined message for all weak passwords
    lea dx, pass_strength_weak_both_reasons
    mov ah, 9
    int 21h
    line_gap

    ; Restore registers pushed for analysis
    pop bx                      ; Restore BX (password length)
    pop di                      ; Restore DI (base offset for current user)
    pop si                      ; Restore SI (password_lengths + AX)
    pop bp                      ; Restore original BP
    
    jmp return_to_main_menu_after_strength_check ; Exit to main menu if weak

password_is_strong:
    lea dx, pass_strength_strong
    mov ah, 9
    int 21h
    line_gap
    ; Continue to encryption directly
    jmp continue_add_user_flow

return_to_main_menu_after_strength_check:
    ; Add a prompt so the user knows to press a key before returning
    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h ; Wait for key press
    line_gap ; Add a newline after the key press

    jmp main_menu ; Return to main menu

continue_add_user_flow:
    ; Restore registers pushed for analysis
    pop bx                      ; Restore BX (password length)
    pop di                      ; Restore DI (base offset for current user)
    pop si                      ; Restore SI (password_lengths + AX)
    pop bp                      ; Restore original BP

    ; --- Get Key Input ---
    lea dx, enter_key_prompt
    mov ah, 9
    int 21h

    mov ah, 01h              ; Read single character key
    int 21h                  ; AL has the input key (THIS IS THE KEY TO STORE)

    push ax                  ; Save AL (the input key) onto the stack

    ; Calculate address in 'keys' array: keys[current_user_count]
    mov bl, [current_user_count] ; Get user index (0-4) into BL
    mov al, bl                   ; Move 8-bit user index to AL
    mov ah, 0                    ; Clear AH (AX now holds 16-bit user index)
    mov si, offset keys          ; SI = base address of keys array
    add si, ax                   ; Add 16-bit user index to SI. SI now points to keys[user_index].

    pop ax                       ; Restore AL (the original input key) from stack

    mov [si], al                 ; Store the key character at keys[current_user_count]
    mov ch, al                   ; Save this correct key in CH for immediate encryption

    ; --- Encrypt the Password ---
    ; Get encryption key from CH (which holds the key read from user)
    ; Get password length from password_lengths array for current user
    mov al, [current_user_count] ; User index (0-4)
    mov ah, 0                    ; Clear AH to make AX a 16-bit index
    mov si, ax                   ; Move the 16-bit index from AX to SI
    mov cl, [password_lengths + si] ; Load actual password length into CL using SI

    mov si, offset passwords     ; Base address of passwords array
    add si, di                   ; Point SI to the current user's password in the array

encrypt_password_loop:
    cmp cl, 0                    ; Check if length is zero
    je encrypt_password_done     ; If so, done with encryption

    mov bl, [si]                 ; Get character into BL
    xor bl, ch                   ; Encrypt using XOR (key from CH)
    mov [si], bl                 ; Store encrypted character back
    inc si                       ; Move to next character
    dec cl                       ; Decrement length counter
    jmp encrypt_password_loop    ; Loop back

encrypt_password_done:

    ; --- Display Encrypted Password ---
    lea dx, enc_password_msg
    mov ah, 9
    int 21h
    line_gap ; Add a new line after the message

    ; Reload password length for display loop
    mov al, [current_user_count] ; User index (0-4)
    mov ah, 0
    mov si, ax                   ; Move the 16-bit index from AX to SI
    mov cl, [password_lengths + si] ; Load actual password length into CL using SI

    mov si, offset passwords     ; Base address of passwords array
    add si, di                   ; Point SI to the current user's password in the array

show_encrypted_password_loop:
    cmp cl, 0                    ; Check if length is zero
    je show_encrypted_password_done ; If so, done displaying

    mov al, [si]                 ; Get encrypted character into AL for show_hex_byte
    call show_hex_byte           ; Call procedure to display byte in hex
    inc si                       ; Move to next character
    dec cl                       ; Decrement length counter
    jmp show_encrypted_password_loop ; Loop back

show_encrypted_password_done:
    line_gap ; Add a new line after displaying hex values

    ; Increment the overall user count
    inc byte ptr [current_user_count]

    ; Display success message
    lea dx, user_added_msg
    mov ah, 9
    int 21h
    line_gap

    ; Wait for any key press before returning to main menu
    lea dx, input_prompt ; Re-use input prompt to indicate waiting for input
    mov ah, 9
    int 21h
    mov ah, 1 ; Wait for any key press
    int 21h
    jmp main_menu

vault_full_handler:
    lea dx, vault_full_msg
    mov ah, 9
    int 21h
    line_gap
    ; Wait for any key press before returning to main menu
    lea dx, input_prompt
    mov ah, 9
    int 21h
    mov ah, 1
    int 21h
    jmp main_menu

ShowPassword: ; This is the implementation for option '2'
    ; Clear screen
    mov ax, 0003h
    int 10h

    ; Check if there are any users added
    cmp byte ptr [current_user_count], 0
    je no_users_added

    ; Ask for username
    lea dx, enter_name_prompt ; Reusing prompt "Enter name (max 10 chars): $"
    mov ah, 9
    int 21h

    ; Get username input into temp_username
    mov si, offset temp_username
    mov cx, MAX_NAME_LEN ; Max length for username
    mov bx, 0 ; Clear BX for use as a counter for input length

get_username_input_loop:
    mov ah, 01h             ; Read character from keyboard
    int 21h

    cmp al, 13              ; Check for Enter key (Carriage Return)
    je end_username_input

    cmp bx, MAX_NAME_LEN    ; Check if max length reached (BX counts up)
    jge skip_store_user_char ; If max length, don't store, just wait for Enter

    mov [si], al            ; Store character at current SI
    inc si                  ; Move to next byte in buffer
    inc bx                  ; Increment character count
    jmp get_username_input_loop
skip_store_user_char:
    ; Discard extra characters if max length is reached before Enter
    jmp get_username_input_loop
end_username_input:
    mov byte ptr [si], '$' ; Terminate the input username string with '$'


    ; Search for username in names array
    mov byte ptr [user_found_idx], 0FFh ; Reset found index to indicate not found
    mov bl, 0                           ; BL = Current user index to check (0 to current_user_count-1)

search_user_loop:
    cmp bl, [current_user_count] ; Check if all users checked
    jge user_search_done         ; If BL >= current_user_count, no match found

    ; Calculate offset for current name in names array
    mov al, MAX_NAME_LEN
    mul bl                       ; AX = user_index * MAX_NAME_LEN
    mov di, ax                   ; DI holds offset for names array

    ; Compare temp_username with names[bl]
    push bx                      ; Save current user index (BL)
    push di                      ; Save current offset (DI)

    mov si, offset temp_username ; Source 1: input username
    mov di, offset names         ; Source 2: stored names array
    add di, ax                   ; Point DI to the current user's name slot

    mov cx, MAX_NAME_LEN         ; Max characters to compare (up to 10)

compare_name_chars_loop:
    mov al, [si]                 ; Get char from input username
    mov ah, [di]                 ; Get char from stored username

    cmp al, '$'                  ; Check if input username ends
    je check_stored_name_end
    cmp ah, '$'                  ; Check if stored username ends
    je check_input_name_end

    cmp al, ah                   ; Compare characters
    jne name_mismatch            ; If not equal, mismatch

    inc si                       ; Move to next char in temp_username
    inc di                       ; Move to next char in stored name
    loop compare_name_chars_loop ; Decrement CX, loop if CX > 0

    ; If loop finishes, strings match up to MAX_NAME_LEN or both ended prematurely
    jmp name_match

name_mismatch:
    pop di                       ; Restore DI
    pop bx                       ; Restore BL (user index)
    inc bl                       ; Move to next user
    jmp search_user_loop         ; Continue search

check_stored_name_end:
    ; Input username ended. Check if stored name also ended.
    cmp ah, '$'                  ; AH holds the char from stored name, which is already '$' here
    je name_match                ; If both ended, it's a match
    jmp name_mismatch            ; If stored name didn't end here, mismatch

check_input_name_end:
    ; Stored name ended. Check if input username also ended.
    cmp al, '$'                  ; AL holds the char from input username, which is already '$' here
    je name_match                ; If both ended, it's a match
    jmp name_mismatch            ; If input username didn't end here, mismatch

name_match:
    pop di                       ; Restore DI
    pop bx                       ; Restore BL (user index)
    mov [user_found_idx], bl     ; Store the index of the matched user in user_found_idx
    jmp user_search_done         ; Found a match, exit search loop

user_search_done:
    cmp byte ptr [user_found_idx], 0FFh ; Check if a user was found
    je username_not_found

    ; --- Username Found! Now ask for decryption key ---
    mov bl, [user_found_idx]     ; Get matched user index into BL (8-bit)

    lea dx, enter_dec_key_prompt
    mov ah, 9
    int 21h
    mov ah, 01h                  ; Read key input
    int 21h                      ; AL has the input decryption key

    ; Compare input key with stored key
    mov bh, al                   ; Save input key from AL to BH (AL will be used for index calc)

    mov al, bl                   ; Move 8-bit user index (from BL) to AL
    mov ah, 0                    ; Clear AH for 16-bit index
    mov si, offset keys          ; Base address of keys array
    add si, ax                   ; Add 16-bit index to SI (SI points to stored key)

    cmp bh, [si]                 ; Compare saved input key (BH) with stored key ([SI])
    jne incorrect_key_handler

    ; --- Correct Key! Decrypt and Display Password ---
    lea dx, decrypted_pass_msg
    mov ah, 9
    int 21h
    line_gap

    ; Calculate password offset for the matched user
    mov al, MAX_PASS_LEN
    mul bl                       ; AX = user_index * MAX_PASS_LEN (BL holds user_found_idx)
    mov di, ax                   ; DI holds the offset for password in 'passwords' array

    ; Get the actual password length for the matched user
    mov al, bl                   ; User index (BL) to AL for indexing 'password_lengths'
    mov ah, 0
    mov si, offset password_lengths
    add si, ax                   ; SI points to the correct length slot
    mov cl, [si]                 ; CL holds actual password length

    ; Get the encryption/decryption key
    mov al, bl                   ; User index (BL) to AL
    mov ah, 0
    mov si, offset keys          ; Base address of keys array
    add si, ax                   ; Add 16-bit index to SI
    mov ch, [si]                 ; CH holds the key

    mov si, offset passwords     ; Base address of passwords array
    add si, di                   ; Point SI to the current user's encrypted password

decrypt_and_display_loop:
    cmp cl, 0                    ; Check if length is zero
    je decrypt_display_done

    mov bl, [si]                 ; Get encrypted character into BL
    xor bl, ch                   ; Decrypt using XOR (key from CH)
    mov dl, bl                   ; Move decrypted character to DL for display
    mov ah, 02h                  ; Display character
    int 21h

    inc si                       ; Move to next character
    dec cl                       ; Decrement length counter
    jmp decrypt_and_display_loop

decrypt_display_done:
    line_gap                     ; Add a new line after displaying

    ; Wait for a key press before returning to main menu
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
    ; Wait for a key press before returning to main menu
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
    ; Wait for a key press before returning to main menu
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
    ; Wait for a key press before returning to main menu
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

; Convert and display a byte in hexadecimal
show_hex_byte PROC
    push ax
    push bx
    push dx

    ; High nibble
    mov ah, 0
    mov bl, al           ; Copy AL to BL
    shr bl, 4            ; Shift high nibble to low position
    call print_hex_digit ; Display the high nibble

    ; Low nibble
    mov bl, al           ; Original AL (full byte) to BL
    and bl, 0Fh          ; Mask to get only the low nibble
    call print_hex_digit ; Display the low nibble

    ; Space after hex byte for readability
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
    jbe belowA           ; If digit is 0-9, jump to belowA
    add bl, 7            ; Convert 10-15 to 'A'-'F' (e.g., 10 becomes 17, which is 'A')
belowA:
    add bl, '0'          ; Convert numeric digit to ASCII character
    mov dl, bl           ; Move character to DL for display
    mov ah, 02h          ; DOS function to display character
    int 21h
    ret
print_hex_digit ENDP

END MAIN