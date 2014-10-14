/*
 * Author: Michael Kimi
 */

import CommonTypes::*;
import CrossBar::*;
import Vector::*; //for replication method
import FShow::*;  //for show method

typedef enum {Start, Test, End} TestPhase_t deriving (Bits, Eq);
typedef 6                       NofNodes_t;

(* synthesize *)
module mkCrossBarTestBench();
   
   Integer maxCyclesToRun = 50;
   Integer nodeId = 1;

   
   Reg#(Bit#(32)) cycle       <- mkReg(0);
   Reg#(TestPhase_t)testPhase <- mkReg(Start);
   Reg#(Bit#(4))  testStage   <- mkReg(0);
   TwoCrossBar#(int) twoXb    <- mkTwoCrossBar(0);
   ThreeCrossBar#(NofNodes_t, int) fxb <- mkRingNodeCrossBar(nodeId);
   
   ///////////////////////////////////////////////////////////////////
   rule timeout if (cycle > fromInteger(maxCyclesToRun));
      $display("Timeout termination cycle count %d", cycle);
      $finish();
   endrule
   
   rule clockCount;
      $display("\n== cycle %03d", cycle);
      cycle <= cycle + 1;
   endrule

   //////////////////////////////////////////////////////////////////
   rule start(testPhase == Start);
      $display("Start tests:");
      testPhase <= Test;
   endrule
   
   //////////////////////////////////////////////////////////////////
   Reg#(Direction_t) dir0 <- mkReg(Up);
   Reg#(Direction_t) dir1 <- mkReg(Down);
   Reg#(int) data0 <- mkReg('d100);
   Reg#(int) data1 <- mkReg('d200);
   Reg#(Bool) drainEnable <- mkReg(False);
   
   //////////////////////////////////////////////////////////////////
   rule test_rout_to_distinct_ports(testPhase == Test && cycle < 10);
      RoutPath_t p0 = RoutPath_t{level: replicate(dir0)}; 
      RoutPath_t p1 = RoutPath_t{level: replicate(dir1)};

      RoutRequest_t#(int) r0 = RoutRequest_t{path:p0, data:data0};
      RoutRequest_t#(int) r1 = RoutRequest_t{path:p1, data:data1};
      $display("put r0 ",fshow(r0));
      $display("    r1 ",fshow(r1));
      twoXb.putPortUp(r0);
      twoXb.putPortDn(r1);
      
      data0 <= data0 + 1;
      data1 <= data1 + 1;
      //swtich directions:
      bit d0 = pack(dir0); dir0 <= unpack(~d0);
      bit d1 = pack(dir1); dir1 <= unpack(~d1);
      
      drainEnable <= True;
   endrule
   
   //////////////////////////////////////////////////////////////////
   rule test_rout_to_same_port_up(testPhase == Test && 
				  cycle >= 10 && 
				  cycle < 20 );
      RoutPath_t       path = RoutPath_t{level:replicate(Down)};
      RoutRequest_t#(int) r = RoutRequest_t{path:path, data:data0};
      $display("put up ", fshow(r));
      twoXb.putPortUp(r);
      data0 <= data0 + 1;
   endrule

   rule test_rout_to_same_port_dn(testPhase == Test && 
				  cycle >= 10 && 
				  cycle < 20 );
      RoutPath_t       path = RoutPath_t{level:replicate(Down)};
      RoutRequest_t#(int) r = RoutRequest_t{path:path, data:data1};
      $display("put dn ", fshow(r));
      twoXb.putPortDn(r);
      data1 <= data1 + 1;
   endrule
   
   //////////////////////////////////////////////////////////////////
   rule test_one_port_at_a_time(testPhase == Test && 
				cycle >= 20 && cycle < 30);
      RoutPath_t       path = RoutPath_t{level:replicate(Up)};
      RoutRequest_t#(int) r = RoutRequest_t{path:path, data:data0};
      $display("put up ", fshow(r));
      twoXb.putPortDn(r);
      data0 <= data0 + 1;
   endrule
   
   //////////////////////////////////////////////////////////////////
   rule drainOutPortUp if( drainEnable ); 
      let up <- twoXb.getPortUp;
      $display("drain out port Up:  ", fshow(up));
   endrule

   rule drainOutPortDn if( drainEnable ); 
      let dn <- twoXb.getPortDn;
      $display("drain out port Dn:  ", fshow(dn));
   endrule
   
   ///////////////////////////////////////////////////////////////////
   // BELOW WRITTEN TEST FOR FULL-CORSSBAR MODULE

   /**
    * create address vector v of these values: nodeId={0,1,6} 
    * each time put v[i] to port i and verify that every time
    * we get the correct same data in each output port
    * */
   Vector#(3, Reg#(Address_t#(NofNodes_t))) destAddr 
	   <- replicateM(mkRegU());

   Vector#(3, Reg#(int)) data <- replicateM(mkReg(fromInteger(0)));
   
   rule initRegisters if (cycle == 1);
      destAddr[0] <= fromInteger(0);
      destAddr[1] <= fromInteger(1);
      destAddr[2] <= fromInteger(2);
      data[0] <= 'd000;
      data[1] <= 'd100;
      data[2] <= 'd200;
   endrule
   
   rule routeToDistinctPorts if (cycle >= 40 && cycle < 50 );
      $display("putPort0: addr ", destAddr[0], ", data", data[0]);
      $display("putPort1: addr ", destAddr[1], ", data", data[1]);
      $display("putPort2: addr ", destAddr[2], ", data", data[2]);
      //put the vector elements ot all ports in fxb
      fxb.putPort0(destAddr[0], data[0]);
      fxb.putPort1(destAddr[1], data[1]);
      fxb.putPort2(destAddr[2], data[2]);
      //rotate vectors down
      destAddr[0] <= destAddr[1];
      destAddr[1] <= destAddr[2];
      destAddr[2] <= destAddr[0];
      data[0]     <= data[1] + 1;
      data[1]     <= data[2] + 1;
      data[2]     <= data[0] + 1;
   endrule
   
   // drain the ouput ports of fxb module ////////////////////////////
   rule drainFxbOutputUp;
      $display("OutputUp  : ", fxb.getPortUp);
   endrule
   
   rule drainFxbOutputDn;
      $display("OutputDn  : ", fxb.getPortDn);
   endrule
   
   rule drainFxbOutputSelf;
      $display("OutputSelf: ", fxb.getPortSelf);
   endrule
   
endmodule

