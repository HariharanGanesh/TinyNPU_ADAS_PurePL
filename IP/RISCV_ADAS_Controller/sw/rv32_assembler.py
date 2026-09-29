"""
rv32_assembler.py - PicoRV32 RV32I Assembler
Project: RISCV_ADAS_NPU300

Supported instructions:
  LUI, ADDI, LW, SW, J (JAL x0), BNE, LI (pseudo: LUI+ADDI), NOP
  ANDI added for bitmask operations
"""
import sys
import re

def parse_reg(r):
    r = r.strip().replace(',', '')
    if r.startswith('x'): return int(r[1:])
    if r == 'zero': return 0
    if r == 'ra':   return 1
    if r == 'sp':   return 2
    if r == 'gp':   return 3
    if r == 'tp':   return 4
    if r.startswith('t'):
        t = int(r[1:])
        return t + 5 if t <= 2 else t + 25
    if r.startswith('a'):
        return int(r[1:]) + 10
    if r.startswith('s'):
        s = int(r[1:])
        return 8 if s == 0 else 9 if s == 1 else s + 16
    return int(r)

def parse_imm(imm, labels, pc):
    imm = imm.strip().replace(',', '')
    if imm in labels:
        return labels[imm] - pc
    if imm.startswith('0x'):  return int(imm, 16)
    if imm.startswith('-0x'): return -int(imm[3:], 16)
    return int(imm)

def sign_extend(val, bits):
    """Sign-extend an integer to 'bits' wide."""
    if val >= (1 << (bits - 1)):
        val -= (1 << bits)
    return val

def assemble(lines):
    labels = {}
    instructions = []
    pc = 0

    # First pass: collect labels and instructions
    for line in lines:
        line = line.split('#')[0].strip()
        if not line:
            continue
        if ':' in line:
            label, rest = line.split(':', 1)
            labels[label.strip()] = pc
            line = rest.strip()
        if line:
            # Handle LI pseudo as two instructions (counts as 2 words)
            parts = re.findall(r'[\w\-\.+]+', line)
            opcode = parts[0].lower() if parts else ''
            if opcode == 'li':
                instructions.append((pc, line))
                pc += 8  # LI expands to LUI + ADDI = 2 words
            else:
                instructions.append((pc, line))
                pc += 4

    machine_code = []
    for pc, line in instructions:
        parts = re.findall(r'[\w\-\.+]+', line)
        opcode = parts[0].lower()

        if opcode == 'lui':
            rd  = parse_reg(parts[1])
            imm = parse_imm(parts[2], labels, pc)
            inst = ((imm & 0xFFFFF) << 12) | (rd << 7) | 0x37
            machine_code.append(inst)

        elif opcode == 'addi':
            rd  = parse_reg(parts[1])
            rs1 = parse_reg(parts[2])
            imm = parse_imm(parts[3], labels, pc) & 0xFFF
            inst = (imm << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13
            machine_code.append(inst)

        elif opcode == 'andi':
            rd  = parse_reg(parts[1])
            rs1 = parse_reg(parts[2])
            imm = parse_imm(parts[3], labels, pc) & 0xFFF
            inst = (imm << 20) | (rs1 << 15) | (7 << 12) | (rd << 7) | 0x13
            machine_code.append(inst)

        elif opcode == 'lw':
            rd = parse_reg(parts[1])
            # Support both "lw rd, imm(rs1)" and "lw rd imm rs1"
            rest = line.split(parts[1], 1)[1].strip().lstrip(',').strip()
            match = re.match(r'(-?\w+)\((\w+)\)', rest)
            if match:
                imm = parse_imm(match.group(1), labels, pc) & 0xFFF
                rs1 = parse_reg(match.group(2))
            else:
                imm = parse_imm(parts[2], labels, pc) & 0xFFF
                rs1 = parse_reg(parts[3])
            inst = (imm << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03
            machine_code.append(inst)

        elif opcode == 'sw':
            rs2 = parse_reg(parts[1])
            rest = line.split(parts[1], 1)[1].strip().lstrip(',').strip()
            match = re.match(r'(-?\w+)\((\w+)\)', rest)
            if match:
                imm = parse_imm(match.group(1), labels, pc) & 0xFFF
                rs1 = parse_reg(match.group(2))
            else:
                imm = parse_imm(parts[2], labels, pc) & 0xFFF
                rs1 = parse_reg(parts[3])
            imm11_5 = (imm >> 5) & 0x7F
            imm4_0  = imm & 0x1F
            inst = (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | (imm4_0 << 7) | 0x23
            machine_code.append(inst)

        elif opcode in ('j', 'jal') and (len(parts) == 2 or (len(parts) == 3 and parse_reg(parts[1]) == 0)):
            # j label  OR  jal x0, label
            label_or_imm = parts[-1]
            imm = parse_imm(label_or_imm, labels, pc)
            imm20    = (imm >> 20) & 1
            imm10_1  = (imm >> 1)  & 0x3FF
            imm11    = (imm >> 11) & 1
            imm19_12 = (imm >> 12) & 0xFF
            inst = (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | (0 << 7) | 0x6F
            machine_code.append(inst)

        elif opcode == 'bne':
            rs1 = parse_reg(parts[1])
            rs2 = parse_reg(parts[2])
            imm = parse_imm(parts[3], labels, pc)
            imm12   = (imm >> 12) & 1
            imm10_5 = (imm >> 5)  & 0x3F
            imm4_1  = (imm >> 1)  & 0xF
            imm11   = (imm >> 11) & 1
            inst = (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (1 << 12) | (imm4_1 << 8) | (imm11 << 7) | 0x63
            machine_code.append(inst)

        elif opcode == 'beq':
            rs1 = parse_reg(parts[1])
            rs2 = parse_reg(parts[2])
            imm = parse_imm(parts[3], labels, pc)
            imm12   = (imm >> 12) & 1
            imm10_5 = (imm >> 5)  & 0x3F
            imm4_1  = (imm >> 1)  & 0xF
            imm11   = (imm >> 11) & 1
            inst = (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (0 << 12) | (imm4_1 << 8) | (imm11 << 7) | 0x63
            machine_code.append(inst)

        elif opcode == 'li':
            # Pseudo-instruction: expands to LUI + ADDI
            rd  = parse_reg(parts[1])
            imm = parse_imm(parts[2], labels, pc)
            upper = (imm + 0x800) >> 12
            lower = imm & 0xFFF
            if lower >= 0x800:  # sign bit set: lower is negative as 12-bit
                lower -= 0x1000
            inst_lui  = ((upper & 0xFFFFF) << 12) | (rd << 7) | 0x37
            inst_addi = ((lower & 0xFFF)   << 20) | (rd << 15) | (0 << 12) | (rd << 7) | 0x13
            machine_code.append(inst_lui)
            machine_code.append(inst_addi)

        elif opcode == 'nop':
            machine_code.append(0x00000013)  # addi x0, x0, 0

        else:
            raise ValueError(f"Unknown opcode: '{opcode}' in line: '{line}'")

    return machine_code


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python rv32_assembler.py <input.s> <output.hex>")
        sys.exit(1)

    with open(sys.argv[1], 'r') as f:
        lines = f.readlines()

    code = assemble(lines)

    with open(sys.argv[2], 'w') as f:
        for word in code:
            f.write(f"{word & 0xFFFFFFFF:08x}\n")

    print(f"Assembled {len(code)} instructions -> {sys.argv[2]}")
