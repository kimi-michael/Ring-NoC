/*
 * Author: Michael Kimi
 */
//This module implements a pool of indexs. It starts when all entries are
// ready to be allocated. Each time user may request to get one index
// at a time until all indexes are allocated.
// When user "finishes using an index" he should return that index to
// the allocator (for future allocation)
//
import Fifo::*;

interface Allocator#(numeric type n, type t);
   method t      freeIndex();
   method Action nextFree();
   method Action deallocate(t index);
   method Bool notEmpty();
   method Bool notFull();
   method Bool isNotInitializing();
endinterface

module mkIndexAllocator(Allocator#(n, t)) provisos (Bits#(t, tSz), Eq#(t), Arith#(t));
   
   Fifo#(n,t) indexFifo <- mkCFFifo;
   
   Reg#(Bool) isInitDone <- mkReg(False);
   Reg#(t) ii <- mkReg(0);
   
   Integer depth = valueOf(n);
   
   //init the pool in first "n" # of cycles"
   rule initializePool if ( !isInitDone );
      //$display("@%4t alc: initialize element #%02d", $time, ii);
      indexFifo.enq(ii);
      if (ii == fromInteger(depth-1)) 
	 isInitDone <= True;
      ii <= ii + 1;
   endrule

   method t freeIndex() if (isInitDone);
      return indexFifo.first;
   endmethod

   method Action nextFree() if (isInitDone);
      //$display("@%4t alc: calulate next after %d", $time, indexFifo.first);
      indexFifo.deq;
   endmethod
   
   method Action deallocate(t index) if (isInitDone);
      //$display("@%4t alc: deallocate index %3d", $time, index);
      indexFifo.enq(index);
   endmethod
   
   method Bool notEmpty = !indexFifo.notFull;
      
   method Bool notFull  = !indexFifo.notEmpty;
      
   method Bool isNotInitializing = isInitDone;
   
endmodule
