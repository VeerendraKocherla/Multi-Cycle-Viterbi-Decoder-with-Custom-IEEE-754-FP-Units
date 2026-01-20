package mktb;

import RegFile::*;
import Vector::*;
import viterbipkg :: *;

`define MAX_ENTRIES 1024

typedef enum {
   START, LOAD_NM, LOAD_OBS, GO, CATCH, 
   WORKMEM_PUT, TRACEBACK, RESET, DISP, 
   RECUR, GET_PATHPROB, WRITE, CLEAR_DATA} State deriving(Bounded, Bits, Eq);

function Bit#(32) fn_findindex(Int#(32) req_row, Int#(32) req_col, Int#(32) tot_cols);
   Bit#(32) index = pack((req_row * tot_cols) + req_col);
   return index;
endfunction

module mkTestbench(Empty);

   RegFile#(Bit#(1), Int#(32)) n_mem <- mkRegFileLoad("../test-cases/huge/N_huge.dat", 0, 1);
   RegFile#(Bit#(32), Bit#(32)) a_mem <- mkRegFileLoad("../test-cases/huge/A_huge.dat", 0, `MAX_ENTRIES);
   RegFile#(Bit#(32), Bit#(32)) b_mem <- mkRegFileLoad("../test-cases/huge/B_huge.dat", 0, `MAX_ENTRIES);
   RegFile#(Bit#(32), Int#(32)) input_mem <- mkRegFileLoad("../test-cases/huge/input_huge.dat", 0, `MAX_ENTRIES);


   Vector#(1000, Reg#(Bit#(32))) working_mem <- replicateM(mkReg(0));
   
   Vector#(31, Reg#(Bit#(32))) vtstore <- replicateM(mkReg(0));
   Vector#(31, Reg#(Bit#(32))) prevvt <- replicateM(mkReg(0));
   Vector#(31, Reg#(Bit#(32))) traced_states <- replicateM(mkReg(0));

   Reg#(State) rg_state<- mkReg(START);

   Reg#(File) memory_wr <- mkReg(InvalidFile);
   Reg#(Bit#(32)) clk <- mkReg(0);
   Reg#(Int#(32)) n_val <- mkReg(0);
   Reg#(Int#(32)) m_val <- mkReg(0);
   Reg#(Int#(32)) curr_obs <- mkReg(0);
   Reg#(Int#(32)) iter <- mkReg(0);
   Reg#(Bit#(32)) pathprob <- mkReg(0);
   Reg#(Bit#(32)) buf_state <- mkReg(0);

   Reg#(Int#(32)) seqwr_ptr <- mkReg(0);
   Reg#(Int#(32)) seqptr <- mkReg(-1);
   Reg#(Int#(32)) inp_ptr <- mkReg(0);
   Reg#(Bit#(32)) addr_ptr <- mkReg(9999);
   Reg#(Int#(32)) state_i_ptr <- mkReg(1);
   Reg#(Int#(32)) state_j_ptr <- mkReg(0);
   Reg#(Int#(32)) wmid <- mkReg(0);

   Ifc_viterbi vd <- mkViterbi;
   Ifc_viterbi vd2 <- mkViterbi;

   rule rl_tick;
      $display("------------------CLOCK [%0d]--------------------", clk);
      // $display("iter %d", iter);
      clk <= clk + 1;
      // if (inp_ptr==106) $finish(0);
      // if (inp_ptr==5) begin
      //    for (Integer i = 0; i < 20; i = i+1) begin
      //       $display(working_mem[i]);
      //    end
      //    $finish;
      // end
   endrule

   rule rl_open(addr_ptr == 9999 && rg_state == START) ; //Open Initially
      // Open the file and check for proper opening
      File file <- $fopen( "bsv_output.dat","w" ) ;
      if ( file == InvalidFile )
      begin
         $display("cannot open the file" );
         $finish(0);
      end
      addr_ptr <= 0 ;      
      memory_wr <= file ; // Save the file in a Register
      rg_state <= LOAD_NM;
   endrule

   rule rl_loadnm (rg_state == LOAD_NM);
      n_val <= n_mem.sub(0);
      m_val <= n_mem.sub(1);
      rg_state <= LOAD_OBS;
   endrule

   rule rl_updobs (rg_state == LOAD_OBS);
      // $display("reading n = %d and m= %d", n_val, m_val);
      // $display("inp ptr: %d", inp_ptr);
      seqptr <= seqptr + 1;
      curr_obs <= input_mem.sub(pack(inp_ptr));
      rg_state <= GO;
   endrule

   rule rl_go (rg_state == GO);
   $display("%h", curr_obs);
      if (curr_obs == 32'hFFFFFFFF) begin 
         inp_ptr <= inp_ptr + 1;
         rg_state <= RECUR;
      end else if (curr_obs == 32'h0) begin
         $fwrite(memory_wr, "%h\n", 32'h0);
         // $display("writing data: %h at addr: %d ", 0, addr_ptr);
         addr_ptr <= addr_ptr + 1;
         $finish(0);
      end else begin
         if (seqptr == 0) begin
            let id = fn_findindex(0, state_j_ptr, n_val);
            vd.put_a(a_mem.sub(id));
            vd.put_v(0);
            rg_state <= CATCH;
            // $display("a_mem now: %h", a_mem.sub(id));
         end else begin
            let id = fn_findindex(state_i_ptr, state_j_ptr, n_val);
            // let workmem_index = fn_findindex(inp_ptr-1, state_i_ptr-1, n_val);
            $display("prev vt: %h", prevvt[state_i_ptr-1]);
            vd.put_a(a_mem.sub(id));
            vd.put_v(prevvt[state_i_ptr-1]);
            // $display("state i ptr %d", state_i_ptr);
            // $display("state j ptr %d", state_j_ptr);
            // $display("a_mem now: %h", a_mem.sub(id));
            if (state_i_ptr == n_val) begin
               rg_state <= CATCH;
               // $finish(0);
            end
         state_i_ptr <= state_i_ptr + 1;
         end
      end
   endrule

   rule rl_capture (rg_state == CATCH) ;
      let em_index = fn_findindex(state_j_ptr, curr_obs-1, m_val);
      $display("b_mem now: %h", b_mem.sub(em_index));
      let optstate = vd.get_optstate();
      let vt <- vd.get_optprob(b_mem.sub(em_index));
      $display("vt: %h \n", vt);
      // if (seqptr != 0) begin
         working_mem[wmid] <= optstate;
         wmid <= wmid + 1;
      // end
      // seqptr <= seqptr + 1;
      vtstore[state_j_ptr] <= vt;
      state_i_ptr <= 1;
      if (state_j_ptr == n_val-1) begin
         state_j_ptr <= 0;
         inp_ptr <= inp_ptr + 1;
         rg_state <= RESET;
      end else begin 
         state_j_ptr <= state_j_ptr + 1;
         rg_state <= GO;
      end
   endrule

   rule rl_reset (rg_state == RESET);
      for (Integer i = 0; i < 31; i = i + 1) begin
         prevvt[i] <= vtstore[i];
      end
      rg_state <= LOAD_OBS;
   endrule

   rule rl_recur (rg_state == RECUR);
   if (iter < n_val-1) begin
      $display("iter %d", iter);
      vd.put_a(vtstore[iter]);
      vd.put_v(0);
      iter <= iter + 1;
   end else begin
      rg_state <= GET_PATHPROB;
      iter <= 1;
   end
   endrule

   rule rl_getpath (rg_state == GET_PATHPROB);
         let optstate = vd.get_optstate();  
         let optvt <- vd.get_optprob(0);
         $display("myvvt, %h", optvt);
         $display("bufstate, %h", optstate);
         $display("seqptr %d", seqptr);
         traced_states[0] <= optstate;
         buf_state <= optstate;
         pathprob <= optvt;
         rg_state <= TRACEBACK;
         // $finish(0);
   endrule

   rule rl_traceback (rg_state == TRACEBACK);
      $display("iter trace, %d", iter);
      if (iter < seqptr) begin
         let index = (seqptr - iter) * n_val + unpack(buf_state-1);
         let s = working_mem[index];
         traced_states[iter] <= s;
         buf_state <= s;
         iter <= iter + 1;
      end else begin 
         seqwr_ptr <= seqptr-1;
         rg_state <= WRITE;
         iter <= 0;
      end
   endrule

   rule rl_write (rg_state == WRITE);
      for (Integer i = 0; i < 31; i = i+ 1) begin 
         $display("trace %d: %h", i, traced_states[i]);
         // $display()
      end
      Bit#(32) data;
      if (seqwr_ptr >= 0) begin
         data = traced_states[seqwr_ptr];
      end else if (seqwr_ptr == -1) begin
         data = pathprob;
      end else begin
         data = 32'hFFFFFFFF;
         seqptr <= -1;
         wmid <= 0;
         rg_state <= CLEAR_DATA;
      end
      $fwrite(memory_wr, "%h\n", data);
      $display("writing data: %h at addr: %d ", data, addr_ptr);
      addr_ptr <= addr_ptr + 1;
      seqwr_ptr <= seqwr_ptr - 1;
   endrule

   rule rl_clear (rg_state == CLEAR_DATA);
      for (Integer i = 0; i < 1000; i = i+ 1) begin 
         working_mem[i] <= 0;
      end
      for (Integer i = 0; i < 31; i = i + 1) begin
         prevvt[i] <= 0;
         vtstore[i] <= 0;
         traced_states[i] <= 0;
      end
      rg_state <= LOAD_OBS;
   endrule

endmodule
endpackage : mktb

