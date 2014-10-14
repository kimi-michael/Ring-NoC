/*
 * Author: Michael Kimi
 */
package RingForFpga;

import CommonTypes::*;
import RingNode::*;
import Ring::*;

//////////////////////////////////////////////////////////////////////
// define synthesizeable interface & module to be tested on FPGA
//////////////////////////////////////////////////////////////////////
interface RingWith4Nodes; // define ring with 4 nodes ifc
   method Action enq0(Packet#(4) packet);
   method Packet#(4) first0();
   method Action deq0();
   
   method Action enq1(Packet#(4) packet);
   method Packet#(4) first1();
   method Action deq1();
   
   method Action enq2(Packet#(4) packet);
   method Packet#(4) first2();
   method Action deq2();
   
   method Action enq3(Packet#(4) packet);
   method Packet#(4) first3();
   method Action deq3();
endinterface


// implement ring with 4 node. Flit size is 8, number of VCs is 2
module mkRingWith4Nodes(RingWith4Nodes);
   
   Integer iNofNodes = 4;
   
   RingNode#(4, 8, 2) nodeVector[4];
   for (Integer i = 0; i < iNofNodes; i = i+ 1) begin
      nodeVector[i]<-mkRingNode(i); // create all ring nodes
   end
   
   // connect all nodes to form a ring ///////////////////////////////
   for (Integer i = 0; i < iNofNodes; i = i+ 1) begin
      
      let curNode = nodeVector[i];
      let nextNode = nodeVector[(i+1)%iNofNodes];
      
      rule putFlitToNext;
	 let flit <-curNode.getUp();
	 nextNode.putDn(flit);
      endrule
      
      rule getFlitFromNext;
	 let flit <-nextNode.getDn();
	 curNode.putUp(flit);
      endrule
   end
   
   // implement all the methods
   method Action enq0(Packet#(4) packet); 
      nodeVector[0].enq(packet);
   endmethod
   method Packet#(4) first0 = nodeVector[0].first;
   method Action deq0 = nodeVector[0].deq;
   
   method Action enq1(Packet#(4) packet); 
      nodeVector[1].enq(packet); 
   endmethod
   method Packet#(4) first1 = nodeVector[1].first;
   method Action deq1 = nodeVector[1].deq;
   
   method Action enq2(Packet#(4) packet); 
      nodeVector[2].enq(packet); 
   endmethod
   method Packet#(4) first2 = nodeVector[2].first;
   method Action deq2 = nodeVector[2].deq;
   
   method Action enq3(Packet#(4) packet); 
      nodeVector[3].enq(packet); 
   endmethod
   method Packet#(4) first3 = nodeVector[3].first;
   method Action deq3 = nodeVector[3].deq;

endmodule

// now synthesize the synthesizable module :)
(* synthesize *)
module mkRingWith4Nodes_Synth(RingWith4Nodes);
   let _u <- mkRingWith4Nodes();
   return _u;
endmodule

endpackage
