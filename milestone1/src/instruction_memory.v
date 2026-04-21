// ============================================================
// Module: instruction_memory
// Purpose: Read-only instruction memory (ROM) for Harvard
//          architecture. Stores 16-bit instructions indexed
//          by word address.
//
// I/O Description:
//   addr        - 16-bit word address input
//   instruction - 16-bit instruction output (combinational)
//
// Design Decisions:
//   - Harvard architecture: separate instruction and data
//     memories allow simultaneous instruction fetch and
//     data read/write in one clock cycle (essential for
//     single-cycle design).
//   - 256-entry depth is sufficient for simulation/testing.
//   - Combinational read (no clock) — instruction appears
//     immediately when address changes.
//   - Contents initialized via hierarchical access in testbench.
//
// Waveform Checkpoints:
//   - instruction output should change with addr
//   - Verify fetched instruction matches expected encoding
// ============================================================

module instruction_memory #(
    parameter MEM_DEPTH = 256
)(
    input  wire [15:0] addr,
    output wire [15:0] instruction
);

    reg [15:0] mem [0:MEM_DEPTH-1];

    // Combinational read — use lower bits to index
    assign instruction = mem[addr[7:0]];

    // Initialization block — zero out memory to avoid X's
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 16'h0000;
    end

endmodule
