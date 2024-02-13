/*********************************************
 * OPL 22.1.1.0 Model
 * Author: reube
 * Creation Date: Jan 30, 2024 at 11:14:53 AM
 *********************************************/

{string} districts = { "washington", "oregon" } ;
{string} grains = ... ;
//{string} pulses = { "peas", "dal" } ;
{string} crops = grains;// union pulses;

float available[districts][crops] = [[200, 400, 200, 500, 100, 100, 100, 200], [100, 200, 100, 200, 100, 200, 200, 200]];

int preferences[districts][crops] = [[8, 7, 6, 5, 4, 3, 2, 1], [1, 2, 3, 4, 5, 6, 7, 8]];

float min_grain = 300 ;
float min_pulse = 100 ;

dvar float+ basket[districts][crops];

dexpr float utility  =  ( sum (crop in crops, district in districts) (preferences[district][crop] * basket[district][crop]));

maximize utility ;

subject to {
  
  // Minimum basket content constraints
  forall ( district in districts ) {
    ct1: ( sum ( grain in grains ) basket[district][grain] ) == min_grain;
//    ct2: ( sum ( puls in pulses) basket[district][puls] ) == min_pulse ;
  }
  
  // Baskets do not exceed available
  forall ( crop in crops ) {
    ct3: ( sum (district in districts) basket[district][crop] ) <= sum (district in districts) (available[district][crop]) ;
  }
  
}

// After solving the model, write the results to a csv file
execute {
  var f = new IloOplOutputFile("output.csv");
  for(var c in crops) {
    f.write(c+",");
  }
  f.writeln("District");
  for(var d in districts) {
    for(var c in crops) {
      f.write(basket[d][c].solutionValue+",");
    }
    
    // Write district name in last column with no comma
    f.writeln(d);
  }
  f.close();
}
