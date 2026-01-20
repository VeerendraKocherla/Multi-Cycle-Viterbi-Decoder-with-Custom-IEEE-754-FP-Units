package utils;

typedef struct {
    Bit#(1) sign;
    Bit#(8) exponent;
    Bit#(23) mantissa;
} Float32_t deriving(Bits, Eq);

interface Ifc_fpadder;
    method Bit#(32) fpadd(Bit#(32) xbit, Bit#(32) ybit);
endinterface

interface Ifc_fpmax;
    method Bit#(32) fpmax(Bit#(32) xbit, Bit#(32) ybit);
endinterface

function Int#(8) fn_findleadone33 (Bit#(33) x);
    Int#(8) index = -1;
    Bool found = False;
    for (Integer i = 32; i >= 0; i = i - 1) begin
        if (x[i] == 1 && found == False) begin
            index = fromInteger(i);
            found = True;
        end
    end
    return index;
endfunction


(*synthesize*)
module mkFPadder(Ifc_fpadder);

method Bit#(32) fpadd(Bit#(32) xbit, Bit#(32) ybit);

    Float32_t x = unpack(xbit);
    Float32_t y = unpack(ybit);
    Float32_t result;

    // Default result initialization
    result.sign = 0;
    result.exponent = 0;
    result.mantissa = 0;

    // --- Detect special cases ---
    Bool x_is_zero = (x.exponent == 0 && x.mantissa == 0);
    Bool y_is_zero = (y.exponent == 0 && y.mantissa == 0);

    // --- Handle zero cases through control flags ---
    Bool do_normal_add = !(x_is_zero || y_is_zero);

    if (x_is_zero && !y_is_zero) begin
        result = y;
    end else if (y_is_zero && !x_is_zero) begin
        result = x;
    end else if (x_is_zero && y_is_zero) begin
        // result already initialized to zero
    end else if (do_normal_add) begin

        // --- Normal floating-point addition ---
        Int#(8) exp_diff = unpack(signExtend(x.exponent)) - unpack(signExtend(y.exponent));

        Bit#(32) mant_x = {1'b1, x.mantissa, 8'b0};
        Bit#(32) mant_y = {1'b1, y.mantissa, 8'b0};

        if (exp_diff >= 0) begin
            mant_y = mant_y >> exp_diff;
            result.exponent = x.exponent;
        end else begin
            mant_x = mant_x >> (-exp_diff);
            result.exponent = y.exponent;
        end

        Bit#(33) mant_sum;

        if (x.sign == y.sign) begin
            mant_sum = zeroExtend(mant_x) + zeroExtend(mant_y);
            result.sign = x.sign;
        end else begin
            if (mant_x >= mant_y) begin
                mant_sum = zeroExtend(mant_x) - zeroExtend(mant_y);
                result.sign = x.sign;
            end else begin
                mant_sum = zeroExtend(mant_y) - zeroExtend(mant_x);
                result.sign = y.sign;
            end
        end

        // --- Normalization ---
        if (mant_sum[32] == 1) begin
            mant_sum = mant_sum >> 1;
            result.exponent = result.exponent + 1;
        end else if (mant_sum[31] == 0) begin
            Int#(8) idbit = fn_findleadone33(mant_sum);
            if (idbit == -1) begin
                result.exponent = 8'b0;
                result.sign = 0;
            end else begin 
                mant_sum = mant_sum << (8'd31 - idbit);
                result.exponent = result.exponent - pack(8'd31 - idbit);
            end
        end

        // --- Rounding (Round to Nearest, Even) ---
        Bit#(24) fraction = zeroExtend(mant_sum[30:8]);
        Bit#(1) g = mant_sum[7];
        Bit#(1) r = mant_sum[6];
        Bit#(1) s = reduceOr(mant_sum[5:0]);
        Bit#(1) lsb = mant_sum[8];

        Bool round_up = False;
        if (g == 1) begin
            if (r == 1 || s == 1) begin
                round_up = True;
            end else if (lsb == 1) begin
                round_up = True;
            end
        end

        if (round_up) begin
            fraction = fraction + 24'd1;
            if (fraction[23] == 1) begin
                result.exponent = result.exponent + 1;
            end
        end

        result.mantissa = truncate(fraction);
    end

    return pack(result);
endmethod

endmodule

(*synthesize*)
module mkFindmax(Ifc_fpmax);
    method Bit#(32) fpmax(Bit#(32) xbit, Bit#(32) ybit);
        Float32_t x = unpack(xbit);
        Float32_t y = unpack(ybit);

        Bit#(32) result = 0;
        Bit#(32) key_x=0, key_y=0;
        let isNan_x = (x.exponent == 8'hFF) && (x.mantissa != 0);
        let isNan_y = (y.exponent == 8'hFF) && (y.mantissa != 0);

        if (isNan_x && isNan_y) begin
            result = 32'h7FC00000;
        end else if (isNan_x) begin
            result = ybit;
        end else if (isNan_y) begin
            result = xbit;
        end else begin 
            key_x = (x.sign == 1) ? ~xbit : (xbit ^ 32'h80000000);
            key_y = (y.sign == 1) ? ~ybit : (ybit ^ 32'h80000000);
            if (key_x >= key_y) begin 
                result = xbit;
            end else begin
                result = ybit;
            end
        end
        return result;
    endmethod
endmodule
endpackage