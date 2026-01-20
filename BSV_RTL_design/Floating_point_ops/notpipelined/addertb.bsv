package addertb;

import utils::*;
import Vector::*;

typedef struct {
    Bit#(32) a;
    Bit#(32) b;
    Bit#(32) expected;
} TestCase deriving (Bits, Eq);

(* synthesize *)
module mkTbFpAdder(Empty);

    Ifc_fpadder dut <- mkFPadder;

    Reg#(UInt#(8)) idx <- mkReg(0);
    Reg#(UInt#(8)) result_idx <- mkReg(0);
    Reg#(UInt#(8)) cycle <- mkReg(0);

    // --- Test vectors ---
    Vector#(28, TestCase) tests = newVector;

    // Populate testcases
    tests[0] = TestCase { a: 32'h40000000, b: 32'h42c80000, expected: 32'h42cc0000 };
    tests[1] = TestCase { a: 32'hc2c80000, b: 32'h40000000, expected: 32'hc2c40000 };
    tests[2] = TestCase { a: 32'h42480000, b: 32'hc0000000, expected: 32'h42400000 };
    tests[3] = TestCase { a: 32'h00000000, b: 32'h42480000, expected: 32'h42480000 };
    tests[4] = TestCase { a: 32'hc2480000, b: 32'h00000000, expected: 32'hc2480000 };
    tests[5] = TestCase { a: 32'h00000000, b: 32'h00000000, expected: 32'h00000000 };
    tests[6] = TestCase { a: 32'h3f8ccccd, b: 32'hbf8ccccd, expected: 32'h00000000 };
    tests[7] = TestCase { a: 32'h40490fdb, b: 32'h402df854, expected: 32'h40bb8418 };
    tests[8] = TestCase { a: 32'hc0490fdb, b: 32'h402df854, expected: 32'hbed8bc38 };
    tests[9] = TestCase { a: 32'h40490fdb, b: 32'hc02df854, expected: 32'h3ed8bc38 };
    tests[10] = TestCase { a: 32'hc0490fdb, b: 32'hc02df854, expected: 32'hc0bb8418 };
    tests[11] = TestCase { a: 32'h42480000, b: 32'h40490fdb, expected: 32'h425490fe };
    tests[12] = TestCase { a: 32'h42c80000, b: 32'h402df854, expected: 32'h42cd6fc3 };
    tests[13] = TestCase { a: 32'hc2c80000, b: 32'h40490fdb, expected: 32'hc2c1b781 };
    tests[14] = TestCase { a: 32'hc02df854, b: 32'h40000000, expected: 32'hbf37e150 };
    tests[15] = TestCase { a: 32'h40490fdb, b: 32'h00000000, expected: 32'h40490fdb };
    tests[16] = TestCase { a: 32'hc0490fdb, b: 32'h00000000, expected: 32'hc0490fdb };
    tests[17] = TestCase { a: 32'h40490fdb, b: 32'hc0490fdb, expected: 32'h00000000 };
    tests[18] = TestCase { a: 32'h402df854, b: 32'hc02df854, expected: 32'h00000000 };
    tests[19] = TestCase { a: 32'h41200000, b: 32'hbe99999a, expected: 32'h411b3333 };
    tests[20] = TestCase { a: 32'hbc23d70a, b: 32'h43200000, expected: 32'h431ffd71 };
    tests[21] = TestCase { a: 32'h42c80000, b: 32'h3e4ccccd, expected: 32'h42c86666 };
    tests[22] = TestCase { a: 32'h3e19999a, b: 32'h42480000, expected: 32'h4248999a };
    tests[23] = TestCase { a: 32'h3eaaaaab, b: 32'h3dcccccd, expected: 32'h3eddddde };
    tests[24] = TestCase { a: 32'h4b189680, b: 32'h4b189680, expected: 32'h4b989680 };
    tests[25] = TestCase { a: 32'h3dcccccd, b: 32'h3dcccccd, expected: 32'h3e4ccccd };
    tests[26] = TestCase { a: 32'h3f7d70a4, b: 32'h3f7d70a4, expected: 32'h3ffd70a4 };
    tests[27] = TestCase { a: 32'h3c23d70a, b: 32'h3c23d70a, expected: 32'h3ca3d70a };

    // --- Equal function ---
    function Bool equal_fp(Bit#(32) x, Bit#(32) y);
        if ((x[30:23] == 8'hff && x[22:0] != 0) &&
            (y[30:23] == 8'hff && y[22:0] != 0))
            return True;
        else
            return (x == y);
    endfunction

    // --- Feed inputs into DUT ---
    rule feed_inputs (idx < 28);
        let t = tests[idx];
        dut.put_operands(t.a, t.b);
        $display("[cycle %0d] put_operands: a=%h b=%h (test %0d)", cycle, t.a, t.b, idx);
        idx <= idx + 1;
    endrule

    // --- Collect and check outputs ---
    rule check_results (result_idx < 28);
        let result <- dut.get_result();
        let expected = tests[result_idx].expected;

        if (equal_fp(result, expected))
            $display("[cycle %0d] [PASS] test %0d: got=%h expected=%h", cycle, result_idx, result, expected);
        else
            $display("[cycle %0d] [FAIL] test %0d: got=%h expected=%h", cycle, result_idx, result, expected);
        
        result_idx <= result_idx + 1;
        
        // Finish simulation after all results are collected
        if (result_idx == 27) begin
            $display("\nAll tests completed!");
            $finish(0);
        end
    endrule

    // --- Clock counter ---
    rule tick;
        cycle <= cycle + 1;
    endrule

endmodule

endpackage
