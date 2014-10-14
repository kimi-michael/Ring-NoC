/*
 * Author: Michael Kimi
 */
package Ring;

import Vector::*;
import FShow::*;
import CommonTypes::*;
import RingNode::*;

//////////////////////////////////////////////////////////////////////
// IMPORTANT NOTE:
// The following types:
//   PayloadSz
//   Payload
//   Packet
// were moved to CommonTypes.bsv file. Otherwise they cause a circular 
// dependancy as explaned below:
// 1. RingNode should include Ring to know these types hence
//    RingNode->Ring
// 2. Ring should include RingNode cause it instantiates RingNodes to
//    form a ring :) thus: Ring->RingNode
// Now 1 and 2 form a circular include depandancy
//
//////////////////////////////////////////////////////////////////////

typedef 32 FlitSize_t; // size of a flit, have to satisfy the equation
		       //  (packet_size % flit_size == 0)
typedef 4 NumberOfVCs_t; // number of virtual channels in a system

//////////////////////////////////////////////////////////////////////
/// Ring interface. The parameter is the type used to specify node IDs.
//////////////////////////////////////////////////////////////////////
interface Ring#(numeric type nofNodes);
   
   // get a specific endpoint in the ring. 
   method RingNode#(nofNodes, FlitSize_t, NumberOfVCs_t) 
    getNode(Bit#(TLog#(nofNodes)) idx);

endinterface

//////////////////////////////////////////////////////////////////////
/// module implementation
//////////////////////////////////////////////////////////////////////
module mkRing(Ring#(nofNodes));
   
   Integer iNofNodes = valueOf(nofNodes);
   
   RingNode#(nofNodes, FlitSize_t, NumberOfVCs_t) nodeVector[valueOf(nofNodes)];
   for (Integer i = 0; i < iNofNodes; i = i+ 1) begin
      nodeVector[i]<-mkRingNode(i); // create all ring nodes
   end
   
   // connect all nodes to form a ring ///////////////////////////////
   for (Integer i = 0; i < iNofNodes; i = i+ 1) begin
	 
      let curNode = nodeVector[i];
      let nextNode = nodeVector[(i+1)%iNofNodes];
      
      rule putFlitToNext;
	 let flit <- curNode.getUp();
	 $display("@%4t rn%1d: sending flit to Up-Ring ...    ", 
	    $time, i, fshow(flit));
	 nextNode.putDn(flit);
      endrule
      
      rule getFlitFromNext;
	 let flit <- nextNode.getDn();
	 $display("@%4t rn%1d: getting flit from Up-Ring ...  ", 
	    $time, i, fshow(flit));
	 curNode.putUp(flit);
      endrule
   end
   
   //////////////////////////////////////////////////////////////////////
   method RingNode#(nofNodes, FlitSize_t, NumberOfVCs_t) 
    getNode(Bit#(TLog#(nofNodes)) idx);
      return nodeVector[idx];
   endmethod
   
endmodule


endpackage
