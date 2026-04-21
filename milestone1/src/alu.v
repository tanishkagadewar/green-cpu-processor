// ============================================================
// Module: alu
// Purpose: 16-bit Arithmetic Logic Unit supporting all
//          Milestone 1 R-type operations.
//
// I/O Description:
//   a           - 16-bit operand A (rs1 data)
//   b           - 16-bit operand B (rs2 data or immediate)
//   alu_control - 4-bit operation selector
//   result      - 16-bit computation result
//   zero        - High when result == 0
//
// Supported Operations (via localparam):
//   ALU_ADD (0000): a + b
//   ALU_SUB (0001): a - b
//   ALU_SLT (0010): (signed a < signed b) ? 1 : 0
//   ALU_OR  (0011): a | b
//   ALU_AND (0100): a & b
//   ALU_SRL (0101): a >> b[3:0]  (logical shift right)
//   ALU_SLL (0110): a << b[3:0]  (logical shift left)
//   ALU_SRA (0111): a >>> b[3:0] (arithmetic shift right)
//
// Design Decisions:
//   - Pure combinational module, no clock.
//   - Shift amount uses b[3:0] (max shift 15 for 16-bit data).
//   - SLT uses $signed comparison for correct signed semantics.
//   - SRA uses $signed(a) >>> to propagate sign bit.
//
// Waveform Checkpoints:
//   - Verify result for each alu_control setting
//   - zero flag should assert when result == 0
// ============================================================

module alu (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [3:0]  alu_control,
    output reg  [15:0] result,
    output wire        zero
);

    // ALU operation codes
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_SLT = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_AND = 4'b0100;
    localparam ALU_SRL = 4'b0101;
    localparam ALU_SLL = 4'b0110;
    localparam ALU_SRA = 4'b0111;

    // Zero flag
    assign zero = (result == 16'h0000);

    // Combinational ALU logic
    always @(*) begin
        case (alu_control)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 16'h0001 : 16'h0000;
            ALU_OR:  result = a | b;
            ALU_AND: result = a & b;
            ALU_SRL: result = a >> b[3:0];
            ALU_SLL: result = a << b[3:0];
            ALU_SRA: result = $signed(a) >>> b[3:0];
            default: result = 16'h0000;
        endcase
    end

endmodule
