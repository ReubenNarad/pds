/*********************************************
 * OPL 22.1.1.0 Model
 * Author: User10
 * Creation Date: Oct 2, 2023 at 2:19:14 PM
 *********************************************/
 
//Modify CPLEX Parameters
execute PARAMS
{

cplex.nodefileind = 3; //saves nodes in files instead of working memory
cplex.workmem = 55296; //restrict working memory to 50 mb
cplex.preind = 1; 
cplex.epgap = 0.0115; // Optimality gap = 1.15%
cplex.threads = 16;

}


//DEFINE SETS 


//Define set of districts
range locations = 1..46; // Changed from 625

//Define set of states
{string} states = ...;

execute {
  writeln("Including states:")
  writeln(states);
}

//Define set of crops 
{string} crops = ...;


//DEFINE PARAMETERS 

/*Keep code as is if varying parameters and running �main.mod� else, 
specify the values of fp, tcf, tc_road, tc_rail, flow_cap before running the code. */

//MSP for each food crop
float mspg[crops] = ...;

//Fixed cost of operating a procurement center
int ff = 0;

//Operational cost of procurement for each food crop
float F[crops] = ...;

//Govt. Disposable quantity of each crop in each district 
float PC[locations][crops] = ...;  

// Demand of each crop in each district;
float D[locations][crops] = ...; 

// Road Distance between districts
float tt[locations][locations] = ...; 

//Leakage ratio of a crop in each state
float leakage[states][crops] = ... ;

/* Current (2011-12) PDS consumption in each district for each food crop. 
This would be 0 for coarse crops as coarse crops were not purchased through PDS in 2009-10 */
float curr_PDS_C[locations][crops] = ...;

//Transporation cost to farmers
float tcf = 2.64;

//Road Transporation cost per tonne-km
float tc_road = 2.64; 

//Road Transporation cost per tonne-km
float tc_rail = 1.32; 

//Flow capacity of a storage unit (tonnes per month)
float flow_cap = 3911.00;

//Fixed cost of storage 
float fp = 468816.00; 

//Variable cost of storage (Operational Cost in Rs./tonne/month from HLC Report)
float fv = 377.5; 

//Capacity of a procurement center
int big_M = 100000000; //10^8

// Open market price per unit food crop to consumer;
//float W[locations][crops] = ...; 

//This are for different senarios and UNUSED
// ############## ??? ######################

//Lower limit for procurement of each food crop in each state according to current(2009-10) procurement quantities
//float Act_Proc[states][crops] = ...;

//Quantity of food crops coming into states as per 2011-2012 movement data   
//float Act_to_state[to_states] = ...;

//Quantity of food crops coming into states as per 2011-2012 movement data
//float Act_from_state[from_states] = ...;

//DECLARE DECISION VARIABLES

//Quantity of a food crop transported between districts going from producing district to procuring district 
dvar float+ Q[locations][locations][crops];

//dvar float+ q1[states][crops][hh] ;

//Quantity of a food crop going from procuring district to stage 1 storing district 
dvar float+ T[locations][locations][crops];

//Quantity of a food crop going from stage 1 storing district to stage 2 storing district 
dvar float+ Tp[locations][locations][crops];

//Quantity of a food crop going from stage 2 storing district to distribution district
dvar float+ S[locations][locations][crops] ;

//PDS consumption/purchase of each crop in each district 
//Name different from the, that is PCi'j 
dvar float+ PDS_consmp[locations][crops];

//Number of storage centers in stage 1 of Storage in each district
dvar int+ Y[locations];

//Number of storage centers in stage 2 of Storage in each district
dvar int+ Yp[locations];

//Dummy variable to capture maximum of number of storage centers operating in Stage 1 & Stage 2, for each district
dvar int+ z[locations];

//binary decision variable for decision to procure a crop in a district
//This is 1-yk, different as compared to appendix 
dvar boolean Z[locations][crops];

//Excess consumption over the PDS purchase for each food crop in each district
//dvar float+ de[locations][crops];

//Building the objective function

//statement 1 broken into 2 parts, msp and f. 
//Expression to capture total purchase cost of procurement over all districts and food crops
dexpr float MSP = (sum (i in locations, proc in locations, j in crops) ( Q[i][proc][j]* mspg[j] ) ) ;

//Expression to capture total operational cost of procurement over all districts and food crops
dexpr float proc_cost = (sum(proc in locations, j in crops) ( (F[j] * ( sum(i in locations) (Q[i][proc][j]) ) + ff*Z[proc][j]) ) ) ;

//Expression to capture total storage cost in stage 1 over all districts and food crops
dexpr float storage_cost1 = (sum ( store in locations) ( (fp *z[store]) +  ( sum( proc in locations, j in crops ) fv * T[proc][store][j] ) ) )   ;

//Expression to capture total storage cost in stage 2 over all districts and food crops
dexpr float storage_cost2 = (sum ( store in locations) ( ( sum( proc in locations, j in crops ) fv * Tp[proc][store][j] ) ) )   ;

//Expression to capture total transportation cost incurred by farmers, who are coming to sell their produce, over all districts and food crops
dexpr float transportation_cost_farmer = (sum (i in locations, proc in locations, j in crops) ( Q[i][proc][j] * tcf * tt[i][proc] ) ) ;

//Expression to capture total transportation cost when transporating crops from procurement center to Stage 1 of storage, over all districts and food crops
dexpr float transportation_cost_stage1 = (sum (proc in locations, store in locations, j in crops) ( T[proc][store][j] * tc_road * tt[proc][store]) ) ;

//Expression to capture total transportation cost when transporating crops from Stage 1 to Stage 2 of storage, over all districts and food crops
dexpr float transportation_cost_stage2 = (sum (proc in locations, store in locations, j in crops) ( Tp[proc][store][j] * tc_rail * tt[proc][store]) ) ;

//Expression to capture total transportation cost when transporating crops from Stage 2 of storage to distribution district, over all districts and food crops
dexpr float transportation_cost_outbound = (sum (store in locations , distri in locations, j in crops) ( S[store][distri][j] * tc_road * tt[store][distri] ) ) ;


//MODEL

//OBJECTIVE FUNCTION 
//Minimize total government's cost
minimize
   
proc_cost + MSP + storage_cost1 + storage_cost2 + transportation_cost_farmer + transportation_cost_stage1 + transportation_cost_stage2 + transportation_cost_outbound //+ Open_mkt_Cost
 
;

//CONSTRAINTS 
subject to {


// Constraint 1
forall ( i in locations, j in crops)  { 

// Quantity sent for procurement from district i of j has to be less than equal to the quantity available for procurement
	ct1: ( sum (proc in locations) Q[i][proc][j] ) <= PC[i][j] ;

//	c42: de[i][j] == D[i][j] - PDS_consmp[i][j] ;	
}

// Constraint 2-4
//FLOW CONSTRAINTS 

// Total quantity procured in a district has to be equal to the quantity gone for storage from that district

forall ( proc in locations, j in crops ) {

	ct45: ( sum ( i in locations) Q[i][proc][j] ) ==  ( sum ( store in locations ) T[proc][store][j] ) ;

}
//Total quantity coming to storage Stage 1 has to be equal to the total quantity going out of storage Stage 1

 forall ( store1 in locations, j in crops) {
  
  	ct107: ( sum ( proc in locations) T[proc][store1][j] ) == ( sum ( store2 in locations) Tp[store1][store2][j] ) ;	 

 }

//Total quantity stored at storage Stage 2 has to be equal to the total quantity distributed from storage Stage 2
 
forall ( store2 in locations, j in crops) {
  
  	ct110: ( sum ( store1 in locations) Tp[store1][store2][j] ) == ( sum ( distri in locations) S[store2][distri][j] ) ;	 

 }
 
// Constraint 5
//Decision for Procurement Centres
forall (proc in locations, j in crops) {
  
	ct2: ( sum ( i in locations) Q[i][proc][j] ) <= big_M * Z[proc][j] ;

}

//Contraint 6
/*If total quantity procured in a state is not equal to 0 then there exists atleast one storage center in that state. 
This constraint is written for each state.
*/
//All the district is of a common state are listed. We can turn on or off, based on this. 
ct179:( !(( sum ( proc in locations, store in (1..14), j in crops ) Q[proc][store][j] ) == 0 ) ) => ( ( sum ( i in (1..14) ) Y[i] ) >= 1 ) ;

ct180:( !((sum ( store in locations, distri in 15..26, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (15..26) ) Y[i] ) >= 1 ) ; 

//ct146:( !((sum ( store in locations, distri in 27..46, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (27..46) ) Y[i] ) >= 1 ) ;   
//
//ct147:( !((sum ( store in locations, distri in 47..47, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (47..47) ) Y[i] ) >= 1 ) ; 
//
//ct148:( !(( sum ( store in locations, distri in 48..62, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (48..62) ) Y[i] ) >= 1 ) ;
//
//ct149:( !(( sum ( store in locations, distri in 63..82, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (63..82) ) Y[i] ) >= 1 ) ; 
//
//ct150:( !(( sum ( store in locations, distri in 83..90, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (83..90) ) Y[i] ) >= 1 ) ; 
//
//ct151:( !(( sum ( store in locations, distri in 91..122, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (91..122) ) Y[i] ) >= 1 ) ;
//
//ct152:( !(( sum ( store in locations, distri in 123..193, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (123..193) ) Y[i] ) >= 1 ) ; 
//
//ct153:( !(( sum ( store in locations, distri in 194..231, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (194..231) ) Y[i] ) >= 1 ) ; 
//
//ct154:( !(( sum ( store in locations, distri in 232..235, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (232..235) ) Y[i] ) >= 1 ) ;
//
//ct155:( !(( sum ( store in locations, distri in 236..251, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (236..251) ) Y[i] ) >= 1 ) ; 
//
//ct156:( !(( sum ( store in locations, distri in 252..262, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (252..262) ) Y[i] ) >= 1 ) ; 
//
//ct157:( !(( sum ( store in locations, distri in 263..271, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (263..271) ) Y[i] ) >= 1 ) ; 
//
//ct158:( !(( sum ( store in locations, distri in 272..279, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (272..279) ) Y[i] ) >= 1 ) ; 
//
//ct159:( !(( sum ( store in locations, distri in 280..283, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (280..283) ) Y[i] ) >= 1 ) ; 
//
//ct160:( !(( sum ( store in locations, distri in 284..290, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (284..290) ) Y[i] ) >= 1 ) ; 
//
//ct162:( !(( sum ( store in locations, distri in 291..317, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (291..317) ) Y[i] ) >= 1 ) ; 
//
//ct163:( !(( sum ( store in locations, distri in 318..336, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (318..336) ) Y[i] ) >= 1 ) ;  
//
//ct164:( !(( sum ( store in locations, distri in 337..358, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (337..358) ) Y[i] ) >= 1 ) ; 
//
//ct165:( !(( sum ( store in locations, distri in 359..388, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (359..388) ) Y[i] ) >= 1 ) ; 
//
//ct167:( !(( sum ( store in locations, distri in 389..406, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (389..406) ) Y[i] ) >= 1 ) ;   
//
//ct168:( !(( sum ( store in locations, distri in 407..456, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (407..456) ) Y[i] ) >= 1 ) ;  
//
//ct169:( !(( sum ( store in locations, distri in 457..481, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (457..481) ) Y[i] ) >= 1 ) ;  
//
//ct170:( !(( sum ( store in locations, distri in 482..483, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (482..483) ) Y[i] ) >= 1 ) ;  
//
//ct171:( !(( sum ( store in locations, distri in 484..484, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (484..484) ) Y[i] ) >= 1 ) ;  
//
//ct172:( !(( sum ( store in locations, distri in 485..518, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (485..518) ) Y[i] ) >= 1 ) ;  
//
//ct173:( !(( sum ( store in locations, distri in 519..541, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (519..541) ) Y[i] ) >= 1 ) ;  
//	
//ct174:( !(( sum ( store in locations, distri in 542..570, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (542..570) ) Y[i] ) >= 1 ) ;  
//
//ct175:( !(( sum ( store in locations, distri in 571..572, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (571..572) ) Y[i] ) >= 1 ) ;  
//
//ct176:( !(( sum ( store in locations, distri in 573..573, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (573..573) ) Y[i] ) >= 1 ) ;  
//
//ct177:( !(( sum ( store in locations, distri in 574..587, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (574..587) ) Y[i] ) >= 1 ) ;  
//	
//ct178:( !(( sum ( store in locations, distri in 588..618, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (588..618) ) Y[i] ) >= 1 ) ;  
//
//ct1780:( !(( sum ( store in locations, distri in 619..622, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (619..622) ) Y[i] ) >= 1 ) ;  
//
//ct1781:( !(( sum ( store in locations, distri in 623..625, j in crops ) Q[store][distri][j] ) == 0 ) ) => ( ( sum ( i in (623..625) ) Y[i] ) >= 1 ) ; 

//Constraint 7&8
// Flow Capacity constraint for storage centres
 
 forall ( store1 in locations )  
 {
  ct108: ( sum ( proc in locations, j in crops) T[proc][store1][j] ) <= Y[store1] * flow_cap ; 
 }	
 
 
 forall (store2 in locations ) 
 {
  ct109: ( sum ( store1 in locations, j in crops) Tp[store1][store2][j] ) <= Yp[store2] * flow_cap ; 
 
 }
 
//Constraint 9&10
//Dummy variable to take max (y[i],yp[i])
 forall ( i in locations )
   {
    ct15: z[i] >= Y[i];
 
 	ct16: z[i] >= Yp[i] ;  
   }

//District and crop wise constraint: Current(2011-12) PDS consumption is a lower bound for PDS purchase determined by the model
/**This constraint is valid when allowing for procurement of ONLY rice and wheat
If allowing for procurement of all crops (coarse crops + rice and wheat )
 change this constraint to: for each district, total PDS purchase (sum over all crops) should not be less than current(2009-10) total PDS consumption (sum over all crops). 
*/
// Constraint 11
//forall ( distri in locations) {
//
//	ct219: ( sum( j in crops ) curr_PDS_C[distri][j] ) <= ( sum( j in crops ) PDS_consmp[distri][j] )  ;
//
//}

//Constraint 12
forall ( distri in locations, j in crops) { 

//PDS Purchase has to be less the consumption of crop j in the district
//	ct217: PDS_consmp[distri][j] <= D[distri][j] ;
	ct217: PDS_consmp[distri][j] >= D[distri][j] ;
	
//	ct218: PDS_consmp[distri][j] <= ( sum (store in locations) S[store][distri][j] ) ; 
}


// Constraint 13
//Incorporating leakage in the PDS Distribution. This constraint is written for each state.

forall ( j in crops ) {

ct143: (sum ( distri in (1..14) ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in (1..14) ) S[store][distri][j] ) * (1 - leakage["Jammu & Kashmir"][j] ) ; 
//
ct144: (sum ( distri in 15..26 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 15..26 ) S[store][distri][j] )* (1 - leakage["Himachal Pradesh"][j] ); 
//
ct145: (sum ( distri in 27..46 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 27..46 ) S[store][distri][j] ) * (1 - leakage["Punjab"][j] );   
//
//ct111: (sum ( distri in 47..47 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 47..47 ) S[store][distri][j] ) * ( 1- leakage ["Chandigarh"][j] ) ; 
//
//ct112: (sum ( distri in 48..62 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 48..62 ) S[store][distri][j] ) * (1- leakage ["Uttaranchal"][j] ) ; 
//
//ct113: (sum ( distri in 63..82 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 63..82 ) S[store][distri][j] ) * (1- leakage ["Hariyana"][j] ) ; 
//
//ct114: (sum ( distri in 83..90 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 83..90 ) S[store][distri][j] ) * (1- leakage ["Delhi"][j]) ; 
//
//ct115: (sum ( distri in 91..122 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 91..122 ) S[store][distri][j] ) * (1- leakage ["Rajasthan"][j] ) ; 
//
//ct116: (sum ( distri in 123..193 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 123..193 ) S[store][distri][j] ) * (1 - leakage ["Uttar Pradesh"][j] ) ; 
//
//ct117: (sum ( distri in 194..231 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 194..231 ) S[store][distri][j] ) * (1 - leakage ["Bihar"][j] ) ; 
//
//ct118: (sum ( distri in 232..235 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 232..235 ) S[store][distri][j] ) * (1 - leakage ["Sikkim"][j] ) ; 

//ct119: (sum ( distri in 236..251 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 236..251 ) S[store][distri][j] ) * (1- leakage ["Arunachal Pradesh"][j] ); 

//ct120: (sum ( distri in 252..262 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 252..262  ) S[store][distri][j] ) * (1 - leakage ["Nagaland"][j] ) ; 
//
//ct121: (sum (distri in 263..271 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 263..271 ) S[store][distri][j] ) * (1 - leakage ["Maniupur"][j] ) ; 
//
//ct122: (sum ( distri in 272..279 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 272..279 ) S[store][distri][j] ) * (1 - leakage ["Mizoram"][j] ) ; 
//
//ct123: (sum ( distri in 280..283 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 280..283 ) S[store][distri][j] ) * (1 - leakage ["Tripura"][j] ); 
//
//ct124: (sum ( distri in 284..290 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 284..290 ) S[store][distri][j] ) * (1 - leakage ["Meghalaya"][j] ); 
//
//ct125: (sum ( distri in 291..317 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 291..317 ) S[store][distri][j] ) * ( 1 - leakage ["Assam"][j]) ;  
//
//ct126: (sum ( distri in 318..336 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 318..336 ) S[store][distri][j] ) * ( 1- leakage ["West Bengal"][j] ); 
//
//ct127: (sum ( distri in 337..358 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 337..358 ) S[store][distri][j] ) * ( 1 - leakage ["Jharkhand"][j] ) ;
//
//ct128: (sum ( distri in 359..388 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 359..388 ) S[store][distri][j] ) * ( 1- leakage ["Orissa"][j] ) ; 
//
//ct129: (sum ( distri in 389..406 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 389..406 ) S[store][distri][j] ) * ( 1 - leakage ["Chattisgarh"][j] ) ; 
//
//ct130: (sum ( distri in 407..456 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 407..456 ) S[store][distri][j] ) *  ( 1 - leakage ["Madhya Pradesh"][j] ) ;  
//
//ct131: (sum ( distri in 457..481 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 457..481 ) S[store][distri][j] ) * ( 1- leakage ["Gujarat"][j] ) ; 
//
//ct132: (sum ( distri in 482..483 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 482..483 ) S[store][distri][j] ) * ( 1 - leakage ["Daman & Diu"][j] );
//
//ct133: (sum ( distri in 484..484 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 484..484 ) S[store][distri][j] ) * ( 1- leakage ["D & N Haveli"][j]) ;  
//
//ct134: (sum ( distri in 485..518 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 485..518 ) S[store][distri][j] ) * ( 1 - leakage ["Maharashtra"][j] ) ; 
//
//ct135: (sum ( distri in 519..541 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 519..541 ) S[store][distri][j] ) *  ( 1 - leakage ["Andhra Pradesh"][j] ) ;  
//
//ct136: (sum ( distri in 542..570 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 542..570 ) S[store][distri][j] ) *  ( 1 - leakage ["Karnataka"][j] ) ;
//
//ct137: (sum ( distri in 571..572 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 571..572 ) S[store][distri][j] ) * ( 1- leakage ["Goa"][j] ) ;  
//	
//ct139: (sum ( distri in 573..573 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 573..573 ) S[store][distri][j] ) * ( 1-  leakage ["Lakshadeep"][j] ) ; 
//
//ct140: (sum ( distri in 574..587 ) PDS_consmp[distri][j] )  <= (sum ( store in locations, distri in 574..587 ) S[store][distri][j] ) * ( 1 - leakage ["Kerala"][j] ) ; 
//
//ct141: (sum ( distri in 588..618 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 588..618 ) S[store][distri][j] ) * (1 - leakage ["Tamil Nadu"][j] ) ; 
//	
//ct142: (sum ( distri in 619..622 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 619..622 ) S[store][distri][j] ) * (1 - leakage ["Puducherry"][j] ) ;

//ct1420:(sum ( distri in 623..625 ) PDS_consmp[distri][j] ) <= (sum ( store in locations, distri in 623..625 ) S[store][distri][j] ) * (1 - leakage ["A & N Island"][j] ) ; 

}

/*
//IMPOSING MOVEMENT & PROCUREMENT PATTERN. Comment out these constraints when allowing for procurement of ALL cropS.
 
//IMPOSING MOVEMENT 

// Reported quantity going from states is a lower bound to model-determined quantity leaving states
// This is the data from FCI which tells from which state the surplus crops are mmving from and going to which state, to replicate the current PDS supply chain. 


ct401: (sum ( proc in (asSet(locations) diff asSet(27..46)), distri in 27..46, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Punjab"] ;  

ct402: (sum ( proc in (asSet(locations) diff asSet(63..82)), distri in 63..82, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Hariyana"] ; 

ct403: (sum ( proc in (asSet(locations) diff asSet(48..62)), distri in 48..62, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Uttaranchal"] ; 
	
ct404: (sum ( proc in (asSet(locations) diff asSet(123..193)), distri in 123..193, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Uttar Pradesh"] ; 

ct405: (sum ( proc in (asSet(locations) diff asSet(194..231)), distri in 194..231, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Bihar"] ; 

ct406: (sum ( proc in (asSet(locations) diff asSet(318..336)), distri in 318..336, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["West Bengal"] ; 

ct407: (sum ( proc in (asSet(locations) diff asSet(485..518)), distri in 485..518, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Maharashtra"] ; 

ct408: (sum ( proc in (asSet(locations) diff asSet(359..388)), distri in 359..388, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Orissa"] ; 

ct409: (sum ( proc in (asSet(locations) diff asSet(389..406)), distri in 389..406, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Chattisgarh"] ; 
	
ct410: (sum ( proc in (asSet(locations) diff asSet(407..456)), distri in 407..456, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Madhya Pradesh"] ; 

ct411: (sum ( proc in (asSet(locations) diff asSet(519..541)), distri in 519..541, j in crops) Tp[distri][proc][j] ) >= Act_from_state ["Andhra Pradesh"] ; 



// Reported quantity coming to states is a lower bound to model-determined quantity coming in states
// Constraint 27

ct412: (sum ( proc in (asSet(locations) diff asSet(1..14)) , distri in (1..14) , j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Jammu & Kashmir"] ; 

ct413: (sum ( proc in (asSet(locations) diff asSet(15..26)) , distri in 15..26, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Himachal Pradesh"] ; 

ct414: (sum ( proc in (asSet(locations) diff asSet(48..62)), distri in 48..62, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Uttaranchal"] ; 

ct415: (sum ( proc in (asSet(locations) diff asSet(83..90)), distri in 83..90, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Delhi"] ; 
	
ct416: (sum ( proc in (asSet(locations) diff asSet(123..193)), distri in 123..193, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Uttar Pradesh"] ; 

ct417: (sum ( proc in (asSet(locations) diff asSet(194..231)), distri in 194..231, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Bihar"] ; 

ct418: (sum ( proc in (asSet(locations) diff asSet(232..317)), distri in (232..317), j in crops) Tp[proc][distri][j] ) >= Act_to_state ["N.E.Zone"] ; // 8 states

ct419: (sum ( proc in (asSet(locations) diff asSet(318..336)), distri in 318..336, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["West Bengal"] ; 

ct420: (sum ( proc in (asSet(locations) diff asSet(91..122)), distri in 91..122, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Rajasthan"] ; 

ct421: (sum ( proc in (asSet(locations) diff asSet(457..484)), distri in 457..484, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Gujarat"] ;  //Gujarat/D&D/D&N

ct422: (sum ( proc in (asSet(locations) diff asSet(485..518)), distri in (asSet (485..518) union asSet (571..572)), j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Maharashtra"] ; //Maharashtra/Goa 

ct423: (sum ( proc in (asSet(locations) diff asSet(542..570)), distri in 542..570, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Karnataka"] ;  

ct424: (sum ( proc in (asSet(locations) diff asSet(573..587)), distri in 573..587, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Kerala"] ; //Kerala/Lakshwadweep

ct425: (sum ( proc in (asSet(locations) diff asSet(337..358)), distri in 337..358, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Jharkhand"] ; 

ct426: (sum ( proc in (asSet(locations) diff asSet(359..388)), distri in 359..388, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Orissa"] ; 

ct427: (sum ( proc in (asSet(locations) diff asSet(389..406)), distri in 389..406, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Chattisgarh"] ; 
	
ct428: (sum ( proc in (asSet(locations) diff asSet(407..456)), distri in 407..456, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Madhya Pradesh"] ; 

ct429: (sum ( proc in (asSet(locations) diff asSet(519..541)), distri in 519..541, j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Andhra Pradesh"] ; 

ct430: (sum ( proc in (asSet(locations) diff asSet(588..625)), distri in (588..625) , j in crops) Tp[proc][distri][j] ) >= Act_to_state ["Tamil Nadu"] ; //TN/Pondi/A&N 
*/


//IMPOSING CURRENT (2009-10) PROCUREMENT
// Constraint 24

/*
forall ( j in {"rice","wheat"} ) { 

ct302: (sum ( store in locations, distri in (1..14) ) Q[store][distri][j] ) >=  Act_Proc ["Jammu & Kashmir"][j]  ;

ct304: (sum ( store in locations, distri in 15..26 ) Q[store][distri][j] ) >=  Act_Proc ["Himachal Pradesh"][j] ;

ct306: (sum ( store in locations, distri in 27..46 ) Q[store][distri][j] ) >=  Act_Proc ["Punjab"][j] ;

ct308: (sum ( store in locations, distri in 47..47 ) Q[store][distri][j] ) >=  Act_Proc ["Chandigarh"][j]  ;

ct310: (sum ( store in locations, distri in 63..82 ) Q[store][distri][j] ) >=  Act_Proc ["Hariyana"][j]  ; 

ct312: (sum ( store in locations, distri in 48..62 ) Q[store][distri][j] ) >=  Act_Proc ["Uttaranchal"][j]  ; 

ct314: (sum ( store in locations, distri in 83..90 ) Q[store][distri][j] ) >=  Act_Proc ["Delhi"][j]  ; 

ct316: (sum ( store in locations, distri in 123..193 ) Q[store][distri][j] ) >=  Act_Proc ["Uttar Pradesh"][j]  ; 

ct318: (sum ( store in locations, distri in 194..231 ) Q[store][distri][j] ) >=  Act_Proc ["Bihar"][j]  ; 

ct320: (sum ( store in locations, distri in 232..235 ) Q[store][distri][j] ) >=  Act_Proc ["Sikkim"][j]  ; 

ct322: (sum ( store in locations, distri in 236..251 ) Q[store][distri][j] ) >=  Act_Proc ["Arunachal Pradesh"][j]  ; 

ct324: (sum ( store in locations, distri in 252..262 ) Q[store][distri][j] ) >=  Act_Proc ["Nagaland"][j] ; 

ct326: (sum ( store in locations, distri in 263..271 ) Q[store][distri][j] ) >=  Act_Proc ["Maniupur"][j]  ; 

ct328: (sum ( store in locations, distri in 272..279 ) Q[store][distri][j] ) >=  Act_Proc ["Mizoram"][j]  ; 

ct330: (sum ( store in locations, distri in 280..283 ) Q[store][distri][j] ) >=  Act_Proc ["Tripura"][j]  ; 

ct332: (sum ( store in locations, distri in 284..290 ) Q[store][distri][j] ) >=  Act_Proc ["Meghalaya"][j] ; 

ct334: (sum ( store in locations, distri in 291..317 ) Q[store][distri][j] ) >=  Act_Proc ["Assam"][j] ; 

ct336: (sum ( store in locations, distri in 318..336 ) Q[store][distri][j] ) >=  Act_Proc ["West Bengal"][j]  ; 

ct338: (sum ( store in locations, distri in 91..122 ) Q[store][distri][j] ) >=  Act_Proc ["Rajasthan"][j]  ; 

ct340: (sum ( store in locations, distri in 457..481 ) Q[store][distri][j] ) >=  Act_Proc ["Gujarat"][j] ; 

ct342: (sum ( store in locations, distri in 482..483 ) Q[store][distri][j] ) >=  Act_Proc ["Daman & Diu"][j]  ; 

ct344: (sum ( store in locations, distri in 484..484 ) Q[store][distri][j] ) >=  Act_Proc ["D & N Haveli"][j]  ; 

ct346: (sum ( store in locations, distri in 485..518 ) Q[store][distri][j] ) >=  Act_Proc ["Maharashtra"][j]  ; 

ct239: (sum ( store in locations, distri in 542..570 ) Q[store][distri][j] ) >=  Act_Proc ["Karnataka"][j]  ; 

ct240: (sum ( store in locations, distri in 571..572 ) Q[store][distri][j] ) >=  Act_Proc ["Goa"][j]  ; 

ct241: (sum ( store in locations, distri in 573..573 ) Q[store][distri][j] ) >=  Act_Proc ["Lakshadeep"][j]  ; 

ct242: (sum ( store in locations, distri in 574..587 ) Q[store][distri][j] ) >=  Act_Proc ["Kerala"][j]  ; 

ct243: (sum ( store in locations, distri in 337..358 ) Q[store][distri][j] ) >=  Act_Proc ["Jharkhand"][j]  ; 

ct244: (sum ( store in locations, distri in 359..388 ) Q[store][distri][j] ) >=  Act_Proc ["Orissa"][j]  ; 

ct245: (sum ( store in locations, distri in 389..406 ) Q[store][distri][j] ) >=  Act_Proc ["Chattisgarh"][j]  ; 

ct246: (sum ( store in locations, distri in 407..456 ) Q[store][distri][j] ) >=  Act_Proc ["Madhya Pradesh"][j]  ; 

ct247: (sum ( store in locations, distri in 519..541 ) Q[store][distri][j] ) >=  Act_Proc ["Andhra Pradesh"][j]  ; 

ct248: (sum ( store in locations, distri in 588..618 ) Q[store][distri][j] ) >=  Act_Proc ["Tamil Nadu"][j]  ; 

ct249: (sum ( store in locations, distri in 619..622 ) Q[store][distri][j] ) >=  Act_Proc ["Puducherry"][j]  ; 

ct250: (sum ( store in locations, distri in 623..625 ) Q[store][distri][j] ) >=  Act_Proc ["A & N Island"][j]  ; 
} 
*/

// Interstate constraints - 18, 19

ct1001: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 1 && store <= 14) && (distri >= 15)) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1002: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 15 && store <= 26) && ((distri <= 14) || (distri >= 27))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1003: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 27 && store <= 46) && ((distri <= 26) || (distri >= 47))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1004: forall (store in locations, distri in locations, j in crops) {
		    if ((store == 47) && ((distri <= 46) || (distri >= 48))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1005: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 48 && store <= 62) && ((distri <= 47) || (distri >= 63))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1006: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 63 && store <= 82) && ((distri <= 62) || (distri >= 83))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

CT1007: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 83 && store <= 90) && ((distri <= 82) || (distri >= 91))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1008: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 91 && store <= 122) && ((distri <= 90) || (distri >= 123))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1009: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 123 && store <= 193) && ((distri <= 122) || (distri >= 194))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1010: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 194 && store <= 231) && ((distri <= 193) || (distri >= 232))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1011: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 232 && store <= 235) && ((distri <= 231) || (distri >= 236))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1012: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 236 && store <= 251) && ((distri <= 235) || (distri >= 252))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1013: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 252 && store <= 262) && ((distri <= 251) || (distri >= 263))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1014: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 263 && store <= 271) && ((distri <= 262) || (distri >= 272))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1015: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 272 && store <= 279) && ((distri <= 271) || (distri >= 280))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1016: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 280 && store <= 283) && ((distri <= 279) || (distri >= 284))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1017: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 284 && store <= 290) && ((distri <= 283) || (distri >= 291))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1018: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 291 && store <= 317) && ((distri <= 290) || (distri >= 318))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1019: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 318 && store <= 336) && ((distri <= 317) || (distri >= 337))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1020: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 337 && store <= 358) && ((distri <= 336) || (distri >= 359))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1021: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 359 && store <= 388) && ((distri <= 358) || (distri >= 389))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1022: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 389 && store <= 406) && ((distri <= 388) || (distri >= 407))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1023: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 407 && store <= 456) && ((distri <= 406) || (distri >= 457))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1024: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 457 && store <= 481) && ((distri <= 456) || (distri >= 482))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1025: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 482 && store <= 483) && ((distri <= 481) || (distri >= 484))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1026: forall (store in locations, distri in locations, j in crops) {
		    if ((store == 484) && ((distri <= 483) || (distri >= 485))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1027: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 485 && store <= 518) && ((distri <= 484) || (distri >= 519))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1028: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 519 && store <= 541) && ((distri <= 518) || (distri >= 542))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1029: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 542 && store <= 570) && ((distri <= 541) || (distri >= 571))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1030: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 571 && store <= 572) && ((distri <= 570) || (distri >= 573))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1031: forall (store in locations, distri in locations, j in crops) {
		    if ((store == 573) && ((distri <= 572) || (distri >= 574))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1032: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 574 && store <= 587) && ((distri <= 573) || (distri >= 588))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1033: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 588 && store <= 618) && ((distri <= 587) || (distri >= 619))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1034: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 619 && store <= 622) && ((distri <= 618) || (distri >= 623))) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

ct1035: forall (store in locations, distri in locations, j in crops) {
		    if ((store >= 623) && (distri <= 622)) {
		        Q[store][distri][j] == 0;
		        T[store][distri][j] == 0;
		        Tp[store][distri][j] == 0;
		        S[store][distri][j] == 0;
		    }
		}

} //END OF CONSTRAINTS



//WRITING RESULTS 

/*RESULTS ARE WRITTEN IN A .txt file
Open file destination where you want to write/save the results. Write results in the file. 
Close file.
*/


execute {


//WRITING COST 

	var ofile = new IloOplOutputFile("Optimal Cost_Interstate.txt");
	
	ofile.writeln("Optimal objective value="+cplex.getObjValue());
	ofile.writeln("Optimal_proc_cost = " + proc_cost.solutionValue );
	ofile.writeln("Optimal_storage_cost1 = " + storage_cost1.solutionValue );
	ofile.writeln("Optimal_storage_cost2 = " + storage_cost2.solutionValue );
	ofile.writeln("Optimal_transportation_cost_farmer = " + transportation_cost_farmer.solutionValue );
	ofile.writeln("Optimal_transportation_cost_stage1 = " + transportation_cost_stage1.solutionValue );
	ofile.writeln("Optimal_transportation_cost_stage2 = " + transportation_cost_stage2.solutionValue );
	ofile.writeln("Optimal_transportation_cost_outbound = " + transportation_cost_outbound.solutionValue );
	ofile.writeln("Optimal_MSP_cost = " + MSP.solutionValue );
//	ofile.writeln("Optimal_Open_Mkt_Cost = " + Open_mkt_Cost.solutionValue );
	ofile.close();
 
 //WRITING values of decision variable Q
 
  var ofile1 = new IloOplOutputFile("Q_Interstate.txt");  
  
  for(var i in locations)
  	 for(var j in locations)
  	 	 for(var k in crops) {
  	 	 
  	 	 ofile1.writeln("Q["+i+"]["+j+"]["+k+"]= "+Q[i][j][k].solutionValue);
  	 	  	 
  	 	  	 }
  	 	  	 
 ofile1.close(); 
  	 	  	 
//WRITING values of total number of storage centers in a district 
 
var ofile2 = new IloOplOutputFile("Z_Interstate.txt");  
 
   
   for(i in locations)
  			{
  	 	 
  	 	 ofile2.writeln("Z["+i+"]= "+z[i].solutionValue);
  	
  	 	   	 } 	 
  	 	   	 
  ofile2.close(); 
  	 	   	 
//WRITING values of decision variable T
  var ofile3 = new IloOplOutputFile("T_Interstate.txt");  	  	 
  	 	  	 
  for(i in locations)
  	 for(j in locations)
  	 	 for(k in crops) {
  	 	 
  	 	 ofile3.writeln("T["+i+"]["+j+"]["+k+"]= "+T[i][j][k].solutionValue);
  	 	  	 
  	 	  	 }	
  	 	  	 
  ofile3.close();  
  
//WRITING values of decision variable Tp

  var ofile4 = new IloOplOutputFile("Tp_Interstate.txt");  
  
  for(i in locations)
  	 for(j in locations)
  	 	 for(k in crops) {
  	 	 
  	 	 ofile4.writeln("Tp["+i+"]["+j+"]["+k+"]= "+Tp[i][j][k].solutionValue);
  	 	  	 
  	 	  	 }
  	 	  	 
 ofile4.close(); 	
  	 	  	 
 //WRITING values of decision variable S
  var ofile5 = new IloOplOutputFile("S_Interstate.txt");    
  
  for(i in locations)
  	 for(j in locations)
  	 	 for(k in crops) {
  	 	 
  	 	 ofile5.writeln("S["+i+"]["+j+"]["+k+"]="+S[i][j][k].solutionValue);
  	 	  	 
  	 	  	 }
  	 	  	 
  ofile5.close(); 
  
 //WRITING values of decision variable PDS Purchase
 var ofile6 = new IloOplOutputFile("PC_Interstate.txt");    
  
 for(i in locations)
  	 	 for(j in crops) {
  	 	 
  	 	 ofile6.writeln("PDS_C["+i+"]["+j+"]="+PDS_consmp[i][j].solutionValue);
  	 	  	 
  	 	  	 }
  	 	  	 
  ofile6.close(); 

//WRITING values of decision variable de i.e. excess demand 	 
	  	 
// var ofile7 = new IloOplOutputFile("de_Interstate.txt");  
// 
//  	 	  	 
//   for(i in locations) 
//  {
//  	for ( j in crops) {
//     ofile7.writeln("de["+i+"]["+j+"]= "+de[i][j].solutionValue+" ");
//  		}	
//  ofile7.writeln (" "); 	 
//  } 
//  	 	  	 
//ofile7.close(); 
//
}
