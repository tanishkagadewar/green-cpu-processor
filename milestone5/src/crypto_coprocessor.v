// ============================================================
// Module: crypto_coprocessor
// Purpose: 16-bit SPN block cipher with 4 rounds.
//   Encryption: state = P(S(state ^ rk[i])) for 4 rounds + final key
//   Decryption: inverse operations with reversed key order
//
// Uses PRESENT cipher S-box (4-bit, applied to 4 nibbles).
// Bit permutation is self-inverse (PRESENT-style).
// Key schedule: 5 round keys derived by rotation + XOR with constants.
//
// Interface: multi-cycle with ready/valid handshake.
//   start=1 begins computation. done=1 signals result ready.
//   Latency: 5 cycles (1 startup + 4 rounds).
//
// Design Decision: Instruction-triggered (ENC/DEC opcodes) rather
//   than memory-mapped, because it integrates cleanly with the
//   register-to-register datapath and avoids address space conflicts.
//
// Waveform Checkpoints:
//   active, round_counter, state, done, data_out
// ============================================================

module crypto_coprocessor (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,     // pulse to begin operation
    input  wire        mode,      // 0=encrypt, 1=decrypt
    input  wire [15:0] data_in,   // plaintext or ciphertext
    input  wire [15:0] key_in,    // encryption/decryption key
    output wire        done,      // result ready (combinational)
    output wire [15:0] data_out,  // result (valid when done=1)
    output reg         active     // busy flag
);

    // ---- S-box (PRESENT cipher, 4-bit bijection) ----
    function [3:0] sbox;
        input [3:0] x;
        case (x)
            0:sbox=4'hC; 1:sbox=4'h5; 2:sbox=4'h6;  3:sbox=4'hB;
            4:sbox=4'h9; 5:sbox=4'h0; 6:sbox=4'hA;  7:sbox=4'hD;
            8:sbox=4'h3; 9:sbox=4'hE; 10:sbox=4'hF; 11:sbox=4'h8;
           12:sbox=4'h4;13:sbox=4'h7; 14:sbox=4'h1; 15:sbox=4'h2;
        endcase
    endfunction

    // ---- Inverse S-box ----
    function [3:0] inv_sbox;
        input [3:0] x;
        case (x)
            0:inv_sbox=4'h5; 1:inv_sbox=4'hE; 2:inv_sbox=4'hF;  3:inv_sbox=4'h8;
            4:inv_sbox=4'hC; 5:inv_sbox=4'h1; 6:inv_sbox=4'h2;  7:inv_sbox=4'hD;
            8:inv_sbox=4'hB; 9:inv_sbox=4'h4; 10:inv_sbox=4'h6; 11:inv_sbox=4'h3;
           12:inv_sbox=4'h0;13:inv_sbox=4'h7; 14:inv_sbox=4'h9; 15:inv_sbox=4'hA;
        endcase
    endfunction

    // ---- Sub-bytes: S-box applied to all 4 nibbles ----
    function [15:0] sub_bytes;
        input [15:0] x;
        sub_bytes = {sbox(x[15:12]), sbox(x[11:8]), sbox(x[7:4]), sbox(x[3:0])};
    endfunction

    function [15:0] inv_sub_bytes;
        input [15:0] x;
        inv_sub_bytes = {inv_sbox(x[15:12]), inv_sbox(x[11:8]),
                         inv_sbox(x[7:4]), inv_sbox(x[3:0])};
    endfunction

    // ---- Bit Permutation (PRESENT-style, self-inverse) ----
    // P[i] = (4*i) mod 15 for i<15, P[15]=15
    function [15:0] permute;
        input [15:0] x;
        begin
            permute[0]=x[0];   permute[1]=x[4];   permute[2]=x[8];   permute[3]=x[12];
            permute[4]=x[1];   permute[5]=x[5];   permute[6]=x[9];   permute[7]=x[13];
            permute[8]=x[2];   permute[9]=x[6];   permute[10]=x[10]; permute[11]=x[14];
            permute[12]=x[3];  permute[13]=x[7];  permute[14]=x[11]; permute[15]=x[15];
        end
    endfunction

    // ---- Rotate left ----
    function [15:0] rotl;
        input [15:0] x;
        input integer n;
        rotl = (x << n) | (x >> (16 - n));
    endfunction

    // ---- State Machine ----
    reg [2:0]  round_counter;
    reg [15:0] state;
    // 'active' declared as output reg in port list
    reg        saved_mode;
    reg [15:0] saved_key;

    // ---- Key Schedule (from saved key) ----
    reg [15:0] rk0, rk1, rk2, rk3, rk4;
    always @(*) begin
        rk0 = saved_key;
        rk1 = rotl(saved_key, 3)  ^ 16'h1234;
        rk2 = rotl(saved_key, 6)  ^ 16'h5678;
        rk3 = rotl(saved_key, 9)  ^ 16'h9ABC;
        rk4 = rotl(saved_key, 12) ^ 16'hDEF0;
    end

    // Select round key based on counter
    reg [15:0] enc_key, dec_key;
    always @(*) begin
        case (round_counter[1:0])
            0: begin enc_key = rk0; dec_key = rk3; end
            1: begin enc_key = rk1; dec_key = rk2; end
            2: begin enc_key = rk2; dec_key = rk1; end
            3: begin enc_key = rk3; dec_key = rk0; end
        endcase
    end

    // ---- Round computation (combinational) ----
    reg [15:0] next_state;
    always @(*) begin
        next_state = state;
        if (active) begin
            if (!saved_mode) begin
                // Encryption: P(S(state ^ key))
                next_state = permute(sub_bytes(state ^ enc_key));
                if (round_counter == 3)
                    next_state = next_state ^ rk4; // final whitening
            end else begin
                // Decryption: inv_S(P(state)) ^ key
                if (round_counter == 0)
                    next_state = inv_sub_bytes(permute(state ^ rk4)) ^ dec_key;
                else
                    next_state = inv_sub_bytes(permute(state)) ^ dec_key;
            end
        end
    end

    // Done is combinational — result available same cycle
    assign done = active && (round_counter == 3);
    assign data_out = next_state;

    // ---- Sequential state update ----
    always @(posedge clk) begin
        if (rst) begin
            active <= 0;
            round_counter <= 0;
            state <= 0;
            saved_mode <= 0;
            saved_key <= 0;
        end else if (start && !active) begin
            active <= 1;
            round_counter <= 0;
            state <= data_in;
            saved_mode <= mode;
            saved_key <= key_in;
        end else if (active) begin
            state <= next_state;
            if (done)
                active <= 0;
            else
                round_counter <= round_counter + 1;
        end
    end

endmodule
