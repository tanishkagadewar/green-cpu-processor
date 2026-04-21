// ============================================================
// Module: control_unit (Milestone 2 — Extended ISA)
// Purpose: Decodes opcode to generate all datapath control
//          signals for the full M2 instruction set.
//
// ============================================================
// COMPLETE 16-BIT ISA ENCODING TABLE (Milestones 1 + 2)
// ============================================================
//
// R-Type:  [15:12 op=0000][11:9 rd][8:6 rs1][5:3 rs2][2:0 funct]
//   funct: 000=ADD 001=SUB 010=SLT 011=OR 100=AND 101=SRL 110=SLL 111=SRA
//
// I-Type:  [15:12 opcode][11:9 rd][8:6 rs1][5:0 imm6]
//   0001=LH  0011=ADDI  0100=SUBI  0101=ORI  0110=ANDI  0111=SLTI
//
// S-Type:  [15:12 op=0010][11:9 rs2][8:6 rs1][5:0 imm6]
//   0010=SH
//
// IS-Type: [15:12 op=1000][11:9 rd][8:6 rs1][5:4 shtype][3:0 shamt]
//   shtype: 00=SRLI  01=SLLI  10=SRAI
//
// B-Type:  [15:12 opcode][11:9 rs2][8:6 rs1][5:0 offset6]
//   1001=BEQ  1010=BNE  1011=BLT  1100=BGE
//
// J-Type:  [15:12 op=1101][11:9 rd][8:0 imm9]
//   1101=JAL
//
// JALR:    [15:12 op=1110][11:9 rd][8:6 rs1][5:0 imm6]
//   1110=JALR
//
// ============================================================

module control_unit (
    input  wire [3:0] opcode,
    input  wire [2:0] funct,      // R-type function (instruction[2:0])
    input  wire [1:0] shtype,     // Shift-imm type (instruction[5:4])
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src,    // 0=rs2, 1=immediate
    output reg  [1:0] wb_sel,     // 00=ALU, 01=mem, 10=PC+1
    output reg  [3:0] alu_control,
    output reg        is_branch,
    output reg  [1:0] branch_type,// 00=BEQ 01=BNE 10=BLT 11=BGE
    output reg        is_jal,
    output reg        is_jalr
);

    // Opcode definitions
    localparam OP_RTYPE = 4'b0000;
    localparam OP_LH    = 4'b0001;
    localparam OP_SH    = 4'b0010;
    localparam OP_ADDI  = 4'b0011;
    localparam OP_SUBI  = 4'b0100;
    localparam OP_ORI   = 4'b0101;
    localparam OP_ANDI  = 4'b0110;
    localparam OP_SLTI  = 4'b0111;
    localparam OP_SHIMM = 4'b1000;
    localparam OP_BEQ   = 4'b1001;
    localparam OP_BNE   = 4'b1010;
    localparam OP_BLT   = 4'b1011;
    localparam OP_BGE   = 4'b1100;
    localparam OP_JAL   = 4'b1101;
    localparam OP_JALR  = 4'b1110;

    // ALU operation codes
    localparam ALU_ADD = 4'b0000, ALU_SUB = 4'b0001;
    localparam ALU_SLT = 4'b0010, ALU_OR  = 4'b0011;
    localparam ALU_AND = 4'b0100, ALU_SRL = 4'b0101;
    localparam ALU_SLL = 4'b0110, ALU_SRA = 4'b0111;

    always @(*) begin
        // Safe defaults (NOP)
        reg_write   = 1'b0;  mem_read  = 1'b0;
        mem_write   = 1'b0;  alu_src   = 1'b0;
        wb_sel      = 2'b00; alu_control = ALU_ADD;
        is_branch   = 1'b0;  branch_type = 2'b00;
        is_jal      = 1'b0;  is_jalr    = 1'b0;

        case (opcode)
            // --- Milestone 1 instructions ---
            OP_RTYPE: begin
                reg_write = 1'b1;
                case (funct)
                    3'b000: alu_control = ALU_ADD;
                    3'b001: alu_control = ALU_SUB;
                    3'b010: alu_control = ALU_SLT;
                    3'b011: alu_control = ALU_OR;
                    3'b100: alu_control = ALU_AND;
                    3'b101: alu_control = ALU_SRL;
                    3'b110: alu_control = ALU_SLL;
                    3'b111: alu_control = ALU_SRA;
                    default: alu_control = ALU_ADD;
                endcase
            end
            OP_LH: begin
                reg_write = 1'b1; mem_read = 1'b1;
                alu_src = 1'b1; wb_sel = 2'b01;
                alu_control = ALU_ADD;
            end
            OP_SH: begin
                mem_write = 1'b1; alu_src = 1'b1;
                alu_control = ALU_ADD;
            end

            // --- Milestone 2: I-Type ALU ---
            OP_ADDI: begin reg_write=1; alu_src=1; alu_control=ALU_ADD; end
            OP_SUBI: begin reg_write=1; alu_src=1; alu_control=ALU_SUB; end
            OP_ORI:  begin reg_write=1; alu_src=1; alu_control=ALU_OR;  end
            OP_ANDI: begin reg_write=1; alu_src=1; alu_control=ALU_AND; end
            OP_SLTI: begin reg_write=1; alu_src=1; alu_control=ALU_SLT; end

            // --- Milestone 2: Immediate Shifts ---
            OP_SHIMM: begin
                reg_write = 1'b1; alu_src = 1'b1;
                case (shtype)
                    2'b00: alu_control = ALU_SRL;
                    2'b01: alu_control = ALU_SLL;
                    2'b10: alu_control = ALU_SRA;
                    default: alu_control = ALU_SRL;
                endcase
            end

            // --- Milestone 2: Branches ---
            OP_BEQ: begin is_branch=1; branch_type=2'b00; end
            OP_BNE: begin is_branch=1; branch_type=2'b01; end
            OP_BLT: begin is_branch=1; branch_type=2'b10; end
            OP_BGE: begin is_branch=1; branch_type=2'b11; end

            // --- Milestone 2: Jumps ---
            OP_JAL: begin
                reg_write = 1'b1; is_jal = 1'b1;
                wb_sel = 2'b10; // write PC+1 to rd
            end
            OP_JALR: begin
                reg_write = 1'b1; is_jalr = 1'b1;
                alu_src = 1'b1; alu_control = ALU_ADD; // target = rs1+imm
                wb_sel = 2'b10; // write PC+1 to rd
            end

            default: begin /* NOP */ end
        endcase
    end
endmodule
