/*
 * Author: Michael Kimi
 */
import RingNode::*;
import CommonTypes::*;
import StmtFSM::*;
import FShow::*;
import Vector::*;

////////////////////////////////////////////////////////////////////////////////
/// types
////////////////////////////////////////////////////////////////////////////////

typedef 32 FlitSize_t;
typedef 4 NumberOfVCs_t;
typedef 4 NofNodes_t;

////////////////////////////////////////////////////////////////////////////////
/// helper functions
////////////////////////////////////////////////////////////////////////////////

// helps to generate unique packet payload by incrementing a given's packet 
// payload
function Packet#(NofNodes_t) generateNextPacket(Packet#(NofNodes_t) p);
   Bit#(256) incr = 256'h00000008_00000008_00000008_00000008_00000008_00000008_00000008_00000008;
   Bit#(256) msg = p.msg;
   p.msg = msg + incr;
   return p;
endfunction

// same a above but for flit's payload
function Flit_t#(NofNodes_t, FlitSize_t, NumberOfVCs_t) 
 generateNextFlit(Flit_t#(NofNodes_t, FlitSize_t, NumberOfVCs_t) flit,
		  Address_t#(NofNodes_t) address );
   flit.data = flit.data + 'h8;
   flit.dest = address;
   return flit;
endfunction

// convert integer to address type
function Address_t#(NofNodes_t) addressFromInteger (Integer a);
   Address_t#(NofNodes_t) c = fromInteger(a) ;
   return(c);
endfunction

////////////////////////////////////////////////////////////////////////////////
/// module
////////////////////////////////////////////////////////////////////////////////

(* synthesize *)
module mkRingNodeTestBench();
   Integer nodeId = 0;
   Integer maxCyclesToRun = 40;
   
   
   RingNode#(NofNodes_t, FlitSize_t, NumberOfVCs_t) node <- mkRingNode(nodeId);
   

   Reg#(int) cycle                  <- mkReg(1);
   Reg#(Packet#(NofNodes_t)) packet <- mkReg(Packet{peer: 1, 
						    msg: 256'h00000007_00000006_00000005_00000004_00000003_00000002_00000001_00000000});
   Reg#(Flit_t#(NofNodes_t, FlitSize_t, NumberOfVCs_t)) flit <- mkReg(Flit_t{src: fromInteger(nodeId) ,
									     dest:  0,
									     fltId: 1,
									     pktId: 2,
									     vcId:  0,
									     data:  'hdeadbeaf});
   Vector#(NofNodes_t, Address_t#(NofNodes_t)) destinations = genWith(addressFromInteger);
   
   Reg#(int) i0 <- mkReg(0);

   //////////////////////////////////////////////////////////////////////
   // sequences
   //////////////////////////////////////////////////////////////////////
   Stmt clientEnqSeq =
   seq 
      action
	 $display("@%4t tst: client port enq packet ", $time, fshow(packet));
	 node.enq(packet);
	 packet <= generateNextPacket(packet);
      endaction
//      await(node.notFull);
//       action
// 	 Packet#(NofNodes_t) p = Packet{peer:2, msg:packet.msg};
// 	 $display("@%4t tst: client port enq packet ", $time, fshow(p));
// 	 node.enq(p);
// 	 packet <= generateNextPacket(p);
//       endaction
   endseq;
   
   Stmt upEnqSeq =
   seq 
      while( i0 < fromInteger(valueOf(NofNodes_t)) ) action
	 $display("@%4t tst: dn port put packet ", $time, fshow(flit), " i0: %2d", i0);
	 node.putDn(flit);
	 flit <= generateNextFlit(flit, destinations[i0]);
	 i0 <= i0 + 1;
      endaction
   endseq;
      
   Stmt clientDrainSeq =
   seq
      while (True) action
	 await (node.notEmpty);
	 action
	    $display("@%4t tst: client port deq packet ",
		     $time, fshow(node.first));
	    node.deq();
	 endaction
      endaction
   endseq;
   
   Stmt upDrainSeq =
   seq
      while (True) action
	 let flit <- node.getUp;
	 $display("@%4t tst: up port get packet ", $time, fshow(flit));
      endaction
   endseq;
   
   Stmt downDrainSeq =
   seq
      while (True) action
	 let flit <- node.getDn;
	 $display("@%4t tst: dn port get packet ", $time, fshow(flit));
      endaction
   endseq;
   
   FSM clientPortEnqFSM <- mkFSM(clientEnqSeq);
   FSM upPortEnqFSM     <- mkFSM(upEnqSeq);
   FSM clientDrainFSM   <- mkFSM(clientDrainSeq);
   FSM upDrainFSM       <- mkFSM(upDrainSeq);
   FSM downDrainFSM     <- mkFSM(downDrainSeq);
   
   //////////////////////////////////////////////////////////////////////
   // rules:
   //////////////////////////////////////////////////////////////////////
   
   rule timeout if (cycle > fromInteger(maxCyclesToRun));
      $display("Timeout termination cycle count %d", cycle);
      $finish();
   endrule
   
   rule clockCount;
      $display("== cycle %03d @%3t ==", cycle, $time);
      cycle <= cycle + 1;
   endrule
  
   rule startTest if (cycle == 1);
      clientPortEnqFSM.start;
      //upPortEnqFSM.start;
      clientDrainFSM.start;
      upDrainFSM.start;
      downDrainFSM.start;
      for ( Integer i=0; i<fromInteger(valueOf(NofNodes_t)); i=i+1) begin
	 $display("destination[%2d]=%5d", i, destinations[i]);
      end
  endrule
   
endmodule



