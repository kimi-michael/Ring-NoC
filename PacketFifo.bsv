/*
 * Author: Michael Kimi
 */
import Fifo::*;
import RWire::*;
import FShow::*;

//////////////////////////////////////////////////////////////////////
// module implementation /////////////////////////////////////////////
//
//  if timeOut > 0 each ready packed will be stored in the fifo for
//   timeOut clocks. After that if the client didn't fetched the data
//   it will be released.
//  if timeOut is 0 the data will never be released.
//
module mkPacketFifo#(parameter Integer timeOut) 
   (Fifo#(size, t)) provisos (Bits#(t, tSz), FShow#(t));
   
   Fifo#(size, t) fifo <- mkPipelineFifo;
   
   Reg#(int) ageCount <- mkReg(fromInteger(timeOut));
   Wire#(Bool) resetAgeFromClear <- mkDWire(False);
   Wire#(Bool) resetAgeFromDeq   <- mkDWire(False);
   
   Wire#(Bool) deqCommand <- mkDWire(False);
   Wire#(Bool) ageThresholdReached <- mkDWire(False);
   
   rule doDeque if (ageThresholdReached || deqCommand);
      if ( ageThresholdReached && !deqCommand)
	 $display("@%4t pkf: age threshold reached, throw ", $time, fshow(fifo.first));
      else if (!ageThresholdReached && deqCommand)	  
	 $display("@%4t pkf: deque command, dequing  pkt  ", $time, fshow(fifo.first));
      else						  
	 $display("@%4t pkf: deque from age and command   ", $time, fshow(fifo.first));
      fifo.deq();
   endrule
   
   if (timeOut > 0) begin
      
      // assert age threshold reached signal when deq haven't been called
      // during the last TIMEOUT number of cycles
      rule ageThreshold if (ageCount == fromInteger(timeOut));
	 ageThresholdReached <= True;
      endrule
      
      // control of the age counter
      rule ageControl if (fifo.notEmpty);
	 if (resetAgeFromClear || resetAgeFromDeq || ageThresholdReached ) 
	    ageCount <= 0;
	 else 
	    ageCount <= ageCount + 1;
      endrule
      
   end
   
   method Bool notFull = fifo.notFull;
   
   method Bool notEmpty = fifo.notEmpty;
      
   method t first = fifo.first;

   method Action deq;
      deqCommand <= True;
      if (timeOut > 0)
	 resetAgeFromDeq <= True;
   endmethod
   
   method Action enq(t x);
      fifo.enq(x);
   endmethod
   
   method Action clear;
      fifo.clear;
      if (timeOut > 0)
	 resetAgeFromClear <= True;
   endmethod

endmodule
