// ============================================================
// Module: control_unit (Milestone 5 — with Crypto instructions)
//
// UPDATED ENCODING TABLE for opcode 1111:
//   [15:12=1111][11:9 rd][8:6 rs1][5:3 rs2][2:0 funct]
//   funct=000: FADD  rd = fp_add(rs1, rs2)
//   funct=001: FMUL  rd = fp_mul(rs1, rs2)
//   funct=010: ENC   rd = encrypt(rs1, key=rs2)  ← NEW
//   funct=011: DEC   rd = decrypt(rs1, key=rs2)  ← NEW
// ============================================================
module control_unit (
    input  wire [3:0] opcode,
    input  wire [2:0] funct,
    input  wire [1:0] shtype,
    output reg        reg_write, mem_read, mem_write, alu_src,
    output reg  [1:0] wb_sel,
    output reg  [3:0] alu_control,
    output reg        is_branch, is_jal, is_jalr,
    output reg  [1:0] branch_type,
    output reg        is_fpu, fpu_op,
    output reg        is_crypto, crypto_mode  // NEW: 0=ENC, 1=DEC
);
    localparam OP_RTYPE=0, OP_LH=1, OP_SH=2, OP_ADDI=3, OP_SUBI=4;
    localparam OP_ORI=5, OP_ANDI=6, OP_SLTI=7, OP_SHIMM=8;
    localparam OP_BEQ=9, OP_BNE=10, OP_BLT=11, OP_BGE=12;
    localparam OP_JAL=13, OP_JALR=14, OP_SPECIAL=15;

    always @(*) begin
        reg_write=0; mem_read=0; mem_write=0; alu_src=0;
        wb_sel=0; alu_control=0; is_branch=0; branch_type=0;
        is_jal=0; is_jalr=0; is_fpu=0; fpu_op=0;
        is_crypto=0; crypto_mode=0;
        case (opcode)
            OP_RTYPE: begin reg_write=1;
                case(funct) 0:alu_control=0; 1:alu_control=1; 2:alu_control=2;
                    3:alu_control=3; 4:alu_control=4; 5:alu_control=5;
                    6:alu_control=6; 7:alu_control=7; default:alu_control=0;
                endcase end
            OP_LH:   begin reg_write=1; mem_read=1; alu_src=1; wb_sel=1; end
            OP_SH:   begin mem_write=1; alu_src=1; end
            OP_ADDI: begin reg_write=1; alu_src=1; alu_control=0; end
            OP_SUBI: begin reg_write=1; alu_src=1; alu_control=1; end
            OP_ORI:  begin reg_write=1; alu_src=1; alu_control=3; end
            OP_ANDI: begin reg_write=1; alu_src=1; alu_control=4; end
            OP_SLTI: begin reg_write=1; alu_src=1; alu_control=2; end
            OP_SHIMM: begin reg_write=1; alu_src=1;
                case(shtype) 0:alu_control=5; 1:alu_control=6; 2:alu_control=7;
                    default:alu_control=5; endcase end
            OP_BEQ:  begin is_branch=1; branch_type=0; end
            OP_BNE:  begin is_branch=1; branch_type=1; end
            OP_BLT:  begin is_branch=1; branch_type=2; end
            OP_BGE:  begin is_branch=1; branch_type=3; end
            OP_JAL:  begin reg_write=1; is_jal=1; wb_sel=2; end
            OP_JALR: begin reg_write=1; is_jalr=1; alu_src=1; wb_sel=2; end
            OP_SPECIAL: begin
                case (funct)
                    3'b000: begin reg_write=1; is_fpu=1; fpu_op=0; end // FADD
                    3'b001: begin reg_write=1; is_fpu=1; fpu_op=1; end // FMUL
                    3'b010: begin reg_write=1; is_crypto=1; crypto_mode=0; end // ENC
                    3'b011: begin reg_write=1; is_crypto=1; crypto_mode=1; end // DEC
                    default: ;
                endcase
            end
            default: ;
        endcase
    end
endmodule
