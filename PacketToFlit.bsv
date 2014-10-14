/*
 * Author: Michael Kimi
 */
/**
* Implements all moduel related to PacketToFlit module
*/
import FShow::*;
import CommonTypes::*;
import Fifo::*; //for pipleind n-elemenst fifos
import SpecialFIFOs::*; //for pipelined standard fifos (1-elements)
import FIFOF::*;
import Vector::*;
import Cntr::*;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

interface PacketToFlit#(numeric type nofNodes, 
			numeric type fltSz, 
			numeric type numVC);
   // put the packet into the unit, will be invoked by clinet
   method Action enq(Packet#(nofNodes) packet);
   // read a topmost flit of a unit, will invoked by VCFiFo
   method Flit_t#(nofNodes, fltSz, numVC) first();
   // remove the topmost flit and put the next one (if any) instead
   method Action deq();
   // true if the unit has any flits in it
   method Bool notEmpty();
   // true if the unit can accept more packets from a client
   method Bool notFull();
endinterface

module mkPacketToFlit#(parameter Integer nodeId)
   (PacketToFlit#(nofNodes, fltSz, numVC));
   
   //some ints i'm using here
   Integer flitFifoSize = valueOf(NofFlitsInPacket_t#(fltSz));
   Integer pktCountLim  = valueOf(TSub#(TExp#(PacketIdSize_t), 1));
   Integer fltCountLim  = flitFifoSize - 1;
   Integer vcCountLim   = valueOf(numVC) - 1;
   
   //fifos
   FIFOF#(Packet#(nofNodes)) packetFifo <- mkPipelineFIFOF;
   Fifo#(NofFlitsInPacket_t#(fltSz),
	 Flit_t#(nofNodes, fltSz, numVC)) flitFifo <- mkPipelineFifo;
   //counters
   Cntr#(PacketId_t)       pktCount <- mkCntr(pktCountLim);
   Cntr#(FlitId_t#(fltSz)) fltCount <- mkCntr(fltCountLim);
   Cntr#(VcId_t#(numVC))    vcCount <- mkCntr(vcCountLim);

   /******************************************************************
    * This rule is activezed when we have a packet in a packetFifo.
    * Then every cycle we will enque a flit out of the arrived packet
    * into the flitFifo
    *****************************************************************/
   rule enqFlit if (packetFifo.notEmpty && flitFifo.notFull);
      
      Flit_t#(nofNodes, fltSz, numVC) flit = ?;
      Bit#(PayloadSz) packet = pack(packetFifo.first.msg);
      FlitPayload_t#(fltSz) flitsArr[flitFifoSize];

      //split the packet vector into vector of flits
      for( Integer i = 0; i < flitFifoSize; i = i + 1 ) begin
	 flitsArr[i] = packet[ (i+1)*valueOf(fltSz) - 1 : i*valueOf(fltSz)];
      end
      
      //update flit's fields
      flit.src   = fromInteger(nodeId);
      flit.dest  = packetFifo.first.peer;
      flit.fltId = fltCount.getCount;
      flit.pktId = pktCount.getCount;
      flit.vcId  = vcCount.getCount;
      flit.data  = flitsArr[fltCount.getCount]; //choose the appropriate flit

//      $display("@%4t p2f: enq flit ", $time, fshow(flit));

      flitFifo.enq(flit);
      
      //it's a last flit of a pkt
      if (fltCount.getCount == fromInteger(fltCountLim)) begin
	 pktCount.increment;
	 vcCount.increment;
	 packetFifo.deq;
      end
      fltCount.increment;
      
   endrule
   
   ///////////////////////////////////////////////////////////////////
   /// methods implementation
   ///////////////////////////////////////////////////////////////////
   method Action enq(Packet#(nofNodes) packet) if (packetFifo.notFull);
//      $display("@%4t p2f: enq packet ", $time, fshow(packet));
      packetFifo.enq(packet);
   endmethod
   
   method Action deq() if (flitFifo.notEmpty);
//      $display("@%4t p2f: deq flit ", $time, fshow(flitFifo.first));
      flitFifo.deq;
   endmethod
   
   method Flit_t#(nofNodes,fltSz,numVC) first = flitFifo.first;
      
   method Bool notEmpty = flitFifo.notEmpty;
   
   method Bool notFull  = packetFifo.notFull;

   

endmodule
