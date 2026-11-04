.intel_syntax noprefix
.code64
start:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    sub rsp, 0x40
    mov rsi, rdx
    mov rdi, rdx
    call heap
    test al, al
    je done
    mov rdi, qword ptr [rsi + 0x38]
    call heap
    test al, al
    je done
    mov rdi, qword ptr [rdi]
    call heap
    test al, al
    je done
    lea rbx, [rdi - 8]
    mov rcx, rbx
    call image_table
    test al, al
    je done
    movss xmm1, dword ptr [rsi + 0xa0]
    xorps xmm0, xmm0
    comiss xmm1, xmm0
    jbe done
    mov eax, 0x47c35000
    movd xmm0, eax
    comiss xmm1, xmm0
    jae done
    movss dword ptr [rsp + 0x24], xmm1
    mov qword ptr [rsp + 0x38], rbx
    lea rax, [rsp + 0x38]
    mov qword ptr [rsp + 0x30], rax
    lea rcx, [rsp + 0x28]
    movabs rax, 0x140c86ef0
    call rax
    mov rdi, qword ptr [rbx + 0x58]
    call heap
    test al, al
    je done
    movzx r13d, byte ptr [rdi + 8]
    lea r12, [rdi + 0x10]
find:
    test r13d, r13d
    je done
    mov rdi, qword ptr [r12 + 0x10]
    call heap
    test al, al
    je next
    movabs rax, 0x143a88538
    cmp qword ptr [rdi], rax
    je found
next:
    add r12, 0x20
    dec r13d
    jmp find
found:
    mov r12, rdi
    mov rdi, qword ptr [r12 + 0x10]
    call heap
    test al, al
    je done
    cmp byte ptr [rdi + 0x12f], 0
    jne done
    movss xmm0, dword ptr [r12 + 0x20]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    jbe done
    movss xmm1, dword ptr [rsp + 0x24]
    movss xmm2, dword ptr [rip + inverse_k]
    mulss xmm1, xmm2
    subss xmm0, xmm1
    xorps xmm2, xmm2
    maxss xmm0, xmm2
    movss dword ptr [r12 + 0x20], xmm0
done:
    add rsp, 0x40
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret
heap:
    xor eax, eax
    test dil, 7
    jne 1f
    cmp rdi, 0x10000
    jb 1f
    movabs rdx, 0x7ff000000000
    cmp rdi, rdx
    jae 1f
    mov al, 1
1:
    ret
image_table:
    xor eax, eax
    mov rcx, qword ptr [rcx]
    movabs rdx, 0x143660000
    cmp rcx, rdx
    jb 2f
    movabs rdx, 0x1442f0000
    cmp rcx, rdx
    jae 2f
    mov al, 1
2:
    ret
.balign 4
inverse_k:
    .float 0.00005
