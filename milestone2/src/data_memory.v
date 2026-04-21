// ============================================================
// Module: data_memory (unchanged from Milestone 1)
// ============================================================
module data_memory #(parameter MEM_DEPTH = 256)(
    input  wire        clk, mem_read, mem_write,
    input  wire [15:0] addr, write_data,
    output wire [15:0] read_data
);
    reg [15:0] mem [0:MEM_DEPTH-1];
    assign read_data = mem_read ? mem[addr[7:0]] : 16'h0000;
    always @(posedge clk) begin
        if (mem_write) mem[addr[7:0]] <= write_data;
    end
    integer i;
    initial for (i = 0; i < MEM_DEPTH; i = i + 1) mem[i] = 16'h0000;
endmodule
