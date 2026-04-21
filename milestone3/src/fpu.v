// ============================================================
// Module: fpu — FP16 Floating-Point Unit Wrapper
// Selects between FADD and FMUL based on fpu_op.
// Pure combinational (chosen for single-cycle integration).
//
// Design Decision: Combinational rather than multi-cycle because
// FP16's small operand widths (11-bit mantissa, 22-bit product)
// produce manageable critical paths. Multi-cycle would add
// complexity without significant benefit at this data width.
//
// I/O:
//   op_a, op_b - 16-bit FP16 operands
//   fpu_op     - 0: FADD, 1: FMUL
//   result     - 16-bit FP16 result
// ============================================================

module fpu (
    input  wire [15:0] op_a,
    input  wire [15:0] op_b,
    input  wire        fpu_op,  // 0=FADD, 1=FMUL
    output wire [15:0] result
);

    localparam FPU_ADD = 1'b0;
    localparam FPU_MUL = 1'b1;

    wire [15:0] add_result, mul_result;

    fp16_fadd u_fadd (
        .op_a   (op_a),
        .op_b   (op_b),
        .result (add_result)
    );

    fp16_fmul u_fmul (
        .op_a   (op_a),
        .op_b   (op_b),
        .result (mul_result)
    );

    assign result = (fpu_op == FPU_MUL) ? mul_result : add_result;

endmodule
