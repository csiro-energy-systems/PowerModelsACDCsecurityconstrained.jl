function mpc = case5_acdc()
%case 5 nodes    Power flow data for 5 bus, 2 generator case.
%   Please see 'help caseformat' for details on the case file format.
%
%   case file can be used together with dc case files "case5_stagg_....m"
%
%   Network data from ...
%   G.W. Stagg, A.H. El-Abiad, "Computer methods in power system analysis",
%   McGraw-Hill, 1968.
%
%   MATPOWER case file data provided by Jef Beerten.

%% MATPOWER Case Format : Version 1
%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 100;

%% bus data
%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm      Va	baseKV	zone	Vmax	Vmin
mpc.bus = [
	1       3       0	0	0   0   1       1.06	0	345     1       1.1     0.9;
	2       2       20	10	0   0   1       1       0	345     1       1.1     0.9;
	3       1       45	15	0   0   1       1       0	345     1       1.1     0.9;
	4       1       40	5	0   0   1       1       0	345     1       1.1     0.9;
	5       1       60	10	0   0   1       1       0	345     1       1.1     0.9;
];

%% generator data
%	bus	Pg      Qg	Qmax	Qmin	Vg	mBase       status	Pmax	Pmin	pc1 pc2 qlcmin qlcmax qc2min qc2max ramp_agc ramp_10 ramp_30 ramp_q apf
mpc.gen = [
	1	0       0	500      -500    1.06	100       1       250     10 0 0 0 0 0 0 0 0 0 0 0;
  2	40      0	300      -300    1      100       1       300     10 0 0 0 0 0 0 0 0 0 0 0;
];

%% load limit data
%column_names% 	bus	Pmax	Pmin
mpc.load_limit = [
	1	100      100	
    2	100      100	
    3	75      75
    4	75      75        
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle
%	status angmin angmax
mpc.branch = [
    1   2   0.02    0.06    0.06    100   100   100     0       0       1 -60 60;
    1   3   0.08    0.24    0.05    100   100   100     0       0       1 -60 60;
    2   3   0.06    0.18    0.04    100   100   100     0       0       1 -60 60;
    2   4   0.06    0.18    0.04    100   100   100     0       0       1 -60 60;
    2   5   0.04    0.12    0.03    100   100   100     0       0       1 -60 60;
    3   4   0.01    0.03    0.02    100   100   100     0       0       1 -60 60;
    4   5   0.08    0.24    0.05    100   100   100     0       0       1 -60 60;
];


%% generator fcas trapezium
% service (1=LReg, 2=RReg, 3=L1S, 4=R1S, 5=L6S, 6=R6S, 7=L60S, 8=R60S, 9=L5M, 10=R5M)
%column_names%   gen  service emin    lb  ub  emax  amax
mpc.fcas_gen = [
    1       1   20  100 150 200 75;
    1       2   20  20 200 200 100;
    2       1   20  100 150 200 75;
    2       2   20  20 200 200 75;    
 ];

%% generator fcas cost
%	gen    service n	x1	y1	...	xn	yn
mpc.fcas_cost_gen = [
	1	1	2	0  0  100  5001;
	1	2	2	0  0  100  5000;
	2	1	2	0  0  100  5000;
	2	2	2	0  0  100  5000;    
 ];

%% load fcas trapezium
% service (1=RReg, 2=LReg, 3=L1S, 4=R1S, 5=L6S, 6=R6S, 7=L60S, 8=R60S, 9=L5M, 10=R5M)
%column_names%   load  service emin    lb  ub  emax  amax
mpc.fcas_load = [
    1       1   20  100 150 200 100;
    2       1   20  100 150 200 100;
 ];

%% load fcas cost
%	load    service n	x1	y1	...	xn	yn
mpc.fcas_cost_load = [
	1	1	2	0  0  100  5000;
	2	1	2	0  0  100  5000;
 ];

%% fcas targets
%column_names%   service p
mpc.fcas_target = [
    1   0;
    2   0;
 ];

%% generator cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	1	0	0	10	5.80178826582 3409.77768201 14.3237964633 4639.70192051 22.8458046608 5876.74930659 31.3678128583 7120.91984024 39.8898210558 8372.21352147 48.4118292532 9630.63035026 56.9338374507 10896.1703266 65.4558456482 12168.8334506 73.9778538457 13448.6197221 82.4998620432 14735.5291412;
	1	0	0	10	5.80178826582 3409.77768201 14.3237964633 4639.70192051 22.8458046608 5876.74930659 31.3678128583 7120.91984024 39.8898210558 8372.21352147 48.4118292532 9630.63035026 56.9338374507 10896.1703266 65.4558456482 12168.8334506 73.9778538457 13448.6197221 82.4998620432 20000;
];


%% load cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.loadbid = [
	1	0	0	2	0  10000  300  0;
	1	0	0	2	0  10000  300  0;
	1	0	0	2	0  10000  300  0;
	1	0	0	2	0  10000  300  0;        
];

% adds current ratings to branch matrix
%column_names%	c_rating_a
mpc.branch_currents = [
100;100;100;100;100;100;100;
];
