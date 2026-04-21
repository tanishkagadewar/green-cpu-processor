// ============================================================
// Module: register_file (unchanged from Milestone 1)
// ============================================================
module register_file (
    input  wire        clk, rst, reg_write,
    input  wire [2:0]  rs1_addr, rs2_addr, rd_addr,
    input  wire [15:0] write_data,
    output wire [15:0] rs1_data, rs2_data
);
    reg [15:0] registers [0:7];
    integer i;
    assign rs1_data = (rs1_addr == 3'b000) ? 16'h0000 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 3'b000) ? 16'h0000 : registers[rs2_addr];
    always @(posedge clk) begin
        if (rst) for (i = 0; i < 8; i = i + 1) registers[i] <= 16'h0000;
        else if (reg_write && rd_addr != 3'b000) registers[rd_addr] <= write_data;
    end
endmodule
