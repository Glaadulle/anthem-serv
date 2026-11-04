.intel_syntax noprefix
.code64
.set PLAYER_BONUS, 0x1537377e8
.set WEAPON_COUNTERS, 0x1537377d0
.set AI_SHOT, 1
.set SECTION_IMPACT, 2
.set SERVER_CHARACTER, 0x143a75900
.set GEAR_COMPONENT, 0x143a876c0
.set ACTION_GEAR, 0x143a5bf40
.set ENTITY_BUS, 0x143bb1148
.set DAMAGE_IMPACT_PHYSICAL, 0x4d6f4827
.set FLOAT_TYPE, 0x9c76c920
start:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    sub rsp, 0x90
    mov qword ptr [rsp + 0x48], rcx
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
    cmp qword ptr [rsp + 0x48], AI_SHOT
    je bonus_done
    movabs rax, PLAYER_BONUS
    movss xmm0, dword ptr [rax]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    jbe bonus_done
    mulss xmm1, xmm0
bonus_done:
    movss dword ptr [rsp + 0x24], xmm1
    cmp qword ptr [rsp + 0x48], AI_SHOT
    je impact_amount
    cmp qword ptr [rsp + 0x48], SECTION_IMPACT
    je impact_amount
    movss xmm0, dword ptr [rsi + 0xa0]
    comiss xmm0, dword ptr [rip + projectile_threshold]
    jb impact_amount
    call weapon_damage
    movabs rcx, WEAPON_COUNTERS
    test al, al
    je weapon_fallback
    lock inc dword ptr [rcx]
    movss dword ptr [rcx + 8], xmm0
    movaps xmm1, xmm0
    jmp impact_amount
weapon_fallback:
    lock inc dword ptr [rcx + 4]
    movss xmm1, dword ptr [rsp + 0x24]
impact_amount:
    mov qword ptr [rsp + 0x38], rbx
    lea rax, [rsp + 0x38]
    mov qword ptr [rsp + 0x30], rax
    lea rcx, [rsp + 0x28]
    movabs rax, 0x140c86ef0
    call rax
placeable:
    mov rdi, qword ptr [rbx + 0x58]
    movzx r13d, byte ptr [rdi + 8]
    lea r12, [rdi + 0x10]
placeable_find:
    test r13d, r13d
    je done
    mov rdi, qword ptr [r12 + 0x10]
    call heap
    test al, al
    je placeable_next
    movabs rax, 0x143a740a0
    cmp qword ptr [rdi], rax
    jne placeable_next
    mov rax, qword ptr [rdi + 8]
    cmp rax, qword ptr [rbx + 0x58]
    je placeable_found
placeable_next:
    add r12, 0x20
    dec r13d
    jmp placeable_find
placeable_found:
    mov r12, rdi
    mov rdi, qword ptr [r12 + 0x10]
    call heap
    test al, al
    je done
    cmp byte ptr [rdi + 0xe2], 0
    jne done
    test byte ptr [r12 + 0x100], 3
    jne done
    movss xmm0, dword ptr [r12 + 0x24]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    ja placeable_ready
    mov eax, 0x3f800000
    mov dword ptr [r12 + 0x24], eax
    mov dword ptr [r12 + 0x20], eax
placeable_ready:
    movss xmm3, dword ptr [rdi + 0xa0]
    xorps xmm2, xmm2
    comiss xmm3, xmm2
    ja placeable_scale
    mov eax, 0x42c80000
    movd xmm3, eax
placeable_scale:
    movss xmm1, dword ptr [rsp + 0x24]
    divss xmm1, xmm3
    movss xmm0, dword ptr [r12 + 0x20]
    subss xmm0, xmm1
    xorps xmm2, xmm2
    maxss xmm0, xmm2
    movss dword ptr [r12 + 0x20], xmm0
    mov ecx, 1
    movabs rdx, 0x153737f80
    lock xadd dword ptr [rdx], ecx
    and ecx, 7
    mov qword ptr [rdx + rcx*8 + 0x10], r12
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    ja done
    mov dword ptr [r12 + 0x100], 2
    lea rcx, [rbx + 0x170]
    xor edx, edx
    movabs rax, 0x140959e00
    call rax
    mov rcx, qword ptr [rbx + 0x28]
    mov rdx, qword ptr [r12 + 0x10]
    mov r8d, 0xa96f26e7
    movabs rax, 0x141b465b0
    call rax
    mov rdi, qword ptr [r12 + 0x1f0]
    call heap
    test al, al
    je done
    mov byte ptr [rsp + 0x20], 1
    mov rcx, rdi
    lea rdx, [rsp + 0x20]
    movabs rax, 0x1403fa290
    call rax
    jmp done
done:
    add rsp, 0x90
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret
weapon_damage:
    mov rcx, qword ptr [rsi + 0x40]
    call heap_rcx
    je weapon_fail
    mov rcx, qword ptr [rcx]
    call heap_rcx
    je weapon_fail
    sub rcx, 8
    movabs rax, SERVER_CHARACTER
    cmp qword ptr [rcx], rax
    jne weapon_fail
    cmp qword ptr [rcx + 0x2b8], 0
    je weapon_fail
    mov rcx, qword ptr [rcx + 0x58]
    call heap_rcx
    je weapon_fail
    movzx r9d, byte ptr [rcx + 8]
    lea r8, [rcx + 0x10]
gear_find:
    test r9d, r9d
    je weapon_fail
    mov rcx, qword ptr [r8 + 0x10]
    call heap_rcx
    je gear_next
    movabs rax, GEAR_COMPONENT
    cmp qword ptr [rcx], rax
    je gear_found
gear_next:
    add r8, 0x20
    dec r9d
    jmp gear_find
gear_found:
    mov r10d, dword ptr [rcx + 0x774]
    mov r8, qword ptr [rcx + 0x38]
    mov r9, qword ptr [rcx + 0x40]
    mov rcx, r8
    call heap_rcx
    je weapon_fail
    mov r11d, 64
slot_find:
    cmp r8, r9
    jae weapon_fail
    dec r11d
    js weapon_fail
    cmp dword ptr [r8], r10d
    je slot_found
    add r8, 0x88
    jmp slot_find
slot_found:
    mov rcx, qword ptr [r8 + 0x20]
    call heap_rcx
    je weapon_fail
    movabs rax, ACTION_GEAR
    cmp qword ptr [rcx], rax
    jne weapon_fail
    mov rcx, qword ptr [rcx + 0x28]
    call heap_rcx
    je weapon_fail
    movabs rax, ENTITY_BUS
    cmp qword ptr [rcx], rax
    jne weapon_fail
    mov r8, qword ptr [rcx + 0x30]
    mov r9d, 32
part:
    mov rcx, r8
    call heap_rcx
    je weapon_fail
    dec r9d
    js weapon_fail
    mov r10, qword ptr [r8 + 0x70]
    mov rcx, r10
    call heap_rcx
    je part_next
    mov rcx, qword ptr [r10 + 0x10]
    mov r11d, 8
class:
    call heap_rcx
    je part_next
    mov rcx, qword ptr [rcx]
    call heap_rcx
    je part_next
    mov rdi, rcx
    movzx r12d, word ptr [rdi + 0x2a]
    cmp r12d, 256
    jbe 4f
    mov r12d, 256
4:
    test r12d, r12d
    je class_parent
    mov rcx, qword ptr [rdi + 0x38]
    call heap_rcx
    je class_parent
    mov r13, rcx
field:
    cmp dword ptr [r13], DAMAGE_IMPACT_PHYSICAL
    jne field_next
    mov rcx, qword ptr [r13 + 8]
    call heap_rcx
    je field_next
    mov rcx, qword ptr [rcx]
    call heap_rcx
    je field_next
    cmp dword ptr [rcx], FLOAT_TYPE
    jne field_next
    movzx eax, word ptr [r13 + 6]
    movss xmm0, dword ptr [r10 + rax]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    jbe weapon_fail
    mov eax, 0x47c35000
    movd xmm2, eax
    comiss xmm0, xmm2
    jae weapon_fail
    mov eax, 1
    ret
field_next:
    add r13, 16
    dec r12d
    jne field
class_parent:
    mov rcx, qword ptr [rdi + 0x30]
    dec r11d
    jne class
part_next:
    mov r8, qword ptr [r8 + 0x28]
    jmp part
weapon_fail:
    xor eax, eax
    ret
heap_rcx:
    test cl, 7
    jne 3f
    cmp rcx, 0x10000
    jb 3f
    movabs rax, 0x7ff000000000
    cmp rcx, rax
    jae 3f
    mov eax, 1
    test eax, eax
    ret
3:
    xor eax, eax
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
projectile_threshold:
    .float 100.0
