.MODEL SMALL 

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
; declare variables here
main_msg1 db "1.Encrypt$"
main_msg2 db "2.Dcrypt$"
main_msg3 db "3.Exit$"
input db "Enter: $"
en_msg1 db "Encrypting...$"
d_msg1 db "Dcrypting...$"
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
    
    ; Show option to go back
    lea dx,back_msg
    mov ah,9
    int 21h
    
    line_gap 10,13
    
    lea dx,input
    mov ah,9
    int 21h
    
    mov ah,1
    int 21h
    sub al,30h
    
    cmp al,0
    je main_menu  ; Go back to main menu if input is 0
    
    jmp Encrypt   ; Otherwise stay in Encrypt menu
    
Dcrypt:
    ; Clear screen
    mov ax, 0003h
    int 10h
    
    lea dx,d_msg1 
    mov ah,9 
    int 21h
    
    line_gap 10,13
    
    ; Show option to go back
    lea dx,back_msg
    mov ah,9
    int 21h
    
    line_gap 10,13
    
    lea dx,input
    mov ah,9
    int 21h
    
    mov ah,1
    int 21h
    sub al,30h
    
    cmp al,0
    je main_menu  ; Go back to main menu if input is 0
    
    jmp Dcrypt    ; Otherwise stay in Decrypt menu

exit:
    ; exit to DOS
    MOV AX,4C00H 
    INT 21H

MAIN ENDP 
END MAIN