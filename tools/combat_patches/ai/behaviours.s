.intel_syntax noprefix
.code64
.set PROVIDER, 0x153737500
.set ENTITY, 0x153737540
.set EMPTY_ARRAY, 0x153737578
.set MOVE_TO_POINT_TABLE, 0x143acfbd8
.set MOVE_TO_POINT_TYPE, 0x1451fd510
.set MOVE_TO_TARGET_TYPE, 0x1451fd580
.set SUBSTITUTE_HEAD, 0x153737070
.set SUBSTITUTE_MAGIC, 0x4e4f4954554d4f43
factory:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x40
    mov rsi, rcx
    mov rdi, rdx
    mov rcx, qword ptr [rsi + 8]
    test rcx, rcx
    je factory_fail
    call find_or_make
    test rax, rax
    je factory_fail
    mov rcx, qword ptr [rsi]
    mov qword ptr [rsp + 0x20], rcx
    mov qword ptr [rsp + 0x28], rax
    mov rcx, qword ptr [rsi + 0x10]
    mov qword ptr [rsp + 0x30], rcx
    lea rcx, [rsp + 0x20]
    mov rdx, rdi
    movabs rax, 0x140dc4be0
    call rax
    jmp factory_out
factory_fail:
    mov dword ptr [rdi], 0
    xor eax, eax
factory_out:
    add rsp, 0x40
    pop rdi
    pop rsi
    pop rbx
    ret

compare_hook:
    mov rcx, qword ptr [rax + 0x10]
    cmp rcx, rbx
    je compare_same
    movabs rdx, SUBSTITUTE_MAGIC
    cmp qword ptr [rcx + 0x80], rdx
    jne compare_different
compare_ours:
    mov rax, qword ptr [rbx + 0x10]
    cmp qword ptr [rcx + 0x70], rax
    jne compare_different
    mov eax, dword ptr [rbx + 0x30]
    cmp dword ptr [rcx + 0x7c], eax
    jne compare_different
    mov eax, dword ptr [rbx + 0x50]
    cmp dword ptr [rcx + 0x50], eax
    jne compare_different
    push rcx
    mov rcx, rbx
    call range_of
    pop rcx
    ucomiss xmm0, dword ptr [rcx + 0x78]
    jp compare_different
    jne compare_different
compare_same:
    jmp qword ptr [rip + same_target]
compare_different:
    jmp qword ptr [rip + different_target]

range_of:
    mov rax, qword ptr [rcx + 0x10]
    lea rdx, [rip + types]
range_loop:
    cmp qword ptr [rdx], 0
    je range_unknown
    cmp qword ptr [rdx], rax
    je range_hit
    add rdx, 16
    jmp range_loop
range_hit:
    mov eax, dword ptr [rdx + 8]
    test eax, eax
    je range_default
    movss xmm0, dword ptr [rcx + rax]
    movabs r8, MOVE_TO_TARGET_TYPE
    cmp qword ptr [rdx], r8
    je range_raw
    comiss xmm0, dword ptr [rip + minimum_range]
    jb range_default
    comiss xmm0, dword ptr [rip + maximum_range]
    ja range_default
    ret
range_default:
    movss xmm0, dword ptr [rdx + 12]
    ret
range_unknown:
    movss xmm0, dword ptr [rip + fallback_range]
    ret
range_raw:
    xorps xmm1, xmm1
    maxss xmm0, xmm1
    minss xmm0, dword ptr [rip + maximum_range]
    ret

find_or_make:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x30
    mov rbx, rcx
    call range_of
    movss dword ptr [rsp + 0x28], xmm0
    movabs rsi, SUBSTITUTE_HEAD
    mov rax, qword ptr [rsi]
find_scan:
    test rax, rax
    je find_make
    mov rdx, qword ptr [rbx + 0x10]
    cmp qword ptr [rax + 0x70], rdx
    jne find_next
    movss xmm2, dword ptr [rsp + 0x28]
    ucomiss xmm2, dword ptr [rax + 0x78]
    jp find_next
    jne find_next
    mov edx, dword ptr [rbx + 0x30]
    cmp dword ptr [rax + 0x7c], edx
    jne find_next
    mov edx, dword ptr [rbx + 0x50]
    cmp dword ptr [rax + 0x50], edx
    je find_done
find_next:
    mov rax, qword ptr [rax + 0x88]
    jmp find_scan
find_make:
    movabs rcx, 0x1446b4110
    mov rcx, qword ptr [rcx]
    test rcx, rcx
    je find_fail
    mov edx, 0x90
    mov r8d, 0x10
    xor r9d, r9d
    movabs rax, 0x1403bb060
    call rax
    test rax, rax
    je find_fail
    movss xmm2, dword ptr [rsp + 0x28]
    movabs rcx, MOVE_TO_POINT_TABLE
    mov qword ptr [rax], rcx
    mov qword ptr [rax + 8], 0
    mov qword ptr [rax + 0x10], 0
    mov rcx, qword ptr [rbx + 0x18]
    mov qword ptr [rax + 0x18], rcx
    mov rcx, qword ptr [rbx + 0x20]
    mov qword ptr [rax + 0x20], rcx
    mov rcx, qword ptr [rbx + 0x28]
    mov qword ptr [rax + 0x28], rcx
    mov ecx, dword ptr [rbx + 0x30]
    mov qword ptr [rax + 0x30], rcx
    movabs rcx, EMPTY_ARRAY
    mov qword ptr [rax + 0x38], rcx
    mov qword ptr [rax + 0x40], rcx
    movabs rcx, ENTITY
    mov qword ptr [rax + 0x48], rcx
    mov ecx, dword ptr [rbx + 0x50]
    mov qword ptr [rax + 0x50], rcx
    movabs rcx, PROVIDER
    mov qword ptr [rax + 0x58], rcx
    mov ecx, dword ptr [rip + stop_threshold]
    mov dword ptr [rax + 0x60], ecx
    mov ecx, dword ptr [rip + update_period]
    mov dword ptr [rax + 0x64], ecx
    mov dword ptr [rax + 0x68], 1
    movss dword ptr [rax + 0x6c], xmm2
    mov rcx, qword ptr [rbx + 0x10]
    mov qword ptr [rax + 0x70], rcx
    movss dword ptr [rax + 0x78], xmm2
    mov ecx, dword ptr [rbx + 0x30]
    mov dword ptr [rax + 0x7c], ecx
    movabs rcx, SUBSTITUTE_MAGIC
    mov qword ptr [rax + 0x80], rcx
    movabs rcx, MOVE_TO_POINT_TYPE
    mov qword ptr [rax + 0x10], rcx
    mov rcx, qword ptr [rsi]
    mov qword ptr [rax + 0x88], rcx
    movabs rcx, MOVE_TO_TARGET_TYPE
    cmp qword ptr [rbx + 0x10], rcx
    jne find_link
    mov dword ptr [rax + 0x6c], 0
    movss dword ptr [rax + 0x60], xmm2
    movss xmm0, dword ptr [rbx + 0x5c]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja find_chase_period
    movss xmm0, dword ptr [rip + chase_period]
find_chase_period:
    movss dword ptr [rax + 0x64], xmm0
    mov byte ptr [rax + 0x69], 1
find_link:
    mov qword ptr [rsi], rax
    jmp find_done
find_fail:
    xor eax, eax
find_done:
    add rsp, 0x30
    pop rdi
    pop rsi
    pop rbx
    ret

reserve:
    .fill 14, 1, 0xcc

spread_evaluate:
    push rbx
    push rsi
    push rdi
    push r12
    sub rsp, 0x28
    mov rbx, rdx
    mov rsi, r8
    mov rdi, rcx
    movabs rax, 0x1407d9830
    call rax
    test al, al
    je spread_finish
    mov rdx, rsi
    call context_entity
    test rax, rax
    je spread_success
    mov r12, rax
    mov rcx, rax
    call entity_radius
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    jbe spread_success
    movaps xmm2, xmm0
    mov rcx, r12
    shr rcx, 4
    imul ecx, ecx, 0x9e3779b1
    mov edx, ecx
    shr ecx, 28
    movabs rax, 0x1446e5490
    mov rax, qword ptr [rax]
    test rax, rax
    je spread_no_time
    mov rax, qword ptr [rax + 0x18]
    test rax, rax
    je spread_no_time
    movsd xmm1, qword ptr [rax + 0x10]
    divsd xmm1, qword ptr [rip + slot_seconds]
    cvttsd2si rax, xmm1
    add ecx, eax
spread_no_time:
    and ecx, 15
    lea r8, [rip + directions]
    movss xmm0, dword ptr [r8 + rcx * 8]
    movss xmm1, dword ptr [r8 + rcx * 8 + 4]
    shr edx, 24
    and edx, 3
    cvtsi2ss xmm3, edx
    mulss xmm3, dword ptr [rip + jitter]
    addss xmm2, xmm3
    mulss xmm0, xmm2
    mulss xmm1, xmm2
    addss xmm0, dword ptr [rbx + 0x30]
    movss dword ptr [rbx + 0x30], xmm0
    addss xmm1, dword ptr [rbx + 0x38]
    movss dword ptr [rbx + 0x38], xmm1
spread_success:
    mov al, 1
spread_finish:
    add rsp, 0x28
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

entity_radius:
    xorps xmm0, xmm0
    mov rax, qword ptr [rcx + 0x58]
    test rax, rax
    je radius_done
    movzx edx, byte ptr [rax + 8]
    lea rax, [rax + 0x10]
    movabs r8, 0x143acd3d0
radius_find:
    test edx, edx
    je radius_done
    mov r9, qword ptr [rax + 0x10]
    test r9, r9
    je radius_next
    cmp qword ptr [r9], r8
    je radius_ai
radius_next:
    add rax, 0x20
    dec edx
    jmp radius_find
radius_ai:
    mov r9, qword ptr [r9 + 0x30]
    test r9, r9
    je radius_done
    mov r9, qword ptr [r9 + 0x10]
    test r9, r9
    je radius_done
    movabs r8, MOVE_TO_POINT_TYPE
    cmp qword ptr [r9 + 0x10], r8
    jne radius_done
    movss xmm0, dword ptr [r9 + 0x6c]
radius_done:
    ret

context_entity:
    sub rsp, 0x28
    mov rax, qword ptr [rdx]
    mov rcx, rdx
    call qword ptr [rax + 0x10]
    test rax, rax
    je context_none
    mov rcx, rax
    movabs rax, 0x1403992f0
    call rax
    test rax, rax
    je context_none
    movabs rcx, 0x143a75900
    cmp qword ptr [rax], rcx
    je context_done
context_none:
    xor eax, eax
context_done:
    add rsp, 0x28
    ret

.balign 8
same_target:
    .quad 0x146d4a98d
different_target:
    .quad 0x146d4a8d4
slot_seconds:
    .double 8.0
jitter:
    .float 1.5
stop_threshold:
    .float 3.0
update_period:
    .float 2.0
minimum_range:
    .float 1.0
maximum_range:
    .float 100.0
fallback_range:
    .float 15.0
chase_period:
    .float 0.33
.balign 8
types:
    .quad 0x1451fd350
    .long 0x58
    .float 15.0
    .quad 0x1451fcfd0
    .long 0x58
    .float 15.0
    .quad 0x1451fd3c0
    .long 0x5c
    .float 15.0
    .quad 0x145280fd0
    .long 0x70
    .float 15.0
    .quad 0x145280ef0
    .long 0
    .float 15.0
    .quad 0x1451fd580
    .long 0x58
    .float 15.0
    .quad 0x145281190
    .long 0
    .float 30.0
    .quad 0, 0
directions:
    .float 1.000000, 0.000000
    .float 0.923880, 0.382683
    .float 0.707107, 0.707107
    .float 0.382683, 0.923880
    .float 0.000000, 1.000000
    .float -0.382683, 0.923880
    .float -0.707107, 0.707107
    .float -0.923880, 0.382683
    .float -1.000000, 0.000000
    .float -0.923880, -0.382683
    .float -0.707107, -0.707107
    .float -0.382683, -0.923880
    .float -0.000000, -1.000000
    .float 0.382683, -0.923880
    .float 0.707107, -0.707107
    .float 0.923880, -0.382683
.balign 16
provider_table:
    .quad 0x1403737d0, 0x1407f2ea0, 0x140390e40, 0
entity_table:
    .quad 0x1403737d0, 0x140372010, 0x140390e70, 0

entity_evaluate:
    push rbx
    sub rsp, 0x20
    call context_entity
    mov rbx, rax
    test rax, rax
    je entity_player
    movabs rax, 0x153737608
    mov rax, qword ptr [rax]
    test rax, rax
    je entity_player
    mov rcx, rbx
    call rax
    test rax, rax
    jne entity_done
entity_player:
    mov rcx, rbx
    movabs rax, 0x142b38010
    call rax
entity_done:
    add rsp, 0x20
    pop rbx
    ret

.balign 16
detach_nodes:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    movabs rax, 0x144326b38
    mov r8, qword ptr [rax]
    mov r9d, dword ptr [rax + 8]
    test r8, r8
    je detach_done
    movabs r11, 0x153737580
detach_bucket:
    test r9d, r9d
    je detach_done
    dec r9d
    lea rcx, [r8 + r9 * 8]
    mov edx, 4096
detach_walk:
    mov rax, qword ptr [rcx]
    test rax, rax
    je detach_bucket
    dec edx
    je detach_bucket
    mov r10, rax
    sub r10, r11
    cmp r10, 0x48
    jae detach_next
    mov r10, qword ptr [rax + 0x10]
    mov qword ptr [rcx], r10
    jmp detach_walk
detach_next:
    lea rcx, [rax + 0x10]
    jmp detach_walk
detach_done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    jmp qword ptr [rip + clear_table]
clear_table:
    .quad 0x146d56800
