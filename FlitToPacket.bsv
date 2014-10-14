/*
 * Author: Michael Kimi
 */
import Ehr::*;
import FIFOF::*;
import CommonTypes::*;
import Vector::*;
import Cntr::*;
import IndexPool::*;
import BRAM::*;
import Fifo::*;
import PacketFifo::*;
import FShow::*;

//////////////////////////////////////////////////////////////////////
// interface definition //////////////////////////////////////////////
//
// nofAssemblPkts: defines the number of packets that may be 
//  assembled concurrently from arriving flits.
// nofWaitingPkts: define the number of ready packets to be fetched
//  by client
interface FlitToPacket#(numeric type nofNodes, 
			numeric type fltSz, 
			numeric type numVC, 
			numeric type nofAssemblPkts,
			numeric type nofWaitingPkts);
   //enq flit into the flit to packet unit
   method Action enq(Flit_t#(nofNodes, fltSz, numVC) flit);
   //deq an assembled packet from the unit
   method Action deq();
   //return the assembled packet 
   method Packet#(nofNodes) first();
   //return true if unit isn't empty and has a ready packet for a client
   method Bool notEmpty();
   //return true if unit isn't full and can accept a flit
   method Bool notFull();
   //report all configuration parameters, for debug
   method Action reportConfiguration();
   //return true if the unit finished its internal initialization
   method Bool isNotInitializing();
      
   method Action reportStatus();

endinterface

//////////////////////////////////////////////////////////////////////
// internal type definitions /////////////////////////////////////////

typedef Bit#(TLog#(depth)) 
 RamIndex_t#(numeric type depth); //for ram's indexing 

typedef struct {
   Address_t#(nofNodes) src;	//indexing field 
   PacketId_t           pktId;	//indexing field
   } CamEntry_t#(numeric type nofNodes) deriving (Bits, Eq);

typedef struct {
   Flit_t#(nofNodes, fltSz, numVC) flit; //arrived flit
   Bool                 isAllocated;     //true if flit is in the cam
   RamIndex_t#(depth)   rowIdx;	         //valid if isAllocated==True
   FlitId_t#(fltSz) flitCnt;  //count arrived flits
   } Forward_t#(numeric type nofNodes, 
		numeric type numVC, 
		numeric type fltSz,
		numeric type depth) deriving (Bits, Eq);

//////////////////////////////////////////////////////////////////////
// define show methods for common types for easy printing...
instance FShow#(Forward_t#(nofNodes, numVC, flitSz, depth)) ;
   function Fmt fshow (Forward_t#(nofNodes, numVC, flitSz, depth) fw);
      return ($format("<Forward isAloc:%b", fw.isAllocated) 
	      + $format(" rowIdx:0x%h", fw.rowIdx)
	      + $format(" flitCnt:0x%h", fw.flitCnt)
	      + $format(" flit:",fshow(fw.flit))
	      + $format(">"));
   endfunction
endinstance



//////////////////////////////////////////////////////////////////////
// helper functions //////////////////////////////////////////////////

// creates a write request into the ram structure from forwarded data
function BRAMRequest#(RamIndex_t#(depth),    // address type
		      FlitPayload_t#(fltSz)) // data type
   makeWriteRequest(Forward_t#(nofNodes, numVC, fltSz, depth) fw);
   return BRAMRequest{write:           True,
		      responseOnWrite: False,
		      address:         fw.rowIdx,
		      datain:          fw.flit.data};
endfunction

// creates a read request from the ram structure from forwarded data
function BRAMRequest#(RamIndex_t#(depth),
		      FlitPayload_t#(fltSz))
   makeReadRequest(Forward_t#(nofNodes, numVC, fltSz, depth) fw);
   return BRAMRequest{write:           False,
		      responseOnWrite: True,
		      address:         fw.rowIdx,
		      datain:          ?};
endfunction

// return a payload type from vector of flits
function Payload toPayload(Vector#(nofFlitsInPacket, FlitPayload_t#(fltSz)) flits)
  provisos (Mul#(nofFlitsInPacket, fltSz, PayloadSz));
   Bit#(PayloadSz) packet = pack(flits);
   return unpack(packet);
endfunction

function Bool isMatching(Flit_t#(nofNodes, fltSz, numVC) flit,
			 CamEntry_t#(nofNodes) entry);
   return (flit.src == entry.src) && (flit.pktId == entry.pktId);
endfunction

////////////////////////////////////////////////////////////////////////////////
// Module implementation
// 
// Implements Flit to packed assembled module. Flits may arrive into
// this module from multiple sources. all flits are being assembled into
// a packed. when a packed is ready it may be fetched. In case no one fetched
// the packet during `dropTimeout` number of cycles the assembled packet will
// be dropped silently
////////////////////////////////////////////////////////////////////////////////
module mkFlitToPacket#(parameter Integer dropTimeout)
  (FlitToPacket#(nofNodes, fltSz, numVC, nofAssemblPkts, nofWaitingPkts))
   provisos(Mul#(TDiv#(PayloadSz, fltSz), fltSz, PayloadSz)); //TODO check why BSC screams w/o this dummy proviso?
   
   Integer flitCountLim = valueOf(NofFlitsInPacket_t#(fltSz))-1;
   
   //CAM that store packet's allocated row for flits that are being assembled
   Vector#(nofAssemblPkts, Ehr#(2, CamEntry_t#(nofNodes))) cam
     <- replicateM( mkEhr( CamEntry_t{src:?, pktId:?}));

   // stores a valid bit for each entry in a CAM
   Vector#(nofAssemblPkts, Ehr#(2, Bool)) validEntry
     <- replicateM(mkEhr(False));
   
   //counters that counts arrived flits in assembled packets
   Vector#(nofAssemblPkts, Cntr#(FlitId_t#(fltSz))) flitsCounter 
     <- replicateM( mkCntr(flitCountLim) );
   
   
   //flopping stage FIFOs (registers)
   FIFOF#(Flit_t#(nofNodes, fltSz, numVC))                    stage1 <- mkFIFOF;
   FIFOF#(Forward_t#(nofNodes, numVC, fltSz, nofAssemblPkts)) stage2 <- mkFIFOF;
   FIFOF#(Flit_t#(nofNodes, fltSz, numVC))                    stage3 <- mkFIFOF;
   
   //packet FIFO, to store assembled packets for client
   Fifo#(nofWaitingPkts, Packet#(nofNodes)) packetFifo
     <- mkPacketFifo(dropTimeout);
   
   //track free ram entries
   Allocator#(nofAssemblPkts, RamIndex_t#(nofAssemblPkts)) indexPool
     <- mkIndexAllocator;
   
   //create RAM structure to hold all flits data (of assembled packet)
   Integer nofBRAMs = valueOf(NofFlitsInPacket_t#(fltSz))-1;

   BRAM_Configure cfg = defaultValue;//BRAM config obj
   cfg.memorySize = valueOf(nofAssemblPkts);  // set memory size
   
   BRAM1Port#(RamIndex_t#(nofAssemblPkts), 
	      FlitPayload_t#(fltSz)) ramArr[nofBRAMs];
   for (Integer i=0; i<nofBRAMs; i=i+1) begin 
      ramArr[i] <- mkBRAM1Server(cfg);
   end
   
   ////////////////////////////////////////////////////////////////////////
   /// rules section
   ////////////////////////////////////////////////////////////////////////

   // do cam look-up on the arrived flit. If miss allocate entry, If hit
   //  find out numbers of arrived flits so far & the allocated ram row
   rule cycle1CamLookup if (stage1.notEmpty && indexPool.isNotInitializing);
      
      let flit = stage1.first;
      stage1.deq;
      
      Bool isFound = False;
      CamEntry_t#(nofNodes) foundEntry = ?;
      FlitId_t#(fltSz) count = 0;
      RamIndex_t#(nofAssemblPkts) rowIdx = ?;
   
      //make a cam look up to check if flit belongs to a packet 
      // which is being assembled
      for (Integer i=0; i<valueOf(nofAssemblPkts); i=i+1) begin
	 foundEntry = cam[i][1];
	 if (validEntry[i][1] && isMatching(flit, foundEntry)) begin // we have a hit
	    isFound = True;
	    rowIdx = fromInteger(i);
	    //$display("@%4t f2p: matching index %2d flit cnt %2d", $time, i, count);
	 end
      end
      
      if (!isFound) begin // in case of MISS, allocate resources for that flit
	 rowIdx = indexPool.freeIndex;
	 indexPool.nextFree;
      end
      
      count = flitsCounter[rowIdx].getCount;
      flitsCounter[rowIdx].increment; 

           
      Forward_t#(nofNodes, numVC, fltSz,
		 nofAssemblPkts) fw = Forward_t{flit:        flit, 
						isAllocated: isFound, 
						rowIdx:      rowIdx, 
						flitCnt:     count};

//       if (isFound)
// 	 $display("@%4t f2p: stg1 HIT - forwarding ", $time, fshow(fw));
//       else
// 	 $display("@%4t f2p: stg1 MISS- forwarding ", $time, fshow(fw));
      
      stage2.enq(fw);
   endrule
   
   //receive "cam look-up result" on the arrived request and write it to rams
   rule cycle2RamOperation if (stage2.notEmpty && indexPool.isNotInitializing);
      Fmt formatStr;   
      let fwEntry = stage2.first;
      let isAllocated = fwEntry.isAllocated;
      let ramIdx = fwEntry.flitCnt;
      let rowIdx = fwEntry.rowIdx;
      let flit = fwEntry.flit;
      stage2.deq;
      
      //Description of the following code:
      //1. first flit of a packet -> a write the flit into pre-allocated entry in ram
      //2. last flit of a packet  -> a read from all rams and write to packetFifo
      //                             b dealloc entry from cam (set valid==False)
      //                             c dealloc entry from ram
      //3. some flit of a packet arrived => write to appropriate RAM

      if (isAllocated == False) begin //1.
	 //1st flit will always be written to a free row at ram 0
	 ramArr[0].portA.request.put(makeWriteRequest(fwEntry));
	 cam[rowIdx][0] <= CamEntry_t{src:    flit.src,    // update the cam
				      pktId:  flit.pktId};
	 validEntry[rowIdx][0] <= True;	                   // set entry valid

	 formatStr = $format("FRST FLIT OF PKT. write flit to ram 0 row", 
			     rowIdx, " ", fshow(flit));
	 
      end
      else if (isAllocated && (ramIdx == fromInteger(flitCountLim))) begin //2.
	 for (Integer i=0; i < nofBRAMs; i=i+1) begin // generate reads from all rams
	    ramArr[i].portA.request.put(makeReadRequest(fwEntry));
	 end
	 indexPool.deallocate(rowIdx);   // de allocate row
	 validEntry[ramIdx][1] <= False; // invalidate the entry in CAM
	 stage3.enq(flit);	         // enable next processing stage

	 formatStr = $format("LAST FLIT OF PKT. reading from all rams and de alloc row ",
			     rowIdx, fshow(flit));

      end
      else begin //3.
	 ramArr[ramIdx].portA.request.put(makeWriteRequest(fwEntry));
	 
	 formatStr = $format("SOME FLIT OF PKT. write flit to ram ", ramIdx, " row ", 
			     rowIdx, " ", fshow(flit));
      end
      
//      $display("@%4t f2p: stg2 ", $time, formatStr);
   endrule
   
   // receive read data from all rams and assemble them into a single
   // packet. Then write this packet to packetFifo
   rule cycle3WriteToPackeFifo if (stage3.notEmpty);
      let flit = stage3.first;
      
      Vector#(NofFlitsInPacket_t#(fltSz), FlitPayload_t#(fltSz)) 
        flitsData = newVector;
      
      for (Integer i=0; i < nofBRAMs; i=i+1) begin // put flits read flits
	 flitsData[i] <- ramArr[i].portA.response.get();
      end
      //put the last piece directly from stage3 FIFO (it isn't written into rams)
      flitsData[nofBRAMs] = flit.data;
      
      Packet#(nofNodes) packet = Packet{peer: flit.dest, 
					msg:  toPayload(flitsData)};
      
//      $display("@%4t f2p: stg3 assembled ", $time, fshow(packet));

      packetFifo.enq(packet);

      stage3.deq;
   endrule
   
   
   ////////////////////////////////////////////////////////////////////////////////
   /// implementation of interface's methods:
   ////////////////////////////////////////////////////////////////////////////////
   
   method Action enq(Flit_t#(nofNodes, fltSz, numVC) flit) 
    if (indexPool.isNotInitializing);
      
//      $display("@%4t f2p: stg0 staging ", $time, fshow(flit));
      stage1.enq(flit);
   endmethod
   
   method Action deq = packetFifo.deq;
      
   method Packet#(nofNodes) first = packetFifo.first;

   method Bool notEmpty = packetFifo.notEmpty;

   method Bool notFull = !indexPool.notFull;
      
   method Action reportConfiguration();      
      $display("From Interface:");
      $display(" Number of Nodes = %3d", valueOf(nofNodes));
      $display(" Flit Size       = %3d", valueOf(fltSz));
      $display(" Number of VCs   = %3d", valueOf(numVC));
      $display(" # Assembled pkts= %3d", valueOf(nofAssemblPkts));
      $display(" # Waiting pkts  = %3d", valueOf(nofWaitingPkts));
      $display("Internal:");
      $display(" Flit Cout Limit = %3d", flitCountLim);
      $display(" Timeout         = %3d", dropTimeout);
      $display(" Number of RAMs  = %3d", nofBRAMs);
   endmethod
      
   method Action reportStatus();
      $display("Flit2Packet status:");
      $display(" IdxALC notEmpty = %b, notFull = %b, notInit = %b", indexPool.notEmpty, indexPool.notFull, indexPool.isNotInitializing);
      $display(" PktFFO notEmpty = %b, notFull = %b", packetFifo.notEmpty, packetFifo.notFull);
      $display(" stage1 notEmpty = %b, notFull = %b", stage1.notEmpty, stage1.notFull);
      $display(" stage2 notEmpty = %b, notFull = %b", stage2.notEmpty, stage2.notFull);
      $display(" stage3 notEmpty = %b, notFull = %b", stage3.notEmpty, stage3.notFull);
      
   endmethod
      
   method Bool isNotInitializing = indexPool.isNotInitializing;
      
endmodule

