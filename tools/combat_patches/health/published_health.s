.intel_syntax noprefix
.code64
.set PUBLISH, 0x1403fa290
.set ORIGINAL_EVALUATOR, 0x1407d7cb0
.set ORIGINAL_SETTINGS_EVALUATE, 0x140c13f70
.set STATE, 0x153737780
.set SIMPLE_HEALTH_TABLE, 0x143a88538
.set PLAYER_HEALTH_TABLE, 0x143a88050
.set HEALTH_NETWORK_TABLE, 0x143a881f8
.set MARK_DIRTY, 0x141e5e2c0
.set DYLAN_MAX_HEALTH, 0x9f424473
.set SETTINGS_ENTRIES, 26
.set DOWNED_FRAMES, 0x1537377e0
.set REVIVE_FRAMES, 240
.set PLAYER_TABLE, 0x153737a00
.set PLAYER_ENTRIES, 4
.set PLAYER_ENTRY_SIZE, 0x18
.set PLAYER_STAMP, 0x153737a60
.set REVIVE_MESSAGE_TABLE, 0x143a8b658
.set SERVER_BUS, 0x1446ceca0
.set BUS_SEND, 0x1403e7c60
.set REQUEST_TRANSITION, 0x140edeae0
.set PLAYER_CONTROLLABLE, 0x14039aca0
.set HEALTH_RATIO, 0x128
set_health:
    push rbx
    sub rsp, 0x30
    mov rbx, rcx
    xorps xmm0, xmm0
    maxss xmm1, xmm0
    minss xmm1, dword ptr [rbx + 0x24]
    movss dword ptr [rbx + 0x20], xmm1
    mov rcx, rbx
    call store_ratio
    mov rcx, rbx
    mov edx, 3
    call replicate
    mov rcx, rbx
    call publish_current
    add rsp, 0x30
    pop rbx
    ret

publish_current:
    movabs rax, SIMPLE_HEALTH_TABLE
    cmp qword ptr [rcx], rax
    jne 2f
    push rbx
    sub rsp, 0x30
    movss xmm1, dword ptr [rcx + 0x20]
    movss dword ptr [rsp + 0x28], xmm1
    mov rcx, qword ptr [rcx + 0x38]
    test rcx, rcx
    je 1f
    test cl, 7
    jne 1f
    mov rax, qword ptr [rcx]
    test rax, rax
    je 3f
    movss xmm0, dword ptr [rax]
    ucomiss xmm0, xmm1
    jp 3f
    je 1f
3:
    lea rdx, [rsp + 0x28]
    movabs rax, PUBLISH
    call rax
1:
    add rsp, 0x30
    pop rbx
2:
    ret

.org 0x100, 0xcc
evaluator:
    movabs rax, STATE
    cmp byte ptr [rax], 1
    jne original
    cmp rcx, qword ptr [rax + 8]
    jne original
    mov byte ptr [rax], 2
    push rcx
    push rdx
    push r8
    push r9
    push rbx
    push rsi
    sub rsp, 0x28
    lea rsi, [rax + 0x10]
    mov ebx, 4
next:
    mov rcx, qword ptr [rsi]
    test rcx, rcx
    je skip
    movss xmm1, dword ptr [rsi + 8]
    call set_health
skip:
    add rsi, 0x10
    dec ebx
    jne next
    add rsp, 0x28
    pop rsi
    pop rbx
    pop r9
    pop r8
    pop rdx
    pop rcx
original:
    movabs rax, ORIGINAL_EVALUATOR
    jmp rax

.org 0x1f0, 0xcc
replicate:
    movabs rax, HEALTH_NETWORK_TABLE
    cmp qword ptr [rcx + 0x1e8], rax
    jne 1f
    add rcx, 0x1e8
    movabs rax, MARK_DIRTY
    jmp rax
1:
    ret

.org 0x220, 0xcc
settings_update:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x30
    mov rbx, rcx
    movabs rax, ORIGINAL_SETTINGS_EVALUATE
    call rax
    mov qword ptr [rsp + 0x20], rax
    lea rsi, [rbx + 0xa0 + 0x10]
    mov edi, SETTINGS_ENTRIES
entry:
    mov rcx, qword ptr [rsi]
    call heap
    test al, al
    je entry_next
    cmp dword ptr [rcx + 0x18], DYLAN_MAX_HEALTH
    jne entry_next
    mov rdx, qword ptr [rcx]
    mov rcx, qword ptr [rcx + 0x10]
    call heap
    test al, al
    je entry_next
    mov rax, qword ptr [rcx]
    movabs r8, SIMPLE_HEALTH_TABLE
    cmp rax, r8
    je entry_target
    movabs r8, PLAYER_HEALTH_TABLE
    cmp rax, r8
    jne entry_next
entry_target:
    test rdx, rdx
    je entry_next
    test dl, 3
    jne entry_next
    movss xmm1, dword ptr [rdx]
    call apply_max
entry_next:
    add rsi, 0x18
    dec edi
    jne entry
    mov rax, qword ptr [rsp + 0x20]
    add rsp, 0x30
    pop rdi
    pop rsi
    pop rbx
    ret

apply_max:
    xorps xmm0, xmm0
    comiss xmm1, xmm0
    jbe 1f
    movss xmm2, dword ptr [rcx + 0x24]
    ucomiss xmm1, xmm2
    jp 2f
    je 1f
2:
    movss xmm3, dword ptr [rcx + 0x20]
    comiss xmm2, xmm0
    jbe 3f
    divss xmm3, xmm2
    mov eax, 0x3f800000
    movd xmm0, eax
    minss xmm3, xmm0
    jmp 4f
3:
    mov eax, 0x3f800000
    movd xmm3, eax
4:
    movss dword ptr [rcx + 0x24], xmm1
    mulss xmm3, xmm1
    movss dword ptr [rcx + 0x20], xmm3
    push rbx
    sub rsp, 0x20
    mov rbx, rcx
    call store_ratio
    mov rcx, rbx
    mov edx, 3
    call replicate
    mov rcx, rbx
    call publish_current
    add rsp, 0x20
    pop rbx
1:
    ret


heap:
    xor eax, eax
    test cl, 7
    jne 1f
    cmp rcx, 0x10000
    jb 1f
    movabs r8, 0x7ff000000000
    cmp rcx, r8
    jae 1f
    mov al, 1
1:
    ret

store_ratio:
    movss xmm0, dword ptr [rcx + 0x24]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    jbe 1f
    movss xmm2, dword ptr [rcx + 0x20]
    divss xmm2, xmm0
    mov eax, 0x3f800000
    movd xmm0, eax
    minss xmm2, xmm0
    xorps xmm0, xmm0
    maxss xmm2, xmm0
1:
    movss dword ptr [rcx + HEALTH_RATIO], xmm2
    ret

.org 0x380, 0xcc
player_update:
    jmp player_update_body

revive_player:
    push rbx
    sub rsp, 0x20
    mov rbx, rcx
    and byte ptr [rbx + 0x158], 0xfc
    mov edx, 8
    call replicate
    mov rcx, rbx
    movss xmm1, dword ptr [rbx + 0x24]
    call set_health
    mov rcx, rbx
    call send_revive
    add rsp, 0x20
    pop rbx
    ret

send_revive:
    push rbx
    push rdi
    push rsi
    sub rsp, 0x60
    mov rax, qword ptr [rcx + 8]
    mov rsi, qword ptr [rax]
    lea rdi, [rsp + 0x20]
    xor eax, eax
    mov ecx, 8
    rep stosq
    movabs rax, REVIVE_MESSAGE_TABLE
    mov qword ptr [rsp + 0x20], rax
    mov dword ptr [rsp + 0x28], 0xb7d01296
    mov dword ptr [rsp + 0x2c], 0x2f592866
    mov dword ptr [rsp + 0x30], 0xff
    lea rax, [rsi + 0x610]
    mov qword ptr [rsp + 0x50], rax
    mov rax, qword ptr [rsi + 0x58]
    lea rbx, [rax + 0x10]
    movzx edi, byte ptr [rax + 8]
    shl rdi, 5
    add rdi, rbx
3:
    cmp rbx, rdi
    jae 5f
    test dword ptr [rbx + 4], 0x800
    je 4f
    mov rcx, qword ptr [rbx + 0x10]
    mov rax, qword ptr [rcx]
    lea rdx, [rsp + 0x20]
    call qword ptr [rax + 0xa0]
4:
    add rbx, 0x20
    jmp 3b
5:
    movabs rax, SERVER_BUS
    mov rax, qword ptr [rax]
    test rax, rax
    je 6f
    mov rcx, qword ptr [rax + 0x20]
    test rcx, rcx
    je 6f
    lea rdx, [rsp + 0x20]
    movabs rax, BUS_SEND
    call rax
6:
    add rsp, 0x60
    pop rsi
    pop rdi
    pop rbx
    ret

.org 0x500, 0xcc
respawn_call:
    sub rsp, 0x28
    movabs rax, DOWNED_FRAMES
    inc dword ptr [rax + 0x10]
    movabs rax, REQUEST_TRANSITION
    call rax
    mov rcx, qword ptr [r15 + 0x220]
    movabs rax, PLAYER_CONTROLLABLE
    call rax
    test rax, rax
    je 3f
    mov rax, qword ptr [rax + 0x58]
    test rax, rax
    je 3f
    lea rdx, [rax + 0x10]
    movzx ecx, byte ptr [rax + 8]
    shl rcx, 5
    add rcx, rdx
    movabs r9, PLAYER_HEALTH_TABLE
1:
    cmp rdx, rcx
    jae 3f
    mov r8, qword ptr [rdx + 0x10]
    test r8, r8
    je 2f
    cmp qword ptr [r8], r9
    jne 2f
    mov al, byte ptr [r8 + 0x158]
    and al, 3
    cmp al, 1
    jne 3f
    mov rcx, r8
    call revive_player
    jmp 3f
2:
    add rdx, 0x20
    jmp 1b
3:
    add rsp, 0x28
    ret

.org 0x5a0, 0xcc
party_revive_call:
    sub rsp, 0x28
    movabs rax, BUS_SEND
    call rax
    movabs rax, DOWNED_FRAMES
    inc dword ptr [rax + 0x14]
    add rsp, 0x28
    ret

.org 0x600, 0xcc
player_update_body:
    movabs rax, PLAYER_HEALTH_TABLE
    cmp qword ptr [rcx], rax
    jne 9f
    push rbx
    push rsi
    sub rsp, 0x28
    mov rbx, rcx
    call player_entry
    mov rsi, rax
    movabs r8, DOWNED_FRAMES
    cmp byte ptr [r8 + 4], 0
    jne 4f
    mov eax, dword ptr [r8 + 0x14]
    cmp eax, dword ptr [rsi + 0xc]
    je 1f
    mov dword ptr [rsi + 0xc], eax
    mov al, byte ptr [rbx + 0x158]
    and al, 3
    cmp al, 1
    je 4f
1:
    cmp byte ptr [r8 + 5], 0
    je 2f
    mov al, byte ptr [rbx + 0x158]
    and al, 3
    cmp al, 1
    je 3f
2:
    mov dword ptr [rsi + 8], 0
    jmp 5f
3:
    inc dword ptr [rsi + 8]
    cmp dword ptr [rsi + 8], REVIVE_FRAMES
    jb 5f
4:
    mov dword ptr [rsi + 8], 0
    mov byte ptr [r8 + 4], 0
    mov rcx, rbx
    call revive_player
5:
    add rsp, 0x28
    pop rsi
    pop rbx
9:
    ret

player_entry:
    movabs r9, PLAYER_STAMP
    inc qword ptr [r9]
    mov r11, qword ptr [r9]
    movabs r8, PLAYER_TABLE
    xor eax, eax
    mov edx, PLAYER_ENTRIES
1:
    cmp qword ptr [r8], rcx
    je 4f
    test rax, rax
    je 2f
    mov r9, qword ptr [r8 + 0x10]
    cmp r9, qword ptr [rax + 0x10]
    jae 3f
2:
    mov rax, r8
3:
    add r8, PLAYER_ENTRY_SIZE
    dec edx
    jne 1b
    mov qword ptr [rax], rcx
    mov qword ptr [rax + 8], 0
    jmp 5f
4:
    mov rax, r8
5:
    mov qword ptr [rax + 0x10], r11
    ret
