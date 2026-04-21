# Milestone 3 — IEEE 754 Half-Precision Floating Point Unit (FPU)

## Overview
This milestone introduces Floating Point capabilities by implementing a hardware-compliant IEEE 754 Half-Precision FPU (FP16). 

## Architecture
We designed the FPU natively as pure combinational logic rather than multi-cycle. A custom 16-bit operand width yields highly manageable critical paths and natively supports immediate integration into a CPU datapath without rigid handshaking limits.

### Components
1. **Adder (`fp16_fadd.v`)**: 
   - Handles full IEEE 754 arithmetic alignment shifting.
   - Leverages Leading Zero Counting (LZC) for exact normalization.
   - Hardwired for Round-to-Nearest-Even (RNE) rounding logic.
2. **Multiplier (`fp16_fmul.v`)**:
   - Executes an 11×11 mantissa product scale.
   - Detects overflow and underflow strictly.
3. **Wrapper (`fpu.v`)**:
   - A top-level module multiplexing FADD and FMUL outputs against the CPU core requests natively.

### Special Cases Handled
- **Not a Number (NaN)** propagation
- ± Infinity handling (+Inf + -Inf = NaN)
- Signed zeros (±0)
- Deep Denormal Input / Output management

## Simulation Results
The `fpu_tb.v` runs 20 directed test cases exploring mathematical edges across the combinations.
* **Final Check**: 20/20 verification checks **PASSED**.

## How to Simulate
```bash
# Compile
C:\iverilog\bin\iverilog.exe -o fpu_tb.vvp src/*.v tb/fpu_tb.v

# Run
C:\iverilog\bin\vvp.exe fpu_tb.vvp
```
