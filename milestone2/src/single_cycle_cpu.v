// ============================================================
// Module: single_cycle_cpu (Milestone 2 — Extended Datapath)
// Purpose: Complete single-cycle CPU with branches, jumps,
//          I-type ALU, and immediate shift support.
//
// New vs M1:
//   - Branch comparator for BEQ/BNE/BLT/BGE
//   - PC mux: sequential / branch_target / jal_target / jalr_target
//   - Write-back mux: ALU / mem / PC+1 (for JAL/JALR link)
//   - Multiple immediate formats: 6-bit, 9-bit, 4-bit shamt
//   - rs2_addr mux extended for B-type instructions
//
// Waveform Checkpoints:
//   pc, instruction, alu_result, write_data, is_branch,
//   branch_taken, is_jal, is_jalr, pc_next
// ============================================================

module single_cycle_cpu (
    input wire clk,
    input wire rst
);

    // --------------------------------------------------------
    // Opcode parameters
    // --------------------------------------------------------
    localparam OP_RTYPE = 4'b0000;
    localparam OP_SH    = 4'b0010;
    localparam OP_SHIMM = 4'b1000;
    localparam OP_BEQ   = 4'b1001;
    localparam OP_BNE   = 4'b1010;
    localparam OP_BLT   = 4'b1011;
    localparam OP_BGE   = 4'b1100;

    // --------------------------------------------------------
    // Wires
    // --------------------------------------------------------
    wire [15:0] pc, instruction;
    wire [3:0]  opcode;
    wire [2:0]  rd_addr, rs1_addr, rs2_addr, funct;
    wire [1:0]  shtype;

    // Control signals
    wire        reg_write, mem_read, mem_write, alu_src;
    wire [1:0]  wb_sel;
    wire [3:0]  alu_control;
    wire        is_branch, is_jal, is_jalr;
    wire [1:0]  branch_type;

    // Datapath signals
    wire [15:0] rs1_data, rs2_data;
    wire [15:0] alu_result, alu_input_b, mem_read_data, write_data;
    wire        alu_zero;

    // --------------------------------------------------------
    // Instruction field extraction
    // --------------------------------------------------------
    assign opcode   = instruction[15:12];
    assign rd_addr  = instruction[11:9];
    assign rs1_addr = instruction[8:6];
    assign funct    = instruction[2:0];
    assign shtype   = instruction[5:4];

    // rs2_addr: [5:3] for R-type, [11:9] for SH and B-type
    wire is_b_type = (opcode == OP_BEQ) || (opcode == OP_BNE) ||
                     (opcode == OP_BLT) || (opcode == OP_BGE);
    assign rs2_addr = (opcode == OP_SH || is_b_type) ?
                      instruction[11:9] : instruction[5:3];

    // --------------------------------------------------------
    // Immediate generation
    // --------------------------------------------------------
    wire [15:0] imm_6bit  = {{10{instruction[5]}}, instruction[5:0]};
    wire [15:0] imm_9bit  = {{7{instruction[8]}}, instruction[8:0]};
    wire [15:0] imm_shamt = {12'b0, instruction[3:0]};

    // Select immediate for ALU
    wire [15:0] alu_imm = (opcode == OP_SHIMM) ? imm_shamt : imm_6bit;
    assign alu_input_b  = alu_src ? alu_imm : rs2_data;

    // --------------------------------------------------------
    // PC logic
    // --------------------------------------------------------
    wire [15:0] pc_plus_1     = pc + 16'h0001;
    wire [15:0] branch_target = pc + imm_6bit;
    wire [15:0] jal_target    = pc + imm_9bit;
    // JALR target = alu_result (rs1 + sign_ext(imm6))

    // Branch comparator
    reg branch_taken;
    always @(*) begin
        branch_taken = 1'b0;
        if (is_branch) begin
            case (branch_type)
                2'b00: branch_taken = (rs1_data == rs2_data);               // BEQ
                2'b01: branch_taken = (rs1_data != rs2_data);               // BNE
                2'b10: branch_taken = ($signed(rs1_data) < $signed(rs2_data));  // BLT
                2'b11: branch_taken = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // PC next mux
    wire [15:0] pc_next = is_jal                       ? jal_target    :
                          is_jalr                      ? alu_result    :
                          (is_branch && branch_taken)  ? branch_target :
                          pc_plus_1;

    // --------------------------------------------------------
    // Write-back mux: 00=ALU, 01=mem, 10=PC+1
    // --------------------------------------------------------
    assign write_data = (wb_sel == 2'b01) ? mem_read_data :
                        (wb_sel == 2'b10) ? pc_plus_1     :
                        alu_result;

    // --------------------------------------------------------
    // Module instantiations
    // --------------------------------------------------------
    pc_register u_pc (
        .clk(clk), .rst(rst), .pc_next(pc_next), .pc(pc)
    );

    instruction_memory u_imem (
        .addr(pc), .instruction(instruction)
    );

    register_file u_regfile (
        .clk(clk), .rst(rst), .reg_write(reg_write),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr),
        .write_data(write_data), .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    control_unit u_ctrl (
        .opcode(opcode), .funct(funct), .shtype(shtype),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .alu_src(alu_src), .wb_sel(wb_sel), .alu_control(alu_control),
        .is_branch(is_branch), .branch_type(branch_type),
        .is_jal(is_jal), .is_jalr(is_jalr)
    );

    alu u_alu (
        .a(rs1_data), .b(alu_input_b),
        .alu_control(alu_control), .result(alu_result), .zero(alu_zero)
    );

    data_memory u_dmem (
        .clk(clk), .mem_read(mem_read), .mem_write(mem_write),
        .addr(alu_result), .write_data(rs2_data), .read_data(mem_read_data)
    );

endmodule
