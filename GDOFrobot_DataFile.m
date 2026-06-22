% Simscape(TM) Multibody(TM) version: 26.1%%%%% Do not add code to this file. Do not edit the physical units shown in comments.

%%%VariableName:smiData

%============= RigidTransform%
%Initialize the RigidTransform structure array by filling in null values.
smiData.RigidTransform(7).translation = [0.0 0.0 0.0];
smiData.RigidTransform(7).angle = 0.0;
smiData.RigidTransform(7).axis = [0.0 0.0 0.0];
smiData.RigidTransform(7).ID = "";

%%Rotation Method - Arbitrary Axis
smiData.RigidTransform(1).translation = [143.7031038027925 238.74387820902288 208.34589117172845];  % mm
smiData.RigidTransform(1).angle = 2.0943951023931953;  % rad
smiData.RigidTransform(1).axis = [0.57735026918962584 0.57735026918962584 0.57735026918962584];
smiData.RigidTransform(1).ID = "B[Link1-1:-:Link2-1]";

%%Rotation Method - Arbitrary Axis
smiData.RigidTransform(2).translation = [-143.70310380279301 -1.7177370637000422e-12 4.1211478674085811e-13];  % mm
smiData.RigidTransform(2).angle = 2.0943951023931962;  % rad
smiData.RigidTransform(2).axis = [-0.57735026918962573 -0.57735026918962595 0.57735026918962551];
smiData.RigidTransform(2).ID = "F[Link1-1:-:Link2-1]";

%%Rotation Method - Arbitrary Axis
smiData.RigidTransform(3).translation = [-12.662797421533673 316.51179972819165 186.18791013630974];  % mm
smiData.RigidTransform(3).angle = 3.1415926535897931;  % rad
smiData.RigidTransform(3).axis = [1 0 0];
smiData.RigidTransform(3).ID = "B[base_joint-1:-:Link1-1]";

%%Rotation Method - Arbitrary Axis
smiData.RigidTransform(4).translation = [-186.18791013630957 2.5934809855243657e-13 -2.8421709430404007e-14];  % mm
smiData.RigidTransform(4).angle = 2.0943951023931957;  % rad
smiData.RigidTransform(4).axis = [0.57735026918962584 0.57735026918962573 0.57735026918962573];
smiData.RigidTransform(4).ID = "F[base_joint-1:-:Link1-1]";

%%Rotation Method - Arbitrary Axis
smiData.RigidTransform(5).translation = [0 144.99999999999997 0];  % mm
smiData.RigidTransform(5).angle = 2.0943951023931953;  % rad
smiData.RigidTransform(5).axis = [-0.57735026918962584 -0.57735026918962584 -0.57735026918962584];
smiData.RigidTransform(5).ID = "B[base_joint-1:-:base-2]";

%%Rotation Method - Arbitrary Axis
smiData.RigidTransform(6).translation = [-5.6843418860812054e-14 150.00000000000006 9.3582822835231286e-14];  % mm
smiData.RigidTransform(6).angle = 2.0943951023931953;  % rad
smiData.RigidTransform(6).axis = [-0.57735026918962584 -0.57735026918962584 -0.57735026918962584];
smiData.RigidTransform(6).ID = "F[base_joint-1:-:base-2]";

%%Rotation Method - Arbitrary Axis
smiData.RigidTransform(7).translation = [251.53207115363202 -12.16871441740107 316.85639346018434];  % mm
smiData.RigidTransform(7).angle = 1.5707963267949003;  % rad
smiData.RigidTransform(7).axis = [6.9829626776862415e-15 1 -6.9829626776862415e-15];
smiData.RigidTransform(7).ID = "RootGround[base-2]";

%============= Solid%
%%%Product of Inertia (PoI)
%Initialize the Solid structure array by filling in null values.
smiData.Solid(4).mass = 0.0;
smiData.Solid(4).CoM = [0.0 0.0 0.0];
smiData.Solid(4).MoI = [0.0 0.0 0.0];
smiData.Solid(4).PoI = [0.0 0.0 0.0];
smiData.Solid(4).color = [0.0 0.0 0.0];
smiData.Solid(4).opacity = 0.0;
smiData.Solid(4).ID = "";

%%Visual Properties - Simple
smiData.Solid(1).mass = 1.6377543344446917;  % kg
smiData.Solid(1).CoM = [-4.3177255318030205 239.23586798294019 8.7680101802673734e-07];  % mm
smiData.Solid(1).MoI = [11419.465375806038 6706.2702316731002 9789.2080044510603];  % kg*mm^2
smiData.Solid(1).PoI = [0.00015305785554484532 -0.0097501675221107059 584.44546196938529];  % kg*mm^2
smiData.Solid(1).color = [1 0.4392156862745098 0.058823529411764705];
smiData.Solid(1).opacity = 1;
smiData.Solid(1).ID = "base_joint*:*Default";

%%Visual Properties - Simple
smiData.Solid(2).mass = 2.2751437492444428;  % kg
smiData.Solid(2).CoM = [0.00011633499235594973 -0.14308560781313157 -125.66697696992108];  % mm
smiData.Solid(2).MoI = [25511.520076336616 25390.823981125806 2610.9641197824512];  % kg*mm^2
smiData.Solid(2).PoI = [-30.985158921258655 0.038452669400859361 0.0027962984352898419];  % kg*mm^2
smiData.Solid(2).color = [1 0.45490196078431372 0.027450980392156862];
smiData.Solid(2).opacity = 1;
smiData.Solid(2).ID = "Link2*:*Default";

%%Visual Properties - Simple
smiData.Solid(3).mass = 3.8875246923317497;  % kg
smiData.Solid(3).CoM = [-42.454231071435196 82.366634701648962 -2.0213592204751649e-05];  % mm
smiData.Solid(3).MoI = [12884.794730308815 23057.434999424204 26828.983730976328];  % kg*mm^2
smiData.Solid(3).PoI = [0.0028947784672904674 -0.0028933999535150469 -935.19453701223688];  % kg*mm^2
smiData.Solid(3).color = [1 0.4392156862745098 0.058823529411764705];
smiData.Solid(3).opacity = 1;
smiData.Solid(3).ID = "base*:*Default";

%%Visual Properties - Simple
smiData.Solid(4).mass = 3.2557437752800058;  % kg
smiData.Solid(4).CoM = [-2.3302453123874666e-05 81.937597729103658 51.37103471827303];  % mm
smiData.Solid(4).MoI = [41973.079205788046 17704.401681289495 29793.823938650221];  % kg*mm^2
smiData.Solid(4).PoI = [-16499.03009621927 0.0085346335499154099 0.011671999211057505];  % kg*mm^2
smiData.Solid(4).color = [1 0.47058823529411764 0.058823529411764705];
smiData.Solid(4).opacity = 1;
smiData.Solid(4).ID = "Link1*:*Default";

%============= Joint%
%%%%%%%%%%Position Target (Pos)
%Initialize the RevoluteJoint structure array by filling in null values.
smiData.RevoluteJoint(3).Rz.Pos = 0.0;
smiData.RevoluteJoint(3).ID = "";

smiData.RevoluteJoint(1).Rz.Pos = 23.439153469113286;  % deg
smiData.RevoluteJoint(1).ID = "[Link1-1:-:Link2-1]";

smiData.RevoluteJoint(2).Rz.Pos = -103.90302753292676;  % deg
smiData.RevoluteJoint(2).ID = "[base_joint-1:-:Link1-1]";

smiData.RevoluteJoint(3).Rz.Pos = -153.33981478967132;  % deg
smiData.RevoluteJoint(3).ID = "[base_joint-1:-:base-2]";

