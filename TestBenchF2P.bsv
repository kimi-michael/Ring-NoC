/*
 * Author: Michael Kimi
 */
import CommonTypes::*;
import FlitToPacket::*;
import StmtFSM::*;
import FShow::*;

typedef enum {Start, Test, End} TestPhase deriving (Bits, Eq);
typedef 4 NofNodes;
typedef 32 FlitSz;
typedef 2 NofVCs;
typedef 10 NofAssembeldPackets;
typedef 10 NofWaitingPkts;

function Flit_t#(NofNodes, FlitSz, NofVCs) calcNextFlit(Flit_t#(NofNodes, FlitSz, NofVCs) flit);
   Flit_t#(NofNodes, FlitSz, NofVCs) result = flit;
   result.data = flit.data + zeroExtend(1'b1); 
   result.fltId = flit.fltId + zeroExtend(1'b1);
   return result;
endfunction

(* synthesize *)
module mkF2PTestBench();
   
   Integer maxCyclesToRun = 40;
   Reg#(Bit#(32)) cycle  <- mkReg(1);
   Reg#(TestPhase) phase <- mkReg(Start);

   Reg#(Flit_t#(NofNodes, FlitSz, NofVCs)) flitA <- mkReg(Flit_t{src:    0, 
								 dest:   0,
								 fltId:  0,
								 pktId:  0,
								 vcId:   0,
								 data:   0});

   Reg#(Flit_t#(NofNodes, FlitSz, NofVCs)) flitB <- mkReg(Flit_t{src:    0, 
								 dest:   0,
								 fltId:  0,
								 pktId:  1,
								 vcId:   0,
								 data:   'h10});

   Integer nofFlitsInPacket = valueOf(NofFlitsInPacket_t#(FlitSz))-1;
   Integer dropTimeout = 20;
   
   FlitToPacket#(NofNodes, FlitSz, NofVCs,
		 NofAssembeldPackets, NofWaitingPkts) dut <- mkFlitToPacket(dropTimeout);
   

   //////////////////////////////////////////////////////////////////////
   // statement's implementation 
   //////////////////////////////////////////////////////////////////////
   Reg#(int) ii <- mkReg(0);
   
   // Enque single packet when all filtes written back to back
   Stmt enqueSinglePacketBackToBackSequence =
   seq
      action 
	 dut.reportStatus();
	 dut.reportConfiguration();
      endaction
      await( dut.isNotInitializing );
      $display("Enable enq and deq");
      $display("Dut notEmpty = %b, notFull = %b, isNotInit",
	       dut.notEmpty, dut.notFull, dut.isNotInitializing);

      while (ii <= 7) seq
	 action 
	    $display("@%4t tst: tst enq flit ", $time, fshow(flitA));
	    dut.enq(flitA);
	    
	    flitA <= calcNextFlit(flitA);
	    ii <= ii + 1;
	 endaction
      endseq
   endseq;

   // Enque single packet when all filtes written only on even cycles
   Stmt enqueSinglePacketWithBubblesSequence =
   seq
      action 
	 dut.reportStatus();
	 dut.reportConfiguration();
      endaction
      await( dut.isNotInitializing );
      $display("Enable enq and deq");
      $display("Dut notEmpty = %b, notFull = %b, isNotInit",
	       dut.notEmpty, dut.notFull, dut.isNotInitializing);

      while (ii <= 7) seq
	 if ( cycle % 2 == 1 ) // put some bubbles into the enq flow
	 action 
	    $display("@%4t tst: tst enq flit ", $time, fshow(flitA));
	    dut.enq(flitA);
	    
	    flitA <= calcNextFlit(flitA);
	    ii <= ii + 1;
	 endaction
	 else // every even cycle don't enq anything
	    noAction;
      endseq
   endseq;
   
   // Enque 2 packets when all filtes written back to back
   Stmt enqueTwoPacketsBackToBackSequence =
   seq
      action 
	 dut.reportStatus();
	 dut.reportConfiguration();
      endaction
      await( dut.isNotInitializing );
      $display("Enable enq and deq");
      $display("Dut notEmpty = %b, notFull = %b, isNotInit",
	       dut.notEmpty, dut.notFull, dut.isNotInitializing);
      
      //1
      action dut.enq(flitA); flitA <= calcNextFlit(flitA); endaction
      action dut.enq(flitB); flitB <= calcNextFlit(flitB); endaction
      //2
      action dut.enq(flitA); flitA <= calcNextFlit(flitA); endaction
      action dut.enq(flitB); flitB <= calcNextFlit(flitB); endaction
      //3
      action dut.enq(flitA); flitA <= calcNextFlit(flitA); endaction
      action dut.enq(flitB); flitB <= calcNextFlit(flitB); endaction
      noAction;
      noAction;
      //4
      action dut.enq(flitA); flitA <= calcNextFlit(flitA); endaction
      action dut.enq(flitB); flitB <= calcNextFlit(flitB); endaction
      //5
      action dut.enq(flitA); flitA <= calcNextFlit(flitA); endaction
      action dut.enq(flitB); flitB <= calcNextFlit(flitB); endaction
      noAction;
      //6
      action dut.enq(flitA); flitA <= calcNextFlit(flitA); endaction
      action dut.enq(flitB); flitB <= calcNextFlit(flitB); endaction
      //7
      action dut.enq(flitA); flitA <= calcNextFlit(flitA); endaction
      action dut.enq(flitB); flitB <= calcNextFlit(flitB); endaction
      //8
      action dut.enq(flitA); flitA <= calcNextFlit(flitA); endaction
      action dut.enq(flitB); flitB <= calcNextFlit(flitB); endaction
      
   endseq;
   
   
   FSM testFSM <- mkFSM( enqueTwoPacketsBackToBackSequence );
   
   ///////////////////////////////////////////////////////////////////   
   rule enqueRule if ( cycle == 1 );
      testFSM.start;
   endrule

   rule timeout if (cycle > fromInteger(maxCyclesToRun));
      $display("Timeout termination cycle count %d", cycle);
      $finish();
   endrule
   
   rule clockCount;
      $display("== cycle %03d @%3t ==", cycle, $time);
      cycle <= cycle + 1;
   endrule
   
   //////////////////////////////////////////////////////////////////
   rule deque if ( cycle == 70 );
      $display("@%4t tst: popped data ", $time,  fshow(dut.first()));
      dut.deq();
   endrule

endmodule
