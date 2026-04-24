# 16-bit RISC-V-Style Processor

![Verilog](https://img.shields.io/badge/Language-Verilog-blue)
![Simulation](https://img.shields.io/badge/Simulation-Icarus_Verilog-green)
![Platform](https://img.shields.io/badge/Platform-FPGA_Ready-orange)
![License](https://img.shields.io/badge/License-MIT-purple)

**A complete, custom-built 16-bit pipelined CPU written from scratch in Verilog.**

This project traces the iterative construction of a digital hardware processor, evolving from a simple single-cycle datapath into a 5-stage pipelined architecture equipped with an IEEE-754 Half-Precision FPU (Floating Point Unit) and a deeply integrated Cryptographic Co-Processor.

## 🏗️ Architecture Highlights
* **Instruction Set Architecture (ISA)**: Custom tightly-packed 16-bit encoding with exactly 16 opcodes and 7 formats (R, I, S, IS, B, J, JALR).
* **Memory Model**: Harvard Architecture (separate isolated Instruction ROM and Data RAM boundaries), natively word-addressed.
* **General-Purpose Registers**: 8 × 16-bit registers (R0 hardwired to `0`).
* **Datapath Pipeline**: Highly cohesive 5-stage pipeline (`IF` → `ID` → `EX` → `MEM` → `WB`).
* **Simulation Validated**: Verified completely via Icarus Verilog and GTKWave directly natively using rigorous directed testbenches mapping branches, forwards, and complex jumps flawlessly. 

> *Note: A block diagram of the architecture and pipeline layout can be referenced in the design documentation.*

---

## 📈 Evolution & Milestones

The project is structured entirely inside 5 precise directories detailing iteration growth cleanly. (**Note:** Every milestone folder contains an isolated `walkthrough.md` exploring its distinct implementations and testing routines.)

### 📌 Milestone 1: Single-Cycle Core
Base implementation evaluating 10 commands targeting logic routines, shifting evaluations, basic load (`LH`), and basic store (`SH`). Features an early isolated central `control_unit.v`.

### 🔀 Milestone 2: ISA Extension
Expands control flow logic capabilities adding 15 new instructions. Natively injects branch-specific evaluation comparators routing taken jumps to target addresses, extending jump linking correctly.

### 🧮 Milestone 3: IEEE 754 Half-Precision FPU
Introduces `fp16_fadd` and `fp16_fmul`. Designed as a pure combinational hardware abstraction computing alignment shifting securely with strictly enforced Round-to-Nearest-Even (RNE) compliance and NaN/Infinity bounds.

### 🏎️ Milestone 4: 5-Stage Pipelined Setup
Rebuilds the CPU logic utilizing isolated pipeline registers targeting advanced performance limits. Fully implements:
* **Forwarding Check**: Re-routing EX/MEM output streams dynamically catching Read-After-Write (RAW) exceptions instantaneously. 
* **Load-Use Execution Limits**: Calculating memory delay bounds halting inputs strictly with temporary bubbles logic perfectly mapped out.
* **Branch Flushing Operations**: Imposes hard jumps killing broken path progression entirely.

### 🔐 Milestone 5: Cryptographic Co-Processor
Replaces abstract boundaries with custom encryption hardware natively inside the `EX` pipeline stage. Implements a multi-cycle (5-cycle latency) 16-bit Substitution-Permutation Network (SPN) cipher running over an optimized 4-bit PRESENT S-box pattern triggered specifically by new `ENC`/`DEC` CPU commands directly.

---

## 🚀 Quick Start & Simulation Tools

To explore the architecture directly locally you only require **Icarus Verilog** and **GTKWave**.

All milestone code variants include independent `tb/` (testbench) routines. Simply run Icarus (`iverilog`) targeting a milestone's `src` files against its testing script.

*Example simulating Milestone 5 natively:*
```bash
# 1. Compile 
iverilog -o cpu_tb.vvp milestone5/src/*.v milestone5/tb/pipelined_cpu_tb.v

# 2. Run outputs
vvp cpu_tb.vvp

# 3. Analyze waveforms graphically 
gtkwave m5_crypto_tb.vcd
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
