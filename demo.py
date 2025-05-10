#single-key
# message and key
msg = input("Enter your message: ")
key = input("Enter your key: ")
global c
c = 0
# encrypt via XOR
encrypted_bytes = []
for c in msg:
    encrypted = ord(c) ^ ord(key)
    encrypted_bytes.append(encrypted)

# show encrypted values in hex
print("Encrypted bytes (hex):", [hex(b) for b in encrypted_bytes])

def validate_key():
    while True:
        gkey = input("Enter key to decrypt: ")
        if gkey == key:
            # Decrypt the message
            decrypted = "".join(chr(b ^ ord(gkey)) for b in encrypted_bytes)
            print("Decrypted message:", decrypted)
            break
        else:
            if c>=3:
                break 
            c+=1
            print("Incorrect key! Access denied.")

# Try to decrypt
validate_key()