/*
 * Author: Michael Kimi
 */
/**
* Define all common types that are being used in this project
*/
import FShow::*;// for being able to "pretty print" types defined below

//////////////////////////////////////////////////////////////////////
// Important note:
// Type definitions from Ring.bsv appears here to remove inclusion 
// of Ring.bsv from all other modules which eventually cause cyrcular
// dependancy
//////////////////////////////////////////////////////////////////////

typedef 256 PayloadSz; // data size received by the node from a client.
typedef Bit#(PayloadSz) Payload;

typedef struct {       // data packet received from the client (user) 
   Bit#(TLog#(nodeNum)) peer; // destination Id of the receiving node
   Payload msg;               // data itself to be send to a peer
   } Packet#(type nodeNum) deriving(Bits, Eq);


//////////////////////////////////////////////////////////////////////
// other typedefs
//////////////////////////////////////////////////////////////////////

//number of flits in a packet
typedef TDiv#(PayloadSz, fltSz) 
NofFlitsInPacket_t#(numeric type fltSz);

// size of packet id field in bits
typedef 4 PacketIdSize_t; 

// represent packet id
typedef Bit#(PacketIdSize_t) PacketId_t;

// holds flit's data
typedef Bit#(fltSz) FlitPayload_t#(numeric type fltSz); 

// represent flit's id, calc size of flit id field in bits from
//  proveded types
typedef Bit#(TLog#(TDiv#(PayloadSz, fltSz))) 
FlitId_t#(numeric type fltSz);

// address of a node on a ring
typedef Bit#(TLog#(nofNodes)) 
Address_t#(numeric type nofNodes);

// represend a VC type of a flit
typedef Bit#(TLog#(numVC)) 
VcId_t#(numeric type numVC);

// a header of tagged flit
typedef struct{
   Address_t#(nofNodes)    src;  //flit's sender address
   Address_t#(nofNodes)    dest; //flit's destination address
   FlitId_t#(fltSz) fltId;//flit's id
   PacketId_t              pktId;//source packet id
   VcId_t#(numVC)          vcId; //VC of a flit
   FlitPayload_t#(fltSz)   data; //flit's data
   } Flit_t#(numeric type nofNodes, 
	     numeric type fltSz,
	     numeric type numVC) deriving (Bits, Eq);


//////////////////////////////////////////////////////////////////////
// define show methods for common types for easy printing...
instance FShow#(Flit_t#(nofNodes, flitSz, numVC)) ;
   function Fmt fshow ( Flit_t#(nofNodes, flitSz, numVC) f);
      return $format("<Flit src:0x%h dest:0x%h fltId:0x%h pktId:0x%h vcId:0x%h data:0x%h>"
		     ,f.src, f.dest, f.fltId, f.pktId, f.vcId, f.data);
   endfunction
endinstance

instance FShow#(Packet#(nodeNum)) ;
   function Fmt fshow ( Packet#(nodeNum) p);
      return $format("<Packet peer:0x%h msg:0x%h>", p.peer, p.msg);
   endfunction  
endinstance

