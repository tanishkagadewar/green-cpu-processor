// ============================================================
// Module: single_cycle_cpu
// Purpose: Top-level integration of the single-cycle 16-bit
//          RISC-V-style processor datapath.
//
// Architecture: Single-cycle — all 5 stages (IF, ID, EX, MEM,
//   WB) complete within one clock cycle.
//
// Memory Model: Harvard architecture — separate instruction
//   memory (ROM) and data memory (RAM). This allows simultaneous
//   instruction fetch and data read/write without structural
//   hazards in a single cycle.
//
// Datapath flow:
//   IF:  PC -> Instruction Memory -> instruction
//   ID:  Instruction decode -> Register File reads (rs1, rs2)
//   EX:  ALU computes (address for LD/ST, result for R-type)
//   MEM: Data Memory read/write (for LH/SH)
//   WB:  Write-back to Register File (ALU result or mem data)
//
// I/O Description:
//   clk - System clock
//   rst - Synchronous active-high reset
//
// Design Decisions:
//   - Word-addressed memory: PC increments by 1 per cycle.
//   - For S-type (SH), rs2 field is at instruction[11:9]
//     instead of [5:3]; a mux selects the correct rs2 address.
//   - R0 is hardwired to zero in the register file.
//
// Waveform Checkpoints:
//   - pc: should increment by 1 each cycle
//   - instruction: verify correct encoding fetched
//   - alu_result: verify computation matches expected
//   - rs1_data, rs2_data: verify correct register values
//   - write_data: verify correct data written back to regfile
//   - mem_read_data: for LH, verify data from memory
// ============================================================

module single_cycle_cpu (
    input wire clk,
    input wire rst
);

    // --------------------------------------------------------
    // Opcode parameters (for rs2 address mux)
    // --------------------------------------------------------
    localparam OP_SH = 4'b0010;

    // --------------------------------------------------------
    // Internal wires
    // --------------------------------------------------------

    // Program Counter
    wire [15:0] pc;
    wire [15:0] pc_next;

    // Instruction fetch
    wire [15:0] instruction;

    // Instruction field extraction
    wire [3:0]  opcode;
    wire [2:0]  rd_addr;
    wire [2:0]  rs1_addr;
    wire [2:0]  rs2_addr;
    wire [2:0]  funct;

    // Control signals
    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        alu_src;
    wire        mem_to_reg;
    wire [3:0]  alu_control;

    // Datapath signals
    wire [15:0] rs1_data;
    wire [15:0] rs2_data;
    wire [15:0] imm_ext;
    wire [15:0] alu_input_b;
    wire [15:0] alu_result;
    wire        alu_zero;
    wire [15:0] mem_read_data;
    wire [15:0] write_data;

    // --------------------------------------------------------
    // PC Logic — sequential increment (no branches in M1)
    // --------------------------------------------------------
    assign pc_next = pc + 16'h0001;

    // --------------------------------------------------------
    // Instruction Field Extraction
    // --------------------------------------------------------
    assign opcode   = instruction[15:12];
    assign rd_addr  = instruction[11:9];
    assign rs1_addr = instruction[8:6];
    assign funct    = instruction[2:0];

    // rs2 address mux: S-type uses instruction[11:9] as rs2
    // (the data register to store), R-type uses instruction[5:3]
    assign rs2_addr = (opcode == OP_SH) ? instruction[11:9] : instruction[5:3];

    // --------------------------------------------------------
    // ALU Input B Mux
    // --------------------------------------------------------
    // alu_src=0: register rs2 (R-type)
    // alu_src=1: sign-extended immediate (I-type/S-type)
    assign alu_input_b = alu_src ? imm_ext : rs2_data;

    // --------------------------------------------------------
    // Write-Back Mux
    // --------------------------------------------------------
    // mem_to_reg=0: write ALU result (R-type)
    // mem_to_reg=1: write memory data (LH)
    assign write_data = mem_to_reg ? mem_read_data : alu_result;

    // --------------------------------------------------------
    // Module Instantiations
    // --------------------------------------------------------

    // Program Counter Register
    pc_register u_pc (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    // Instruction Memory (ROM)
    instruction_memory u_imem (
        .addr        (pc),
        .instruction (instruction)
    );

    // Register File (8 x 16-bit)
    register_file u_regfile (
        .clk        (clk),
        .rst        (rst),
        .reg_write  (reg_write),
        .rs1_addr   (rs1_addr),
        .rs2_addr   (rs2_addr),
        .rd_addr    (rd_addr),
        .write_data (write_data),
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data)
    );

    // Sign-Extension Unit
    sign_extend u_signext (
        .imm_in  (instruction[5:0]),
        .imm_out (imm_ext)
    );

    // Control Unit
    control_unit u_ctrl (
        .opcode      (opcode),
        .funct       (funct),
        .reg_write   (reg_write),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .alu_src     (alu_src),
        .mem_to_reg  (mem_to_reg),
        .alu_control (alu_control)
    );

    // ALU
    alu u_alu (
        .a           (rs1_data),
        .b           (alu_input_b),
        .alu_control (alu_control),
        .result      (alu_result),
        .zero        (alu_zero)
    );

    // Data Memory (RAM)
    data_memory u_dmem (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .addr       (alu_result),
        .write_data (rs2_data),
        .read_data  (mem_read_data)
    );

endmodule
