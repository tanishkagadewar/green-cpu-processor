// ============================================================
// Module: data_memory
// Purpose: 16-bit wide data RAM for load/store operations.
//          Part of Harvard architecture (separate from IMEM).
//
// I/O Description:
//   clk        - System clock (writes on rising edge)
//   mem_read   - Read enable (gates read output)
//   mem_write  - Write enable
//   addr       - 16-bit word address
//   write_data - 16-bit data to write
//   read_data  - 16-bit data read output
//
// Design Decisions:
//   - Word-addressed: each address holds one 16-bit word.
//   - Combinational read, synchronous write.
//   - 256-entry depth for simulation; uses addr[7:0].
//   - Read output gated by mem_read to prevent spurious reads.
//   - Contents can be pre-loaded in testbench via hierarchical access.
//
// Waveform Checkpoints:
//   - read_data should reflect mem[addr] when mem_read=1
//   - After SH, verify mem contents at written address
// ============================================================

module data_memory #(
    parameter MEM_DEPTH = 256
)(
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [15:0] addr,
    input  wire [15:0] write_data,
    output wire [15:0] read_data
);

    reg [15:0] mem [0:MEM_DEPTH-1];

    // Combinational read
    assign read_data = mem_read ? mem[addr[7:0]] : 16'h0000;

    // Synchronous write
    always @(posedge clk) begin
        if (mem_write)
            mem[addr[7:0]] <= write_data;
    end

    // Zero-initialize for simulation
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 16'h0000;
    end

endmodule
