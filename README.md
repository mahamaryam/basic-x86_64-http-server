# basic-x86_64-http-server
a pretty basic http server in assembly langauge x86-64
on the client side:
curl http://127.0.0.1:8080 --output response.html
then run the html file:
google-chrome response.html

on the server side:
nasm -f elf64 -o socket.o create_socket.asm
ld -o socket socket.o
./socket
