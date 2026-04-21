# Green CPU — 16-bit RISC-V-Style Processor in Verilog

A complete, custom-built 16-bit pipelined processor written from scratch in Verilog HDL. This project traces the iterative construction of a digital CPU — evolving from a simple single-cycle datapath into a 5-stage pipelined architecture with an IEEE-754 Half-Precision FPU and a hardware Cryptographic Co-Processor.

Simulated and verified using **Icarus Verilog** and **GTKWave** across 51 test cases with a 100% pass rate.

---

## Architecture Highlights

| Feature | Details |
|---|---|
| **ISA** | Custom 16-bit encoding — 16 opcodes, 7 formats (R, I, S, IS, B, J, JALR) |
| **Memory** | Harvard Architecture — separate Instruction ROM and Data RAM |
| **Registers** | 8 × 16-bit general-purpose (R0 hardwired to `0`) |
| **Pipeline** | 5-stage: `IF → ID → EX → MEM → WB` |
| **CPI** | 1.11 measured (90% pipeline efficiency) |
| **FPU** | IEEE-754 Half-Precision (fp16) FADD and FMUL |
| **Crypto** | 16-bit SPN cipher with 4-bit PRESENT S-box |

---

## Project Structure

```
green-cpu-processor/
├── milestone1/          # Single-cycle core (10 instructions)
│   ├── src/             # RTL source files
│   ├── tb/              # Testbench
│   └── walkthrough.md   # Design notes & test results
├── milestone2/          # ISA extension (+15 instructions, branches, jumps)
├── milestone3/          # IEEE-754 fp16 FPU (FADD, FMUL)
├── milestone4/          # 5-stage pipeline (forwarding, hazard detection)
└── milestone5/          # Cryptographic co-processor (ENC/DEC instructions)
```

---

## Milestones

### Milestone 1 — Single-Cycle Core
Base implementation with 10 instructions covering arithmetic (ADD, SUB, SLT), logic (OR, AND), shifts (SLL, SRL, SRA), and memory access (LH, SH). All 5 datapath stages execute in a single clock cycle.

**Modules:** `pc_register`, `instruction_memory`, `register_file`, `alu`, `data_memory`, `sign_extend`, `control_unit`, `single_cycle_cpu` (top)

### Milestone 2 — ISA Extension
Expands the ISA with 15 new instructions — branch comparators (BEQ, BNE, BLT, BGE), immediate arithmetic (ADDI, SLTI, ORI, ANDI), and jump-link (JAL, JALR). Tests branch-taken and branch-not-taken paths.

### Milestone 3 — IEEE-754 Half-Precision FPU
Standalone FPU supporting fp16 addition and multiplication. Implements Round-to-Nearest-Even (RNE) with full NaN/Infinity handling. Designed as a pure combinational unit for integration into the pipeline EX stage.

**Modules:** `fp16_fadd`, `fp16_fmul`, `fpu`

### Milestone 4 — 5-Stage Pipelined CPU
Full rebuild into a 5-stage pipeline with:
- **Forwarding Unit** — EX/MEM → EX data forwarding to resolve RAW hazards without stalling
- **Hazard Detection Unit** — Load-use stall insertion (1-cycle bubble)
- **Branch Flushing** — Incorrect-path instruction squashing on taken branches

**Measured CPI: 1.11 | Pipeline Efficiency: 90%**

### Milestone 5 — Cryptographic Co-Processor
Hardware-accelerated encryption integrated directly into the EX pipeline stage. Implements a 16-bit Substitution-Permutation Network (SPN) cipher with 4 rounds, triggered by new `ENC`/`DEC` opcodes. Multi-cycle (5 clock cycle) handshake stalls the pipeline cleanly while the co-processor operates.

**Verified:** Plaintext `26` → Ciphertext `0xE9F8` → Decrypted `26` ✅

---

## Quick Start

**Requirements:** [Icarus Verilog](http://iverilog.icarus.com/) + [GTKWave](http://gtkwave.sourceforge.net/)

```bash
# Example: Simulate Milestone 5 (full pipelined CPU with crypto)
iverilog -o m5_tb.vvp milestone5/src/*.v milestone5/tb/pipelined_cpu_tb.v
vvp m5_tb.vvp

# View waveforms (VCD file generated in current directory)
gtkwave m5_crypto_tb.vcd
```

Each milestone folder contains its own `walkthrough.md` with simulation commands, expected outputs, and GTKWave signal guides.

---

## Test Results Summary

| Milestone | Test Cases | Result |
|---|---|---|
| M1 — Single-Cycle | 13 instructions | ✅ 13/13 PASS |
| M2 — ISA Extension | 10 instructions | ✅ 10/10 PASS |
| M3 — FPU | 8 operations | ✅ 8/8 PASS |
| M4 — Pipeline | 15 instructions | ✅ 15/15 PASS |
| M5 — Crypto | 5 round-trip tests | ✅ 5/5 PASS |
| **Total** | **51** | **✅ 51/51 (100%)** |

---

## Tools Used

- **Icarus Verilog** — Simulation & compilation
- **GTKWave** — Waveform analysis
- **Verilog HDL** — RTL design language

---

## Author

**Tanishka Gadewar** — Electronics & Communication Engineering, PICT Pune  
Built as part of a structured hardware design curriculum covering RTL design, pipeline architecture, FPU implementation, and hardware security.
