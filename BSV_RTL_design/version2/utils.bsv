package utils;

typedef struct {
    Bit#(1) sign;
    Bit#(8) exponent;
    Bit#(23) mantissa;
} Float32_t deriving(Bits, Eq);

interface Ifc_fpadder;
    method Action put_operands(Bit#(32) xbit, Bit#(32) ybit);
    method ActionValue#(Bit#(32)) get_result();
endinterface

interface Ifc_fpmax;
    method Action put_operands(Bit#(32) xbit, Bit#(32) ybit);
    method ActionValue#(Bit#(32)) get_result();
endinterface

function Int#(8) fn_findleadone33 (Bit#(33) x);
    Int#(8) index;
    case (1)
        x[32] : index = 32;
        x[31] : index = 31;
        x[30] : index = 30;
        x[29] : index = 29;
        x[28] : index = 28;
        x[27] : index = 27;
        x[26] : index = 26;
        x[25] : index = 25;
        x[24] : index = 24;
        x[23] : index = 23;
        x[22] : index = 22;
        x[21] : index = 21;
        x[20] : index = 20;
        x[19] : index = 19;
        x[18] : index = 18;
        x[17] : index = 17;
        x[16] : index = 16;
        x[15] : index = 15;
        x[14] : index = 14;
        x[13] : index = 13;
        x[12] : index = 12;
        x[11] : index = 11;
        x[10] : index = 10;
        x[9]  : index = 9;
        x[8]  : index = 8;
        x[7]  : index = 7;
        x[6]  : index = 6;
        x[5]  : index = 5;
        x[4]  : index = 4;
        x[3]  : index = 3;
        x[2]  : index = 2;
        x[1]  : index = 1;
        x[0]  : index = 0;
        default: index = -1;
    endcase
    return index;
endfunction

(*synthesize*)
module mkFPadder(Ifc_fpadder);
    // Registers for operands and result
    Reg#(Bit#(32)) rg_operand1 <- mkReg(0);
    Reg#(Bit#(32)) rg_operand2 <- mkReg(0);
    Reg#(Bit#(32)) rg_result <- mkReg(0);
    Reg#(Bool) rg_valid <- mkReg(False);
    Reg#(Bool) rg_result_ready <- mkReg(False);

    // Rule to process floating-point addition
    rule rl_fpadd(rg_valid && !rg_result_ready);
        Bit#(32) xbit = rg_operand1;
        Bit#(32) ybit = rg_operand2;
        
        Float32_t x = unpack(xbit);
        Float32_t y = unpack(ybit);
        Float32_t result;

        result.sign = 0;
        result.exponent = 0;
        result.mantissa = 0;

        Bool x_is_zero = (x.exponent == 0 && x.mantissa == 0);
        Bool y_is_zero = (y.exponent == 0 && y.mantissa == 0);
        Bool do_normal_add = !(x_is_zero || y_is_zero);

        if (x_is_zero && !y_is_zero) begin
            result = y;
        end else if (y_is_zero && !x_is_zero) begin
            result = x;
        end else if (x_is_zero && y_is_zero) begin
            // result already zero
        end else if (do_normal_add) begin
            // Fixed exponent difference calculation
            Int#(10) exp_x = unpack(zeroExtend(x.exponent));
            Int#(10) exp_y = unpack(zeroExtend(y.exponent));
            Int#(10) exp_diff = exp_x - exp_y;

            Bit#(32) mant_x = {1'b1, x.mantissa, 8'b0};
            Bit#(32) mant_y = {1'b1, y.mantissa, 8'b0};

            if (exp_diff >= 0) begin
                mant_y = mant_y >> pack(exp_diff);
                result.exponent = x.exponent;
            end else begin
                mant_x = mant_x >> pack(-exp_diff);
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

            // Normalization
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

            // Rounding
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

        rg_result <= pack(result);
        rg_valid <= False;
        rg_result_ready <= True;
    endrule

    method Action put_operands(Bit#(32) xbit, Bit#(32) ybit) if (!rg_valid);
        rg_operand1 <= xbit;
        rg_operand2 <= ybit;
        rg_valid <= True;
        rg_result_ready <= False;
    endmethod

    method ActionValue#(Bit#(32)) get_result() if (rg_result_ready);
        rg_result_ready <= False;
        return rg_result;
    endmethod
endmodule

(*synthesize*)
module mkFindmax(Ifc_fpmax);
    Reg#(Bit#(32)) rg_operand1 <- mkReg(0);
    Reg#(Bit#(32)) rg_operand2 <- mkReg(0);
    Reg#(Bit#(32)) rg_result <- mkReg(0);
    Reg#(Bool) rg_valid <- mkReg(False);
    Reg#(Bool) rg_result_ready <- mkReg(False);

    rule rl_fpmax(rg_valid && !rg_result_ready);
        Bit#(32) xbit = rg_operand1;
        Bit#(32) ybit = rg_operand2;
        
        Float32_t x = unpack(xbit);
        Float32_t y = unpack(ybit);

        Bit#(32) result = 0;
        Bit#(32) key_x = 0, key_y = 0;
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
        
        rg_result <= result;
        rg_valid <= False;
        rg_result_ready <= True;
    endrule

    method Action put_operands(Bit#(32) xbit, Bit#(32) ybit) if (!rg_valid);
        rg_operand1 <= xbit;
        rg_operand2 <= ybit;
        rg_valid <= True;
        rg_result_ready <= False;
    endmethod

    method ActionValue#(Bit#(32)) get_result() if (rg_result_ready);
        rg_result_ready <= False;
        return rg_result;
    endmethod
endmodule

endpackage
