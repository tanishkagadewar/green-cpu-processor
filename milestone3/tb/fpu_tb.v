// ============================================================
// Testbench: fpu_tb — FP16 FADD + FMUL verification
// Tests: normal, denormal, Inf, NaN, zero, rounding
//
// FP16 reference values:
//   1.0=0x3C00  2.0=0x4000  3.0=0x4200  0.5=0x3800
//   1.5=0x3E00  6.0=0x4600  2.25=0x4080 -1.0=0xBC00
//   -2.0=0xC000 -3.0=0xC200  0=0x0000  -0=0x8000
//   +Inf=0x7C00 -Inf=0xFC00 qNaN=0x7E00
//   smallest denorm=0x0001
// ============================================================

`timescale 1ns / 1ps

module fpu_tb;

    reg  [15:0] op_a, op_b;
    reg         fpu_op;
    wire [15:0] result;
    integer pass_count, fail_count, test_num;

    fpu uut (.op_a(op_a), .op_b(op_b), .fpu_op(fpu_op), .result(result));

    task check;
        input [15:0] expected;
        input [8*40-1:0] desc;
        begin
            #1;
            if (result === expected) begin
                $display("[PASS] T%0d: %0s => 0x%04h", test_num, desc, result);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] T%0d: %0s => 0x%04h (exp 0x%04h)",
                         test_num, desc, result, expected);
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    initial begin
        $dumpfile("fpu_tb.vcd");
        $dumpvars(0, fpu_tb);
        pass_count = 0; fail_count = 0; test_num = 1;

        $display("============================================================");
        $display(" Milestone 3 — FP16 FPU Testbench");
        $display("============================================================");

        // ===================== FADD TESTS =====================
        fpu_op = 0;
        $display("");
        $display("--- FADD: Normal Cases ---");

        op_a = 16'h3C00; op_b = 16'h4000; // 1.0 + 2.0 = 3.0
        check(16'h4200, "FADD 1.0 + 2.0 = 3.0");

        op_a = 16'h3E00; op_b = 16'h3E00; // 1.5 + 1.5 = 3.0
        check(16'h4200, "FADD 1.5 + 1.5 = 3.0");

        op_a = 16'h4200; op_b = 16'hBC00; // 3.0 + (-1.0) = 2.0
        check(16'h4000, "FADD 3.0 + (-1.0) = 2.0");

        op_a = 16'hBC00; op_b = 16'hC000; // -1.0 + (-2.0) = -3.0
        check(16'hC200, "FADD -1.0 + (-2.0) = -3.0");

        op_a = 16'h3C00; op_b = 16'hBC00; // 1.0 + (-1.0) = +0.0
        check(16'h0000, "FADD 1.0 + (-1.0) = +0.0");

        $display("");
        $display("--- FADD: Special Cases ---");

        op_a = 16'h0000; op_b = 16'h3C00; // 0 + 1.0 = 1.0
        check(16'h3C00, "FADD 0 + 1.0 = 1.0");

        op_a = 16'h0000; op_b = 16'h0000; // 0 + 0 = 0
        check(16'h0000, "FADD 0 + 0 = 0");

        op_a = 16'h7C00; op_b = 16'h3C00; // +Inf + 1.0 = +Inf
        check(16'h7C00, "FADD +Inf + 1.0 = +Inf");

        op_a = 16'h7C00; op_b = 16'hFC00; // +Inf + (-Inf) = NaN
        check(16'h7E00, "FADD +Inf + -Inf = NaN");

        op_a = 16'h7E00; op_b = 16'h3C00; // NaN + 1.0 = NaN
        check(16'h7E00, "FADD NaN + 1.0 = NaN");

        $display("");
        $display("--- FADD: Denormals ---");

        op_a = 16'h0001; op_b = 16'h0000; // smallest denorm + 0
        check(16'h0001, "FADD denorm + 0 = denorm");

        op_a = 16'h0001; op_b = 16'h0001; // denorm + denorm
        check(16'h0002, "FADD denorm + denorm");

        // ===================== FMUL TESTS =====================
        fpu_op = 1;
        $display("");
        $display("--- FMUL: Normal Cases ---");

        op_a = 16'h4000; op_b = 16'h4200; // 2.0 * 3.0 = 6.0
        check(16'h4600, "FMUL 2.0 * 3.0 = 6.0");

        op_a = 16'h3E00; op_b = 16'h3E00; // 1.5 * 1.5 = 2.25
        check(16'h4080, "FMUL 1.5 * 1.5 = 2.25");

        op_a = 16'h3C00; op_b = 16'hBC00; // 1.0 * (-1.0) = -1.0
        check(16'hBC00, "FMUL 1.0 * (-1.0) = -1.0");

        op_a = 16'hC000; op_b = 16'hC200; // -2.0 * -3.0 = 6.0
        check(16'h4600, "FMUL -2.0 * -3.0 = 6.0");

        $display("");
        $display("--- FMUL: Special Cases ---");

        op_a = 16'h4000; op_b = 16'h0000; // 2.0 * 0 = +0
        check(16'h0000, "FMUL 2.0 * 0 = +0");

        op_a = 16'h0000; op_b = 16'h7C00; // 0 * Inf = NaN
        check(16'h7E00, "FMUL 0 * Inf = NaN");

        op_a = 16'h4000; op_b = 16'h7C00; // 2.0 * Inf = +Inf
        check(16'h7C00, "FMUL 2.0 * +Inf = +Inf");

        op_a = 16'h7E00; op_b = 16'h3C00; // NaN * 1.0 = NaN
        check(16'h7E00, "FMUL NaN * 1.0 = NaN");

        // ===================== SUMMARY =====================
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
endmodule
