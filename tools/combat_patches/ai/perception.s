.intel_syntax noprefix
.code64
.set PLAYERS, 0x142b38000
.set IS_PLAYER, 0x142b38008
.set PLAYER_COUNT, 4
.set PLAYER_TABLE, 0x98
.set RECORDS_POINTER, 0x153737618
.set RECORD_COUNT, 128
.set RECORD_SIZE, 0x50
.set SERVER_CHARACTER, 0x143a75900
.set AI_COMPONENT, 0x143acd3d0
.set HOSTILITY_COMPONENT, 0x143bca3d0
.set SIMPLE_HEALTH, 0x143a88538
.set PLAYER_HEALTH, 0x143a88050
.set SHIELD, 0x143a76ae0
.set SERVER_HOSTILITY_MANAGER, 0x14470de38
.set PERCEPTION_DATA_TYPE, 0x1451ca740
.set WANTS_TO_ATTACK_TYPE, 0x145280710
.set R_ENTITY, 0
.set R_TARGET, 8
.set R_SINCE, 0x10
.set R_SEEN, 0x14
.set R_EVALUATED, 0x18
.set R_FORGET, 0x1c
.set R_NEXT, 0x20
.set R_VISIBLE, 0x24
.set R_STATE, 0x25
.set R_CANDIDATE, 0x28
.set R_SIGHT, 0x30
.set R_SPOT_DISTANCE, 0x34
.set R_VITALITY, 0x38
.set R_DAMAGED, 0x3c
.set R_ALERTED, 0x40
.set R_RAYS, 0x44
.set R_CLEAR, 0x48
.set R_GAP, 0x4c
.set BLOCKED_RAY, 0x153737620
.set CODE_BASE, 0x142b30000
.set server_ray_owner, entries + (0x1446e54a8 - CODE_BASE)
.set ray_caster_table, entries + (0x143b44520 - CODE_BASE)
.set cast_ray, entries + (0x14159eec0 - CODE_BASE)
.set clock_owner, entries + (0x1446ceca0 - CODE_BASE)
.set owner_entity, entries + (0x1403992f0 - CODE_BASE)

entries:
    jmp target_evaluate
.balign 8
    jmp has_enemies_evaluate
.balign 8
    jmp line_of_sight_evaluate
.balign 8
    jmp wants_evaluate
.balign 8
    jmp range_evaluate
.balign 8
    jmp target_is_player_evaluate
.balign 8
    jmp target_of
.balign 8
    int3
.balign 8
previous_target:
    .quad 0
previous_has_enemies:
    .quad 0
previous_line_of_sight:
    .quad 0
previous_wants:
    .quad 0
previous_range:
    .quad 0
previous_target_is_player:
    .quad 0

target_evaluate:
    push rsi
    push rdi
    sub rsp, 0x38
    mov rsi, rcx
    mov rdi, rdx
    call context_entity
    test rax, rax
    je target_previous
    mov rcx, rax
    lea rdx, [rsp + 0x20]
    call evaluate
    add rsp, 0x38
    pop rdi
    pop rsi
    ret
target_previous:
    mov rcx, rsi
    mov rdx, rdi
    add rsp, 0x38
    pop rdi
    pop rsi
    jmp qword ptr [rip + previous_target]

has_enemies_evaluate:
    push rsi
    push rdi
    sub rsp, 0x38
    mov rsi, rcx
    mov rdi, rdx
    call context_entity
    test rax, rax
    je has_enemies_previous
    mov rcx, rax
    lea rdx, [rsp + 0x20]
    call evaluate
    test rax, rax
    setne al
    movzx ecx, byte ptr [rsi + 0x34]
    xor eax, ecx
    and eax, 1
    add rsp, 0x38
    pop rdi
    pop rsi
    ret
has_enemies_previous:
    mov rcx, rsi
    mov rdx, rdi
    add rsp, 0x38
    pop rdi
    pop rsi
    jmp qword ptr [rip + previous_has_enemies]

line_of_sight_evaluate:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x30
    mov rsi, rcx
    mov rdi, rdx
    call context_entity
    test rax, rax
    je line_of_sight_previous
    mov rbx, rax
    mov rcx, rax
    lea rdx, [rsp + 0x20]
    call evaluate
    test rax, rax
    je line_of_sight_out
    mov rcx, qword ptr [rsp + 0x20]
    test rcx, rcx
    je line_of_sight_fresh
    movzx eax, byte ptr [rcx + R_VISIBLE]
    jmp line_of_sight_out
line_of_sight_fresh:
    mov rcx, rbx
    mov rdx, rax
    call line_of_sight
line_of_sight_out:
    add rsp, 0x30
    pop rdi
    pop rsi
    pop rbx
    ret
line_of_sight_previous:
    mov rcx, rsi
    mov rdx, rdi
    add rsp, 0x30
    pop rdi
    pop rsi
    pop rbx
    jmp qword ptr [rip + previous_line_of_sight]

wants_evaluate:
    push rsi
    push rdi
    sub rsp, 0x38
    mov rsi, rcx
    mov rdi, rdx
    xor eax, eax
    movabs rcx, WANTS_TO_ATTACK_TYPE
    cmp qword ptr [rsi + 0x10], rcx
    jne wants_out
    call context_entity
    test rax, rax
    je wants_previous
    mov rcx, rax
    lea rdx, [rsp + 0x20]
    call evaluate
    test rax, rax
    setne al
wants_out:
    add rsp, 0x38
    pop rdi
    pop rsi
    ret
wants_previous:
    mov rcx, rsi
    mov rdx, rdi
    add rsp, 0x38
    pop rdi
    pop rsi
    jmp qword ptr [rip + previous_wants]

target_is_player_evaluate:
    push rsi
    push rdi
    sub rsp, 0x38
    mov rsi, rcx
    mov rdi, rdx
    call context_entity
    test rax, rax
    je target_is_player_previous
    mov rcx, rax
    lea rdx, [rsp + 0x20]
    call evaluate
    test rax, rax
    je target_is_player_out
    mov rcx, rax
    movabs rax, IS_PLAYER
    call rax
target_is_player_out:
    add rsp, 0x38
    pop rdi
    pop rsi
    ret
target_is_player_previous:
    mov rcx, rsi
    mov rdx, rdi
    add rsp, 0x38
    pop rdi
    pop rsi
    jmp qword ptr [rip + previous_target_is_player]

range_evaluate:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x30
    mov rsi, rcx
    mov rdi, rdx
    call context_entity
    test rax, rax
    je range_previous
    mov rbx, rax
    mov rcx, rax
    lea rdx, [rsp + 0x20]
    call evaluate
    test rax, rax
    je range_out
    mov rdi, rax
    mov rcx, rbx
    call translation
    test rax, rax
    je range_false
    movups xmm4, xmmword ptr [rax]
    mov rcx, rdi
    call translation
    test rax, rax
    je range_false
    movups xmm1, xmmword ptr [rax]
    subps xmm4, xmm1
    mulps xmm4, xmm4
    cmp byte ptr [rsi + 0x31], 0
    je range_horizontal
    shufps xmm4, xmm4, 0x55
    movaps xmm0, xmm4
    jmp range_distance
range_horizontal:
    movaps xmm0, xmm4
    movaps xmm1, xmm4
    shufps xmm1, xmm1, 0xaa
    addss xmm0, xmm1
    cmp byte ptr [rsi + 0x30], 0
    jne range_distance
    shufps xmm4, xmm4, 0x55
    addss xmm0, xmm4
range_distance:
    sqrtss xmm0, xmm0
    movss xmm1, dword ptr [rsi + 0x2c]
    mov ecx, dword ptr [rsi + 0x28]
    xor eax, eax
    cmp ecx, 1
    je range_not_equal
    cmp ecx, 2
    je range_less
    cmp ecx, 3
    je range_more
    cmp ecx, 4
    je range_less_equal
    cmp ecx, 5
    je range_more_equal
    comiss xmm0, xmm1
    sete al
    jmp range_out
range_not_equal:
    comiss xmm0, xmm1
    setne al
    jmp range_out
range_less:
    comiss xmm0, xmm1
    setb al
    jmp range_out
range_more:
    comiss xmm0, xmm1
    seta al
    jmp range_out
range_less_equal:
    comiss xmm0, xmm1
    setbe al
    jmp range_out
range_more_equal:
    comiss xmm0, xmm1
    setae al
    jmp range_out
range_false:
    xor eax, eax
range_out:
    add rsp, 0x30
    pop rdi
    pop rsi
    pop rbx
    ret
range_previous:
    mov rcx, rsi
    mov rdx, rdi
    add rsp, 0x30
    pop rdi
    pop rsi
    pop rbx
    jmp qword ptr [rip + previous_range]

target_of:
    push rbx
    push rsi
    sub rsp, 0x28
    mov rbx, rcx
    call usable
    test al, al
    je target_of_none
    movabs rax, RECORDS_POINTER
    mov rsi, qword ptr [rax]
    test rsi, rsi
    je target_of_none
    mov edx, RECORD_COUNT
target_of_find:
    cmp qword ptr [rsi + R_ENTITY], rbx
    je target_of_found
    add rsi, RECORD_SIZE
    dec edx
    jne target_of_find
    jmp target_of_none
target_of_found:
    mov rcx, rsi
    call record_perceived
    test al, al
    je target_of_none
    mov rcx, qword ptr [rsi + R_TARGET]
    call usable
    test al, al
    je target_of_none
    mov rax, qword ptr [rsi + R_TARGET]
    jmp target_of_out
target_of_none:
    xor eax, eax
target_of_out:
    add rsp, 0x28
    pop rsi
    pop rbx
    ret

evaluate:
    push rbx
    push rsi
    push rdi
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0xb8
    mov rbx, rcx
    mov qword ptr [rsp + 0x40], rdx
    mov qword ptr [rdx], 0
    call usable
    test al, al
    je evaluate_none
    lea rcx, [rsp + PLAYER_TABLE]
    movabs rax, PLAYERS
    call rax
    call now
    movss dword ptr [rsp + 0x20], xmm0
    call records_base
    mov qword ptr [rsp + 0x88], rax
    test rax, rax
    je evaluate_open
    movss xmm0, dword ptr [rsp + 0x20]
    mov rcx, rbx
    mov rdx, rax
    call find_record
    test rax, rax
    je evaluate_open
    mov rsi, rax
    mov rcx, qword ptr [rsp + 0x40]
    mov qword ptr [rcx], rsi
    movss xmm0, dword ptr [rsp + 0x20]
    movss dword ptr [rsi + R_EVALUATED], xmm0
    mov byte ptr [rsp + 0x7c], 1
    comiss xmm0, dword ptr [rsi + R_NEXT]
    jb evaluate_result
    addss xmm0, dword ptr [rip + selection_period]
    movss dword ptr [rsi + R_NEXT], xmm0
    mov rcx, rbx
    call ai_component
    test rax, rax
    je evaluate_result
    mov r12, rax
    mov rcx, rbx
    mov rdx, r12
    lea r8, [rsp + 0x28]
    call parameters
    movss xmm0, dword ptr [rsp + 0x30]
    movss dword ptr [rsi + R_FORGET], xmm0
    movss xmm0, dword ptr [rsp + 0x28]
    movss dword ptr [rsi + R_SIGHT], xmm0
    mov eax, dword ptr [r12 + 0xc0]
    mov byte ptr [rsi + R_STATE], al
    call record_perceived
    mov byte ptr [rsp + 0x7c], al
    mov rcx, rbx
    call vitality
    movss xmm1, dword ptr [rsi + R_VITALITY]
    movss dword ptr [rsi + R_VITALITY], xmm0
    subss xmm1, xmm0
    comiss xmm1, dword ptr [rip + damage_epsilon]
    jbe evaluate_group
    movss xmm0, dword ptr [rsp + 0x20]
    movss dword ptr [rsi + R_DAMAGED], xmm0
evaluate_group:
    mov rcx, rbx
    call group
    mov dword ptr [rsp + 0x24], eax
    mov byte ptr [rsi + R_VISIBLE], 0

    mov rcx, qword ptr [rsi + R_TARGET]
    test rcx, rcx
    je evaluate_scan
    mov edx, dword ptr [rsp + 0x24]
    call hostile_usable
    test al, al
    jne evaluate_scan
    mov qword ptr [rsi + R_TARGET], 0
    mov dword ptr [rsi + R_SEEN], 0
    mov dword ptr [rsi + R_SPOT_DISTANCE], 0

evaluate_scan:
    mov dword ptr [rsp + 0x6c], 0
    mov qword ptr [rsp + 0x70], 0
    mov eax, dword ptr [rip + unknown_distance]
    mov dword ptr [rsp + 0x78], eax
    mov r14d, -PLAYER_COUNT
    mov r13, qword ptr [rsp + 0x88]
evaluate_candidate:
    cmp r14d, RECORD_COUNT
    jge evaluate_rays
    test r14d, r14d
    jns evaluate_candidate_record
    movsxd rax, r14d
    mov r15, qword ptr [rsp + PLAYER_TABLE + PLAYER_COUNT * 8 + rax * 8]
    jmp evaluate_candidate_check
evaluate_candidate_record:
    mov r15, qword ptr [r13 + R_ENTITY]
    test r15, r15
    je evaluate_candidate_next
    movss xmm0, dword ptr [rsp + 0x20]
    subss xmm0, dword ptr [r13 + R_EVALUATED]
    comiss xmm0, dword ptr [rip + alive_window]
    ja evaluate_candidate_next
evaluate_candidate_check:
    test r15, r15
    je evaluate_candidate_next
    cmp r15, rbx
    je evaluate_candidate_next
    mov rcx, r15
    mov edx, dword ptr [rsp + 0x24]
    call hostile_usable
    test al, al
    je evaluate_candidate_next
    mov rcx, rbx
    mov rdx, r15
    call distance
    comiss xmm0, dword ptr [rsp + 0x78]
    jae evaluate_candidate_sight
    movss dword ptr [rsp + 0x78], xmm0
    mov qword ptr [rsp + 0x70], r15
evaluate_candidate_sight:
    comiss xmm0, dword ptr [rsp + 0x28]
    ja evaluate_candidate_next
    mov eax, dword ptr [rsp + 0x6c]
    cmp eax, 3
    jb evaluate_insert_at
    comiss xmm0, dword ptr [rsp + 0x68]
    jae evaluate_candidate_next
    mov eax, 2
    jmp evaluate_insert_store
evaluate_insert_at:
    inc dword ptr [rsp + 0x6c]
evaluate_insert_store:
    mov qword ptr [rsp + 0x48 + rax * 8], r15
    movss dword ptr [rsp + 0x60 + rax * 4], xmm0
evaluate_bubble:
    test eax, eax
    je evaluate_candidate_next
    movss xmm1, dword ptr [rsp + 0x5c + rax * 4]
    comiss xmm1, dword ptr [rsp + 0x60 + rax * 4]
    jbe evaluate_candidate_next
    movss xmm0, dword ptr [rsp + 0x60 + rax * 4]
    movss dword ptr [rsp + 0x5c + rax * 4], xmm0
    movss dword ptr [rsp + 0x60 + rax * 4], xmm1
    mov rcx, qword ptr [rsp + 0x40 + rax * 8]
    mov rdx, qword ptr [rsp + 0x48 + rax * 8]
    mov qword ptr [rsp + 0x40 + rax * 8], rdx
    mov qword ptr [rsp + 0x48 + rax * 8], rcx
    dec eax
    jmp evaluate_bubble
evaluate_candidate_next:
    test r14d, r14d
    js evaluate_candidate_advance
    add r13, RECORD_SIZE
evaluate_candidate_advance:
    inc r14d
    jmp evaluate_candidate

evaluate_rays:
    xor r15d, r15d
    xor r14d, r14d
evaluate_ray:
    cmp r14d, dword ptr [rsp + 0x6c]
    jae evaluate_rays_done
    mov rcx, rbx
    mov rdx, qword ptr [rsp + 0x48 + r14 * 8]
    call ray_counted
    test al, al
    jne evaluate_ray_hit
    inc r14d
    jmp evaluate_ray
evaluate_ray_hit:
    mov r15, qword ptr [rsp + 0x48 + r14 * 8]
    movss xmm0, dword ptr [rsp + 0x60 + r14 * 4]
    movss dword ptr [rsp + 0x80], xmm0
evaluate_rays_done:
    movss xmm0, dword ptr [rsp + 0x20]
    test r15, r15
    jne evaluate_visible
    mov qword ptr [rsi + R_CANDIDATE], 0
    jmp evaluate_target_sight
evaluate_visible:
    cmp qword ptr [rsi + R_CANDIDATE], r15
    je evaluate_visible_since
    mov qword ptr [rsi + R_CANDIDATE], r15
    movss dword ptr [rsi + R_SINCE], xmm0
evaluate_visible_since:
    movaps xmm1, xmm0
    subss xmm1, dword ptr [rsi + R_SINCE]
    comiss xmm1, dword ptr [rsp + 0x2c]
    jb evaluate_target_sight
    mov qword ptr [rsi + R_TARGET], r15
    movss dword ptr [rsi + R_SEEN], xmm0
    mov byte ptr [rsi + R_VISIBLE], 1
    movss xmm0, dword ptr [rsp + 0x80]
    movss dword ptr [rsi + R_SPOT_DISTANCE], xmm0
    jmp evaluate_damage
evaluate_target_sight:
    mov rdi, qword ptr [rsi + R_TARGET]
    test rdi, rdi
    je evaluate_damage
    xor eax, eax
evaluate_target_candidate:
    cmp eax, dword ptr [rsp + 0x6c]
    jae evaluate_target_ray
    cmp qword ptr [rsp + 0x48 + rax * 8], rdi
    je evaluate_target_rayed
    inc eax
    jmp evaluate_target_candidate
evaluate_target_rayed:
    cmp eax, r14d
    jb evaluate_damage
    je evaluate_target_seen
evaluate_target_ray:
    mov rcx, rbx
    mov rdx, rdi
    call distance
    comiss xmm0, dword ptr [rsp + 0x28]
    ja evaluate_damage
    movss dword ptr [rsp + 0x80], xmm0
    mov rcx, rbx
    mov rdx, rdi
    call ray_counted
    test al, al
    je evaluate_damage
evaluate_target_seen:
    mov byte ptr [rsi + R_VISIBLE], 1
    movss xmm0, dword ptr [rsp + 0x80]
    movss dword ptr [rsi + R_SPOT_DISTANCE], xmm0
    movss xmm0, dword ptr [rsp + 0x20]
    movss dword ptr [rsi + R_SEEN], xmm0

evaluate_damage:
    movss xmm0, dword ptr [rsp + 0x20]
    call record_perceived
    test al, al
    jne evaluate_result
    mov rax, qword ptr [rsp + 0x70]
    test rax, rax
    je evaluate_allies
    movss xmm0, dword ptr [rsp + 0x20]
    movss xmm1, dword ptr [rsi + R_DAMAGED]
    xorps xmm2, xmm2
    comiss xmm1, xmm2
    jbe evaluate_allies
    subss xmm0, xmm1
    comiss xmm0, dword ptr [rip + damage_memory]
    ja evaluate_allies
    mov qword ptr [rsi + R_TARGET], rax
    movss xmm0, dword ptr [rsp + 0x20]
    movss dword ptr [rsi + R_SEEN], xmm0
    jmp evaluate_result

evaluate_allies:
    mov r13, qword ptr [rsp + 0x88]
    mov r14d, RECORD_COUNT
evaluate_ally:
    test r14d, r14d
    je evaluate_result
    cmp r13, rsi
    je evaluate_ally_next
    mov r15, qword ptr [r13 + R_ENTITY]
    test r15, r15
    je evaluate_ally_next
    cmp qword ptr [r13 + R_TARGET], 0
    je evaluate_ally_next
    movss xmm0, dword ptr [rsp + 0x20]
    movaps xmm1, xmm0
    subss xmm1, dword ptr [r13 + R_EVALUATED]
    comiss xmm1, dword ptr [rip + alive_window]
    ja evaluate_ally_next
    mov rcx, r13
    call record_perceived_with_forget
    test al, al
    je evaluate_ally_next
    mov rcx, r15
    call group
    mov edx, eax
    mov ecx, dword ptr [rsp + 0x24]
    call hostility
    test eax, eax
    jne evaluate_ally_next
    mov rcx, rbx
    mov rdx, r15
    call distance
    comiss xmm0, dword ptr [rsp + 0x34]
    jbe evaluate_ally_in_range
    comiss xmm0, dword ptr [rsp + 0x38]
    ja evaluate_ally_next
    movss xmm1, dword ptr [rsp + 0x20]
    subss xmm1, dword ptr [r13 + R_ALERTED]
    comiss xmm1, dword ptr [rip + alive_window]
    ja evaluate_ally_next
evaluate_ally_in_range:
    mov rcx, qword ptr [r13 + R_TARGET]
    cmp rcx, rbx
    je evaluate_ally_next
    mov edx, dword ptr [rsp + 0x24]
    call hostile_usable
    test al, al
    je evaluate_ally_next
    mov rax, qword ptr [r13 + R_TARGET]
    mov qword ptr [rsi + R_TARGET], rax
    movss xmm0, dword ptr [r13 + R_SEEN]
    movss dword ptr [rsi + R_SEEN], xmm0
    jmp evaluate_result
evaluate_ally_next:
    add r13, RECORD_SIZE
    dec r14d
    jmp evaluate_ally

evaluate_result:
    call record_perceived
    test al, al
    je evaluate_none
    cmp byte ptr [rsp + 0x7c], 0
    jne evaluate_result_target
    movss xmm0, dword ptr [rsp + 0x20]
    movss dword ptr [rsi + R_ALERTED], xmm0
evaluate_result_target:
    mov rcx, qword ptr [rsi + R_TARGET]
    call usable
    test al, al
    je evaluate_none
    mov rax, qword ptr [rsi + R_TARGET]
    jmp evaluate_out
evaluate_open:
    xor r15d, r15d
    xor r14d, r14d
evaluate_open_player:
    cmp r14d, PLAYER_COUNT
    jae evaluate_open_done
    mov rcx, qword ptr [rsp + PLAYER_TABLE + r14 * 8]
    test rcx, rcx
    je evaluate_open_next
    mov rdx, rbx
    call hostile_between
    test al, al
    je evaluate_open_next
    mov rcx, rbx
    mov rdx, qword ptr [rsp + PLAYER_TABLE + r14 * 8]
    call distance
    test r15, r15
    je evaluate_open_take
    comiss xmm0, dword ptr [rsp + 0x78]
    jae evaluate_open_next
evaluate_open_take:
    movss dword ptr [rsp + 0x78], xmm0
    mov r15, qword ptr [rsp + PLAYER_TABLE + r14 * 8]
evaluate_open_next:
    inc r14d
    jmp evaluate_open_player
evaluate_open_done:
    mov rax, r15
    jmp evaluate_out
evaluate_none:
    xor eax, eax
evaluate_out:
    add rsp, 0xb8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rdi
    pop rsi
    pop rbx
    ret

hostile_usable:
    push rbx
    push rsi
    sub rsp, 0x28
    mov rbx, rcx
    mov esi, edx
    call usable
    test al, al
    je hostile_usable_out
    mov rcx, rbx
    call group
    mov edx, eax
    mov ecx, esi
    call hostility
    cmp eax, 2
    sete al
hostile_usable_out:
    add rsp, 0x28
    pop rsi
    pop rbx
    ret

hostile_between:
    push rbx
    push rsi
    sub rsp, 0x28
    mov rbx, rcx
    mov rsi, rdx
    call group
    mov dword ptr [rsp + 0x20], eax
    mov rcx, rsi
    call group
    mov ecx, eax
    mov edx, dword ptr [rsp + 0x20]
    call hostility
    cmp eax, 2
    sete al
    add rsp, 0x28
    pop rsi
    pop rbx
    ret

usable:
    push rbx
    sub rsp, 0x20
    mov rbx, rcx
    call translation
    test rax, rax
    je usable_out
    mov rcx, rbx
    movabs rdx, SIMPLE_HEALTH
    call component
    test rax, rax
    jne usable_health
    mov rcx, rbx
    movabs rdx, PLAYER_HEALTH
    call component
    test rax, rax
    je usable_alive
usable_health:
    movss xmm0, dword ptr [rax + 0x20]
    xorps xmm1, xmm1
    xor eax, eax
    comiss xmm0, xmm1
    seta al
    jmp usable_out
usable_alive:
    mov al, 1
usable_out:
    add rsp, 0x20
    pop rbx
    ret

component:
    xor eax, eax
    test rcx, rcx
    je component_done
    test cl, 7
    jne component_done
    movabs r8, SERVER_CHARACTER
    cmp qword ptr [rcx], r8
    jne component_done
    mov r8, qword ptr [rcx + 0x58]
    test r8, r8
    je component_done
    test r8b, 7
    jne component_done
    movzx r9d, byte ptr [r8 + 8]
    lea r8, [r8 + 0x10]
component_loop:
    test r9d, r9d
    je component_done
    mov r10, qword ptr [r8 + 0x10]
    test r10, r10
    je component_next
    cmp qword ptr [r10], rdx
    jne component_next
    mov rax, r10
    ret
component_next:
    add r8, 0x20
    dec r9d
    jmp component_loop
component_done:
    ret

group:
    movabs rdx, HOSTILITY_COMPONENT
    call component
    test rax, rax
    je group_unknown
    mov rcx, qword ptr [rax + 0x58]
    cmp rcx, qword ptr [rax + 0x60]
    je group_own
    test rcx, rcx
    je group_own
    mov eax, dword ptr [rcx]
    ret
group_own:
    mov eax, dword ptr [rax + 0x78]
    ret
group_unknown:
    mov eax, -1
    ret

hostility:
    cmp ecx, -1
    je hostility_default
    cmp edx, -1
    je hostility_default
    mov r10d, edx
    movabs rax, SERVER_HOSTILITY_MANAGER
    mov rax, qword ptr [rax]
    test rax, rax
    je hostility_default
    mov r9, qword ptr [rax + 0x40]
    mov r8d, dword ptr [rax + 0x48]
    test r9, r9
    je hostility_default
    test r8d, r8d
    je hostility_default
    mov r11d, ecx
    mov eax, ecx
    xor edx, edx
    div r8d
    mov rax, qword ptr [r9 + rdx * 8]
hostility_outer:
    test rax, rax
    je hostility_default
    cmp dword ptr [rax], r11d
    je hostility_outer_found
    mov rax, qword ptr [rax + 0x38]
    jmp hostility_outer
hostility_outer_found:
    cmp rax, qword ptr [r9 + r8 * 8]
    je hostility_default
    mov r9, qword ptr [rax + 0x10]
    mov r8d, dword ptr [rax + 0x18]
    test r9, r9
    je hostility_default
    test r8d, r8d
    je hostility_default
    mov eax, r10d
    xor edx, edx
    div r8d
    mov rax, qword ptr [r9 + rdx * 8]
hostility_inner:
    test rax, rax
    je hostility_default
    cmp dword ptr [rax], r10d
    je hostility_inner_found
    mov rax, qword ptr [rax + 0x10]
    jmp hostility_inner
hostility_inner_found:
    cmp rax, qword ptr [r9 + r8 * 8]
    je hostility_default
    mov rax, qword ptr [rax + 8]
    test rax, rax
    je hostility_default
    mov eax, dword ptr [rax + 0x28]
    ret
hostility_default:
    mov eax, 1
    ret

line_of_sight:
    push rbx
    push rsi
    push rdi
    sub rsp, 0xd0
    mov rax, qword ptr [rip + server_ray_owner]
    test rax, rax
    je line_of_sight_clear
    mov rbx, qword ptr [rax + 0x60]
    test rbx, rbx
    je line_of_sight_clear
    lea rax, [rip + ray_caster_table]
    cmp qword ptr [rbx], rax
    jne line_of_sight_clear
    mov rdi, rcx
    mov rsi, rdx
    call translation
    test rax, rax
    je line_of_sight_clear
    movups xmm0, xmmword ptr [rax]
    addps xmm0, xmmword ptr [rip + eye_offset]
    movups xmmword ptr [rsp + 0x40], xmm0
    mov rcx, rsi
    call translation
    test rax, rax
    je line_of_sight_clear
    movups xmm0, xmmword ptr [rsp + 0x40]
    movups xmm1, xmmword ptr [rax]
    addps xmm1, xmmword ptr [rip + target_offset]
    movups xmmword ptr [rsp + 0x50], xmm1
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
    comiss xmm3, dword ptr [rip + minimum_ray]
    jb line_of_sight_clear
    movss xmm4, dword ptr [rip + start_push]
    divss xmm4, xmm3
    shufps xmm4, xmm4, 0
    mulps xmm2, xmm4
    addps xmm0, xmm2
    movups xmmword ptr [rsp + 0x40], xmm0
    mov qword ptr [rsp + 0x30], 0
    lea rax, [rsp + 0x60]
    mov qword ptr [rsp + 0x28], rax
    lea rax, [rsp + 0x50]
    mov qword ptr [rsp + 0x20], rax
    lea r9, [rsp + 0x40]
    xor r8d, r8d
    xor edx, edx
    mov rcx, rbx
    call cast_ray
    test al, al
    je line_of_sight_clear
    movups xmm0, xmmword ptr [rsp + 0x60]
    movups xmm1, xmmword ptr [rsp + 0x50]
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
    jb line_of_sight_clear
    movabs rax, BLOCKED_RAY
    mov qword ptr [rax], rdi
    mov qword ptr [rax + 8], rsi
    movups xmm1, xmmword ptr [rsp + 0x40]
    movups xmmword ptr [rax + 0x10], xmm1
    movups xmm1, xmmword ptr [rsp + 0x50]
    movups xmmword ptr [rax + 0x20], xmm1
    movups xmm1, xmmword ptr [rsp + 0x60]
    movups xmmword ptr [rax + 0x30], xmm1
    mov rcx, qword ptr [rsp + 0x80]
    mov qword ptr [rax + 0x40], rcx
    inc dword ptr [rax + 0x48]
    xor eax, eax
    jmp line_of_sight_out_ray
line_of_sight_clear:
    mov al, 1
line_of_sight_out_ray:
    add rsp, 0xd0
    pop rdi
    pop rsi
    pop rbx
    ret

record_perceived:
    mov rcx, rsi
record_perceived_with_forget:
    movss xmm1, dword ptr [rcx + R_SEEN]
    xorps xmm2, xmm2
    xor eax, eax
    comiss xmm1, xmm2
    jbe record_perceived_done
    movss xmm2, dword ptr [rcx + R_EVALUATED]
    subss xmm2, xmm1
    comiss xmm2, dword ptr [rcx + R_FORGET]
    ja record_perceived_done
    mov al, 1
record_perceived_done:
    ret

now:
    xorps xmm0, xmm0
    mov rax, qword ptr [rip + clock_owner]
    test rax, rax
    je now_done
    mov rax, qword ptr [rax + 0x18]
    test rax, rax
    je now_done
    cvtsd2ss xmm0, qword ptr [rax + 0x10]
now_done:
    ret

find_record:
    mov rax, rdx
    mov edx, RECORD_COUNT
    xor r8d, r8d
find_record_loop:
    cmp qword ptr [rax], rcx
    je find_record_done
    test r8, r8
    jne find_record_next
    cmp qword ptr [rax], 0
    je find_record_free
    movaps xmm1, xmm0
    subss xmm1, dword ptr [rax + R_EVALUATED]
    comiss xmm1, dword ptr [rip + stale_window]
    jbe find_record_next
find_record_free:
    mov r8, rax
find_record_next:
    add rax, RECORD_SIZE
    dec edx
    jne find_record_loop
    mov rax, r8
    test rax, rax
    je find_record_done
    xor edx, edx
find_record_clear:
    mov qword ptr [rax + rdx * 8], 0
    inc edx
    cmp edx, RECORD_SIZE / 8
    jb find_record_clear
    mov qword ptr [rax], rcx
    mov eax, dword ptr [rip + default_time_to_unperceive]
    mov dword ptr [r8 + R_FORGET], eax
    mov rax, r8
find_record_done:
    ret

records_base:
    movabs rax, RECORDS_POINTER
    mov rax, qword ptr [rax]
    test rax, rax
    jne records_base_done
    push rbx
    sub rsp, 0x20
    movabs rcx, 0x1446b4110
    mov rcx, qword ptr [rcx]
    test rcx, rcx
    je records_base_fail
    mov edx, RECORD_COUNT * RECORD_SIZE
    mov r8d, 0x10
    xor r9d, r9d
    movabs rax, 0x1403bb060
    call rax
    test rax, rax
    je records_base_fail
    xor ecx, ecx
records_base_zero:
    mov qword ptr [rax + rcx * 8], 0
    inc ecx
    cmp ecx, RECORD_COUNT * RECORD_SIZE / 8
    jb records_base_zero
    movabs rcx, RECORDS_POINTER
    mov qword ptr [rcx], rax
    jmp records_base_out
records_base_fail:
    xor eax, eax
records_base_out:
    add rsp, 0x20
    pop rbx
records_base_done:
    ret

ai_component:
    movabs rdx, AI_COMPONENT
    jmp component

parameters:
    mov eax, dword ptr [rip + default_sight]
    mov dword ptr [r8], eax
    mov eax, dword ptr [rip + default_time_to_perceive]
    mov dword ptr [r8 + 4], eax
    mov eax, dword ptr [rip + default_time_to_unperceive]
    mov dword ptr [r8 + 8], eax
    mov eax, dword ptr [rip + default_broadcast]
    mov dword ptr [r8 + 0xc], eax
    mov dword ptr [r8 + 0x10], 0
    mov r11d, dword ptr [rdx + 0xc0]
    mov rax, qword ptr [rcx + 0x30]
    test rax, rax
    je parameters_store
    test al, 7
    jne parameters_store
    mov rax, qword ptr [rax + 0x70]
    test rax, rax
    je parameters_store
    test al, 7
    jne parameters_store
    mov r9d, dword ptr [rax - 4]
    and r9d, 0x7fffffff
    je parameters_store
    cmp r9d, 1024
    ja parameters_store
    movabs r10, PERCEPTION_DATA_TYPE
parameters_find:
    mov rcx, qword ptr [rax]
    test rcx, rcx
    je parameters_next
    test cl, 7
    jne parameters_next
    cmp qword ptr [rcx + 0x10], r10
    je parameters_data
parameters_next:
    add rax, 8
    dec r9d
    jne parameters_find
    ret
parameters_data:
    xorps xmm1, xmm1
    movss xmm0, dword ptr [rcx + 0xd0]
    comiss xmm0, xmm1
    jbe parameters_first_alert
    movss dword ptr [r8 + 0xc], xmm0
parameters_first_alert:
    movss xmm0, dword ptr [rcx + 0xd8]
    comiss xmm0, xmm1
    jbe parameters_states
    movss dword ptr [r8 + 0x10], xmm0
parameters_states:
    lea r10, [rcx + 0x88]
    mov rax, qword ptr [rcx + 0xc0]
    test rax, rax
    je parameters_entry
    mov r9d, dword ptr [rax - 4]
    and r9d, 0x7fffffff
    je parameters_entry
    cmp r9d, 64
    ja parameters_entry
parameters_state:
    cmp dword ptr [rax + 0x24], r11d
    je parameters_state_found
    add rax, 0x28
    dec r9d
    jne parameters_state
    jmp parameters_entry
parameters_state_found:
    mov r10, rax
parameters_entry:
    movss xmm0, dword ptr [r10]
    comiss xmm0, xmm1
    jb parameters_times
    movss dword ptr [r8], xmm0
parameters_times:
    movss xmm0, dword ptr [r10 + 0x18]
    comiss xmm0, xmm1
    jb parameters_unperceive
    movss dword ptr [r8 + 4], xmm0
parameters_unperceive:
    movss xmm0, dword ptr [r10 + 0x1c]
    comiss xmm0, xmm1
    jbe parameters_store
    movss dword ptr [r8 + 8], xmm0
parameters_store:
    ret

vitality:
    push rbx
    sub rsp, 0x30
    mov rbx, rcx
    xorps xmm0, xmm0
    movss dword ptr [rsp + 0x20], xmm0
    movabs rdx, SIMPLE_HEALTH
    call component
    test rax, rax
    jne vitality_health
    mov rcx, rbx
    movabs rdx, PLAYER_HEALTH
    call component
    test rax, rax
    je vitality_shield
vitality_health:
    movss xmm0, dword ptr [rax + 0x20]
    movss dword ptr [rsp + 0x20], xmm0
vitality_shield:
    mov rcx, rbx
    movabs rdx, SHIELD
    call component
    test rax, rax
    je vitality_out
    mov rax, qword ptr [rax + 0x50]
    test rax, rax
    je vitality_out
    test al, 3
    jne vitality_out
    movss xmm0, dword ptr [rsp + 0x20]
    addss xmm0, dword ptr [rax]
    movss dword ptr [rsp + 0x20], xmm0
vitality_out:
    movss xmm0, dword ptr [rsp + 0x20]
    add rsp, 0x30
    pop rbx
    ret

ray_counted:
    sub rsp, 0x28
    call line_of_sight
    inc dword ptr [rsi + R_RAYS]
    test al, al
    je ray_counted_blocked
    inc dword ptr [rsi + R_CLEAR]
    jmp ray_counted_out
ray_counted_blocked:
    movss dword ptr [rsi + R_GAP], xmm0
ray_counted_out:
    add rsp, 0x28
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

distance:
    mov r11, rdx
    call translation
    test rax, rax
    je distance_unknown
    movups xmm0, xmmword ptr [rax]
    mov rcx, r11
    call translation
    test rax, rax
    je distance_unknown
    movups xmm1, xmmword ptr [rax]
    subps xmm0, xmm1
    mulps xmm0, xmm0
    movaps xmm1, xmm0
    shufps xmm1, xmm1, 0x55
    movaps xmm2, xmm0
    shufps xmm2, xmm2, 0xaa
    addss xmm0, xmm1
    addss xmm0, xmm2
    sqrtss xmm0, xmm0
    ret
distance_unknown:
    movss xmm0, dword ptr [rip + unknown_distance]
    ret

context_entity:
    sub rsp, 0x28
    mov rax, qword ptr [rdx]
    mov rcx, rdx
    call qword ptr [rax + 0x10]
    test rax, rax
    je context_none
    mov rcx, rax
    call owner_entity
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
minimum_ray:
    .float 1.5
start_push:
    .float 1.0
target_tolerance:
    .float 2.0
unknown_distance:
    .float 1000000.0
damage_memory:
    .float 10.0
alive_window:
    .float 1.0
stale_window:
    .float 5.0
selection_period:
    .float 0.25
default_sight:
    .float 60.0
default_time_to_perceive:
    .float 0.5
default_time_to_unperceive:
    .float 10.0
default_broadcast:
    .float 30.0
damage_epsilon:
    .float 0.0001
