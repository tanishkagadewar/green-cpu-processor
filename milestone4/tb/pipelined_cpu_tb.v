// ============================================================
// Testbench: pipelined_cpu_tb (Milestone 4)
// Tests: forwarding, load-use stall, branch flushing
//
// Program:
//  0: ADDI R1, R0, 10   R1=10
//  1: ADDI R2, R1, 5    R2=15 (EX/MEM forwarding)
//  2: ADD  R3, R1, R2   R3=25 (EX/MEM + MEM/WB forwarding)
//  3: SUB  R4, R3, R1   R4=15 (forwarding chain)
//  4: SH   R1, 0(R0)    mem[0] = 10
//  5: LH   R5, 0(R0)    R5=10 (load from mem)
//  6: ADD  R6, R5, R1   R6=20 (load-use: needs stall)
//  7: BEQ  R0, R0, 2    taken → PC+2=9 (flush 2 insts)
//  8: ADDI R7, R0, 99   [FLUSHED]
//  9: ADDI R7, R0, 42   R7=42
// 10: BEQ  R0, R0, 0    halt loop
//
// Encodings (from M2 ISA):
//  ADDI: op=0011 | ADD: op=0000,funct=000 | SUB: funct=001
//  SH: op=0010 | LH: op=0001 | BEQ: op=1001
// ============================================================

`timescale 1ns / 1ps

module pipelined_cpu_tb;

    reg clk, rst;
    initial clk = 0;
    always #5 clk = ~clk;

    pipelined_cpu uut (.clk(clk), .rst(rst));

    integer pass_count, fail_count;

    initial begin
        $dumpfile("m4_pipeline_tb.vcd");
        $dumpvars(0, pipelined_cpu_tb);
        pass_count = 0; fail_count = 0;

        $display("============================================================");
        $display(" Milestone 4 — Pipelined CPU Testbench");
        $display("============================================================");

        // ---- Load Program ----
        // 0: ADDI R1, R0, 10 → 0011_001_000_001010 = 0x320A
        uut.u_imem.mem[0]  = 16'h320A;
        // 1: ADDI R2, R1, 5  → 0011_010_001_000101 = 0x3445
        uut.u_imem.mem[1]  = 16'h3445;
        // 2: ADD R3, R1, R2  → 0000_011_001_010_000 = 0x0650
        uut.u_imem.mem[2]  = 16'h0650;
        // 3: SUB R4, R3, R1  → 0000_100_011_001_001 = 0x08C9
        uut.u_imem.mem[3]  = 16'h08C9;
        // 4: SH R1, 0(R0)    → 0010_001_000_000000 = 0x2200
        uut.u_imem.mem[4]  = 16'h2200;
        // 5: LH R5, 0(R0)    → 0001_101_000_000000 = 0x1A00
        uut.u_imem.mem[5]  = 16'h1A00;
        // 6: ADD R6, R5, R1   → 0000_110_101_001_000 = 0x0D48
        uut.u_imem.mem[6]  = 16'h0D48;
        // 7: BEQ R0, R0, 2   → 1001_000_000_000010 = 0x9002
        uut.u_imem.mem[7]  = 16'h9002;
        // 8: ADDI R7, R0, 99 → should be flushed (value doesn't matter for result)
        uut.u_imem.mem[8]  = 16'h3E1F;  // ADDI R7, R0, 31 (stand-in)
        // 9: ADDI R7, R0, 25 → 0011_111_000_011001 = 0x3E19 (after branch)
        uut.u_imem.mem[9]  = 16'h3E19;
        // 10: BEQ R0, R0, 0  → halt loop
        uut.u_imem.mem[10] = 16'h9000;

        // ---- Reset ----
        rst = 1;
        repeat(3) @(posedge clk);
        rst = 0;

        // Run enough cycles for all instructions + pipeline drain
        // With stalls and flushes, ~25 cycles should be plenty
        repeat(30) @(posedge clk);
        #1;

        // ---- Verify Results ----
        $display("");
        $display("--- Forwarding Verification ---");

        // R1 = 10
        if (uut.u_regfile.registers[1] === 16'd10) begin
            $display("[PASS] R1 = %0d (ADDI)", uut.u_regfile.registers[1]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R1 = %0d (expected 10)", uut.u_regfile.registers[1]);
            fail_count = fail_count + 1;
        end

        // R2 = 15 (R1+5, EX/MEM forwarding)
        if (uut.u_regfile.registers[2] === 16'd15) begin
            $display("[PASS] R2 = %0d (R1+5, EX/MEM fwd)", uut.u_regfile.registers[2]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R2 = %0d (expected 15)", uut.u_regfile.registers[2]);
            fail_count = fail_count + 1;
        end

        // R3 = 25 (R1+R2, dual forwarding)
        if (uut.u_regfile.registers[3] === 16'd25) begin
            $display("[PASS] R3 = %0d (R1+R2, dual fwd)", uut.u_regfile.registers[3]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R3 = %0d (expected 25)", uut.u_regfile.registers[3]);
            fail_count = fail_count + 1;
        end

        // R4 = 15 (R3-R1, forwarding chain)
        if (uut.u_regfile.registers[4] === 16'd15) begin
            $display("[PASS] R4 = %0d (R3-R1, fwd chain)", uut.u_regfile.registers[4]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R4 = %0d (expected 15)", uut.u_regfile.registers[4]);
            fail_count = fail_count + 1;
        end

        $display("");
        $display("--- Load-Use Stall Verification ---");

        // R5 = 10 (loaded from mem[0])
        if (uut.u_regfile.registers[5] === 16'd10) begin
            $display("[PASS] R5 = %0d (LH mem[0])", uut.u_regfile.registers[5]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R5 = %0d (expected 10)", uut.u_regfile.registers[5]);
            fail_count = fail_count + 1;
        end

        // R6 = 20 (R5+R1, load-use stall then forwarding)
        if (uut.u_regfile.registers[6] === 16'd20) begin
            $display("[PASS] R6 = %0d (R5+R1, load-use stall)", uut.u_regfile.registers[6]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R6 = %0d (expected 20)", uut.u_regfile.registers[6]);
            fail_count = fail_count + 1;
        end

        $display("");
        $display("--- Branch Flush Verification ---");

        // R7 = 25 (from addr 9, not 31 from addr 8 which was flushed)
        if (uut.u_regfile.registers[7] === 16'd25) begin
            $display("[PASS] R7 = %0d (branch flush correct)", uut.u_regfile.registers[7]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R7 = %0d (expected 25, branch flush)", uut.u_regfile.registers[7]);
            fail_count = fail_count + 1;
        end

        // Check memory was written correctly by SH
        if (uut.u_dmem.mem[0] === 16'd10) begin
            $display("[PASS] DMEM[0] = %0d (SH verified)", uut.u_dmem.mem[0]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] DMEM[0] = %0d (expected 10)", uut.u_dmem.mem[0]);
            fail_count = fail_count + 1;
        end

        // ---- Summary ----
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

    // Cycle monitor
    always @(posedge clk) begin
        if (!rst)
            $display("[CYC] t=%0t PC=%0d IF_ID.inst=0x%04h stall=%b flush=%b | EX: fwdA=%b fwdB=%b",
                     $time, uut.pc, uut.if_id_inst,
                     uut.stall, uut.flush,
                     uut.forward_a, uut.forward_b);
    end

endmodule
