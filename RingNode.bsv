/*
 * Author: Michael Kimi
 */
import FShow::*;
import CommonTypes::*;

import PacketToFlit::*;
import VcFifo::*;
import CrossBar::*;
import FlitToPacket::*;

///////////////////////////////////////////////////////////////////////////////
// Important note: all following types should be power of 2 otherwise
//  synth tool fails :(

// number of packets assembled in flit-to-packet sub module
typedef 8 NofAssembeldPackets_t; 

// size of a PACKET_FIFO that stores the assembled packets ready to be fetched
//  by client
typedef 4 NofWaitingPkts_t;	  

// after DropTimeout_t cycles a packet will be dropped from PACKET_FIFO if it
//  wasn't fetched by user.
typedef 16 DropTimeout_t;

////////////////////////////////////////////////////////////////////////////////
// This interface defines a ring node's functionality as seen by the client.
//  Up ring direction denotes the direction of increasing nodeIds (0,1,2..N-1)
//  Donw ring direction is opposite to Up ring i.e. decresing nodeId (...,2,1,0)
// 
// IMPORTANT NOTE: 
//  Original interface didn't define how ring node communicate with peer ring
//  nodes. Thus we have to add interface methods to define the communication 
//  of ring node with upper and lower ring nodes.
////////////////////////////////////////////////////////////////////////////////
interface RingNode#(numeric type nofNodes, 
		    numeric type fltSz, 
		    numeric type numVC);

   // send a payload to node destination
   method Action enq(Packet#(nofNodes) packet);

   // read the first incoming message
   method Packet#(nofNodes) first();

   // dequeue the first incoming message
   method Action deq();

   // get the endpoint's ID
   method Bit#(TLog#(nofNodes)) nodeID();
   
   //ADDED methods for communicating with upper & lower ring node

   // enque flit arriving from upper ring node
   method Action putUp(Flit_t#(nofNodes, fltSz, numVC) flit);
   
   // enque flit arriving from lower ring node
   method Action putDn(Flit_t#(nofNodes, fltSz, numVC) flit);
   
   // deque flit from upper ring node
   method ActionValue#(Flit_t#(nofNodes, fltSz, numVC)) getUp(); 

   // deque flit from lower ring node
   method ActionValue#(Flit_t#(nofNodes, fltSz, numVC)) getDn();
      
   method Bool notEmpty();
   method Bool notFull();
   
endinterface


////////////////////////////////////////////////////////////////////////////////
// RingNode implementing module:
//  nodeId parameter is used to specify node's IDs.
////////////////////////////////////////////////////////////////////////////////
module mkRingNode#(parameter Integer nodeId) (RingNode#(nofNodes, fltSz, numVC))
 provisos(Mul#(TDiv#(PayloadSz, fltSz), fltSz, PayloadSz));

   Integer dropTimeout = valueOf(DropTimeout_t);
   
   //////////////////////////////////////////////////////////////////////
   // instantiation of internal modules:
   //////////////////////////////////////////////////////////////////////
   PacketToFlit#(nofNodes, fltSz, numVC) packetToFlit <- mkPacketToFlit(nodeId);
   // flits from client
   VcFifo#(nofNodes, fltSz, numVC)  clientVcFifo <- mkVcFifo; 
   // flits from upper ring node
   VcFifo#(nofNodes, fltSz, numVC)  upRingVcFifo <- mkVcFifo; 
   // flits from lower ring node
   VcFifo#(nofNodes, fltSz, numVC) downRingVcFifo <- mkVcFifo;
   
   ThreeCrossBar#(nofNodes, Flit_t#(nofNodes, fltSz, numVC)) crossbar
    <- mkRingNodeCrossBar(nodeId);
   
   FlitToPacket#(nofNodes, fltSz, numVC, NofAssembeldPackets_t,
		 NofWaitingPkts_t) flitToPacket <- mkFlitToPacket(dropTimeout);

   //////////////////////////////////////////////////////////////////////
   // rules:
   //////////////////////////////////////////////////////////////////////
   rule fromPacket2FlitToVCFifo;
      let flit = packetToFlit.first;
      $display("@%4t rn%1d: packetToFlit   -> clientVcFifo ", 
	       $time, nodeId, fshow(flit));
      packetToFlit.deq();
      clientVcFifo.put(flit);
   endrule

   (* fire_when_enabled *)
   rule fromClientVCFifoToCrossbar;
      let flit <- clientVcFifo.get();
      $display("@%4t rn%1d: clientVcFifo   -> crossbar     ", 
	       $time, nodeId, fshow(flit));
      crossbar.putPort1(flit.dest, flit);
   endrule

   (* fire_when_enabled *)
   rule fromUpVCFifoToCrossbar;
      let flit <- upRingVcFifo.get();
      $display("@%4t rn%1d: upRingVcFifo   -> crossbar     ",
	       $time, nodeId, fshow(flit));
      crossbar.putPort0(flit.dest, flit);
   endrule

   (* fire_when_enabled *)
   rule fromDownVCFifoToCrossbar;
      let flit <- downRingVcFifo.get();
      $display("@%4t rn%1d: downRingVcFifo -> crossbar     ", 
	       $time, nodeId, fshow(flit));
      crossbar.putPort2(flit.dest, flit);
   endrule
   
   rule fromCrossbarToFlitToPacket;
      let flit <- crossbar.getPortSelf();
      $display("@%4t rn%1d: crossbar       -> flitToPacket ", 
	       $time, nodeId, fshow(flit));
      flitToPacket.enq(flit);
   endrule
   
   //////////////////////////////////////////////////////////////////////
   // methods:
   //////////////////////////////////////////////////////////////////////
   
   method Action enq(Packet#(nofNodes) packet);
      $display("@%4t rn%1d: enq packet                     ", 
	       $time, nodeId, fshow(packet));
      packetToFlit.enq(packet);
   endmethod

   // read the first incoming message
   method Packet#(nofNodes) first = flitToPacket.first;
      
   // dequeue the first incoming message
   method Action deq();
      $display("@%4t rn%1d: deq packet                     ", 
	       $time, nodeId, fshow(flitToPacket.first));
      flitToPacket.deq();
   endmethod

   // get the endpoint's ID
   method Bit#(TLog#(nofNodes)) nodeID();
      return pack(nodeID);
   endmethod

   method Action putUp(Flit_t#(nofNodes, fltSz, numVC) flit);
      $display("@%4t rn%1d: putUp flit                     ",
	       $time, nodeId, fshow(flit));
      upRingVcFifo.put(flit);
   endmethod

   method Action putDn(Flit_t#(nofNodes, fltSz, numVC) flit);
      $display("@%4t rn%1d: enqDn flit                     ",
	       $time, nodeId, fshow(flit));
      downRingVcFifo.put(flit);
   endmethod
   
   // deque flit from upper ring node
   method ActionValue#(Flit_t#(nofNodes, fltSz, numVC)) getUp(); 
      let flit <- crossbar.getPortUp();
      return flit;
   endmethod

   // deque flit from lower ring node
   method ActionValue#(Flit_t#(nofNodes, fltSz, numVC)) getDn();
      let flit <- crossbar.getPortDn();
      return flit;
   endmethod

   method Bool notEmpty = flitToPacket.notEmpty;
   method Bool notFull  = packetToFlit.notFull;
      
endmodule

// (* synthesize *)
// module mkRingNode_Synth(RingNode#(4,32,2));
//    let _u <- mkRingNode(1);
//    return _u;
// endmodule
