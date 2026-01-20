package viterbipkg;

import utils::*;

typedef enum {
   Idle,
   WaitAdd1,
   WaitMax,
   FinalAddReady,
   WaitAdd2
} ViterbiState deriving (Bits, Eq);

interface Ifc_viterbi;
   method Action put_a(Bit#(32) a);
   method Action put_v(Bit#(32) v);
   method Bit#(32) get_optstate();
   method Action start_final_add(Bit#(32) b);
   method ActionValue#(Bit#(32)) get_optprob();
endinterface

(* synthesize *)
(* descending_urgency = "rl_get_max_result, rl_get_add_result, rl_start_add" *)
module mkViterbi(Ifc_viterbi);

   Ifc_fpadder adder1 <- mkFPadder;
   Ifc_fpadder adder2 <- mkFPadder;
   Ifc_fpmax comparator1 <- mkFindmax;

   Reg#(Bit#(32)) val1 <- mkReg(0);
   Reg#(Bit#(32)) val2 <- mkReg(0);
   Reg#(Bit#(32)) add1_result <- mkReg(0);
   Reg#(Bit#(32)) optprob <- mkReg(32'hFF800000);
   Reg#(Bit#(32)) optstate <- mkReg(0);
   Reg#(Bit#(32)) iterstate <- mkReg(0);
   
   Reg#(Bool) got_a <- mkReg(False);
   Reg#(Bool) got_v <- mkReg(False);
   Reg#(Bool) got_b <- mkReg(False);
   Reg#(Bit#(32)) val_b <- mkReg(0);
   
   Reg#(ViterbiState) state <- mkReg(Idle);

   // Rule 1: Start addition when both inputs are ready
   rule rl_start_add (state == Idle && got_a && got_v);
      adder1.put_operands(val1, val2);
      state <= WaitAdd1;
      got_a <= False;
      got_v <= False;
   endrule

   // Rule 2: Get addition result and start max comparison
   rule rl_get_add_result (state == WaitAdd1);
      let result <- adder1.get_result();
      add1_result <= result;
      comparator1.put_operands(result, optprob);
      state <= WaitMax;
   endrule

   // Rule 3: Get max result and update optimal state
   rule rl_get_max_result (state == WaitMax);
      let maxx <- comparator1.get_result();
      
      if (maxx != optprob) begin
         optstate <= iterstate + 1;
         optprob <= maxx;
      end
      
      iterstate <= iterstate + 1;
      state <= Idle;
   endrule

   // Rule 4: Start final addition when b is provided
   rule rl_start_final_add (state == Idle && got_b);
      adder2.put_operands(optprob, val_b);
      state <= WaitAdd2;
      got_b <= False;
   endrule

   // Rule 5: Get final addition result
   rule rl_get_final_result (state == WaitAdd2);
      let result <- adder2.get_result();
      add1_result <= result;  // Store result temporarily
      state <= FinalAddReady;
   endrule

   // Methods
   method Action put_a(Bit#(32) a) if (state == Idle && !got_a);
      val1 <= a;
      got_a <= True;
   endmethod

   method Action put_v(Bit#(32) v) if (state == Idle && !got_v);
      val2 <= v;
      got_v <= True;
   endmethod

   method Bit#(32) get_optstate() if (state == Idle || state == FinalAddReady);
      return optstate;
   endmethod

   method Action start_final_add(Bit#(32) b) if (state == Idle);
      val_b <= b;
      got_b <= True;
   endmethod

   method ActionValue#(Bit#(32)) get_optprob() if (state == FinalAddReady);
      // Reset for next iteration
      optprob <= 32'hFF800000;
      iterstate <= 0;
      state <= Idle;
      return add1_result;
   endmethod

endmodule
endpackage
