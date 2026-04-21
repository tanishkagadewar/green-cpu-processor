// ============================================================
// Module: pc_register (unchanged from Milestone 1)
// ============================================================
module pc_register (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] pc_next,
    output reg  [15:0] pc
);
    always @(posedge clk) begin
        if (rst) pc <= 16'h0000;
        else     pc <= pc_next;
    end
endmodule
