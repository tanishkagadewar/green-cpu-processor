# Milestone 5 — Cryptographic Co-Processor

## Overview
The culmination of the 16-bit processor, integrating native hardware-accelerated encryption directly into the pipelined CPU core.

## Cipher Specifications
Built completely from scratch inside `crypto_coprocessor.v`.
* **Cipher Methodology**: Uses a 16-bit Substitution-Permutation Network (SPN).
* **S-Box**: Employs a 4-bit bijective PRESENT S-box pattern evaluated directly across nibbles.
* **Key Schedule**: Employs an exact rotation architecture paired against mapped XOR sequences to produce five separate cipher round variations natively.
* **Design Control**:
  - Implements strict multi-cycle processing (1 instruction requires 5 clock cycles of evaluation constraint).
  - Uses a formal native handshake architecture across the system (`done` ping resolution).

## Integration with CPU
The Control Unit intercepts custom special formats leveraging opcode bits (`1111`).
* **ENC** *(Encrypt)*: Evaluates using plaintext registers combined with an active key generating ciphertext natively.
* **DEC** *(Decrypt)*: Pushes the exact reverse inverse calculations scaling backward with ciphertext into decrypted plaintext format. 
* Triggers custom stalls globally out of the execution layer dynamically protecting operations across the pipeline perfectly without data loss.

## Simulation Results
Our integration `pipelined_cpu_tb.v` test script formally tests active round-trip cycles scaling dynamically. (Registers Plaintext = `26`, Key = `7`)
1. Translates into full Ciphertext: `0xE9F8` 
2. Safely waits dynamically pausing pipeline operations fully.
3. Translates back correctly recovering the full format: `26`.
* **Final Check**: 5/5 verifications **PASSED**.

## How to Simulate
```bash
# Compile
C:\iverilog\bin\iverilog.exe -o m5_tb.vvp src/*.v tb/pipelined_cpu_tb.v

# Run
C:\iverilog\bin\vvp.exe m5_tb.vvp
```
