// ============================================================
// Module: forwarding_unit
// Detects RAW hazards and selects forwarding sources.
// forward_X: 00=register, 01=EX/MEM, 10=MEM/WB
// ============================================================
module forwarding_unit (
    input wire [2:0] ex_rs1, ex_rs2,
    input wire [2:0] mem_rd, wb_rd,
    input wire       mem_reg_write, wb_reg_write,
    output reg [1:0] forward_a, forward_b
);
    always @(*) begin
        // Default: no forwarding
        forward_a = 2'b00;
        forward_b = 2'b00;

        // Forward A (rs1)
        if (mem_reg_write && mem_rd != 0 && mem_rd == ex_rs1)
            forward_a = 2'b01;  // EX/MEM
        else if (wb_reg_write && wb_rd != 0 && wb_rd == ex_rs1)
            forward_a = 2'b10;  // MEM/WB

        // Forward B (rs2)
        if (mem_reg_write && mem_rd != 0 && mem_rd == ex_rs2)
            forward_b = 2'b01;  // EX/MEM
        else if (wb_reg_write && wb_rd != 0 && wb_rd == ex_rs2)
            forward_b = 2'b10;  // MEM/WB
    end
endmodule
