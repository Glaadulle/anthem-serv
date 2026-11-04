.intel_syntax noprefix
.code64
start:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x50
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
    mov rax, qword ptr [rbx]
    movabs rdx, 0x143660000
    cmp rax, rdx
    jb done
    movabs rdx, 0x1442f0000
    cmp rax, rdx
    jae done
    movss xmm1, dword ptr [rsi + 0xa0]
    xorps xmm0, xmm0
    comiss xmm1, xmm0
    jbe done
    mov eax, 0x47c35000
    movd xmm0, eax
    comiss xmm1, xmm0
    jae done
    mov qword ptr [rsp + 0x38], rbx
    lea rax, [rsp + 0x38]
    mov qword ptr [rsp + 0x30], rax
    lea rcx, [rsp + 0x28]
    movabs rax, 0x140c86ef0
    call rax
done:
    add rsp, 0x50
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
