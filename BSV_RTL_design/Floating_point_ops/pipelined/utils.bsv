package utils;

typedef struct {
    Bit#(1) sign;
    Bit#(8) exponent;
    Bit#(23) mantissa;
} Float32_t deriving(Bits, Eq);

typedef struct {
    Bool do_normal_add;
    Float32_t x;
    Float32_t y;
    Float32_t bypassres;
} Stage1out deriving(Bits, Eq);

typedef struct {
    Bit#(1) signx; 
    Bit#(1) signy;
    Bit#(32) mant_x;
    Bit#(32) mant_y;
    Bit#(8) result_exponent;
    Bool do_normal_add;
    Float32_t bypassres;
} Stage2out deriving(Bits, Eq);

typedef struct {
    Bool  do_normal_add;
    Bit#(33) mant_sum;
    Bit#(8) result_exponent; 
    Bit#(1) result_sign;
    Float32_t bypassres;  // Keep bypassres for bypass path
} Stage3out deriving(Bits, Eq);

typedef struct {
    Bool do_normal_add;
    Bit#(33) normalized_mant;
    Bit#(8) result_exponent;
    Bit#(1) result_sign;
    Float32_t bypassres;  // Propagate bypass result
} Stage4out deriving(Bits, Eq);

interface Ifc_fpadder;
    method Action startadd(Bit#(32) xbit, Bit#(32) ybit);
    method Bit#(32) fpadd_response();
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

    Reg#(Stage1out) rg_stage1 <- mkRegU;
    Reg#(Stage2out) rg_stage2 <- mkRegU;
    Reg#(Stage3out) rg_stage3 <- mkRegU;
    Reg#(Stage4out) rg_stage4 <- mkRegU;

    rule rl_stage2;
        let s1 = rg_stage1;
        Bit#(32) mant_x = 0;
        Bit#(32) mant_y = 0;
        Bit#(8) result_exponent = 0;

        if (s1.do_normal_add) begin
            Int#(8) exp_diff = unpack(signExtend(s1.x.exponent)) - unpack(signExtend(s1.y.exponent));

            mant_x = {1'b1, s1.x.mantissa, 8'b0};
            mant_y = {1'b1, s1.y.mantissa, 8'b0};

            if (exp_diff >= 0) begin
                mant_y = mant_y >> exp_diff;
                result_exponent = s1.x.exponent;
            end else begin
                mant_x = mant_x >> (-exp_diff);
                result_exponent = s1.y.exponent;
            end
        end
        
        Stage2out s2 = Stage2out { 
            signx: s1.x.sign, 
            signy: s1.y.sign,
            mant_x: mant_x, 
            mant_y: mant_y,
            result_exponent: result_exponent,
            bypassres: s1.bypassres,
            do_normal_add: s1.do_normal_add
        };
        rg_stage2 <= s2;
    endrule

    rule rl_stage3;
        let s2 = rg_stage2;
        Bit#(8) result_exponent;
        Bit#(1) result_sign;
        Bit#(33) mant_sum;
        
        if (s2.do_normal_add) begin
            if (s2.signx == s2.signy) begin
                mant_sum = zeroExtend(s2.mant_x) + zeroExtend(s2.mant_y);
                result_sign = s2.signx;
            end else begin
                if (s2.mant_x >= s2.mant_y) begin
                    mant_sum = zeroExtend(s2.mant_x) - zeroExtend(s2.mant_y);
                    result_sign = s2.signx;
                end else begin
                    result_sign = s2.signy;
                    mant_sum = zeroExtend(s2.mant_y) - zeroExtend(s2.mant_x);
                end
            end
            result_exponent = s2.result_exponent;
        end else begin 
            mant_sum = 33'b0;  
            result_exponent = s2.bypassres.exponent;
            result_sign = s2.bypassres.sign;
        end
        
        Stage3out s3 = Stage3out { 
            do_normal_add: s2.do_normal_add, 
            mant_sum: mant_sum, 
            result_exponent: result_exponent, 
            result_sign: result_sign,
            bypassres: s2.bypassres
        };
        rg_stage3 <= s3;
    endrule

    // === Stage 4: normalization ONLY ===
    rule rl_stage4;
        let s3 = rg_stage3;
        Bit#(33) normalized_mant;
        Bit#(8) result_exponent;
        Bit#(1) result_sign;

        if (s3.do_normal_add) begin
            Bit#(33) m = s3.mant_sum;
            Bit#(8) exp = s3.result_exponent;
            Bit#(1) sign = s3.result_sign;

            if (m[32] == 1) begin
                m = m >> 1;
                exp = exp + 1;
            end else if (m[31] == 0) begin
                Int#(8) idbit = fn_findleadone33(m);
                if (idbit == -1) begin
                    exp = 8'b0;
                    sign = 0;
                    m = 0;
                end else begin
                    Bit#(8) shift_amount = pack(8'd31 - idbit);
                    m = m << shift_amount;
                    exp = exp - shift_amount;
                end
            end
            
            normalized_mant = m;
            result_exponent = exp;
            result_sign = sign;
        end else begin
            normalized_mant = 33'b0;  
            result_exponent = s3.bypassres.exponent;
            result_sign = s3.bypassres.sign;
        end

        Stage4out s4 = Stage4out {
            do_normal_add: s3.do_normal_add,
            normalized_mant: normalized_mant,
            result_exponent: result_exponent,
            result_sign: result_sign,
            bypassres: s3.bypassres
        };
        rg_stage4 <= s4;
    endrule

    method Action startadd(Bit#(32) xbit, Bit#(32) ybit);
        Float32_t x = unpack(xbit);
        Float32_t y = unpack(ybit);
        Float32_t res = unpack(0);

        Bool x_is_zero = (x.exponent == 0 && x.mantissa == 0);
        Bool y_is_zero = (y.exponent == 0 && y.mantissa == 0);
        Bool do_normal_add = !(x_is_zero || y_is_zero);

        if (x_is_zero && !y_is_zero) begin
            res = y;
        end else if (y_is_zero && !x_is_zero) begin
            res = x;
        end else if (x_is_zero && y_is_zero) begin
            res = unpack(0);
        end
        
        Stage1out s1 = Stage1out { 
            do_normal_add: do_normal_add,
            x: x, 
            y: y, 
            bypassres: res
        };
        rg_stage1 <= s1;
    endmethod

    method Bit#(32) fpadd_response();
        let s4 = rg_stage4;
        Bit#(32) result;

        if (s4.do_normal_add) begin
            Bit#(33) m = s4.normalized_mant;
            Bit#(8) exp = s4.result_exponent;
            Bit#(1) sign = s4.result_sign;
            
            Bit#(24) fraction = zeroExtend(m[30:8]); 
            Bit#(1) g = m[7];   // Guard bit
            Bit#(1) r = m[6];   // Round bit
            Bit#(1) s = reduceOr(m[5:0]);  // Sticky bit
            Bit#(1) lsb = m[8];  // LSB

            Bit#(1) round_up = g & (r | s | lsb);

            if (round_up == 1) begin
                fraction = fraction + 24'd1;
                if (fraction[23] == 1) begin
                    exp = exp + 1;
                end
            end

            Bit#(23) result_mantissa = fraction[22:0];
            result = {sign, exp, result_mantissa};
        end else begin
            result = pack(s4.bypassres);
        end

        return result;
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