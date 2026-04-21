// ============================================================
// Module: register_file
// Purpose: 8x16-bit register file with 2 read ports and
//          1 write port. R0 is hardwired to zero.
//
// I/O Description:
//   clk        - System clock
//   rst        - Synchronous reset (clears all registers)
//   reg_write  - Write enable for rd_addr
//   rs1_addr   - 3-bit read address for port 1
//   rs2_addr   - 3-bit read address for port 2
//   rd_addr    - 3-bit write address
//   write_data - 16-bit data to write
//   rs1_data   - 16-bit read data from port 1
//   rs2_data   - 16-bit read data from port 2
//
// Design Decisions:
//   - R0 hardwired to 0 (RISC-V convention). Reads from R0
//     always return 0; writes to R0 are ignored.
//   - Combinational reads, synchronous writes on posedge.
//   - Write-through: if reading and writing same register
//     in same cycle, read returns OLD value (new value
//     available next cycle). This is correct for single-cycle
//     designs where each instruction occupies one full cycle.
//
// Waveform Checkpoints:
//   - rs1_data/rs2_data should reflect register contents
//   - Writes should appear in registers one cycle later
//   - R0 should always read as 0
// ============================================================

module register_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        reg_write,
    input  wire [2:0]  rs1_addr,
    input  wire [2:0]  rs2_addr,
    input  wire [2:0]  rd_addr,
    input  wire [15:0] write_data,
    output wire [15:0] rs1_data,
    output wire [15:0] rs2_data
);

    reg [15:0] registers [0:7];
    integer i;

    // Combinational reads — R0 always returns 0
    assign rs1_data = (rs1_addr == 3'b000) ? 16'h0000 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 3'b000) ? 16'h0000 : registers[rs2_addr];

    // Synchronous write with reset
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1)
                registers[i] <= 16'h0000;
        end else if (reg_write && (rd_addr != 3'b000)) begin
            registers[rd_addr] <= write_data;
        end
    end

endmodule
