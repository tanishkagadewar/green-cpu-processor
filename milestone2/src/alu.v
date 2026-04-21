// ============================================================
// Module: alu (unchanged from Milestone 1)
// ============================================================
module alu (
    input  wire [15:0] a, b,
    input  wire [3:0]  alu_control,
    output reg  [15:0] result,
    output wire        zero
);
    localparam ALU_ADD = 4'b0000, ALU_SUB = 4'b0001;
    localparam ALU_SLT = 4'b0010, ALU_OR  = 4'b0011;
    localparam ALU_AND = 4'b0100, ALU_SRL = 4'b0101;
    localparam ALU_SLL = 4'b0110, ALU_SRA = 4'b0111;
    assign zero = (result == 16'h0000);
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
