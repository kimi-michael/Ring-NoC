/*
 * Author: Michael Kimi
 */
import CommonTypes::*;
import Fifo::*;
import FShow::*;
import Arbiter::*;

interface VcFifo#(numeric type nofNodes, 
		  numeric type fltSz, 
		  numeric type numVC);
   //put a flit into vc fifo
   method Action put(Flit_t#(nofNodes, fltSz, numVC) flit);

   //remove the topmost flit out of vc fifo
   method ActionValue#(Flit_t#(nofNodes, fltSz, numVC)) get();
endinterface

module mkVcFifo(VcFifo#(nofNodes, fltSz, numVC))
 provisos(Log#(numVC, numVCSz));
   
   Integer nofVCs = valueOf(numVC);
   
   //vc fifos array - one fifo for each vc
   Fifo#(NofFlitsInPacket_t#(fltSz), 
	 Flit_t#(nofNodes, fltSz, numVC)) vcFifoArr[nofVCs];
   
   //init loop to create all fifos
   for (Integer i = 0; i < nofVCs; i = i+ 1) begin
      vcFifoArr[i]<-mkCFFifo;
   end
   
   Bool isFixed = False;
   Arbiter_IFC#(numVC) arbiter <- mkArbiter(isFixed);
   

   /////////////////////////////////////////////////////////////////////
   /// rules
   /////////////////////////////////////////////////////////////////////
   for (Integer i=0; i < nofVCs; i = i + 1) begin
      //every non empty fifo bids the arbiter
      rule bid if ( vcFifoArr[i].notEmpty() );
	 arbiter.clients[i].request();
      endrule
   end
   
   ////////////////////////////////////////////////////////////////////
   // interface methods implementation 
   
   method Action put(Flit_t#(nofNodes, fltSz, numVC) flit);
//       $display("@%4t vcf: put fifoIdx:%1d ", 
// 	       $time, flit.vcId /*,fshow(flit)*/);
      vcFifoArr[flit.vcId].enq(flit);
   endmethod

   method ActionValue#(Flit_t#(nofNodes, fltSz, numVC)) get();
      //deque from current non empty fifo
      let winFifoId = arbiter.grant_id;
//       $display("@%4t vcf: get fifoIdx:%1d ", 
// 	       $time, winFifoId /*,fshow(flit)*/);
      let res = vcFifoArr[winFifoId].first;
      vcFifoArr[winFifoId].deq;
      return res;
   endmethod

endmodule


// (* synthesize *)
// module mkVcFifo_Synth(VcFifo#(4,32,4));
//    let _u <- mkVcFifo;
//    return _u;
// endmodule
