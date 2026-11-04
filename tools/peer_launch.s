.intel_syntax noprefix
.code64
.set BACKEND_INTERFACE_TABLE, 0x143a444b8
.set GAME_INTERFACE_TABLE, 0x143ca3c28
.set AFTER_VALUES, 0x14a60f7d1
.set AFTER_STATE, 0x14a60f84f
join_values:
    call topology_host
    test al, al
    jz 1f
    mov word ptr [rdi + 0x413], 0x100
    mov dword ptr [rdi + 0x90], 1
    jmp 2f
1:
    mov word ptr [rdi + 0x413], 0
    mov dword ptr [rdi + 0x90], 3
2:
    lea rdx, [rsi + 0x50]
    movabs rax, AFTER_VALUES
    jmp rax

.org 0x60, 0xcc
join_state:
    call topology_host
    mov edx, 0xf
    test al, al
    jz 3f
    mov edx, 5
3:
    movabs rax, AFTER_STATE
    jmp rax

topology_host:
    mov rcx, qword ptr [rdi + 0xc8]
    test rcx, rcx
    jz not_host
    movabs rax, BACKEND_INTERFACE_TABLE
    cmp qword ptr [rcx], rax
    jne not_host
    mov rcx, qword ptr [rcx + 0x30]
    test rcx, rcx
    jz not_host
    movabs rax, GAME_INTERFACE_TABLE
    cmp qword ptr [rcx + 0x388], rax
    jne not_host
    mov rax, qword ptr [rcx + 8]
    cmp rax, qword ptr [rsi + 0x50]
    jne not_host
    mov rax, qword ptr [rcx + 0x768]
    test rax, rax
    jz not_host
    cmp rax, qword ptr [rcx + 0x6a0]
    sete al
    movzx eax, al
    ret
not_host:
    xor eax, eax
    ret
