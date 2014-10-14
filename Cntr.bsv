/*
 * Author: Michael Kimi
 */
// Implemens a cyclic bounded counter, when it reaches it's maximal value
//  it will automaticaly wrap to 0
interface Cntr#(type t);
   // returns current value of a counter
   method t getCount();
   // increments counter to next value
   method Action increment();
   method Action decrement();
endinterface

module mkCntr#(parameter Integer maxVaule) (Cntr#(t))
 provisos(Bits#(t, tSz), Arith#(t), Eq#(t));
   
   Reg#(t) counter <- mkReg(0);
		  
   PulseWire increment_called <- mkPulseWire();
   PulseWire decrement_called <- mkPulseWire();
		  
   rule count;
      Bool isCounterWrapAround = (counter == fromInteger(maxVaule));
      Bool isCounterZero = (counter == 0);
      
      if (increment_called && !decrement_called) begin
	 if (isCounterWrapAround) begin
	    counter <= 0;
	    //$display("@%4t cnt: wrap around to 0", $time);
	 end
	 else begin
	    counter <= counter + 1;
	    //$display("@%4t cnt: increment current value of %3d", $time, counter);
	 end
      end
      else if (!increment_called && decrement_called) begin
	 if (isCounterZero)
	    counter <= 0;
	 else
	    counter <= counter - 1;
      end
      else begin // both inc/dec or none of them been called
	 counter <= counter;
      end
   endrule
		  
   method t getCount = counter;

   method Action decrement();
      decrement_called.send();
   endmethod

   method Action increment();
      increment_called.send();
   endmethod

endmodule

// (* synthesize *)
// module mkCntr_Synth(Cntr#(Bit#(4)));
//    let c <- mkCntr(10);
//    return c;
// endmodule
