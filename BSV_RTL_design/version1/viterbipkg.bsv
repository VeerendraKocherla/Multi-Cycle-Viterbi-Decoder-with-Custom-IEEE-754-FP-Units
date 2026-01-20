package viterbipkg;

import utils::*;

interface Ifc_viterbi;
   method Action put_a(Bit#(32) a);
   method Action put_v(Bit#(32) v);
   // method Action put_b(Bit#(32) b);
   method Bit#(32) get_optstate();
   method ActionValue#(Bit#(32)) get_optprob(Bit#(32) b);
   // method ActionValue#(Bit#(32)) get_optprob();
endinterface

(* synthesize*) 
(*descending_urgency = "rl_compute, get_optstate, get_optprob " *)
// (* synthesize *)
module mkViterbi(Ifc_viterbi);

   Ifc_fpadder adder1 <- mkFPadder;
   Ifc_fpadder adder2 <- mkFPadder;
   Ifc_fpmax comparator1 <- mkFindmax;
   // Ifc_fpmax comparator2 <- mkFindmax;

   Reg#(Bit#(32)) val1 <- mkReg(0);
   Reg#(Bit#(32)) val2 <- mkReg(0);
   Reg#(Bit#(32)) val3 <- mkReg(0);
   Reg#(Bit#(32)) optprob <- mkReg(32'hFF800000);
   Reg#(Bit#(32)) optstate <- mkReg(0);
   Reg#(Bit#(32)) iterstate <- mkReg(0);
   // Reg#(Bit#(32)) optprob <- mkReg(32'hFF800000);
   // Reg#(Bit#(32)) result <- mkReg(0);
   
   Reg#(Bool) got_a <- mkReg(False);
   Reg#(Bool) got_v <- mkReg(False);
   Reg#(Bool) got_res <- mkReg(False);

   // Reg#(Bool) got_b <- mkReg(False);
   // Reg#(Bool) got_opt <- mkReg(False);

   // Computation rule — fires every cycle when both inputs ready and output space available
   rule rl_compute (got_a && got_v);
      let result = adder1.fpadd(val1, val2);
      let maxx = comparator1.fpmax(result, optprob);
      if (maxx != optprob) begin
         optstate <= iterstate + 1;
         optprob <= maxx;
      end
      iterstate <= iterstate + 1;
      got_res <= True;
      got_a <= False;
      got_v <= False;
   endrule

   // Methods
   method Action put_a(Bit#(32) a) if (!got_a);
      val1 <= a;
      got_a <= True;
   endmethod

   method Action put_v(Bit#(32) v) if (!got_v);
      val2 <= v;
      got_v <= True;
   endmethod

   method Bit#(32) get_optstate() if (got_res);
      return optstate;
   endmethod

   method ActionValue#(Bit#(32)) get_optprob(Bit#(32) b) if (got_res);
      let z = adder2.fpadd(optprob, b);
      optprob <= 32'hFF800000;
      got_res <= False;
      iterstate <= 0;
      return z;
   endmethod

endmodule
endpackage
