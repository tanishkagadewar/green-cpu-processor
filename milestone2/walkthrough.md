# Milestone 2 — ISA Extension (Single-Cycle Datapath)

## Overview
This milestone extends the basic single-cycle core from Milestone 1 to support control flow operations, I-type formatting (immediates), and immediate-based shifts.

## What Was Added
- **Branch Comparator**: Evaluates condition flags necessary for executing branching logic.
- **Multiplexers**:
  - **4-way PC Mux**: Allows routing for sequential progression (PC+1), branch targets, JAL targets, and JALR targets.
  - **3-way Write-Back Mux**: Supports returning ALU results, memory load data, or Link register targets (PC+1).
- **Multi-Format Immediate Generator**: Extends logic covering 6-bit sign-extensions, 9-bit sign-extensions (for JAL), and 4-bit zero-extensions (for shift amounts).

## Newly Supported Instructions
| Category | Instructions |
|----------|-------------|
| **I-Type ALU** | ADDI, SUBI, ORI, ANDI, SLTI |
| **Immediate Shifts** | SRLI, SLLI, SRAI |
| **Branches** | BEQ, BNE, BLT, BGE |
| **Jumps** | JAL, JALR |

## Simulation Results
The `single_cycle_cpu_tb.v` tests a 28-instruction program covering all new branches (both taken and not taken paths).
* **Final Check**: 8/8 verification checks executed and **PASSED**.
* Proved subroutine nesting and logic bounds perfectly handled.

## How to Simulate
```bash
# Compile
C:\iverilog\bin\iverilog.exe -o m2_cpu_tb.vvp src/*.v tb/single_cycle_cpu_tb.v

# Run
C:\iverilog\bin\vvp.exe m2_cpu_tb.vvp
```
