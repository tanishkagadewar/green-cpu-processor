// ============================================================
// Testbench: single_cycle_cpu_tb (Milestone 2)
// Purpose: Verify all new M2 instructions:
//   I-type ALU, immediate shifts, branches, JAL, JALR
//
// Test Program Flow:
//   0-6:   I-type ALU (ADDI, SUBI, ORI, ANDI, SLTI)
//   7-10:  Immediate shifts (SLLI, SRLI, SRAI)
//   11-22: Branch tests (BEQ/BNE/BLT/BGE taken & not-taken)
//   23-27: JAL/JALR with subroutine call and return
//
// Encoding Reference:
//   R:  [15:12=0000][11:9 rd][8:6 rs1][5:3 rs2][2:0 funct]
//   I:  [15:12 op  ][11:9 rd][8:6 rs1][5:0 imm6]
//   IS: [15:12=1000][11:9 rd][8:6 rs1][5:4 shtype][3:0 shamt]
//   B:  [15:12 op  ][11:9 rs2][8:6 rs1][5:0 offset6]
//   J:  [15:12=1101][11:9 rd][8:0 imm9]
//   JR: [15:12=1110][11:9 rd][8:6 rs1][5:0 imm6]
// ============================================================

`timescale 1ns / 1ps

module single_cycle_cpu_tb;

    reg clk, rst;
    initial clk = 0;
    always #5 clk = ~clk;

    single_cycle_cpu uut (.clk(clk), .rst(rst));

    integer pass_count, fail_count;

    initial begin
        $dumpfile("m2_cpu_tb.vcd");
        $dumpvars(0, single_cycle_cpu_tb);
        pass_count = 0; fail_count = 0;

        $display("============================================================");
        $display(" Milestone 2 — Extended ISA Testbench");
        $display("============================================================");

        // ---- Load Program ----
        // Phase 1: I-Type ALU
        uut.u_imem.mem[0]  = 16'h320A;  // ADDI R1, R0, 10   -> R1=10
        uut.u_imem.mem[1]  = 16'h3405;  // ADDI R2, R0, 5    -> R2=5
        uut.u_imem.mem[2]  = 16'h4643;  // SUBI R3, R1, 3    -> R3=7
        uut.u_imem.mem[3]  = 16'h5845;  // ORI  R4, R1, 5    -> R4=15
        uut.u_imem.mem[4]  = 16'h6A47;  // ANDI R5, R1, 7    -> R5=2
        uut.u_imem.mem[5]  = 16'h7C8A;  // SLTI R6, R2, 10   -> R6=1 (5<10)
        uut.u_imem.mem[6]  = 16'h7E45;  // SLTI R7, R1, 5    -> R7=0 (10<5?no)

        // Phase 2: Immediate Shifts
        uut.u_imem.mem[7]  = 16'h8652;  // SLLI R3, R1, 2    -> R3=40
        uut.u_imem.mem[8]  = 16'h8841;  // SRLI R4, R1, 1    -> R4=5
        uut.u_imem.mem[9]  = 16'h363F;  // ADDI R3, R0, -1   -> R3=0xFFFF
        uut.u_imem.mem[10] = 16'h88E3;  // SRAI R4, R3, 3    -> R4=0xFFFF

        // Phase 3: Branches
        uut.u_imem.mem[11] = 16'h9442;  // BEQ R1,R2,2  (10==5? NO)  ->12
        uut.u_imem.mem[12] = 16'h3A01;  // ADDI R5,R0,1              R5=1
        uut.u_imem.mem[13] = 16'h9242;  // BEQ R1,R1,2  (10==10? YES)->15
        uut.u_imem.mem[14] = 16'h3A1F;  // ADDI R5,R0,31 [SKIPPED]
        uut.u_imem.mem[15] = 16'hA442;  // BNE R1,R2,2  (10!=5? YES) ->17
        uut.u_imem.mem[16] = 16'h3A1E;  // ADDI R5,R0,30 [SKIPPED]
        uut.u_imem.mem[17] = 16'hB282;  // BLT R2,R1,2  (5<10? YES)  ->19
        uut.u_imem.mem[18] = 16'h3A1D;  // ADDI R5,R0,29 [SKIPPED]
        uut.u_imem.mem[19] = 16'hC442;  // BGE R1,R2,2  (10>=5? YES) ->21
        uut.u_imem.mem[20] = 16'h3A1C;  // ADDI R5,R0,28 [SKIPPED]
        uut.u_imem.mem[21] = 16'hB442;  // BLT R1,R2,2  (10<5? NO)   ->22
        uut.u_imem.mem[22] = 16'hC282;  // BGE R2,R1,2  (5>=10? NO)  ->23

        // Phase 4: JAL / JALR
        uut.u_imem.mem[23] = 16'hDC03;  // JAL R6, 3    -> R6=24, jump->26
        uut.u_imem.mem[24] = 16'h3A14;  // ADDI R5,R0,20 (after return)
        uut.u_imem.mem[25] = 16'h9000;  // BEQ R0,R0,0  (halt loop)
        uut.u_imem.mem[26] = 16'h3E19;  // ADDI R7,R0,25 (subroutine)
        uut.u_imem.mem[27] = 16'hE180;  // JALR R0,R6,0  -> return to 24

        // ---- Reset ----
        rst = 1;
        @(posedge clk); @(posedge clk);
        rst = 0;

        // ---- Run 30 cycles (enough for full program + halt) ----
        repeat (30) @(posedge clk);
        #1;

        // ---- Verify Results ----
        $display("");
        $display("--- I-Type ALU Verification ---");

        // R1 = 10 (ADDI)
        if (uut.u_regfile.registers[1] === 16'h000A) begin
            $display("[PASS] R1 = %0d (ADDI R0+10)", uut.u_regfile.registers[1]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R1 = 0x%04h (expected 0x000A)", uut.u_regfile.registers[1]);
            fail_count = fail_count + 1;
        end

        // R2 = 5 (ADDI)
        if (uut.u_regfile.registers[2] === 16'h0005) begin
            $display("[PASS] R2 = %0d (ADDI R0+5)", uut.u_regfile.registers[2]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R2 = 0x%04h (expected 0x0005)", uut.u_regfile.registers[2]);
            fail_count = fail_count + 1;
        end

        // R3 final = 0xFFFF (overwritten by ADDI R3,R0,-1 at addr 9)
        if (uut.u_regfile.registers[3] === 16'hFFFF) begin
            $display("[PASS] R3 = 0x%04h (ADDI -1 overwrote SLLI)", uut.u_regfile.registers[3]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R3 = 0x%04h (expected 0xFFFF)", uut.u_regfile.registers[3]);
            fail_count = fail_count + 1;
        end

        // R4 final = 0xFFFF (SRAI 0xFFFF>>>3)
        if (uut.u_regfile.registers[4] === 16'hFFFF) begin
            $display("[PASS] R4 = 0x%04h (SRAI 0xFFFF>>>3)", uut.u_regfile.registers[4]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R4 = 0x%04h (expected 0xFFFF)", uut.u_regfile.registers[4]);
            fail_count = fail_count + 1;
        end

        $display("");
        $display("--- Branch Verification ---");

        // R5 final = 20 (from ADDI at addr 24 after JALR return)
        // If any taken branch failed, R5 would be 31/30/29/28
        if (uut.u_regfile.registers[5] === 16'h0014) begin
            $display("[PASS] R5 = %0d (branches+JALR return correct)", uut.u_regfile.registers[5]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R5 = 0x%04h (expected 0x0014=20)", uut.u_regfile.registers[5]);
            fail_count = fail_count + 1;
        end

        $display("");
        $display("--- JAL/JALR Verification ---");

        // R6 = 24 (JAL at addr 23 saved return address PC+1=24)
        if (uut.u_regfile.registers[6] === 16'h0018) begin
            $display("[PASS] R6 = %0d (JAL return addr = 24)", uut.u_regfile.registers[6]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R6 = 0x%04h (expected 0x0018=24)", uut.u_regfile.registers[6]);
            fail_count = fail_count + 1;
        end

        // R7 = 25 (ADDI in subroutine at addr 26)
        if (uut.u_regfile.registers[7] === 16'h0019) begin
            $display("[PASS] R7 = %0d (subroutine ADDI=25)", uut.u_regfile.registers[7]);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] R7 = 0x%04h (expected 0x0019=25)", uut.u_regfile.registers[7]);
            fail_count = fail_count + 1;
        end

        // PC should be stuck at 25 (halt loop)
        if (uut.pc === 16'h0019) begin
            $display("[PASS] PC = %0d (halted at BEQ loop)", uut.pc);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] PC = %0d (expected 25)", uut.pc);
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
            $display("[CYC] t=%0t PC=%0d INST=0x%04h ALU=0x%04h WB=0x%04h br=%b jal=%b jalr=%b",
                     $time, uut.pc, uut.instruction, uut.alu_result,
                     uut.write_data, uut.is_branch, uut.is_jal, uut.is_jalr);
    end

endmodule
