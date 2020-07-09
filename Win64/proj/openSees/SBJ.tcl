#Korean Fire Tests on CHS
#Experimental Study on Limiting Temperatures of Circular Hollow Sections

# Units mm, N/mm�
#		o-------------------------------------------------------o <---
#		1		2		3		4	5	6		7		8		9
#					y
#					|
#					|	
#					|_________	x
#				   /
#				  /
#				 /z
set ANALYSIS "HasLoad";
set TANALYSIS "Has0Thermo"; 

wipe;
file mkdir WrapperData;
model BasicBuilder -ndm 2 -ndf 3;
source DisplayPlane.tcl;		# procedure for displaying a plane in model
source DisplayModel2D.tcl;		# procedure for displaying 2D perspective of model

#define node
set NumEles 2;
set BeamLen 3.0;
set Colen $BeamLen;
set EleLen [expr $BeamLen/$NumEles]

for {set NodeID 0} {$NodeID <= $NumEles} {incr NodeID} {
set locX [expr $NodeID*$EleLen];
set NodeTag [expr $NodeID+1];
node $NodeTag $locX $Colen;

set locY [expr $NodeID*$EleLen];
set NodeTag [expr $NodeID+1001];
node $NodeTag 0 $locY;
}



#node 1000 0 0;

set EndNodeTag [expr $NumEles+1];
set MidNodeTag [expr $NumEles/2+1];
#define boundary condition;
puts "Now uniform load";
fix 1001 1 1 1;
fix $EndNodeTag 1 1 1;


#define an elastic material with Tag=1 and E=2e11.
uniaxialMaterial ElasticThermal 1 2e8 1.2e-5 -sSoft;
uniaxialMaterial ElasticThermal 2 2e18 1.2e-5 -sSoft;
uniaxialMaterial ElasticThermal 3 2e5 1.2e-5 -sSoft;
uniaxialMaterial JointEPThermal 4 2e5 1.0e-2 ;
#uniaxialMaterial SteelECThermal 1 EC3 3e8 2e11;
#uniaxialMaterial Steel01Thermal 1 3e8 2e11 0.00001;
#define fibred section; Two fibres: fiber $yLoc $zLoc $A $matTag 

set ColJointTag [expr $NumEles+1001];
#set BeamJointTag [expr $NumEles+101];
element beamColumnJointThermal 100 $ColJointTag 1 2 2 3 -limit -1 -1 0.5;

set NumFibers 16;
set b 0.2;
set d 0.05;
set secTag 1;
set NumInts 5;
section fiberSecThermal $secTag {
	for {set fiberID 1} {$fiberID<=$NumFibers} {incr fiberID} {
		set fiberLocy [expr ($d/$NumFibers)*($fiberID-0.5)-$d/2];
		set fiberArea [expr ($d/$NumFibers)*$b*0.5];
		fiber $fiberLocy -0.05 $fiberArea 1;
		fiber $fiberLocy 0.05 $fiberArea 1;
		#puts "$fiberLocy, $fiberArea";
		}
	}


#define coordinate transforamtion: geomTransf $type $TransfTag;
#three transformation types can be chosen: Linear, PDelta, Corotational)
#geomTransf Linear 1;
geomTransf Corotational 1 ; 
#geomTransf PDelta 1 ;

#define beam element: dispBeamColumnThermal $eleTag $iNode $jNode $numIntgrPts $secTag $TransfTag;
#"numIntgrPts" is the number of integration points along the element;
#"TransfTag" is pre-defined coordinate-transformation;
for {set eleID 1} {$eleID<= $NumEles} {incr eleID} {
	#set BeamEleId [expr $eleID];
	set NodeTag0 $eleID;
	set NodeTag1 [expr $eleID+1];
	#element dispBeamColumnThermal $eleID $NodeTag0 $NodeTag1 $NumInts 1 1;
	element dispBeamColumnThermal $eleID $NodeTag0 $NodeTag1 $NumInts 1 1;
	
	set ColEleId [expr $eleID+1000];
	set NodeTag0 [expr $eleID+1000];
	set NodeTag1 [expr $eleID+1001];
	#element dispBeamColumnThermal $eleID $NodeTag0 $NodeTag1 $NumInts 1 1;
	element dispBeamColumnThermal $ColEleId $NodeTag0 $NodeTag1 $NumInts 1 1;
}

#define output

set MidSpanEle [expr $NumEles/2];
set FiberLocBot [expr ($d/$NumFibers)/2-($d/2)];
set FiberLocTop [expr ($d/$NumFibers)*($NumFibers-0.5)-$d/2];
puts "$FiberLocBot , $FiberLocTop";


#display 2D deformation shape
set ViewScale 0.1;	# scaling factor for viewing deformed shape, it depends on the dimensions of the model
DisplayModel2D DeformedShape $ViewScale;

recorder Node -file JointData/Node1_DOF.out -time -node 1 -dof 1 2 3 disp;
recorder Node -file JointData/NodeMid_DOF.out -time -node $MidNodeTag -dof 1 2 3 disp;
recorder Element -file JointData/Element1GF.out -time -ele 1  globalForce;
recorder Element -file JointData/Joint100D.out -time -ele 100 deform;
recorder Element -file JointData/Joint100F.out -time -ele 100 forces;

if {$ANALYSIS == "HasLoad"} {
#define Uniform load
puts "Now applying uniform load";

pattern Plain 1 Linear {

   load	$MidNodeTag  0  -10000 0;
   #eleLoad -range 1 $NumEles -type -beamUniform -10000 0

};


constraints Plain;
numberer Plain;
system BandGeneral;
test NormDispIncr 1e-5 10 2 ;
algorithm Newton;
integrator LoadControl 0.001;
analysis Static;
analyze 1000;
loadConst -time 0.0
}

if {$TANALYSIS == "HasThermo"} {

puts "Thermal action"
# Define Thermal Load
set minusHalfD [expr -$d/2]
set HalfD [expr $d/2]

pattern Plain 2 Linear {
#Here we define nodal thermal action
load 1 -nodalThermal 800 $minusHalfD 400 $HalfD;

load $MidNodeTag -nodalThermal 200 $minusHalfD 100 $HalfD

load $EndNodeTag -nodalThermal 0 $minusHalfD 0 $HalfD

#Here we offer different approaches to appliy the thermal action to element, 1: elemental thermal action, 2:using end nodal thermal action(each node), 3: using thermal action wrapper

#load $EndNodeTag -nodalThermal 800 $minusHalfD 400 $HalfD

#eleLoad -range 1 $NumEles -type -beamThermal -source -node

#eleLoad -range 1 $NumEles -type -ThermalWrapper -nodeLoc 1 0 $EndNodeTag 1; 
#eleLoad -range 1 $NumEles -type -beamThermal 800 -$HalfD 400 $HalfD

}


constraints Plain;
numberer Plain;
system BandGeneral;
test NormDispIncr 1.0e-3 100 1;
algorithm Newton;
integrator LoadControl 0.01;
analysis Static;
analyze 100;

}
wipe
