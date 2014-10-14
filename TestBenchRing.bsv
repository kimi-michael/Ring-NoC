/*
 * Author: Michael Kimi
 */
import Ring::*;
import RingNode::*;
import CommonTypes::*;
import StmtFSM::*;
import FShow::*;
import Fifo::*;
import Vector::*;

typedef 4 NofNodes_t;		// num of nodes in a ring
typedef 4 NofPackets_t;		// num of packets to be sent in this test

// helps to get unique payload for each packet
function Payload getNextPayload(Payload p);
   Bit#(256) incr = 256'h00000008_00000008_00000008_00000008_00000008_00000008_00000008_00000008;
   return (p + incr);
endfunction

// convert from integer to address type
function Address_t#(NofNodes_t) addressFromInteger (Integer a);
   Address_t#(NofNodes_t) c = fromInteger(a) ;
   return(c);
endfunction

(* synthesize *)
module mkRingTestBench();
   
   Bit#(TLog#(NofNodes_t)) nodeId = 1; // source node that send all packets
   Integer maxCyclesToRun = 200;
   Integer numberOfNodes = valueOf(NofNodes_t);
   
   Ring#(NofNodes_t) ring <- mkRing();
   
   // fifos that immitates ring nodes, we will test each recieved
   //  packet in a j's ring node with packet in j's fifo
   Vector#(NofNodes_t, Fifo#(NofPackets_t, Packet#(NofNodes_t))) 
     sentPacketFifos <- replicateM(mkPipelineFifo);
   
   // holds all destination addresses that we gonna send in this test
   Vector#(NofNodes_t, Address_t#(NofNodes_t)) destinations = genWith(addressFromInteger);
// override the destinations if needed
//    destinations[0] = 3;
//    destinations[1] = 0;
//    destinations[2] = 3;
//    destinations[3] = 1;
   
   Reg#(int) cycle <- mkReg(1);
   Reg#(Packet#(NofNodes_t)) packet <- mkReg(Packet{peer: 1, 
						    msg: 256'h00000007_00000006_00000005_00000004_00000003_00000002_00000001_00000000});
   Reg#(int) i0 <- mkReg(0);
   
////////////////////////////////////////////////////////////////////////////////
/// sequences
////////////////////////////////////////////////////////////////////////////////
   
   // put a packet(s) into 0'th ring node. put the same packet into sentPacketFifos
   //  for verification 
   Stmt enqSeq = 
   seq
      while ( i0 < fromInteger(valueOf(NofPackets_t)) ) action
	 Packet#(NofNodes_t) p = Packet{peer: destinations[i0], 
					msg : getNextPayload(packet.msg)};
	 $display("@%4t tst: enq packet ...                 ", $time, fshow(p));	 
	 sentPacketFifos[p.peer].enq(p); //put pkt into a dest fifo for test
	 ring.getNode(nodeId).enq(p); //put pkt into src node (to be transmitted to dest node)
	 packet <= p;
	 i0 <= i0+1;
      endaction
   endseq;
   
   FSM enqFSM <- mkFSM(enqSeq);

////////////////////////////////////////////////////////////////////////////////
/// rules
////////////////////////////////////////////////////////////////////////////////
   
   for (Integer i=0; i<numberOfNodes; i=i+1) begin
      
      // drain each ring node and check the received packet vs. expected packet
      rule drainAndValidate;
	 
	 let ringNode = ring.getNode(fromInteger(i));
	 
	 let expectedPacket = sentPacketFifos[i].first;
	 let arrivedPacket  = ringNode.first();
 	 
	 sentPacketFifos[i].deq();
	 ringNode.deq();
	 
	 Fmt formatStr;   
	 if (expectedPacket == arrivedPacket) 
	    formatStr = $format("ok");
	 else 
	    formatStr = $format("Error: packets are different ", 
				"\n expcted: %s \n   found: %s", 
				fshow(expectedPacket), fshow(arrivedPacket));
	 	       
	 $display("@%4t tst: deq from peer %1d ... ", $time, i, formatStr);
	 
      endrule
      
   end

   rule startTest if (cycle == 1);
      enqFSM.start;
   endrule
   
   rule timeout if (cycle > fromInteger(maxCyclesToRun));
      $display("Timeout termination cycle count %d", cycle);
      $finish();
   endrule
   
   rule clockCount;
      $display("== cycle %03d @%3t ==", cycle, $time);
      cycle <= cycle + 1;
   endrule
  
endmodule
