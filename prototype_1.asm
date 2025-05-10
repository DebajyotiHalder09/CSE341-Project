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
; here, the vault is saved using 3 sets of variables
; All strings use double quotes for consistency
main_msg1 db "1.Encrypt$"
main_msg2 db "2.Decrypt$"
main_msg3 db "3.Exit$"
input db "Enter: $"
en_msg1 db "Encrypting...$"
d_msg1 db "Decrypting...$"
back_msg db "0. Go back to main$" 

prompt1 db "Enter name (max 10 chars): $"
prompt2 db 0Dh,0Ah,"Enter password: $"
prompt3 db 0Dh,0Ah,"Enter 1-char key: $"
prompt4 db 0Dh,0Ah,"Enter key to decrypt: $"
prompt5 db 0Dh,0Ah,"Decrypted password: $"
enc_msg db 0Dh,0Ah,"Encrypted password (hex): $"
wrong_msg db 0Dh,0Ah,"Incorrect key! Access denied.$"
access_den db 0Dh,0Ah,"Too many attempts. Access blocked.$"

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
    
    lea dx,main_msg3 
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
    je exit
    
    jmp main_menu  ; Invalid input, go back to main menu
    
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