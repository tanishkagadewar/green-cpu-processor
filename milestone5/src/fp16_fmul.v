// ============================================================
// Module: fp16_fmul — IEEE 754 Half-Precision Floating-Point Multiplier
// Pure combinational. Handles: normals, denormals, zero, Inf, NaN.
// Rounding: Round-to-Nearest-Even (RNE).
// Overflow → Inf, Underflow → denormal or zero.
//
// FP16: [15] sign | [14:10] exponent (bias=15) | [9:0] fraction
// ============================================================

module fp16_fmul (
    input  wire [15:0] op_a,
    input  wire [15:0] op_b,
    output reg  [15:0] result
);
    // Unpack
    wire        s_a = op_a[15],       s_b = op_b[15];
    wire [4:0]  e_a = op_a[14:10],    e_b = op_b[14:10];
    wire [9:0]  f_a = op_a[9:0],      f_b = op_b[9:0];

    // Classify
    wire a_zero = (e_a == 0) && (f_a == 0);
    wire b_zero = (e_b == 0) && (f_b == 0);
    wire a_inf  = (e_a == 5'h1F) && (f_a == 0);
    wire b_inf  = (e_b == 5'h1F) && (f_b == 0);
    wire a_nan  = (e_a == 5'h1F) && (f_a != 0);
    wire b_nan  = (e_b == 5'h1F) && (f_b != 0);

    // Full mantissa {implicit, fraction}
    wire [10:0] m_a = (e_a == 0) ? {1'b0, f_a} : {1'b1, f_a};
    wire [10:0] m_b = (e_b == 0) ? {1'b0, f_b} : {1'b1, f_b};

    // Result sign
    wire res_sign = s_a ^ s_b;

    // Intermediates
    reg signed [7:0] exp_raw;
    reg [21:0] product;
    reg [10:0] res_mant;
    reg        guard, rbit, sticky, round_up;
    reg [11:0] mant_rounded;
    reg [4:0]  shift_r;
    reg signed [7:0] exp_final;

    always @(*) begin
        result = 16'h0000;

        if (a_nan || b_nan) begin
            result = 16'h7E00; // NaN
        end else if (a_inf || b_inf) begin
            if (a_zero || b_zero)
                result = 16'h7E00; // 0 × Inf = NaN
            else
                result = {res_sign, 5'h1F, 10'b0}; // Inf
        end else if (a_zero || b_zero) begin
            result = {res_sign, 15'b0}; // ±0
        end else begin
            // Effective exponents (denormals use exp=1)
            exp_raw = ((e_a == 0) ? 8'sd1 : {3'b0, e_a})
                    + ((e_b == 0) ? 8'sd1 : {3'b0, e_b})
                    - 8'sd15; // subtract bias

            product = m_a * m_b; // 11×11 = 22 bits

            // Normalize: product is in [0, 4) range
            // If product[21]=1: 1x.xxxx format, needs shift right
            if (product[21]) begin
                exp_raw  = exp_raw + 1;
                res_mant = product[21:11];
                guard    = product[10];
                rbit     = product[9];
                sticky   = |product[8:0];
            end else begin
                res_mant = product[20:10];
                guard    = product[9];
                rbit     = product[8];
                sticky   = |product[7:0];
            end

            // Handle denormal products (leading zeros in mantissa)
            // This happens when one or both inputs are denormals
            if (res_mant[10] == 0 && res_mant != 0) begin
                // Find and remove leading zeros
                while (res_mant[10] == 0 && exp_raw > 1) begin
                    res_mant = {res_mant[9:0], guard};
                    guard = rbit;
                    rbit = sticky;
                    sticky = 0;
                    exp_raw = exp_raw - 1;
                end
            end

            // Round to nearest even
            round_up = guard & (rbit | sticky | res_mant[0]);
            mant_rounded = {1'b0, res_mant} + (round_up ? 12'd1 : 12'd0);

            if (mant_rounded[11]) begin
                mant_rounded = mant_rounded >> 1;
                exp_raw = exp_raw + 1;
            end

            exp_final = exp_raw;

            // Overflow → Inf
            if (exp_final >= 31) begin
                result = {res_sign, 5'h1F, 10'b0};
            end
            // Underflow → denormal or zero
            else if (exp_final <= 0) begin
                shift_r = 1 - exp_final[4:0];
                if (shift_r >= 11)
                    result = {res_sign, 15'b0}; // flush to zero
                else begin
                    mant_rounded = mant_rounded >> shift_r;
                    result = {res_sign, 5'b0, mant_rounded[9:0]};
                end
            end
            // Normal result
            else begin
                result = {res_sign, exp_final[4:0], mant_rounded[9:0]};
            end
        end
    end
endmodule
