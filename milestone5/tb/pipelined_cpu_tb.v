// ============================================================
// Testbench: pipelined_cpu_tb (Milestone 5)
// Tests: Encrypt → Decrypt round-trip producing original plaintext
//
// Program:
//   0: ADDI R1, R0, 26    R1 = 26 (plaintext)
//   1: ADDI R2, R0, 7     R2 = 7  (key)
//   2: ENC  R3, R1, R2    R3 = encrypt(26, 7) (multi-cycle stall)
//   3: DEC  R4, R3, R2    R4 = decrypt(R3, 7) = 26 (round-trip)
//   4: SUB  R5, R4, R1    R5 = R4 - R1 = 0 (proves correctness)
//   5: BEQ  R0, R0, 0     halt
//
// Encoding:
//   ENC: op=1111 rd rs1 rs2 funct=010  →  0xF652
//   DEC: op=1111 rd rs1 rs2 funct=011  →  0xF8D3
// ============================================================

`timescale 1ns / 1ps

module pipelined_cpu_tb;

    reg clk, rst;
    initial clk = 0;
    always #5 clk = ~clk;

    pipelined_cpu uut (.clk(clk), .rst(rst));

    integer pass_count, fail_count;

    initial begin
        $dumpfile("m5_crypto_tb.vcd");
        $dumpvars(0, pipelined_cpu_tb);
        pass_count = 0; fail_count = 0;

        $display("============================================================");
        $display(" Milestone 5 — Crypto Co-Processor Testbench");
        $display("============================================================");

        // ---- Load Program ----
        uut.u_imem.mem[0] = 16'h321A;  // ADDI R1, R0, 26
        uut.u_imem.mem[1] = 16'h3407;  // ADDI R2, R0, 7
        uut.u_imem.mem[2] = 16'hF652;  // ENC  R3, R1, R2
        uut.u_imem.mem[3] = 16'hF8D3;  // DEC  R4, R3, R2
        uut.u_imem.mem[4] = 16'h0B09;  // SUB  R5, R4, R1
        uut.u_imem.mem[5] = 16'h9000;  // BEQ  R0, R0, 0 (halt)

        // ---- Reset ----
        rst = 1;
        repeat(3) @(posedge clk);
        rst = 0;

        // Run 50 cycles (enough for 2 crypto operations + pipeline drain)
        repeat(50) @(posedge clk);
        #1;

        // ---- Verify Results ----
        $display("");
        $display("--- Crypto Round-Trip Verification ---");

        // R1 = 26 (plaintext)
        if (uut.u_regfile.registers[1] === 16'd26) begin
            $display("[PASS] R1 = %0d (plaintext)", uut.u_regfile.registers[1]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R1 = %0d (expected 26)", uut.u_regfile.registers[1]);
            fail_count = fail_count + 1;
        end

        // R2 = 7 (key)
        if (uut.u_regfile.registers[2] === 16'd7) begin
            $display("[PASS] R2 = %0d (key)", uut.u_regfile.registers[2]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R2 = %0d (expected 7)", uut.u_regfile.registers[2]);
            fail_count = fail_count + 1;
        end

        // R3 = encrypted value (should NOT equal plaintext)
        $display("[INFO] R3 = 0x%04h (ciphertext)", uut.u_regfile.registers[3]);
        if (uut.u_regfile.registers[3] !== 16'd26 && uut.u_regfile.registers[3] !== 16'd0) begin
            $display("[PASS] R3 != plaintext (encryption changed data)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R3 = plaintext (encryption did not change data!)");
            fail_count = fail_count + 1;
        end

        // R4 = decrypted = original plaintext (round-trip)
        if (uut.u_regfile.registers[4] === 16'd26) begin
            $display("[PASS] R4 = %0d (decrypt = original plaintext!)", uut.u_regfile.registers[4]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R4 = 0x%04h (expected 26 = 0x001A)", uut.u_regfile.registers[4]);
            fail_count = fail_count + 1;
        end

        // R5 = R4 - R1 = 0 (proves round-trip correctness)
        if (uut.u_regfile.registers[5] === 16'd0) begin
            $display("[PASS] R5 = %0d (R4-R1=0, round-trip verified!)", uut.u_regfile.registers[5]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R5 = %0d (expected 0)", uut.u_regfile.registers[5]);
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
            $display("[CYC] t=%0t PC=%0d IF=0x%04h crypt_stall=%b done=%b",
                     $time, uut.pc, uut.if_id_inst,
                     uut.crypto_stall_wire, uut.crypto_done);
    end

endmodule
