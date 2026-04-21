// ============================================================
// Module: fp16_fadd — IEEE 754 Half-Precision Floating-Point Adder
// Pure combinational. Handles: normals, denormals, zero, Inf, NaN.
// Rounding: Round-to-Nearest-Even (RNE).
//
// FP16: [15] sign | [14:10] exponent (bias=15) | [9:0] fraction
// ============================================================

module fp16_fadd (
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

    // Full mantissa {implicit, fraction} and effective exponent
    wire [10:0] m_a = (e_a == 0) ? {1'b0, f_a} : {1'b1, f_a};
    wire [10:0] m_b = (e_b == 0) ? {1'b0, f_b} : {1'b1, f_b};
    wire [4:0] ee_a = (e_a == 0) ? 5'd1 : e_a;
    wire [4:0] ee_b = (e_b == 0) ? 5'd1 : e_b;

    // Magnitude comparison: is |a| >= |b|?
    wire a_ge_b = (ee_a > ee_b) || (ee_a == ee_b && m_a >= m_b);

    // Sorted: L=larger magnitude, S=smaller
    wire        s_L = a_ge_b ? s_a : s_b;
    wire        s_S = a_ge_b ? s_b : s_a;
    wire [4:0]  e_L = a_ge_b ? ee_a : ee_b;
    wire [4:0]  e_S = a_ge_b ? ee_b : ee_a;
    wire [10:0] m_L = a_ge_b ? m_a : m_b;
    wire [10:0] m_S = a_ge_b ? m_b : m_a;

    wire        eff_sub = s_L ^ s_S;
    wire [4:0]  exp_diff = e_L - e_S;

    // Intermediates
    reg [25:0] mL_wide, mS_wide, mS_shifted;
    reg        align_sticky;
    reg [26:0] sum_raw;
    reg signed [6:0] res_exp;
    reg        res_sign;
    reg [25:0] sum_norm;
    reg [10:0] res_mant;
    reg        guard, rbit, sticky, round_up;
    reg [11:0] mant_rounded;
    integer i;
    reg [4:0] lzc;

    always @(*) begin
        // Default
        result = 16'h0000;

        // ---- Special Cases ----
        if (a_nan || b_nan) begin
            result = 16'h7E00;
        end else if (a_inf && b_inf) begin
            result = (s_a == s_b) ? {s_a, 5'h1F, 10'b0} : 16'h7E00;
        end else if (a_inf) begin
            result = op_a;
        end else if (b_inf) begin
            result = op_b;
        end else if (a_zero && b_zero) begin
            result = (s_a & s_b) ? 16'h8000 : 16'h0000;
        end else if (a_zero) begin
            result = op_b;
        end else if (b_zero) begin
            result = op_a;
        end else begin
            // ---- Normal Computation ----
            mL_wide = {m_L, 15'b0};  // 26 bits
            mS_wide = {m_S, 15'b0};

            // Alignment shift with sticky
            if (exp_diff >= 26) begin
                mS_shifted = 0;
                align_sticky = |m_S;
            end else if (exp_diff == 0) begin
                mS_shifted = mS_wide;
                align_sticky = 0;
            end else begin
                mS_shifted = mS_wide >> exp_diff;
                align_sticky = 0;
                for (i = 0; i < 26; i = i + 1)
                    if (i < exp_diff) align_sticky = align_sticky | mS_wide[i];
            end

            // Add or subtract
            res_sign = s_L;
            if (!eff_sub) begin
                sum_raw = {1'b0, mL_wide} + {1'b0, mS_shifted};
            end else begin
                sum_raw = {1'b0, mL_wide} - {1'b0, mS_shifted};
                if (align_sticky) begin
                    sum_raw = sum_raw - 1;
                    align_sticky = 1;
                end
            end

            // Initialize
            res_exp = e_L;
            sum_norm = sum_raw[25:0];

            // Normalize: carry out from addition
            if (sum_raw[26]) begin
                sum_norm = sum_raw[26:1];
                align_sticky = align_sticky | sum_raw[0];
                res_exp = res_exp + 1;
            end else if (sum_raw[25:0] == 0) begin
                // Result is zero
                result = (eff_sub) ? 16'h0000 : {res_sign, 15'b0};
                res_exp = 0;
                sum_norm = 0;
            end else begin
                // Leading zero detection for subtraction
                lzc = 0;
                for (i = 25; i >= 0; i = i - 1)
                    if (sum_norm[i] == 0 && lzc == (25 - i)) lzc = lzc + 1;

                if (lzc > 0) begin
                    if (res_exp > lzc) begin
                        sum_norm = sum_norm << lzc;
                        res_exp = res_exp - lzc;
                    end else begin
                        // Denormal result
                        if (res_exp > 1) begin
                            sum_norm = sum_norm << (res_exp - 1);
                        end
                        res_exp = 0;
                    end
                end
            end

            if (sum_raw[25:0] != 0 || sum_raw[26]) begin
                // Extract mantissa and GRS
                res_mant = sum_norm[25:15];
                guard    = sum_norm[14];
                rbit     = sum_norm[13];
                sticky   = |sum_norm[12:0] | align_sticky;

                // Round to nearest even
                round_up = guard & (rbit | sticky | res_mant[0]);
                mant_rounded = {1'b0, res_mant} + (round_up ? 12'd1 : 12'd0);

                if (mant_rounded[11]) begin
                    mant_rounded = mant_rounded >> 1;
                    res_exp = res_exp + 1;
                end

                // Overflow check
                if (res_exp >= 31) begin
                    result = {res_sign, 5'h1F, 10'b0};
                end else if (res_exp <= 0) begin
                    result = {res_sign, 5'b0, mant_rounded[9:0]};
                end else begin
                    result = {res_sign, res_exp[4:0], mant_rounded[9:0]};
                end
            end
        end
    end
endmodule
