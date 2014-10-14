// Ehr.bsv
//
// The functional design is all Nirav's (ndave@mit.edu) fault.
// Forward complaints/commentary in that direction. Myron 
// (mdk@mit.edu) added probes to it for proper scheduling
//
// The iterative design is all Myron's fault, since he thought
// an alternative approach would help him understand what was
// eventually revealed to be a bug in the bluespec compiler!
//
// The two implementations (mkEhr and mkEhrF) are functionally 
// identical.
//
// NOTE: THIS IS VERY IMPORTANT!!!
//
// Neither of these two modules (mkEhr or mkEhrF) should be used
// without being enclosed immediately in a synthesize boundry.
// This is due to bug in the Bluespec compiler which really
// screws things up.  Finding this out was painful.  Avoid the
// pain and follow this warning --myron
//
// Second point: These two Ehr implementations are close to what
// Dan Rosenband outlined in his thesis.  What they lack is
// scheduling constraints between read/write pairs.  That is to
// say that read_1 and write_1 are conflict free whereas they
// should be FORCED to schedule read_1 < write_1 ...

import Vector ::*;
import RWire  ::*;
import Probe  ::*;

typedef  Vector#(n_sz, Reg#(alpha)) Ehr#(type n_sz, type alpha);

// mkVirtualReg adds one level of ephemeralness to 'base'.  'state'
// is the concrete interface underlying the virtual register (the 
// register itself).  With state and base as input, mkVirtualReg 
// connects them with Rwires and probes so as to enforce the proper 
// rule scheduling and behavior:
//             ... < read_n < write_n < read_n+1 < write_n+1 < ...

module mkVirtualReg#(Reg#(alpha) state, Reg#(alpha) base) 
   (Tuple2#(Reg#(alpha), Reg#(alpha))) provisos(Bits#(alpha,asz));

   // enforce ordering and data forewarding using wires and probes
   RWire#(alpha) w  <- mkRWire(); 
   Probe#(alpha) probe <- mkProbe; 

   Reg#(alpha) i0 = interface Reg
		       method _read();
			  return base._read();
                       endmethod
		       method Action _write(x);
			  w.wset(x);
			  probe <= base._read();
                       endmethod
		    endinterface;

   Reg#(alpha) i1 = interface Reg
		       method _read() = fromMaybe(base._read, w.wget());
                       method _write(x) = noAction; // never used
		    endinterface;   

   return (tuple2(i0,i1));

endmodule

// Creates an Ehr module by layering virtual registers
// .idx[i] holds read_i and write_i methods.  reg.read_n
// is expressec as reg[n]._read();

module mkEhrF#(alpha init)(Ehr#(n,alpha)) provisos(Bits#(alpha, asz),
						   Add#(li, 1, n));

   Reg#(alpha) r <- mkReg(init);

   Vector#(n,Reg#(alpha)) vidx = newVector();

   // 'old' is a placeholder which also ensures that the last-written value 
   // won't get dropped since r and old are both the initial register during 
   // the first iteration of the 'for' loop.
   Reg #(alpha) old = r;
   Tuple2#(Reg#(alpha),Reg#(alpha)) tinf;
   
   // make interfaces
   for(Integer i = 0; i < valueOf(n); i = i + 1)
      begin
	 tinf <- mkVirtualReg(r,old);
	 vidx[i] = tinf.fst();
	 old = tinf.snd();
      end   
   
   rule do_stuff(True);
      r <= tinf.snd._read();
   endrule
   
   return vidx;      

endmodule

/*********************************************************************/
// alternate implementation, not quite as cool as the functional 
// version by Nirav, but less code and possibly easier to understand
/*********************************************************************/

module mkEhr#(alpha init) (Ehr#(n,alpha)) provisos(Bits#(alpha, asz),
						   Add#(li, 1, n));
   
   Reg#(alpha)  r <- mkReg(init);
   Vector#(n, RWire#(alpha)) wires  <- replicateM(mkRWire);
   Vector#(n, RWire#(alpha)) probes <- replicateM(mkRWire);
   Vector#(n, Reg#(alpha)) vidx = newVector();
   Vector#(n, alpha) chain = newVector();
   
   for(Integer i = 0; i < valueOf(n); i = i + 1)
      begin
	 if(i==0) chain[i] = r;
	 else chain[i] = fromMaybe(chain[i-1], wires[i-1].wget());
      end
   
   for(Integer j = 0; j < valueOf(n); j = j + 1)
      begin
	 vidx[j] = interface Reg
		      method _read();
			 return chain[j];
		      endmethod
		      method Action _write(x);
			 wires[j].wset(x);
			 probes[j].wset(chain[j]);
		      endmethod
		   endinterface;
      end
   
   
   (*fire_when_enabled, no_implicit_conditions *)
   rule do_stuff(True);
      r <= fromMaybe(chain[valueOf(li)], wires[valueOf(li)].wget());
   endrule
   
   return  vidx;
   
endmodule

interface Ehr2BSV#(type t);
   interface Reg#(t) r1;
   interface Reg#(t) r2;
endinterface

(* synthesize *)
module mkEhr2BSV (Ehr2BSV#(Bit#(32)));
   Ehr#(2,Bit#(32)) ehr <- mkEhr(0);
   interface r1 = ehr[0];
   interface r2 = ehr[1];
endmodule