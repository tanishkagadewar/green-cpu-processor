// ============================================================
// Module: hazard_unit
// Detects load-use hazards → stall + bubble
// Detects taken branches/jumps → flush
// ============================================================
module hazard_unit (
    // Load-use detection (ID/EX stage)
    input wire       id_ex_mem_read,
    input wire [2:0] id_ex_rd,
    input wire [2:0] if_id_rs1, if_id_rs2,
    // Branch/jump flush (from EX evaluation)
    input wire       branch_taken, is_jal, is_jalr,
    // Outputs
    output wire      stall,       // freeze PC and IF/ID, bubble ID/EX
    output wire      flush        // flush IF/ID and ID/EX
);
    // Load-use: EX stage has a load, and ID stage reads the same register
    assign stall = id_ex_mem_read && (id_ex_rd != 0) &&
                   ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));

    // Flush on taken branch or any jump
    assign flush = branch_taken || is_jal || is_jalr;
endmodule
