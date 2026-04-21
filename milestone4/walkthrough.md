# Milestone 4 — 5-Stage Pipelined Architecture

## Overview
This phase dramatically restructures the single-cycle CPU by dividing operations over a high-performance **5-Stage Pipeline**.

## The 5 Stages
1. **Instruction Fetch (IF)**: PC logic and Instruction ROM memory reads.
2. **Instruction Decode (ID)**: Control unit triggering, and RegFile reading.
3. **Execution (EX)**: Arithmetic ALU operations, FPU combinational processing, and Branch evaluation.
4. **Memory Access (MEM)**: Data RAM read and write execution.
5. **Write Back (WB)**: RegFile finalizing data writes.

## Hazard & Conflict Implementations
Converting into a pipeline inherently creates risks that our custom hardware explicitly counter-balances:

* **Full Data Forwarding** (`forwarding_unit.v`) 
  - Routes EX/MEM and MEM/WB stage pipelines completely backward towards the EX stage resolving *Read-After-Write (RAW)* issues perfectly natively.
  - Implements a *Write-Before-Read Register File* to resolve direct WB→ID same-cycle stalling.
* **Pipeline Stalls** (`hazard_unit.v`)
  - Evaluates direct Load-Use stalls by actively calculating and freezing IF/ID inputs and inserting a precise **1-Cycle System Bubble**.
* **Branch Flushing**
  - Handles control flow penalties evaluating inside the EX stage with a forced 2-cycle flush mechanism to kill speculative paths instantly.

## Simulation Results
The `pipelined_cpu_tb.v` tests forwarding paths, load-use data stall injections, and true branch jumps together to stress the hazard implementations in real time.
* **Final Check**: 8/8 test bench verifications **PASSED**.

## How to Simulate
```bash
# Compile
C:\iverilog\bin\iverilog.exe -o m4_tb.vvp src/*.v tb/pipelined_cpu_tb.v

# Run
C:\iverilog\bin\vvp.exe m4_tb.vvp
```
