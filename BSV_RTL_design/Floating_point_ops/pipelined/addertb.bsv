package addertb;

import utils::*;
import Vector::*;

typedef struct {
    Bit#(32) a;
    Bit#(32) b;
    Bit#(32) expected;
} TestCase deriving (Bits, Eq);
// (* synthesize *)
module mkTbFpAdder(Empty);

    Ifc_fpadder dut <- mkFPadder;

    Reg#(UInt#(8)) idx <- mkReg(0);
    Reg#(UInt#(8)) cycle <- mkReg(0);
    Reg#(Bit#(32)) result <- mkReg(0);

    // --- Test vectors ---

    Vector#(30, TestCase) tests = newVector;

    // Populate testcases
    // 2 + 100 = 102
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
    tests[20] = TestCase { a: 32'hc3640000, b: 32'h3cf5c28f, expected: 32'hc363e147 };
    tests[21] = TestCase { a: 32'hbc23d70a, b: 32'h43200000, expected: 32'h431ffd71 };
    tests[22] = TestCase { a: 32'h42c80000, b: 32'h3e4ccccd, expected: 32'h42c86666 };
    tests[23] = TestCase { a: 32'h3e19999a, b: 32'h42480000, expected: 32'h4248999a };
    tests[24] = TestCase { a: 32'h3eaaaaab, b: 32'h3dcccccd, expected: 32'h3eddddde };
    tests[25] = TestCase { a: 32'h4b189680, b: 32'h4b189680, expected: 32'h4b989680 };
    tests[26] = TestCase { a: 32'h3dcccccd, b: 32'h3dcccccd, expected: 32'h3e4ccccd };
    tests[27] = TestCase { a: 32'h3f7d70a4, b: 32'h3f7d70a4, expected: 32'h3ffd70a4 };
    tests[28] = TestCase { a: 32'h3c23d70a, b: 32'h3c23d70a, expected: 32'h3ca3d70a };
    tests[29] = TestCase { a: 32'h00000001, b: 32'h00000001, expected: 32'h00000002 };

    // --- Equal function ---
    function Bool equal_fp(Bit#(32) x, Bit#(32) y);
        if ((x[30:23] == 8'hff && x[22:0] != 0) &&
            (y[30:23] == 8'hff && y[22:0] != 0))
            return True;
        else
            return (x == y);
    endfunction

    // --- Feed pipeline ---
    rule feed_inputs (idx < 30);
        let t = tests[idx];
        dut.startadd(t.a, t.b);
        $display("[cycle %0d] startadd: a=%h b=%h", cycle, t.a, t.b);
        idx <= idx + 1;
    endrule

    // --- Collect outputs ---
    rule check_results (cycle > 3 && (cycle - 3) < 30);
        let i = cycle - 4;
        let result = dut.fpadd_response();
        let expected = tests[i].expected;

        if (equal_fp(result, expected))
            $display("[PASS] test %0d: got=%h expected=%h \n", i, result, expected);
        else
            $display("[FAIL] test %0d: got=%h expected=%h \n", i, result, expected);
    endrule

    // --- Clock counter ---
    rule tick;
        cycle <= cycle + 1;
        if (cycle > 40) $finish(0);
    endrule

endmodule

endpackage
