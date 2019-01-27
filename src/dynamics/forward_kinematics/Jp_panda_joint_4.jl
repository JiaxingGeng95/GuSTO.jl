export Jp_panda_joint_4
function Jp_panda_joint_4(x)
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

A0 = zeros(3, 14)
  t2 = x3*1.547322079806372E-12;
  t3 = x3*2.397658246531322E-23;
  t4 = t3+1.0;
  t5 = x4*(7.9E1/2.5E2);
  t6 = x3*x5*(3.3E1/4.0E2);
  t7 = t5+t6-x4*x6*4.039685809621067E-13;
  A0[0+1,1+0] = t7;
  A0[0+1,1+1] = t2-t4*x6*(3.3E1/4.0E2)-x4*x5*4.039685809621067E-13;
  A0[0+1,1+2] = x2*1.547322079806372E-12+x1*x5*(3.3E1/4.0E2)-x2*x6*1.978068053388341E-24;
  A0[0+1,1+3] = x1*(7.9E1/2.5E2)-x1*x6*4.039685809621067E-13-x2*x5*4.039685809621067E-13;
  A0[0+1,1+4] = x1*x3*(3.3E1/4.0E2)-x2*x4*4.039685809621067E-13;
  A0[0+1,1+5] = x2*(-3.3E1/4.0E2)-x1*x4*4.039685809621067E-13-x2*x3*1.978068053388341E-24;
  A0[1+1,1+0] = -t2+t4*x6*(3.3E1/4.0E2)+x4*x5*4.039685809621067E-13;
  A0[1+1,1+1] = t7;
  A0[1+1,1+2] = x1*(-1.547322079806372E-12)+x1*x6*1.978068053388341E-24+x2*x5*(3.3E1/4.0E2);
  A0[1+1,1+3] = x2*(7.9E1/2.5E2)+x1*x5*4.039685809621067E-13-x2*x6*4.039685809621067E-13;
  A0[1+1,1+4] = x1*x4*4.039685809621067E-13+x2*x3*(3.3E1/4.0E2);
  A0[1+1,1+5] = x1*(3.3E1/4.0E2)+x1*x3*1.978068053388341E-24-x2*x4*4.039685809621067E-13;
  A0[2+1,1+2] = x6*(-4.039685809621067E-13)+7.9E1/2.5E2;
  A0[2+1,1+3] = x5*(-3.3E1/4.0E2);
  A0[2+1,1+4] = x4*(-3.3E1/4.0E2);
  A0[2+1,1+5] = x3*(-4.039685809621067E-13)+4.039685809621067E-13;


	return A0
end
