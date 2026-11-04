.intel_syntax noprefix
.code64
.set PLAYER_SLOT, 0x142b2abf0
.set SERVER_CONTEXT, 0x1446ceca0
.set SERVER_PEER_TABLE, 0x143b65598
.set SERVER_CONNECTION_TABLE, 0x143a574e8
.set SERVER_CHARACTER, 0x143a75900
.set PLAYER_LIMIT, 4
.set CONNECTION_LIMIT, 16
.set ENTRY_LIMIT, 8

entries:
    jmp players
.balign 8
    jmp is_player
.balign 8
    jmp nearest_player
.balign 8

players:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    mov rdi, rcx
    xor eax, eax
    mov qword ptr [rdi], rax
    mov qword ptr [rdi + 8], rax
    mov qword ptr [rdi + 0x10], rax
    mov qword ptr [rdi + 0x18], rax
    xor ebx, ebx
    movabs rax, SERVER_CONTEXT
    mov rcx, qword ptr [rax]
    call pointer
    test al, al
    je players_done
    mov rcx, qword ptr [rcx + 0xb8]
    call pointer
    test al, al
    je players_done
    movabs rax, SERVER_PEER_TABLE
    cmp qword ptr [rcx], rax
    jne players_done
    mov rsi, qword ptr [rcx + 0x45a8]
    mov r12, qword ptr [rcx + 0x45b0]
    mov r13d, CONNECTION_LIMIT
    mov rcx, rsi
    call pointer
    test al, al
    je players_done
players_connection:
    cmp rsi, r12
    jae players_done
    dec r13d
    js players_done
    mov rcx, qword ptr [rsi]
    add rsi, 8
    call pointer
    test al, al
    je players_connection
    movabs rax, SERVER_CONNECTION_TABLE
    cmp qword ptr [rcx], rax
    jne players_connection
    mov r8, qword ptr [rcx + 0xa90]
    mov r9, qword ptr [rcx + 0xa98]
    mov r10d, ENTRY_LIMIT
    mov rcx, r8
    call pointer
    test al, al
    je players_connection
players_entry:
    cmp r8, r9
    jae players_connection
    dec r10d
    js players_connection
    mov rcx, qword ptr [r8]
    add r8, 8
    call pointer
    test al, al
    je players_entry
    mov rdx, qword ptr [rcx + 0xf8]
    mov rcx, rdx
    call pointer
    test al, al
    je players_entry
    mov rcx, qword ptr [rdx + 0x220]
    call pointer
    test al, al
    je players_entry
    movabs rax, SERVER_CHARACTER
    cmp qword ptr [rcx], rax
    jne players_entry
    cmp qword ptr [rcx + 0x2b8], rdx
    jne players_entry
    xor eax, eax
players_seen:
    cmp eax, ebx
    jae players_store
    cmp qword ptr [rdi + rax * 8], rcx
    je players_entry
    inc eax
    jmp players_seen
players_store:
    cmp ebx, PLAYER_LIMIT
    jae players_done
    mov qword ptr [rdi + rbx * 8], rcx
    inc ebx
    jmp players_entry
players_done:
    test ebx, ebx
    jne players_out
    movabs rax, PLAYER_SLOT
    mov rcx, qword ptr [rax]
    call pointer
    test al, al
    je players_out
    movabs rax, SERVER_CHARACTER
    cmp qword ptr [rcx], rax
    jne players_out
    mov qword ptr [rdi], rcx
    mov ebx, 1
players_out:
    mov eax, ebx
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

is_player:
    movabs rax, PLAYER_SLOT
    cmp rcx, qword ptr [rax]
    je is_player_yes
    call pointer
    test al, al
    je is_player_no
    movabs rax, SERVER_CHARACTER
    cmp qword ptr [rcx], rax
    jne is_player_no
    cmp qword ptr [rcx + 0x2b8], 0
    je is_player_no
is_player_yes:
    test rcx, rcx
    setne al
    movzx eax, al
    ret
is_player_no:
    xor eax, eax
    ret

nearest_player:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x40
    mov rbx, rcx
    lea rcx, [rsp + 0x20]
    call players
    mov esi, eax
    xor eax, eax
    test esi, esi
    je nearest_out
    mov rcx, rbx
    mov rbx, qword ptr [rsp + 0x20]
    call translation
    test rax, rax
    je nearest_done
    movups xmm4, xmmword ptr [rax]
    movss xmm5, dword ptr [rip + farthest]
    xor edi, edi
nearest_loop:
    cmp edi, esi
    jae nearest_done
    mov rcx, qword ptr [rsp + 0x20 + rdi * 8]
    call translation
    test rax, rax
    je nearest_next
    movups xmm0, xmmword ptr [rax]
    subps xmm0, xmm4
    mulps xmm0, xmm0
    movaps xmm1, xmm0
    shufps xmm1, xmm1, 0x55
    movaps xmm2, xmm0
    shufps xmm2, xmm2, 0xaa
    addss xmm0, xmm1
    addss xmm0, xmm2
    comiss xmm0, xmm5
    jae nearest_next
    movss xmm5, xmm0
    mov rbx, qword ptr [rsp + 0x20 + rdi * 8]
nearest_next:
    inc edi
    jmp nearest_loop
nearest_done:
    mov rax, rbx
nearest_out:
    add rsp, 0x40
    pop rdi
    pop rsi
    pop rbx
    ret

pointer:
    xor eax, eax
    test cl, 7
    jne pointer_out
    cmp rcx, 0x10000
    jb pointer_out
    movabs r11, 0x7ff000000000
    cmp rcx, r11
    jae pointer_out
    mov al, 1
pointer_out:
    ret

translation:
    xor eax, eax
    test rcx, rcx
    je translation_done
    test cl, 7
    jne translation_done
    movabs r8, SERVER_CHARACTER
    cmp qword ptr [rcx], r8
    jne translation_done
    mov r8, qword ptr [rcx + 0x58]
    test r8, r8
    je translation_done
    test r8b, 7
    jne translation_done
    movzx r9d, byte ptr [r8 + 9]
    movzx r10d, byte ptr [r8 + 0xa]
    lea r9, [r9 + r10 * 2]
    shl r9, 5
    lea rax, [r8 + r9 + 0x40]
translation_done:
    ret

.balign 4
farthest:
    .float 3.0e38
