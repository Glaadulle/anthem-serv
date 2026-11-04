.intel_syntax noprefix
.code64
.set SECTION_IMPACT, 2
melee:
    push rbx
    sub rsp, 0xf0
    mov rax, qword ptr [rdx + 0x20]
    test rax, rax
    je melee_done
    test al, 7
    jne melee_done
    add rax, 8
    mov qword ptr [rsp + 0xe0], rax
    lea rax, [rsp + 0xe0]
    mov qword ptr [rsp + 0x68], rax
    mov eax, dword ptr [rip + melee_amount]
    mov dword ptr [rsp + 0xd0], eax
    mov qword ptr [rsp + 0x70], 0
    lea rdx, [rsp + 0x30]
    mov ecx, SECTION_IMPACT
    movabs rax, 0x144759e70
    call qword ptr [rax]
melee_done:
    add rsp, 0xf0
    pop rbx
    ret
.org 0x80, 0xcc
explosion:
    push rbx
    sub rsp, 0xf0
    mov rax, qword ptr [rdx]
    test rax, rax
    je explosion_done
    test al, 7
    jne explosion_done
    mov qword ptr [rsp + 0x68], rax
    mov eax, dword ptr [rip + explosion_amount]
    mov dword ptr [rsp + 0xd0], eax
    mov qword ptr [rsp + 0x70], 0
    lea rdx, [rsp + 0x30]
    mov ecx, SECTION_IMPACT
    movabs rax, 0x144759e70
    call qword ptr [rax]
explosion_done:
    add rsp, 0xf0
    pop rbx
    ret
.balign 4
melee_amount:
    .float 6000.0
explosion_amount:
    .float 6000.0
