// ============================================================
// Module: instruction_memory (unchanged from Milestone 1)
// ============================================================
module instruction_memory #(parameter MEM_DEPTH = 256)(
    input  wire [15:0] addr,
    output wire [15:0] instruction
);
    reg [15:0] mem [0:MEM_DEPTH-1];
    assign instruction = mem[addr[7:0]];
    integer i;
    initial for (i = 0; i < MEM_DEPTH; i = i + 1) mem[i] = 16'h0000;
endmodule
