section .data
    socket      dq      0
    port        dw  0x901F   
    ip_addr     dd  0        
    starting    db  "Listening on port 8080...", 0ah, 0ah, 0h
    startingLen equ $ - starting
    client      dq  0
    buffLen     equ 512
    reqBuff     times buffLen db 0
    file        db  "index.html", 0h
    fd          dd  0
    fileBuffer  times buffLen db 0
    here db "here"
    http_response db "HTTP/1.1 200 OK", 0ah
                  db "Content-Type: text/plain", 0ah
                  db "Connection: close", 0ah, 0ah
    http_response_len equ $ - http_response
    
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
    ;creating socket (socket(AF_INET, SOCK_STREAM, 0))
    mov rdi, 2          ;af_inet
    mov rsi, 1          ;tcp
    mov rdx, 0          ;the protocol
    mov rax, 41         
    syscall
    mov [socket],rax
    test rax, rax
    js error
    mov rbx, rax        ;store socket fd

    ;preparation of the socket strcut
    mov rdi, sockaddr
    mov word [rdi], 2   ;AF_INET
    mov word [rdi + 2], 0x901F  
    mov dword [rdi + 4], 0  

    ;binding like...  (bind(sockfd, sockaddr, sizeof(sockaddr)))
    mov rdi, [socket]        ;socket fd
    mov rsi, sockaddr   ;ptr to stryct
    mov     rdx,dword 32          
    mov rax, 49         
    syscall
    test rax, rax
    js error

    mov rax, 1
    mov rdi, 1
    mov rsi, starting
    mov rdx, startingLen
    syscall

    ;listen(listen(sockfd, backlog))
    mov rdi, [socket]      
    mov rsi, 8         
    mov rax, 50         
    syscall
    test rax, rax
    js error

acceptRequests:
    ;accept(sockfd, sockaddr, sizeof(sockaddr))
    mov rdi, [socket]        
    xor rsi,rsi
    xor rdx,rdx
    mov rax, 43         
    syscall
    cmp rax,0
    jl error
    mov [client], rax   

    mov rax, 0         
    mov rdi, [client]  
    mov rsi, reqBuff   
    mov rdx, buffLen    
    syscall
    test rax, rax
    js closeClient      
    
    mov rdi, file
    mov rsi, 0          
    mov rdx, 0
    mov rax, 2          
    syscall
    test rax, rax
    js fileNotFound    
    mov [fd], rax       

    mov rdi, [client]   
    mov rsi, http_response
    mov rdx, http_response_len
    mov rax, 1          
    syscall
    test rax, rax
    js closeClient      

    mov rdi, 1
    mov rax,1
    syscall
readAndWrite:
    mov rax, 0         
    mov rdi, [fd]       
    mov rsi, fileBuffer 
    mov rdx, buffLen    
    syscall
    test rax, rax
    jle closeFile       

    mov rdi, [client]   
    mov rsi, fileBuffer 
    mov rdx, rax        
    mov rax, 1         
    syscall
    test rax, rax
    js closeFile        

    jmp readAndWrite

closeFile:
    mov rax, 3          
    mov rdi, [fd]       
    syscall

closeClient:
    mov rax, 3          
    mov rdi, [client]   
    syscall
    jmp acceptRequests  

fileNotFound:
    mov rdi, [client]
    mov rsi, http_bad_response
    mov rdx, bad_res_len
    mov rax, 1
    syscall

    jmp closeClient  

error:
    mov rdi, 1
    mov rax, 60      
    syscall

