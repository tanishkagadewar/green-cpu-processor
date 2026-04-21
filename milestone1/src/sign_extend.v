// ============================================================
// Module: sign_extend
// Purpose: Sign-extends a 6-bit immediate field to 16 bits
//          for use in I-type and S-type instructions.
//
// I/O Description:
//   imm_in  - 6-bit immediate from instruction[5:0]
//   imm_out - 16-bit sign-extended result
//
// Design Decisions:
//   - Pure combinational (no clock).
//   - Replicates bit [5] (MSB of immediate) across upper 10 bits.
//   - 6-bit signed range: -32 to +31.
//
// Waveform Checkpoints:
//   - Positive immediates: upper bits should be 0
//   - Negative immediates (bit 5 = 1): upper bits should be 1
// ============================================================

module sign_extend (
    input  wire [5:0]  imm_in,
    output wire [15:0] imm_out
);

    assign imm_out = {{10{imm_in[5]}}, imm_in};

endmodule
