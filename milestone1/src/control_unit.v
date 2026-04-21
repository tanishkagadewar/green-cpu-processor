// ============================================================
// Module: control_unit
// Purpose: Decodes the 4-bit opcode and 3-bit funct field to
//          generate all datapath control signals.
//
// I/O Description:
//   opcode      - instruction[15:12], selects instruction type
//   funct       - instruction[2:0], selects R-type operation
//   reg_write   - Enable write to register file
//   mem_read    - Enable data memory read
//   mem_write   - Enable data memory write
//   alu_src     - 0: ALU input B = rs2_data
//                 1: ALU input B = sign-extended immediate
//   mem_to_reg  - 0: write-back = ALU result
//                 1: write-back = memory read data
//   alu_control - 4-bit ALU operation selector
//
// ============================================================
// 16-bit ISA ENCODING TABLE — Milestone 1
// ============================================================
//
// R-Type Format: [15:12 opcode][11:9 rd][8:6 rs1][5:3 rs2][2:0 funct]
//   Opcode = 4'b0000
//   -----------------------------------------------------------
//   Instruction | funct | Operation          | Encoding Example
//   -----------------------------------------------------------
//   ADD rd,rs1,rs2 | 000 | rd = rs1 + rs2    | 0000_ddd_sss_ttt_000
//   SUB rd,rs1,rs2 | 001 | rd = rs1 - rs2    | 0000_ddd_sss_ttt_001
//   SLT rd,rs1,rs2 | 010 | rd = (rs1<rs2)?1:0| 0000_ddd_sss_ttt_010
//   OR  rd,rs1,rs2 | 011 | rd = rs1 | rs2    | 0000_ddd_sss_ttt_011
//   AND rd,rs1,rs2 | 100 | rd = rs1 & rs2    | 0000_ddd_sss_ttt_100
//   SRL rd,rs1,rs2 | 101 | rd = rs1 >> rs2   | 0000_ddd_sss_ttt_101
//   SLL rd,rs1,rs2 | 110 | rd = rs1 << rs2   | 0000_ddd_sss_ttt_110
//   SRA rd,rs1,rs2 | 111 | rd = rs1 >>> rs2  | 0000_ddd_sss_ttt_111
//
// I-Type Format (Load): [15:12 opcode][11:9 rd][8:6 rs1][5:0 imm6]
//   -----------------------------------------------------------
//   LH rd, imm(rs1) | Opcode=0001 | rd = mem[rs1+sext(imm)]
//
// S-Type Format (Store): [15:12 opcode][11:9 rs2][8:6 rs1][5:0 imm6]
//   -----------------------------------------------------------
//   SH rs2, imm(rs1) | Opcode=0010 | mem[rs1+sext(imm)] = rs2
//
// Note: d=rd bits, s=rs1 bits, t=rs2 bits
//       Shifts use rs2[3:0] as shift amount (max 15)
//       imm6 is sign-extended to 16 bits (range: -32 to +31)
// ============================================================
//
// Waveform Checkpoints:
//   - Verify control signals change correctly with opcode
//   - Check alu_control maps correctly from funct for R-type
// ============================================================

module control_unit (
    input  wire [3:0] opcode,
    input  wire [2:0] funct,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src,
    output reg        mem_to_reg,
    output reg  [3:0] alu_control
);

    // Opcode definitions
    localparam OP_RTYPE = 4'b0000;
    localparam OP_LH    = 4'b0001;
    localparam OP_SH    = 4'b0010;

    // ALU operation codes (shared with alu.v)
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_SLT = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_AND = 4'b0100;
    localparam ALU_SRL = 4'b0101;
    localparam ALU_SLL = 4'b0110;
    localparam ALU_SRA = 4'b0111;

    always @(*) begin
        // Default: all signals deasserted (NOP-safe)
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        alu_src     = 1'b0;
        mem_to_reg  = 1'b0;
        alu_control = ALU_ADD;

        case (opcode)
            OP_RTYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;  // Use rs2
                mem_to_reg = 1'b0; // Write ALU result
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
                reg_write   = 1'b1;  // Write loaded data to rd
                mem_read    = 1'b1;  // Read from data memory
                alu_src     = 1'b1;  // ALU B = immediate (addr calc)
                mem_to_reg  = 1'b1;  // Write-back = memory data
                alu_control = ALU_ADD; // Address = rs1 + imm
            end

            OP_SH: begin
                mem_write   = 1'b1;  // Write to data memory
                alu_src     = 1'b1;  // ALU B = immediate (addr calc)
                alu_control = ALU_ADD; // Address = rs1 + imm
            end

            default: begin
                // Undefined opcode — all signals stay at defaults (NOP)
            end
        endcase
    end

endmodule
