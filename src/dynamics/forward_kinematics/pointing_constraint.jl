export pointing_constraint
function pointing_constraint(x)
	x1  = x[1]
	x2  = x[2]
	x3  = x[3]
	x4  = x[4]
	x5  = x[5]
	x6  = x[6]
	x7  = x[7]
	x8  = x[8]
	x9  = x[9]
	x10 = x[10]
	x11 = x[11]
	x12 = x[12]
	x13 = x[13]
	x14 = x[14]

	A0 = zeros(1)
  t2 = x3*(1.0/2.0);
  t3 = t2-1.0/2.0;
  t4 = x5*2.397658246531322E-23;
  t5 = x4*x6*4.896588860146747E-12;
  t12 = x3*x5*2.397658246531322E-23;
  t6 = t4+t5-t12+x3+2.397658246531322E-23;
  t7 = t6*x7*4.896588860146747E-12;
  t8 = x3*x6*4.896588860146747E-12;
  t9 = x4*x5;
  t13 = x6*4.896588860146747E-12;
  t10 = t8+t9-t13;
  t11 = t10*x8*4.896588860146747E-12;
  t14 = x4*x6;
  t23 = x3*4.896588860146747E-12;
  t24 = t3*x5*9.793177720293495E-12;
  t15 = t7+t11+t14-t23-t24-1.174034666040426E-34;
  t16 = t6*x8;
  t18 = t10*x7;
  t17 = t16-t18;
  t19 = x3*2.397658246531322E-23;
  t20 = t3*x5*4.795316493062645E-23;
  t21 = t6*x7;
  t22 = t10*x8;
  t25 = t15*x10;
  t26 = t17*x9;
  t0 = x14*(t7+t11+x3*1.174034666040426E-34-x12*(t25+t26)*4.896588860146747E-12+t3*x5*2.348069332080851E-34-t15*x9+t17*x10-x4*x6*2.397658246531322E-23+x11*(-t5+t19+t20+t21+t22+t15*x9*4.896588860146747E-12-t17*x10*4.896588860146747E-12+5.748765067159655E-46)*4.896588860146747E-12+2.814933898745474E-57)+x13*(x11*(t25+t26)+x12*(-t5+t19+t20+t21+t22+x9*(t7+t11+t14-t23-t24-1.174034666040426E-34)*4.896588860146747E-12-t17*x10*4.896588860146747E-12+5.748765067159655E-46));


	return A0
end