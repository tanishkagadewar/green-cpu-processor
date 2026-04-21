// ============================================================
// Testbench: single_cycle_cpu_tb
// Purpose: Integration testbench for the Milestone 1 single-
//          cycle CPU. Loads a program into instruction memory,
//          pre-loads data memory, runs simulation, and verifies
//          register and memory state after execution.
//
// Test Program (13 instructions):
//   0:  LH  R1, 0(R0)      -> R1 = mem[0] = 5
//   1:  LH  R2, 1(R0)      -> R2 = mem[1] = 3
//   2:  ADD R3, R1, R2      -> R3 = 5 + 3 = 8
//   3:  SUB R4, R1, R2      -> R4 = 5 - 3 = 2
//   4:  SLT R5, R2, R1      -> R5 = (3 < 5) = 1
//   5:  OR  R6, R1, R2      -> R6 = 5 | 3 = 7
//   6:  AND R7, R1, R2      -> R7 = 5 & 3 = 1
//   7:  SH  R3, 4(R0)       -> mem[4] = R3 = 8
//   8:  SLL R3, R1, R2      -> R3 = 5 << 3 = 40
//   9:  SRL R4, R1, R2      -> R4 = 5 >> 3 = 0
//   10: LH  R5, 2(R0)       -> R5 = mem[2] = 0xFFFF
//   11: SRA R6, R5, R2      -> R6 = 0xFFFF >>> 3 = 0xFFFF
//   12: LH  R7, 4(R0)       -> R7 = mem[4] = 8 (verify SH)
//
// Waveform Checkpoints:
//   - Monitor: clk, rst, pc, instruction, alu_result
//   - Monitor: rs1_data, rs2_data, write_data, reg_write
//   - Verify: register file contents after each instruction
//   - Verify: data memory at address 4 after SH instruction
// ============================================================

`timescale 1ns / 1ps

module single_cycle_cpu_tb;

    // --------------------------------------------------------
    // Clock and reset
    // --------------------------------------------------------
    reg clk;
    reg rst;

    // Clock generation: 10ns period (100 MHz)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --------------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------------
    single_cycle_cpu uut (
        .clk (clk),
        .rst (rst)
    );

    // --------------------------------------------------------
    // Test counters
    // --------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        // VCD dump for waveform viewing
        $dumpfile("single_cycle_cpu_tb.vcd");
        $dumpvars(0, single_cycle_cpu_tb);

        pass_count = 0;
        fail_count = 0;

        $display("============================================================");
        $display(" Milestone 1 — Single-Cycle CPU Testbench");
        $display("============================================================");

        // ----------------------------------------------------
        // Pre-load data memory with test values
        // ----------------------------------------------------
        uut.u_dmem.mem[0] = 16'h0005;  // 5
        uut.u_dmem.mem[1] = 16'h0003;  // 3
        uut.u_dmem.mem[2] = 16'hFFFF;  // -1 (signed)
        uut.u_dmem.mem[3] = 16'h0008;  // 8

        // ----------------------------------------------------
        // Load program into instruction memory
        // Encoding: see control_unit.v for full ISA table
        // ----------------------------------------------------
        // R-Type: [15:12 op=0000][11:9 rd][8:6 rs1][5:3 rs2][2:0 funct]
        // I-Type: [15:12 op=0001][11:9 rd][8:6 rs1][5:0 imm6]
        // S-Type: [15:12 op=0010][11:9 rs2][8:6 rs1][5:0 imm6]

        uut.u_imem.mem[0]  = 16'h1200;  // LH  R1, 0(R0)
        uut.u_imem.mem[1]  = 16'h1401;  // LH  R2, 1(R0)
        uut.u_imem.mem[2]  = 16'h0650;  // ADD R3, R1, R2
        uut.u_imem.mem[3]  = 16'h0851;  // SUB R4, R1, R2
        uut.u_imem.mem[4]  = 16'h0A8A;  // SLT R5, R2, R1
        uut.u_imem.mem[5]  = 16'h0C53;  // OR  R6, R1, R2
        uut.u_imem.mem[6]  = 16'h0E54;  // AND R7, R1, R2
        uut.u_imem.mem[7]  = 16'h2604;  // SH  R3, 4(R0)
        uut.u_imem.mem[8]  = 16'h0656;  // SLL R3, R1, R2
        uut.u_imem.mem[9]  = 16'h0855;  // SRL R4, R1, R2
        uut.u_imem.mem[10] = 16'h1A02;  // LH  R5, 2(R0)
        uut.u_imem.mem[11] = 16'h0D57;  // SRA R6, R5, R2
        uut.u_imem.mem[12] = 16'h1E04;  // LH  R7, 4(R0)

        // ----------------------------------------------------
        // Reset sequence: 2 cycles
        // ----------------------------------------------------
        rst = 1'b1;
        @(posedge clk);
        @(posedge clk);
        rst = 1'b0;

        $display("Reset released at time %0t", $time);

        // ----------------------------------------------------
        // Run 14 cycles to complete all 13 instructions
        // (each instruction executes in 1 cycle; result is
        //  written back at the following posedge)
        // ----------------------------------------------------
        repeat (14) @(posedge clk);
        #1;  // Allow combinational logic to settle

        // ----------------------------------------------------
        // Verify Register File State
        // ----------------------------------------------------
        $display("");
        $display("--- Register File Verification ---");

        // R1 = 5 (loaded from mem[0])
        if (uut.u_regfile.registers[1] === 16'h0005) begin
            $display("[PASS] R1 = 0x%04h (expected 0x0005)", uut.u_regfile.registers[1]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R1 = 0x%04h (expected 0x0005)", uut.u_regfile.registers[1]);
            fail_count = fail_count + 1;
        end

        // R2 = 3 (loaded from mem[1])
        if (uut.u_regfile.registers[2] === 16'h0003) begin
            $display("[PASS] R2 = 0x%04h (expected 0x0003)", uut.u_regfile.registers[2]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R2 = 0x%04h (expected 0x0003)", uut.u_regfile.registers[2]);
            fail_count = fail_count + 1;
        end

        // R3: was ADD(8), then SLL(5<<3=40=0x28). Final = 0x0028
        if (uut.u_regfile.registers[3] === 16'h0028) begin
            $display("[PASS] R3 = 0x%04h (expected 0x0028 = SLL 5<<3)", uut.u_regfile.registers[3]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R3 = 0x%04h (expected 0x0028 = SLL 5<<3)", uut.u_regfile.registers[3]);
            fail_count = fail_count + 1;
        end

        // R4: was SUB(2), then SRL(5>>3=0). Final = 0x0000
        if (uut.u_regfile.registers[4] === 16'h0000) begin
            $display("[PASS] R4 = 0x%04h (expected 0x0000 = SRL 5>>3)", uut.u_regfile.registers[4]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R4 = 0x%04h (expected 0x0000 = SRL 5>>3)", uut.u_regfile.registers[4]);
            fail_count = fail_count + 1;
        end

        // R5: was SLT(1), then LH(mem[2]=0xFFFF). Final = 0xFFFF
        if (uut.u_regfile.registers[5] === 16'hFFFF) begin
            $display("[PASS] R5 = 0x%04h (expected 0xFFFF = mem[2])", uut.u_regfile.registers[5]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R5 = 0x%04h (expected 0xFFFF = mem[2])", uut.u_regfile.registers[5]);
            fail_count = fail_count + 1;
        end

        // R6: was OR(7), then SRA(0xFFFF>>>3=0xFFFF). Final = 0xFFFF
        if (uut.u_regfile.registers[6] === 16'hFFFF) begin
            $display("[PASS] R6 = 0x%04h (expected 0xFFFF = SRA 0xFFFF>>>3)", uut.u_regfile.registers[6]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R6 = 0x%04h (expected 0xFFFF = SRA 0xFFFF>>>3)", uut.u_regfile.registers[6]);
            fail_count = fail_count + 1;
        end

        // R7: was AND(1), then LH(mem[4]=8). Final = 0x0008
        // This also verifies the SH instruction stored correctly
        if (uut.u_regfile.registers[7] === 16'h0008) begin
            $display("[PASS] R7 = 0x%04h (expected 0x0008 = mem[4], verifies SH)", uut.u_regfile.registers[7]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R7 = 0x%04h (expected 0x0008 = mem[4], verifies SH)", uut.u_regfile.registers[7]);
            fail_count = fail_count + 1;
        end

        // ----------------------------------------------------
        // Verify Data Memory
        // ----------------------------------------------------
        $display("");
        $display("--- Data Memory Verification ---");

        // DMEM[4] should be 8 (stored by SH at instruction 7)
        if (uut.u_dmem.mem[4] === 16'h0008) begin
            $display("[PASS] DMEM[4] = 0x%04h (expected 0x0008)", uut.u_dmem.mem[4]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] DMEM[4] = 0x%04h (expected 0x0008)", uut.u_dmem.mem[4]);
            fail_count = fail_count + 1;
        end

        // Original data should be intact
        if (uut.u_dmem.mem[0] === 16'h0005) begin
            $display("[PASS] DMEM[0] = 0x%04h (original data intact)", uut.u_dmem.mem[0]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] DMEM[0] = 0x%04h (expected 0x0005)", uut.u_dmem.mem[0]);
            fail_count = fail_count + 1;
        end

        if (uut.u_dmem.mem[1] === 16'h0003) begin
            $display("[PASS] DMEM[1] = 0x%04h (original data intact)", uut.u_dmem.mem[1]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] DMEM[1] = 0x%04h (expected 0x0003)", uut.u_dmem.mem[1]);
            fail_count = fail_count + 1;
        end

        // ----------------------------------------------------
        // Summary
        // ----------------------------------------------------
        $display("");
        $display("============================================================");
        $display(" TEST SUMMARY: %0d PASSED, %0d FAILED (of %0d total)",
                 pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display(" >>> ALL TESTS PASSED <<<");
        else
            $display(" >>> SOME TESTS FAILED <<<");
        $display("============================================================");

        $finish;
    end

    // --------------------------------------------------------
    // Cycle-by-cycle monitor for debugging
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            $display("[CYCLE] t=%0t PC=%0d INST=0x%04h ALU_A=%0d ALU_B=%0d ALU_OUT=0x%04h WB=0x%04h RW=%b MR=%b MW=%b",
                     $time,
                     uut.pc,
                     uut.instruction,
                     uut.rs1_data,
                     uut.alu_input_b,
                     uut.alu_result,
                     uut.write_data,
                     uut.reg_write,
                     uut.mem_read,
                     uut.mem_write);
        end
    end

endmodule
