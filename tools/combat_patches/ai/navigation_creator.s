.intel_syntax noprefix
.code64
.set CALLS, 0x153737490
.set LAST, 0x153737498
.set ALLOCATE, 0x1403bb060
.set SERVER_CONSTRUCTOR, 0x1417c6db0
.set RELEASE_OWNER_HANDLE, 0x141b06870
.set ADD_CREATED, 0x14156fbf0
start:
    push rdi
    sub rsp, 0x20
    movabs rax, CALLS
    lock inc dword ptr [rax]
    mov rcx, qword ptr [rdx + 0x110]
    mov rdi, rdx
    mov rax, qword ptr [rcx]
    call qword ptr [rax + 0x10]
    cmp byte ptr [rdi + 0x121], al
    je create
    xor eax, eax
    add rsp, 0x20
    pop rdi
    ret
create:
    mov rax, qword ptr [rdi + 0x10]
    xor r9d, r9d
    mov qword ptr [rsp + 0x30], rbx
    mov qword ptr [rsp + 0x40], rsi
    mov rcx, qword ptr [rax + 8]
    lea edx, [r9 + 0x50]
    lea r8d, [r9 + 8]
    mov rax, qword ptr [rcx + 0x38]
    mov rcx, qword ptr [rax + 0x58]
    movabs rax, ALLOCATE
    call rax
    mov r8, qword ptr [rdi + 0x110]
    lea rdx, [rdi + 0x10]
    mov rcx, rax
    movabs rax, SERVER_CONSTRUCTOR
    call rax
    mov rcx, qword ptr [rdi + 0x118]
    mov rbx, rax
    test rcx, rcx
    je initialise
    mov rdx, qword ptr [rcx]
    mov r8, qword ptr [rdx + 0x20]
    mov rdx, rax
    call r8
    mov qword ptr [rdi + 0x80], rax
initialise:
    mov rax, qword ptr [rbx]
    lea rdx, [rdi + 0x10]
    or qword ptr [rbx + 0x18], 2
    mov rcx, rbx
    call qword ptr [rax + 0x70]
    mov rcx, qword ptr [rdi + 0x80]
    test rcx, rcx
    je attach
    movabs rax, RELEASE_OWNER_HANDLE
    call rax
    mov qword ptr [rdi + 0x80], 0
attach:
    mov rax, qword ptr [rdi + 0x10]
    xor r8d, r8d
    mov rdx, rbx
    mov qword ptr [rsp + 0x38], rbx
    mov rcx, qword ptr [rax + 8]
    mov rax, qword ptr [rcx]
    call qword ptr [rax + 8]
    mov rcx, qword ptr [rdi + 0x128]
    mov rsi, qword ptr [rsp + 0x40]
    test rcx, rcx
    je done
    lea rdx, [rsp + 0x38]
    movabs rax, ADD_CREATED
    call rax
done:
    movabs rax, LAST
    mov qword ptr [rax], rbx
    mov rax, rbx
    mov rbx, qword ptr [rsp + 0x30]
    add rsp, 0x20
    pop rdi
    ret
