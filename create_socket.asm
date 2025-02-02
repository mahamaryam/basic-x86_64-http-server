section .data
    socket      dq      0
    port        dw  0x901F   ; Port 8080 in network byte order (htons(8080))
    ip_addr     dd  0        ; INADDR_ANY (listen on all interfaces)
    starting    db  "Listening on port 8080...", 0ah, 0ah, 0h
    startingLen equ $ - starting
    client      dq  0
    buffLen     equ 512
    reqBuff     times buffLen db 0
    file        db  "index.html", 0h
    fd          dd  0
    fileBuffer  times buffLen db 0
    here db "here"
    ; HTTP Response (200 OK)
    http_response db "HTTP/1.1 200 OK", 0ah
                  db "Content-Type: text/plain", 0ah
                  db "Connection: close", 0ah, 0ah
    http_response_len equ $ - http_response
    
    ; HTTP 404 Response
    http_bad_response db "HTTP/1.1 404 Not Found", 0ah
                      db "Content-Length: 17", 0ah
                      db "Connection: close", 0ah, 0ah
                      db "File Not Found", 0ah
    bad_res_len equ $ - http_bad_response

section .bss
    sockaddr resb 16    ; sockaddr_in structure

section .text
    global _start

_start:
    ; Create socket (socket(AF_INET, SOCK_STREAM, 0))
    mov rdi, 2          ; AF_INET
    mov rsi, 1          ; SOCK_STREAM (TCP)
    mov rdx, 0          ; Protocol (0 = default for TCP)
    mov rax, 41         ; syscall: socket()
    syscall
    mov [socket],rax
    test rax, rax
    js error
    mov rbx, rax        ; Store socket descriptor

    ; Prepare sockaddr_in structure
    mov rdi, sockaddr
    mov word [rdi], 2   ; sin_family = AF_INET
    mov word [rdi + 2], 0x901F  ; sin_port = htons(8080)
    mov dword [rdi + 4], 0  ; sin_addr = INADDR_ANY (0.0.0.0)

    ; Bind socket (bind(sockfd, sockaddr, sizeof(sockaddr)))
    mov rdi, [socket]        ; Socket descriptor
    mov rsi, sockaddr   ; Pointer to sockaddr struct
    mov     rdx,dword 32            ; Load 32 bit socket address size
    mov rax, 49         ; syscall: bind()
    syscall
    test rax, rax
    js error

    ; Print startup message
    mov rax, 1
    mov rdi, 1
    mov rsi, starting
    mov rdx, startingLen
    syscall

    ; Listen (listen(sockfd, backlog))
    mov rdi, [socket]        ; Socket descriptor
    mov rsi, 8         ; Backlog (max queue size)
    mov rax, 50         ; syscall: listen()
    syscall
    test rax, rax
    js error

acceptRequests:
    ; Accept a new connection (accept(sockfd, sockaddr, sizeof(sockaddr)))
    mov rdi, [socket]        ; Server socket descriptor
    xor rsi,rsi
    xor rdx,rdx
    mov rax, 43         ; syscall: accept()
    syscall
    cmp rax,0
    jl error
    mov [client], rax   ; Store client socket descriptor

    ; Read request (read(client_sock, reqBuff, buffLen))
    mov rax, 0          ; syscall: read()
    mov rdi, [client]   ; Client socket descriptor
    mov rsi, reqBuff    ; Buffer to store request
    mov rdx, buffLen    ; Max bytes to read
    syscall
    test rax, rax
    js closeClient      ; If error, close client
    
    ; Open "index.html"
    mov rdi, file
    mov rsi, 0          ; Read-only mode
    mov rdx, 0
    mov rax, 2          ; syscall: open()
    syscall
    test rax, rax
    js fileNotFound     ; If file doesn't exist, return 404
    mov [fd], rax       ; Store file descriptor

    ; Send HTTP response headers first (write(client_sock, http_response, http_response_len))
    mov rdi, [client]   ; Client socket descriptor
    mov rsi, http_response
    mov rdx, http_response_len
    mov rax, 1          ; syscall: write()
    syscall
    test rax, rax
    js closeClient      ; If failed to write headers, close client

    mov rdi, 1
    mov rax,1
    syscall
readAndWrite:
    ; Read file into buffer
    mov rax, 0          ; syscall: read()
    mov rdi, [fd]       ; File descriptor
    mov rsi, fileBuffer ; Buffer
    mov rdx, buffLen    ; Max bytes to read
    syscall
    test rax, rax
    jle closeFile       ; If EOF (rax == 0), close file

    ; Write file data to client
    mov rdi, [client]   ; Client socket descriptor
    mov rsi, fileBuffer ; Buffer
    mov rdx, rax        ; Length (bytes read)
    mov rax, 1          ; syscall: write()
    syscall
    test rax, rax
    js closeFile        ; If failed to write file data, close client

    ; Continue reading and writing file
    jmp readAndWrite

closeFile:
    ; Close file (close(fd))
    mov rax, 3          ; syscall: close()
    mov rdi, [fd]       ; File descriptor
    syscall

closeClient:
    ; Close client connection (close(client_sock))
    mov rax, 3          ; syscall: close()
    mov rdi, [client]   ; Client socket descriptor
    syscall

    jmp acceptRequests  ; Go back to accepting new connections

fileNotFound:
    ; Send HTTP 404 Response (File Not Found)
    mov rdi, [client]
    mov rsi, http_bad_response
    mov rdx, bad_res_len
    mov rax, 1
    syscall

    jmp closeClient  ; Close the client after sending 404 response

error:
    mov rdi, 1
    mov rax, 60      ; syscall: exit()
    syscall

