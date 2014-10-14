/*
 * Author: Michael Kimi
 */
import CommonTypes::*;
import PacketToFlit::*;

typedef enum {Start, P2F, End} TestPhase deriving (Bits, Eq);

(* synthesize *)
module mkP2FTestBench();
   
   Integer maxCyclesToRun = 20;
   Integer nodeId = 1;
   
   Reg#(Bit#(32)) cycle <- mkReg(0);
   Reg#(TestPhase)testPhase <- mkReg(Start);
   Reg#(Bit#(4))  testStage <- mkReg(0);
   PacketToFlit#(4, 32, 2) p2f <- mkPacketToFlit(nodeId);
   ///////////////////////////////////////////////////////////////////
   rule timeout if (cycle > fromInteger(maxCyclesToRun));
      $display("Timeout termination cycle count %d", cycle);
      $finish();
   endrule
   
   rule clockCount;
      $display("== cycle %03d ==", cycle);
      cycle <= cycle + 1;
   endrule
   //////////////////////////////////////////////////////////////////
   rule start(testPhase == Start);
      $display("Start tests:");
      testPhase <= P2F;
   endrule
   
   rule testP2F_enq(testPhase == P2F);
      Packet#(4) p = Packet{peer: 1, msg: ?/*'h0123456789abcdef*/};
      p.msg = 'hffffeeeeddddccccbbbbaaaa9999888877776666555544443333222211110000 + extend(cycle);
      $display("enq pkt:: dest: %b, msg: %h", p.peer, p.msg);
      p2f.enq(p);
      testStage <= 1;
   endrule
   
   rule testP2F_deq(testPhase == P2F );
      let f = p2f.first();
      $display("deq flit:: src:%d dst:%d fid:%d pid:%d vid:%d data:%h",
	       f.src, f.dest, f.fltId, f.pktId, f.vcId, f.data);
      p2f.deq();
   endrule
endmodule

