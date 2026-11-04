.intel_syntax noprefix
.code64
.set CODE_BASE, 0x142b34000
.set LOS_HEAD, 0x153737678
.set COUNTERS, 0x153737680
.set C_EVALUATIONS, 0
.set C_SEARCHES, 4
.set C_DEFERRED, 8
.set C_RAYS, 0xc
.set C_FOUND, 0x10
.set C_FALLBACK, 0x14
.set C_STAY, 0x18
.set C_CYCLES, 0x20
.set C_MAX_CYCLES, 0x28
.set C_TSC, 0x30
.set C_CLOCK, 0x38
.set ENTITY, 0x153737540
.set EMPTY_ARRAY, 0x153737578
.set MOVE_TO_POINT_TABLE, 0x143acfbd8
.set MOVE_TO_POINT_TYPE, 0x1451fd510
.set TRANSFORM_ENTITY_TYPE, 0x1452972a0
.set MOVE_TO_LOS_TYPE, 0x145280fd0
.set MOVE_FROM_LOS_TYPE, 0x145280ef0
.set FLEE_TYPE, 0x145281190
.set BOOL_TRUE_TYPE, 0x14529b280
.set LOCATION_PATTERN_TYPE, 0x1452810b0
.set SERVER_CHARACTER, 0x143a75900
.set SUBSTITUTE_MAGIC, 0x4e4f4954554d4f43
.set PROVIDER_OFFSET, 0xa0
.set P_KIND, 0xe0
.set P_COUNT, 0xe4
.set P_HASH, 0xe8
.set P_RANGE, 0xec
.set P_SAFE, 0xf0
.set P_FORCE, 0xf4
.set P_DEFAULT, 0xf5
.set ENTRIES, 0x100
.set MAX_POINTS, 192
.set RAY_BUDGET, 32
.set FNV_BASIS, 0x811c9dc5
.set FNV_PRIME, 0x01000193
.set L_A, 0x40
.set L_T, 0x50
.set L_F, 0x60
.set L_P, 0x70
.set L_RESULT, 0x80
.set L_TSC, 0xe0
.set L_LENGTH, 0xe8

.macro mix reg
    xor eax, \reg
    imul eax, eax, FNV_PRIME
.endm

entries:
    jmp los_factory
.balign 8
    jmp los_evaluate
.balign 8

los_factory:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x40
    mov rsi, rcx
    mov rdi, rdx
    mov rbx, qword ptr [rsi + 8]
    test rbx, rbx
    je factory_fail
    mov rax, qword ptr [rbx + 0x10]
    xor r12d, r12d
    movabs rcx, MOVE_TO_LOS_TYPE
    cmp rax, rcx
    je factory_kind
    mov r12d, 1
    movabs rcx, MOVE_FROM_LOS_TYPE
    cmp rax, rcx
    je factory_kind
    mov r12d, 2
    movabs rcx, FLEE_TYPE
    cmp rax, rcx
    jne factory_fail
factory_kind:
    movss xmm0, dword ptr [rip + fifteen]
    test r12d, r12d
    jne factory_range_other
    movss xmm1, dword ptr [rbx + 0x70]
    comiss xmm1, dword ptr [rip + one]
    jb factory_range_store
    comiss xmm1, dword ptr [rip + hundred]
    ja factory_range_store
    movaps xmm0, xmm1
    jmp factory_range_store
factory_range_other:
    cmp r12d, 2
    jne factory_range_store
    movss xmm0, dword ptr [rip + thirty]
factory_range_store:
    movss dword ptr [rsp + 0x3c], xmm0
    xor r13d, r13d
    cmp r12d, 2
    je factory_flee_hash
    mov rcx, rbx
    xor edx, edx
    call walk
    mov r13d, edx
    jmp factory_hashed
factory_flee_hash:
    mov eax, FNV_BASIS
    mov edx, dword ptr [rbx + 0x5c]
    mix edx
factory_hashed:
    mov r14d, eax
    movabs rcx, LOS_HEAD
    mov rax, qword ptr [rcx]
factory_scan:
    test rax, rax
    je factory_make
    mov rdx, qword ptr [rbx + 0x10]
    cmp qword ptr [rax + 0x70], rdx
    jne factory_scan_next
    mov edx, dword ptr [rsp + 0x3c]
    cmp dword ptr [rax + 0x78], edx
    jne factory_scan_next
    mov edx, dword ptr [rbx + 0x30]
    cmp dword ptr [rax + 0x7c], edx
    jne factory_scan_next
    mov edx, dword ptr [rbx + 0x50]
    cmp dword ptr [rax + 0x50], edx
    jne factory_scan_next
    cmp dword ptr [rax + P_HASH], r14d
    je factory_native
factory_scan_next:
    mov rax, qword ptr [rax + 0x88]
    jmp factory_scan
factory_make:
    movabs rcx, 0x1446b4110
    mov rcx, qword ptr [rcx]
    test rcx, rcx
    je factory_fail
    mov edx, r13d
    shl edx, 4
    add edx, ENTRIES
    mov r8d, 0x10
    xor r9d, r9d
    movabs rax, 0x1403bb060
    call rax
    test rax, rax
    je factory_fail
    mov r15, rax
    movabs rcx, MOVE_TO_POINT_TABLE
    mov qword ptr [r15], rcx
    mov qword ptr [r15 + 8], 0
    mov qword ptr [r15 + 0x10], 0
    mov rcx, qword ptr [rbx + 0x18]
    mov qword ptr [r15 + 0x18], rcx
    mov rcx, qword ptr [rbx + 0x20]
    mov qword ptr [r15 + 0x20], rcx
    mov rcx, qword ptr [rbx + 0x28]
    mov qword ptr [r15 + 0x28], rcx
    mov ecx, dword ptr [rbx + 0x30]
    mov qword ptr [r15 + 0x30], rcx
    movabs rcx, EMPTY_ARRAY
    mov qword ptr [r15 + 0x38], rcx
    mov qword ptr [r15 + 0x40], rcx
    movabs rcx, ENTITY
    mov qword ptr [r15 + 0x48], rcx
    mov ecx, dword ptr [rbx + 0x50]
    mov qword ptr [r15 + 0x50], rcx
    lea rcx, [r15 + PROVIDER_OFFSET]
    mov qword ptr [r15 + 0x58], rcx
    mov ecx, dword ptr [rip + point_stop]
    cmp r12d, 2
    jne factory_stop
    mov ecx, dword ptr [rip + flee_stop]
factory_stop:
    mov dword ptr [r15 + 0x60], ecx
    mov ecx, dword ptr [rip + update_period]
    mov dword ptr [r15 + 0x64], ecx
    mov dword ptr [r15 + 0x68], 1
    mov ecx, dword ptr [rsp + 0x3c]
    mov dword ptr [r15 + 0x6c], ecx
    mov rdx, qword ptr [rbx + 0x10]
    mov qword ptr [r15 + 0x70], rdx
    mov dword ptr [r15 + 0x78], ecx
    mov edx, dword ptr [rbx + 0x30]
    mov dword ptr [r15 + 0x7c], edx
    movabs rdx, SUBSTITUTE_MAGIC
    mov qword ptr [r15 + 0x80], rdx
    mov qword ptr [r15 + 0x90], 0
    mov qword ptr [r15 + 0x98], 0
    movabs rdx, CODE_BASE + (provider_table - entries)
    mov qword ptr [r15 + PROVIDER_OFFSET], rdx
    mov qword ptr [r15 + PROVIDER_OFFSET + 8], 0
    movabs rdx, TRANSFORM_ENTITY_TYPE
    mov qword ptr [r15 + PROVIDER_OFFSET + 0x10], rdx
    mov qword ptr [r15 + PROVIDER_OFFSET + 0x18], 0
    mov qword ptr [r15 + PROVIDER_OFFSET + 0x20], 0
    movabs rdx, ENTITY
    mov qword ptr [r15 + PROVIDER_OFFSET + 0x28], rdx
    mov qword ptr [r15 + PROVIDER_OFFSET + 0x30], 0
    mov qword ptr [r15 + PROVIDER_OFFSET + 0x38], 0
    mov dword ptr [r15 + P_KIND], r12d
    mov dword ptr [r15 + P_COUNT], r13d
    mov dword ptr [r15 + P_HASH], r14d
    mov dword ptr [r15 + P_RANGE], ecx
    mov dword ptr [r15 + P_SAFE], 0
    mov dword ptr [r15 + P_FORCE], 0
    mov qword ptr [r15 + P_FORCE + 4], 0
    test r12d, r12d
    jne factory_flags_from
    mov al, byte ptr [rbx + 0x79]
    mov byte ptr [r15 + P_FORCE], al
    mov al, byte ptr [rbx + 0x7b]
    mov byte ptr [r15 + P_DEFAULT], al
    jmp factory_points
factory_flags_from:
    cmp r12d, 1
    jne factory_flags_flee
    mov al, byte ptr [rbx + 0x76]
    mov byte ptr [r15 + P_DEFAULT], al
    jmp factory_points
factory_flags_flee:
    mov eax, dword ptr [rbx + 0x5c]
    mov dword ptr [r15 + P_SAFE], eax
factory_points:
    test r13d, r13d
    je factory_link
    mov rcx, rbx
    lea rdx, [r15 + ENTRIES]
    call walk
factory_link:
    movabs rcx, MOVE_TO_POINT_TYPE
    mov qword ptr [r15 + 0x10], rcx
    movabs rcx, LOS_HEAD
    mov rdx, qword ptr [rcx]
    mov qword ptr [r15 + 0x88], rdx
    mov qword ptr [rcx], r15
    mov rax, r15
factory_native:
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
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

walk:
    push rbx
    push rsi
    push rdi
    mov r8, rdx
    mov eax, FNV_BASIS
    xor r9d, r9d
    mov r10, qword ptr [rcx + 0x58]
    test r10, r10
    je walk_done
    test r10b, 7
    jne walk_done
    mov r11d, dword ptr [r10 - 4]
    and r11d, 0x7fffffff
    cmp r11d, 64
    ja walk_done
walk_group:
    test r11d, r11d
    je walk_done
    mov rbx, qword ptr [r10]
    test rbx, rbx
    je walk_next_group
    test bl, 7
    jne walk_next_group
    movabs rsi, BOOL_TRUE_TYPE
    cmp qword ptr [rbx + 0x10], rsi
    jne walk_next_group
    mov rbx, qword ptr [r10 + 8]
    test rbx, rbx
    je walk_next_group
    test bl, 7
    jne walk_next_group
    movabs rsi, LOCATION_PATTERN_TYPE
    cmp qword ptr [rbx + 0x10], rsi
    jne walk_next_group
    mov rsi, qword ptr [rbx + 0x20]
    test rsi, rsi
    je walk_next_group
    test sil, 7
    jne walk_next_group
    mov edi, dword ptr [rsi - 4]
    and edi, 0x7fffffff
    cmp edi, 256
    ja walk_next_group
walk_point:
    test edi, edi
    je walk_next_group
    cmp r9d, MAX_POINTS
    jae walk_done
    mov edx, dword ptr [rsi]
    mix edx
    mov edx, dword ptr [rsi + 4]
    mix edx
    mov edx, dword ptr [rbx + 0x28]
    mix edx
    mov edx, dword ptr [rbx + 0x2c]
    mix edx
    test r8, r8
    je walk_counted
    mov edx, dword ptr [rsi]
    mov dword ptr [r8], edx
    mov edx, dword ptr [rsi + 4]
    mov dword ptr [r8 + 4], edx
    mov edx, dword ptr [rbx + 0x28]
    mov dword ptr [r8 + 8], edx
    mov edx, dword ptr [rbx + 0x2c]
    mov dword ptr [r8 + 0xc], edx
    add r8, 16
walk_counted:
    inc r9d
    add rsi, 8
    dec edi
    jmp walk_point
walk_next_group:
    add r10, 16
    dec r11d
    jmp walk_group
walk_done:
    mov edx, r9d
    pop rdi
    pop rsi
    pop rbx
    ret

los_evaluate:
    push rbx
    push rsi
    push rdi
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x108
    mov rdi, rcx
    mov rbx, rdx
    mov rsi, r8
    movabs rax, 0x1407d9830
    call rax
    test al, al
    je evaluate_out
    movabs r15, COUNTERS
    inc dword ptr [r15 + C_EVALUATIONS]
    lea rbp, [rdi - PROVIDER_OFFSET]
    mov rdx, rsi
    call context_entity
    test rax, rax
    je evaluate_success
    mov rcx, rax
    call translation
    test rax, rax
    je evaluate_success
    movups xmm0, xmmword ptr [rax]
    movups xmmword ptr [rsp + L_A], xmm0
    mov dword ptr [rsp + L_A + 0xc], 0
    movss xmm0, dword ptr [rbx + 0x30]
    movss dword ptr [rsp + L_T], xmm0
    movss xmm0, dword ptr [rbx + 0x34]
    movss dword ptr [rsp + L_T + 4], xmm0
    movss xmm0, dword ptr [rbx + 0x38]
    movss dword ptr [rsp + L_T + 8], xmm0
    mov dword ptr [rsp + L_T + 0xc], 0
    movss xmm0, dword ptr [rsp + L_T]
    subss xmm0, dword ptr [rsp + L_A]
    movss xmm1, dword ptr [rsp + L_T + 8]
    subss xmm1, dword ptr [rsp + L_A + 8]
    movaps xmm2, xmm0
    mulss xmm2, xmm2
    movaps xmm3, xmm1
    mulss xmm3, xmm3
    addss xmm2, xmm3
    sqrtss xmm2, xmm2
    movss dword ptr [rsp + L_LENGTH], xmm2
    comiss xmm2, dword ptr [rip + minimum_length]
    jae evaluate_normalize
    xorps xmm0, xmm0
    movss xmm1, dword ptr [rip + one]
    jmp evaluate_forward
evaluate_normalize:
    divss xmm0, xmm2
    divss xmm1, xmm2
evaluate_forward:
    movss dword ptr [rsp + L_F], xmm0
    movss dword ptr [rsp + L_F + 4], xmm1
    cmp dword ptr [rbp + P_KIND], 2
    je evaluate_flee
    movabs rax, 0x1446ceca0
    mov rax, qword ptr [rax]
    test rax, rax
    je evaluate_hold
    mov rax, qword ptr [rax + 0x18]
    test rax, rax
    je evaluate_hold
    mov rax, qword ptr [rax + 0x10]
    cmp rax, qword ptr [r15 + C_CLOCK]
    jne evaluate_search
    inc dword ptr [r15 + C_DEFERRED]
evaluate_hold:
    lea rax, [rsp + L_A]
    call write_goal
    jmp evaluate_success

evaluate_search:
    mov qword ptr [r15 + C_CLOCK], rax
    inc dword ptr [r15 + C_SEARCHES]
    rdtsc
    shl rdx, 32
    or rax, rdx
    mov qword ptr [rsp + L_TSC], rax
    mov qword ptr [r15 + C_TSC], rax
    mov r14d, RAY_BUDGET
    lea rcx, [rsp + L_A]
    lea rdx, [rsp + L_T]
    call self_visible
    dec r14d
    cmp dword ptr [rbp + P_KIND], 0
    je evaluate_self_to
    test al, al
    je evaluate_stay
    jmp evaluate_scan
evaluate_self_to:
    test al, al
    je evaluate_scan
    cmp byte ptr [rbp + P_FORCE], 0
    je evaluate_stay
evaluate_scan:
    xor r12d, r12d
evaluate_candidate:
    cmp r12d, dword ptr [rbp + P_COUNT]
    jae evaluate_fallback
    test r14d, r14d
    jle evaluate_fallback
    mov eax, r12d
    shl eax, 4
    lea r13, [rbp + rax + ENTRIES]
    inc r12d
    lea rax, [rsp + L_A]
    movss xmm4, dword ptr [rip + one]
    cmp dword ptr [r13 + 0xc], 0
    je evaluate_reference
    lea rax, [rsp + L_T]
    movss xmm4, dword ptr [rip + minus_one]
evaluate_reference:
    movss xmm2, dword ptr [rsp + L_F]
    mulss xmm2, xmm4
    movss xmm3, dword ptr [rsp + L_F + 4]
    mulss xmm3, xmm4
    movss xmm0, dword ptr [r13]
    movss xmm1, dword ptr [r13 + 4]
    movaps xmm4, xmm0
    mulss xmm4, xmm3
    movaps xmm5, xmm1
    mulss xmm5, xmm2
    addss xmm4, xmm5
    addss xmm4, dword ptr [rax]
    movss dword ptr [rsp + L_P], xmm4
    movaps xmm4, xmm1
    mulss xmm4, xmm3
    mulss xmm0, xmm2
    subss xmm4, xmm0
    addss xmm4, dword ptr [rax + 8]
    movss dword ptr [rsp + L_P + 8], xmm4
    movss xmm4, dword ptr [rax + 4]
    addss xmm4, dword ptr [r13 + 8]
    movss dword ptr [rsp + L_P + 4], xmm4
    mov dword ptr [rsp + L_P + 0xc], 0
    lea rcx, [rsp + L_P]
    lea rdx, [rsp + L_T]
    call point_visible
    dec r14d
    call wanted
    test al, al
    je evaluate_candidate
    cmp r14d, 2
    jl evaluate_fallback
    lea rcx, [rsp + L_P]
    lea rdx, [rsp + L_RESULT]
    call ground
    dec r14d
    test al, al
    je evaluate_candidate
    movss xmm0, dword ptr [rsp + L_RESULT + 4]
    movss dword ptr [rsp + L_P + 4], xmm0
    lea rcx, [rsp + L_P]
    lea rdx, [rsp + L_T]
    call point_visible
    dec r14d
    call wanted
    test al, al
    je evaluate_candidate
    inc dword ptr [r15 + C_FOUND]
    lea rax, [rsp + L_P]
    jmp evaluate_measured

evaluate_fallback:
    inc dword ptr [r15 + C_FALLBACK]
    cmp byte ptr [rbp + P_DEFAULT], 0
    je evaluate_stay
    cmp dword ptr [rbp + P_KIND], 0
    jne evaluate_backup
    movss xmm2, dword ptr [rbp + P_RANGE]
    comiss xmm2, dword ptr [rsp + L_LENGTH]
    jae evaluate_stay
    movss xmm0, dword ptr [rsp + L_F]
    mulss xmm0, xmm2
    movss xmm1, dword ptr [rsp + L_T]
    subss xmm1, xmm0
    movss dword ptr [rsp + L_P], xmm1
    movss xmm0, dword ptr [rsp + L_F + 4]
    mulss xmm0, xmm2
    movss xmm1, dword ptr [rsp + L_T + 8]
    subss xmm1, xmm0
    movss dword ptr [rsp + L_P + 8], xmm1
    movss xmm0, dword ptr [rsp + L_T + 4]
    movss dword ptr [rsp + L_P + 4], xmm0
    lea rax, [rsp + L_P]
    jmp evaluate_measured
evaluate_backup:
    movss xmm2, dword ptr [rip + backup_distance]
    movss xmm0, dword ptr [rsp + L_F]
    mulss xmm0, xmm2
    movss xmm1, dword ptr [rsp + L_A]
    subss xmm1, xmm0
    movss dword ptr [rsp + L_P], xmm1
    movss xmm0, dword ptr [rsp + L_F + 4]
    mulss xmm0, xmm2
    movss xmm1, dword ptr [rsp + L_A + 8]
    subss xmm1, xmm0
    movss dword ptr [rsp + L_P + 8], xmm1
    movss xmm0, dword ptr [rsp + L_A + 4]
    movss dword ptr [rsp + L_P + 4], xmm0
    lea rax, [rsp + L_P]
    jmp evaluate_measured
evaluate_stay:
    inc dword ptr [r15 + C_STAY]
    lea rax, [rsp + L_A]
evaluate_measured:
    call write_goal
    rdtsc
    shl rdx, 32
    or rax, rdx
    sub rax, qword ptr [rsp + L_TSC]
    add qword ptr [r15 + C_CYCLES], rax
    cmp rax, qword ptr [r15 + C_MAX_CYCLES]
    jbe evaluate_success
    mov qword ptr [r15 + C_MAX_CYCLES], rax
    jmp evaluate_success

evaluate_flee:
    movss xmm2, dword ptr [rbp + P_SAFE]
    comiss xmm2, dword ptr [rsp + L_LENGTH]
    jbe evaluate_flee_stay
    movss xmm0, dword ptr [rsp + L_F]
    mulss xmm0, xmm2
    movss xmm1, dword ptr [rsp + L_T]
    subss xmm1, xmm0
    movss dword ptr [rsp + L_P], xmm1
    movss xmm0, dword ptr [rsp + L_F + 4]
    mulss xmm0, xmm2
    movss xmm1, dword ptr [rsp + L_T + 8]
    subss xmm1, xmm0
    movss dword ptr [rsp + L_P + 8], xmm1
    movss xmm0, dword ptr [rsp + L_A + 4]
    movss dword ptr [rsp + L_P + 4], xmm0
    lea rax, [rsp + L_P]
    call write_goal
    jmp evaluate_success
evaluate_flee_stay:
    lea rax, [rsp + L_A]
    call write_goal
evaluate_success:
    mov al, 1
evaluate_out:
    add rsp, 0x108
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rdi
    pop rsi
    pop rbx
    ret

write_goal:
    mov ecx, dword ptr [rax]
    mov dword ptr [rbx + 0x30], ecx
    mov ecx, dword ptr [rax + 4]
    mov dword ptr [rbx + 0x34], ecx
    mov ecx, dword ptr [rax + 8]
    mov dword ptr [rbx + 0x38], ecx
    ret

wanted:
    cmp dword ptr [rbp + P_KIND], 0
    je wanted_done
    xor al, 1
wanted_done:
    ret

cast:
    sub rsp, 0x48
    movabs rax, 0x1446e54a8
    mov rax, qword ptr [rax]
    test rax, rax
    je cast_none
    mov rax, qword ptr [rax + 0x60]
    test rax, rax
    je cast_none
    movabs r9, 0x143b44520
    cmp qword ptr [rax], r9
    jne cast_none
    movabs r9, COUNTERS
    inc dword ptr [r9 + C_RAYS]
    mov qword ptr [rsp + 0x30], 0
    mov qword ptr [rsp + 0x28], r8
    mov qword ptr [rsp + 0x20], rdx
    mov r9, rcx
    xor r8d, r8d
    xor edx, edx
    mov rcx, rax
    movabs rax, 0x14159eec0
    call rax
    jmp cast_out
cast_none:
    xor eax, eax
cast_out:
    add rsp, 0x48
    ret

sight:
    push rbx
    sub rsp, 0x80
    mov rbx, rdx
    lea r8, [rsp + 0x20]
    call cast
    test al, al
    je sight_clear
    movups xmm0, xmmword ptr [rsp + 0x20]
    movups xmm1, xmmword ptr [rbx]
    subps xmm0, xmm1
    mulps xmm0, xmm0
    movaps xmm1, xmm0
    shufps xmm1, xmm1, 0x55
    movaps xmm2, xmm0
    shufps xmm2, xmm2, 0xaa
    addss xmm0, xmm1
    addss xmm0, xmm2
    sqrtss xmm0, xmm0
    comiss xmm0, dword ptr [rip + target_tolerance]
    jb sight_clear
    xor eax, eax
    jmp sight_out
sight_clear:
    mov al, 1
sight_out:
    add rsp, 0x80
    pop rbx
    ret

point_visible:
    sub rsp, 0x48
    movups xmm0, xmmword ptr [rcx]
    addps xmm0, xmmword ptr [rip + eye_offset]
    movups xmmword ptr [rsp + 0x20], xmm0
    movups xmm0, xmmword ptr [rdx]
    addps xmm0, xmmword ptr [rip + target_offset]
    movups xmmword ptr [rsp + 0x30], xmm0
    lea rcx, [rsp + 0x20]
    lea rdx, [rsp + 0x30]
    call sight
    add rsp, 0x48
    ret

self_visible:
    sub rsp, 0x48
    movups xmm0, xmmword ptr [rcx]
    addps xmm0, xmmword ptr [rip + eye_offset]
    movups xmm1, xmmword ptr [rdx]
    addps xmm1, xmmword ptr [rip + target_offset]
    movups xmmword ptr [rsp + 0x30], xmm1
    movaps xmm2, xmm1
    subps xmm2, xmm0
    movaps xmm3, xmm2
    mulps xmm3, xmm3
    movaps xmm4, xmm3
    shufps xmm4, xmm4, 0x55
    movaps xmm5, xmm3
    shufps xmm5, xmm5, 0xaa
    addss xmm3, xmm4
    addss xmm3, xmm5
    sqrtss xmm3, xmm3
    mov al, 1
    comiss xmm3, dword ptr [rip + minimum_ray]
    jb self_visible_out
    movss xmm4, dword ptr [rip + one]
    divss xmm4, xmm3
    shufps xmm4, xmm4, 0
    mulps xmm2, xmm4
    addps xmm0, xmm2
    movups xmmword ptr [rsp + 0x20], xmm0
    lea rcx, [rsp + 0x20]
    lea rdx, [rsp + 0x30]
    call sight
self_visible_out:
    add rsp, 0x48
    ret

ground:
    sub rsp, 0x48
    movups xmm0, xmmword ptr [rcx]
    movaps xmm1, xmm0
    addps xmm0, xmmword ptr [rip + ground_above]
    subps xmm1, xmmword ptr [rip + ground_below]
    movups xmmword ptr [rsp + 0x20], xmm0
    movups xmmword ptr [rsp + 0x30], xmm1
    mov r8, rdx
    lea rcx, [rsp + 0x20]
    lea rdx, [rsp + 0x30]
    call cast
    add rsp, 0x48
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
    movabs rcx, SERVER_CHARACTER
    cmp qword ptr [rax], rcx
    je context_done
context_none:
    xor eax, eax
context_done:
    add rsp, 0x28
    ret

.balign 16
eye_offset:
    .float 0.0, 1.7, 0.0, 0.0
target_offset:
    .float 0.0, 1.5, 0.0, 0.0
ground_above:
    .float 0.0, 2.0, 0.0, 0.0
ground_below:
    .float 0.0, 6.0, 0.0, 0.0
one:
    .float 1.0
minus_one:
    .float -1.0
fifteen:
    .float 15.0
thirty:
    .float 30.0
hundred:
    .float 100.0
minimum_length:
    .float 0.1
minimum_ray:
    .float 1.5
target_tolerance:
    .float 2.0
backup_distance:
    .float 7.0
point_stop:
    .float 1.0
flee_stop:
    .float 3.0
update_period:
    .float 2.0
.balign 16
provider_table:
    .quad 0x1403737d0, 0x1407f2ea0, 0x140390e40, CODE_BASE + (los_evaluate - entries)
