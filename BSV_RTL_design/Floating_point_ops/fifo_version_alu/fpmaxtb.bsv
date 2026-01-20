package fpmaxtb;
import utils::*;


module mkTbFpMaxComparator(Empty);


    Ifc_fpmax dut <- mkFindmax;
    Reg#(UInt#(8)) idx <- mkReg(0);
    Reg#(Bool) test_sent <- mkReg(False);


    // Constants in lowercase
    Bit#(32) pos_zero = 32'h00000000;
    Bit#(32) neg_zero = 32'h80000000;
    Bit#(32) pos_inf  = 32'h7f800000;
    Bit#(32) neg_inf  = 32'hff800000;
    Bit#(32) qnan     = 32'h7fc00000;


    Bit#(32) pi_val     = 32'h40490fdb;  // 3.1415
    Bit#(32) neg_2_17   = 32'hc0ad70a4;  // -2.17
    Bit#(32) pos_half   = 32'h3f000000;  // 0.5
    Bit#(32) neg_quarter= 32'hbe800000;  // -0.25
    Bit#(32) three      = 32'h40400000;  // 3.0
    Bit#(32) two        = 32'h40000000;  // 2.0


    // Helper function for NaN-safe compare
    function Bool equal_fp(Bit#(32) x, Bit#(32) y);
        if ((x[30:23] == 8'hff && x[22:0] != 0) &&
            (y[30:23] == 8'hff && y[22:0] != 0))
            return True; // both NaNs
        else
            return (x == y);
    endfunction


    // Rule to send test inputs
    rule send_tests (idx <= 23 && !test_sent);
        Bit#(32) a = 0;
        Bit#(32) b = 0;


        case (idx)
            0:  begin a = three;        b = two;          end // 3 vs 2
            1:  begin a = neg_2_17;     b = pos_half;     end // -2.17 vs 0.5
            2:  begin a = pi_val;       b = neg_2_17;     end // 3.1415 vs -2.17
            3:  begin a = pos_zero;     b = neg_zero;     end // +0 vs -0
            4:  begin a = pos_inf;      b = two;          end // inf vs 2.0
            5:  begin a = neg_inf;      b = pi_val;       end // -inf vs pi
            6:  begin a = pos_inf;      b = neg_inf;      end // inf vs -inf
            7:  begin a = pi_val;       b = pos_inf;      end // pi vs inf
            8:  begin a = neg_2_17;     b = neg_inf;      end // -2.17 vs -inf
            9:  begin a = qnan;         b = pi_val;       end // NaN vs pi
            10: begin a = pi_val;       b = qnan;         end // pi vs NaN
            11: begin a = qnan;         b = qnan;         end // NaN vs NaN
            12: begin a = pos_inf;      b = qnan;         end // inf vs NaN
            13: begin a = neg_inf;      b = pos_inf;      end // -inf vs inf
            14: begin a = neg_quarter;  b = pos_half;     end // -0.25 vs 0.5
            15: begin a = neg_2_17;     b = neg_quarter;  end // -2.17 vs -0.25
            16: begin a = pi_val;       b = pi_val;       end // equal values
            17: begin a = 32'h00000001; b = 32'h00000002; end // subnormals
            18: begin a = neg_inf;      b = neg_inf;      end // -inf vs -inf
            19: begin a = pos_zero;     b = pos_zero;     end // +0 vs +0
            20: begin a = neg_zero;     b = neg_zero;     end // -0 vs -0
            21: begin a = 32'h00000001; b = 32'h80000001; end // +subnormal vs -subnormal
            22: begin a = 32'h7F7FFFFF; b = pos_inf;      end // largest finite vs +inf
            23: begin a = 32'hFF7FFFFF; b = neg_inf;      end // largest negative finite vs -inf
            default: begin a = 0; b = 0; end
        endcase


        dut.put_operands(a, b);
        test_sent <= True;
        $display("[test %0d] Sent: a=%h b=%h", idx, a, b);
    endrule


    // Rule to receive and check results
    rule check_results (test_sent);
        Bit#(32) expected = 0;


        case (idx)
            0:  expected = three;
            1:  expected = pos_half;
            2:  expected = pi_val;
            3:  expected = pos_zero;
            4:  expected = pos_inf;
            5:  expected = pi_val;
            6:  expected = pos_inf;
            7:  expected = pos_inf;
            8:  expected = neg_2_17;
            9:  expected = pi_val;
            10: expected = pi_val;
            11: expected = qnan;
            12: expected = pos_inf;
            13: expected = pos_inf;
            14: expected = pos_half;
            15: expected = neg_quarter;
            16: expected = pi_val;
            17: expected = 32'h00000002;
            18: expected = neg_inf;
            19: expected = pos_zero;
            20: expected = neg_zero;
            21: expected = 32'h00000001;
            22: expected = pos_inf;
            23: expected = 32'hFF7FFFFF;
            default: expected = 0;
        endcase


        let result <- dut.get_result();


        if (equal_fp(result, expected))
            $display("[PASS] test %0d: result=%h (expected=%h)", idx, result, expected);
        else
            $display("[FAIL] test %0d: got %h expected %h", idx, result, expected);


        if (idx == 23) begin
            $display("All tests completed!");
            $finish(0);
        end


        idx <= idx + 1;
        test_sent <= False;
    endrule


endmodule


endpackage
