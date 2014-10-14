/*
 * Author: Michael Kimi
 */
import FShow::*;
import CommonTypes::*;
import VcFifo::*;

typedef enum {Start, Test, End} TestPhase deriving (Bits, Eq);

(* synthesize *)
module mkVcFifoTestBench();
   
   Integer maxCyclesToRun = 20;
   Integer nodeId = 1;
   
   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(TestPhase)testPhase <- mkReg(Start);
   Reg#(Bit#(4))  testStage <- mkReg(0);
   VcFifo#(4, 32, 2) p2f <- mkVcFifo;
   ///////////////////////////////////////////////////////////////////
   rule timeout if (cycle > fromInteger(maxCyclesToRun));
      $display("Timeout termination cycle count %d", cycle);
      $finish();
   endrule
   
   rule clockCount;
      $display("\n== cycle %03d ==", cycle);
      cycle <= cycle + 1;
   endrule
   //////////////////////////////////////////////////////////////////
   rule start(testPhase == Start);
      $display("Start tests:");
      testPhase <= Test;
   endrule

   Reg#(Bit#(1)) vcId <- mkReg(0);

   rule test_enq(testPhase == Test);
      Flit_t#(4, 32, 2) f = Flit_t{src:1 ,
				   dest: 3,
				   fltId: 1,
				   pktId: 2,
				   vcId:  vcId,
				   data:  'hdeadbeaf + cycle};
      $display("enq flit:: ", fshow(f));
      p2f.put(f);
      vcId <= vcId + 1;
      endrule
   
   rule test_deq(testPhase == Test && cycle > 5);
      let f <- p2f.get();
      $display("deq flit:: ", fshow(f));
   endrule
endmodule

