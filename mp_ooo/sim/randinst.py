import random

# Define register names for readability
registers = [f"x{i}" for i in range(32)]

def generate_register():
    return random.choice(registers)

def generate_imm():
    return random.randint(-2048, 2047)  # Immediate value for I-type instructions (-2048 to 2047)

def generate_u_imm():
    return random.randint(0, (1 << 20) - 1)  # Immediate value for U-type instructions (20 bits)

def generate_shamt():
    return random.randint(0, 31)  # Random shift amount from 0 to 31

# R-type instruction format
def generate_r_type(instr):
    rd = generate_register()
    rs1 = generate_register()
    rs2 = generate_register()
    return f"{instr} {rd}, {rs1}, {rs2}"

# I-type instruction format (immediate)
def generate_i_type(instr):
    rd = generate_register()
    rs1 = generate_register()
    imm = generate_imm()
    return f"{instr} {rd}, {rs1}, {imm}"

# I-type instruction format (shamt for shift instructions)
def generate_i_shamt_type(instr):
    rd = generate_register()
    rs1 = generate_register()
    shamt = generate_shamt()
    return f"{instr} {rd}, {rs1}, {shamt}"

def generate_aligned_imm():
    return random.randint(-512, 511)  # Immediate value for I-type instructions (-2048 to 2047)

# I-type instruction format (load)
def generate_i_load_type(instr):
    rd = generate_register()
    rs1 = generate_register()
    if instr in ['lh', 'lhu']:
        imm = generate_aligned_imm() * 2
    elif instr == 'lw':
        imm = generate_aligned_imm() * 4
    else:
        imm = generate_imm()
    return f"{instr} {rd}, {imm}({rs1})"

# U-type instruction format
def generate_u_type(instr):
    rd = generate_register()
    imm = generate_u_imm()
    return f"{instr} {rd}, {imm}"

# S-type instruction format (store instructions)
def generate_s_type(instr):
    rs1 = generate_register()
    rs2 = generate_register()
    if instr == 'sh':
        imm = generate_aligned_imm() * 2
    elif instr == 'sw':
        imm = generate_aligned_imm() * 4
    else:
        imm = generate_imm()
    return f"{instr} {rs2}, {imm}({rs1})"

# Generate a random instruction based on the instruction format
def generate_instruction():
    instr_type = random.choice([
        'add', 'sub', 'sll', 'srl', 'sra', 'and', 'or', 'xor', 
        'slt', 'sltu', 'addi', 'slli', 'srli', 'srai', 'andi', 
        'ori', 'xori', 'slti', 'sltiu', 'lui', 'auipc', 
        # 'sb', 'sh', 'sw', 'lb', 'lh', 'lw', 'lbu', 'lhu'
    ])
    
    if instr_type in ['add', 'sub', 'sll', 'srl', 'sra', 'and', 'or', 'xor', 'slt', 'sltu']:
        return generate_r_type(instr_type)
    elif instr_type in ['addi', 'andi', 'ori', 'xori', 'slti', 'sltiu']:
        return generate_i_type(instr_type)
    elif instr_type in ['slli', 'srli', 'srai']:
        return generate_i_shamt_type(instr_type)
    elif instr_type in ['lui', 'auipc']:
        return generate_u_type(instr_type)
    # elif instr_type in ['sb', 'sh', 'sw']:
    #     return generate_s_type(instr_type)
    # elif instr_type in ['lb', 'lh', 'lw', 'lbu', 'lhu']:
    #     return generate_i_load_type(instr_type)

# Generate an assembly program
def generate_asm_program(num_instructions):
    program = []
    for _ in range(num_instructions):
        program.append(generate_instruction())
        # program.extend(['nop'] * 5)  # Adding 5 nops between instructions
    # Append the magic instruction to end the simulation
    program.append("slti x0, x0, -256")
    return '\n'.join(program)

# Generate a random assembly program with 10 instructions plus the magic instruction
asm_program = generate_asm_program(10000)
print(asm_program)
