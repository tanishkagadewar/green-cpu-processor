// ============================================================
// Module: pc_register
// Purpose: 16-bit Program Counter with synchronous reset.
//          Holds the current instruction address and updates
//          to pc_next on every rising clock edge.
//
// I/O Description:
//   clk     - System clock (rising-edge triggered)
//   rst     - Synchronous active-high reset (sets PC to 0)
//   pc_next - Next PC value to load
//   pc      - Current PC output
//
// Design Decisions:
//   - Word-addressed: PC increments by 1 per instruction
//     (each address holds one 16-bit instruction word)
//   - Synchronous reset chosen for cleaner FPGA synthesis
//
// Waveform Checkpoints:
//   - pc should increment by 1 each cycle after reset
//   - pc should be 0 during and immediately after reset
// ============================================================

module pc_register (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] pc_next,
    output reg  [15:0] pc
);

    always @(posedge clk) begin
        if (rst)
            pc <= 16'h0000;
        else
            pc <= pc_next;
    end

endmodule
