// ============================================================
// Module: pipelined_cpu — 5-Stage Pipelined 16-bit CPU (M5)
// Stages: IF → ID → EX → MEM → WB
// Features: Full forwarding, load-use stall, branch flush,
//           FPU, and Crypto Co-Processor with stall support.
// ============================================================

module pipelined_cpu (input wire clk, input wire rst);

    // Opcode constants
    localparam OP_SH=4'd2, OP_SHIMM=4'd8;
    localparam OP_BEQ=4'd9, OP_BNE=4'd10, OP_BLT=4'd11, OP_BGE=4'd12;
    localparam OP_JAL=4'd13, OP_JALR=4'd14;

    // ========================================================
    // Wires & Signals
    // ========================================================
    wire [15:0] pc, pc_plus_1, instruction;
    wire        stall, flush;
    wire        crypto_stall_wire;  // crypto co-processor stall
    wire        total_stall;        // combined stall
    wire [15:0] pc_next;

    // ID stage decode wires
    wire [3:0]  id_opcode;
    wire [2:0]  id_rd, id_rs1_addr, id_rs2_addr, id_funct;
    wire [1:0]  id_shtype;
    wire [15:0] id_rs1_data, id_rs2_data;
    wire        id_reg_write, id_mem_read, id_mem_write, id_alu_src;
    wire [1:0]  id_wb_sel;
    wire [3:0]  id_alu_control;
    wire        id_is_branch, id_is_jal, id_is_jalr, id_is_fpu, id_fpu_op;
    wire        id_is_crypto, id_crypto_mode;
    wire [1:0]  id_branch_type;
    wire [15:0] id_imm_ext, id_target;
    wire        id_is_b_type;

    // EX stage wires
    wire [1:0]  forward_a, forward_b;
    reg  [15:0] ex_fwd_a, ex_fwd_b;
    wire [15:0] ex_alu_a, ex_alu_b, ex_alu_result;
    wire        ex_alu_zero;
    wire [15:0] ex_fpu_result, ex_result;
    wire [15:0] ex_crypto_result;
    wire        crypto_done, crypto_active;
    reg         ex_branch_taken;
    wire [15:0] ex_branch_target;

    // MEM stage wires
    wire [15:0] mem_read_data;

    // WB stage wires
    reg  [15:0] wb_data;

    // ========================================================
    // IF/ID Pipeline Register
    // ========================================================
    reg [15:0] if_id_pc, if_id_pc_plus1, if_id_inst;

    // ========================================================
    // ID/EX Pipeline Register
    // ========================================================
    reg [15:0] id_ex_pc_plus1, id_ex_rs1, id_ex_rs2, id_ex_imm, id_ex_target;
    reg [2:0]  id_ex_rd, id_ex_rs1_addr, id_ex_rs2_addr;
    reg        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write, id_ex_alu_src;
    reg [1:0]  id_ex_wb_sel;
    reg [3:0]  id_ex_alu_control;
    reg        id_ex_is_branch, id_ex_is_jal, id_ex_is_jalr;
    reg [1:0]  id_ex_branch_type;
    reg        id_ex_is_fpu, id_ex_fpu_op;
    reg        id_ex_is_crypto, id_ex_crypto_mode;

    // ========================================================
    // EX/MEM Pipeline Register
    // ========================================================
    reg [15:0] ex_mem_result, ex_mem_rs2, ex_mem_pc_plus1;
    reg [2:0]  ex_mem_rd;
    reg        ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
    reg [1:0]  ex_mem_wb_sel;

    // ========================================================
    // MEM/WB Pipeline Register
    // ========================================================
    reg [15:0] mem_wb_result, mem_wb_mem_data, mem_wb_pc_plus1;
    reg [2:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg [1:0]  mem_wb_wb_sel;

    // ========================================================
    // IF Stage
    // ========================================================
    assign pc_plus_1 = pc + 16'd1;

    // Crypto stall: freeze entire pipeline while crypto is computing
    assign crypto_stall_wire = id_ex_is_crypto && !crypto_done;
    assign total_stall = stall || crypto_stall_wire;

    // PC next: flush (branch/jump) overrides stall
    assign pc_next = flush ? ex_branch_target : pc_plus_1;

    pc_register u_pc (
        .clk(clk), .rst(rst),
        .en(!total_stall || flush),
        .pc_next(pc_next), .pc(pc)
    );

    instruction_memory u_imem (.addr(pc), .instruction(instruction));

    // ========================================================
    // IF/ID Register Update
    // ========================================================
    always @(posedge clk) begin
        if (rst || flush) begin
            if_id_inst    <= 16'h0000;
            if_id_pc      <= 16'h0000;
            if_id_pc_plus1<= 16'h0000;
        end else if (!total_stall) begin
            if_id_inst    <= instruction;
            if_id_pc      <= pc;
            if_id_pc_plus1<= pc_plus_1;
        end
        // else: hold (stall)
    end

    // ========================================================
    // ID Stage
    // ========================================================
    assign id_opcode  = if_id_inst[15:12];
    assign id_rd      = if_id_inst[11:9];
    assign id_funct   = if_id_inst[2:0];
    assign id_shtype  = if_id_inst[5:4];
    assign id_rs1_addr= if_id_inst[8:6];

    // rs2 address routing (same as M2)
    assign id_is_b_type = (id_opcode >= OP_BEQ && id_opcode <= OP_BGE);
    assign id_rs2_addr  = (id_opcode == OP_SH || id_is_b_type) ?
                          if_id_inst[11:9] : if_id_inst[5:3];

    // Immediates
    wire [15:0] id_imm_6  = {{10{if_id_inst[5]}}, if_id_inst[5:0]};
    wire [15:0] id_imm_9  = {{7{if_id_inst[8]}}, if_id_inst[8:0]};
    wire [15:0] id_imm_sh = {12'b0, if_id_inst[3:0]};
    assign id_imm_ext = (id_opcode == OP_SHIMM) ? id_imm_sh : id_imm_6;

    // Pre-compute branch/jump target in ID
    assign id_target = (id_opcode == OP_JAL) ? (if_id_pc + id_imm_9)
                                             : (if_id_pc + id_imm_6);

    // Register file
    register_file u_regfile (
        .clk(clk), .rst(rst), .reg_write(mem_wb_reg_write),
        .rs1_addr(id_rs1_addr), .rs2_addr(id_rs2_addr),
        .rd_addr(mem_wb_rd), .write_data(wb_data),
        .rs1_data(id_rs1_data), .rs2_data(id_rs2_data)
    );

    // Control unit
    control_unit u_ctrl (
        .opcode(id_opcode), .funct(id_funct), .shtype(id_shtype),
        .reg_write(id_reg_write), .mem_read(id_mem_read),
        .mem_write(id_mem_write), .alu_src(id_alu_src),
        .wb_sel(id_wb_sel), .alu_control(id_alu_control),
        .is_branch(id_is_branch), .branch_type(id_branch_type),
        .is_jal(id_is_jal), .is_jalr(id_is_jalr),
        .is_fpu(id_is_fpu), .fpu_op(id_fpu_op),
        .is_crypto(id_is_crypto), .crypto_mode(id_crypto_mode)
    );

    // ========================================================
    // ID/EX Register Update
    // ========================================================
    always @(posedge clk) begin
        if (rst || flush || (stall && !crypto_stall_wire)) begin
            // Insert bubble (NOP) — but NOT during crypto stall (hold)
            id_ex_reg_write <= 0; id_ex_mem_read <= 0; id_ex_mem_write <= 0;
            id_ex_alu_src   <= 0; id_ex_wb_sel   <= 0; id_ex_alu_control <= 0;
            id_ex_is_branch <= 0; id_ex_branch_type <= 0;
            id_ex_is_jal    <= 0; id_ex_is_jalr  <= 0;
            id_ex_is_fpu    <= 0; id_ex_fpu_op   <= 0;
            id_ex_is_crypto <= 0; id_ex_crypto_mode <= 0;
            id_ex_rs1 <= 0; id_ex_rs2 <= 0; id_ex_imm <= 0;
            id_ex_rd  <= 0; id_ex_rs1_addr <= 0; id_ex_rs2_addr <= 0;
            id_ex_pc_plus1 <= 0; id_ex_target <= 0;
        end else if (crypto_stall_wire) begin
            // Hold ID/EX during crypto stall (keep ENC/DEC instruction)
        end else begin
            id_ex_reg_write <= id_reg_write; id_ex_mem_read <= id_mem_read;
            id_ex_mem_write <= id_mem_write; id_ex_alu_src  <= id_alu_src;
            id_ex_wb_sel    <= id_wb_sel;    id_ex_alu_control <= id_alu_control;
            id_ex_is_branch <= id_is_branch; id_ex_branch_type <= id_branch_type;
            id_ex_is_jal    <= id_is_jal;    id_ex_is_jalr  <= id_is_jalr;
            id_ex_is_fpu    <= id_is_fpu;    id_ex_fpu_op   <= id_fpu_op;
            id_ex_is_crypto <= id_is_crypto;  id_ex_crypto_mode <= id_crypto_mode;
            id_ex_rs1       <= id_rs1_data;  id_ex_rs2      <= id_rs2_data;
            id_ex_imm       <= id_imm_ext;   id_ex_target   <= id_target;
            id_ex_rd        <= id_rd;
            id_ex_rs1_addr  <= id_rs1_addr;  id_ex_rs2_addr <= id_rs2_addr;
            id_ex_pc_plus1  <= if_id_pc_plus1;
        end
    end

    // ========================================================
    // EX Stage
    // ========================================================

    // Forwarding muxes
    always @(*) begin
        case (forward_a)
            2'b01:   ex_fwd_a = ex_mem_result;
            2'b10:   ex_fwd_a = wb_data;
            default: ex_fwd_a = id_ex_rs1;
        endcase
        case (forward_b)
            2'b01:   ex_fwd_b = ex_mem_result;
            2'b10:   ex_fwd_b = wb_data;
            default: ex_fwd_b = id_ex_rs2;
        endcase
    end

    // ALU inputs
    assign ex_alu_a = ex_fwd_a;
    assign ex_alu_b = id_ex_alu_src ? id_ex_imm : ex_fwd_b;

    alu u_alu (
        .a(ex_alu_a), .b(ex_alu_b), .alu_control(id_ex_alu_control),
        .result(ex_alu_result), .zero(ex_alu_zero)
    );

    // FPU (combinational, in EX stage)
    fpu u_fpu (
        .op_a(ex_fwd_a), .op_b(ex_fwd_b),
        .fpu_op(id_ex_fpu_op), .result(ex_fpu_result)
    );

    // Crypto Co-Processor (multi-cycle, in EX stage)
    wire crypto_start = id_ex_is_crypto && !crypto_active;
    crypto_coprocessor u_crypto (
        .clk(clk), .rst(rst),
        .start(crypto_start),
        .mode(id_ex_crypto_mode),
        .data_in(ex_fwd_a),    // rs1 = plaintext/ciphertext
        .key_in(ex_fwd_b),     // rs2 = key
        .done(crypto_done),
        .data_out(ex_crypto_result),
        .active(crypto_active)
    );

    // EX result mux: Crypto / FPU / ALU
    assign ex_result = id_ex_is_crypto ? ex_crypto_result :
                       id_ex_is_fpu    ? ex_fpu_result    :
                       ex_alu_result;

    // Branch comparator (uses forwarded values)
    always @(*) begin
        ex_branch_taken = 0;
        if (id_ex_is_branch) begin
            case (id_ex_branch_type)
                2'd0: ex_branch_taken = (ex_fwd_a == ex_fwd_b);
                2'd1: ex_branch_taken = (ex_fwd_a != ex_fwd_b);
                2'd2: ex_branch_taken = ($signed(ex_fwd_a) < $signed(ex_fwd_b));
                2'd3: ex_branch_taken = ($signed(ex_fwd_a) >= $signed(ex_fwd_b));
            endcase
        end
    end

    // Branch/jump target
    assign ex_branch_target = id_ex_is_jalr ? ex_alu_result : id_ex_target;

    // ========================================================
    // EX/MEM Register Update
    // ========================================================
    always @(posedge clk) begin
        if (rst) begin
            ex_mem_result <= 0; ex_mem_rs2 <= 0; ex_mem_rd <= 0;
            ex_mem_reg_write <= 0; ex_mem_mem_read <= 0;
            ex_mem_mem_write <= 0; ex_mem_wb_sel <= 0;
            ex_mem_pc_plus1 <= 0;
        end else if (!crypto_stall_wire) begin
            // Hold EX/MEM during crypto stall
            ex_mem_result    <= ex_result;
            ex_mem_rs2       <= ex_fwd_b;
            ex_mem_rd        <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read  <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_wb_sel    <= id_ex_wb_sel;
            ex_mem_pc_plus1  <= id_ex_pc_plus1;
        end
    end

    // ========================================================
    // MEM Stage
    // ========================================================
    data_memory u_dmem (
        .clk(clk), .mem_read(ex_mem_mem_read), .mem_write(ex_mem_mem_write),
        .addr(ex_mem_result), .write_data(ex_mem_rs2),
        .read_data(mem_read_data)
    );

    // ========================================================
    // MEM/WB Register Update
    // ========================================================
    always @(posedge clk) begin
        if (rst) begin
            mem_wb_result <= 0; mem_wb_mem_data <= 0; mem_wb_rd <= 0;
            mem_wb_reg_write <= 0; mem_wb_wb_sel <= 0; mem_wb_pc_plus1 <= 0;
        end else begin
            mem_wb_result    <= ex_mem_result;
            mem_wb_mem_data  <= mem_read_data;
            mem_wb_rd        <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_wb_sel    <= ex_mem_wb_sel;
            mem_wb_pc_plus1  <= ex_mem_pc_plus1;
        end
    end

    // ========================================================
    // WB Stage
    // ========================================================
    always @(*) begin
        case (mem_wb_wb_sel)
            2'b01:   wb_data = mem_wb_mem_data;
            2'b10:   wb_data = mem_wb_pc_plus1;
            default: wb_data = mem_wb_result;
        endcase
    end

    // ========================================================
    // Hazard & Forwarding Units
    // ========================================================
    hazard_unit u_hazard (
        .id_ex_mem_read(id_ex_mem_read), .id_ex_rd(id_ex_rd),
        .if_id_rs1(id_rs1_addr), .if_id_rs2(id_rs2_addr),
        .branch_taken(ex_branch_taken),
        .is_jal(id_ex_is_jal), .is_jalr(id_ex_is_jalr),
        .stall(stall), .flush(flush)
    );

    forwarding_unit u_fwd (
        .ex_rs1(id_ex_rs1_addr), .ex_rs2(id_ex_rs2_addr),
        .mem_rd(ex_mem_rd), .wb_rd(mem_wb_rd),
        .mem_reg_write(ex_mem_reg_write), .wb_reg_write(mem_wb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

endmodule
