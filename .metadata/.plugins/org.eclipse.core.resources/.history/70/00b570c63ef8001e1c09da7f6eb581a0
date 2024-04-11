/*********************************************
 * OPL 22.1.1.0 Model
 * Author: --
 * Creation Date: Jan 30, 2024 at 11:14:53 AM
 *********************************************/
range Clusters = 0..5;
range Crops = 1..16;
range millets = 1..6;
range Pulses = 7..16;
range Districts = 1..625;

string crops[Crops] = ... ;

float preferences[Crops][Clusters] = ... ;

int households[Clusters] = ... ;

string districts[Districts] = ... ;

int households_district[Districts] = ... ;

int clusters_district[Districts] = ... ;

string cereals_district[Districts] = ... ;

// Toy data- will discuss.
float available[Crops] = [3000,3000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000];

float min_millet = .00005 ; // Per household
float min_pulse = .00003 ; // Per household
float min_cereal = .0001 ; // Per household

// Decision variable
dvar float+ basket[Crops][Clusters];

// Objective function
dexpr float utility = ( sum (crop in Crops, cluster in Clusters) (preferences[crop][cluster] * basket[crop][cluster]));

maximize utility ;

subject to {
  
  // Per-household millet and pulse requirements
  forall ( cluster in Clusters ) {
    ct1: ( sum ( millet in millets ) basket[millet][cluster] ) == min_millet * households[cluster];
    ct2: ( sum ( puls in Pulses) basket[puls][cluster] ) == min_pulse * households[cluster];
  }
  
  // Total demand does not exceed availability
  forall ( crop in Crops ) {
    ct3: ( sum (cluster in Clusters) basket[crop][cluster] ) <= available[crop] ;
  }
  
}

// After solving the model, write demand by district to a csv file:

execute {
  var f = new IloOplOutputFile("../data/basket.csv");
  var header = "district,Rice,Wheat"; // Start building the header string
  
  for(var c in Crops) {
    header += "," + crops[c]; // Append each crop name to the header
  }
  
  f.writeln(header); // Write the complete header to the file


  // Calculate per-district demand
  for(var d in Districts) {
    var districtName = districts[d];
    var demandLine = districtName; // Start line with district name
    
    // Calculate Cereal
    var rice_demand = 0;
    var wheat_demand = 0;
    if(cereals_district[d] == "Wheat") {
      wheat_demand = min_cereal * households_district[d];
    } else if(cereals_district[d] == "Rice") {
      rice_demand = min_cereal * households_district[d];
    } else {
        wheat_demand = min_cereal * households_district[d] / 2;
        rice_demand = min_cereal * households_district[d] / 2;
    }
    demandLine += "," + rice_demand + "," + wheat_demand;
	    
    
    for(var c in Crops) {
      var totalCropDemandInDistrict = 0;
      
      for(var cl in Clusters) {
        if(clusters_district[d] == cl) {
          var clusterTotalDemandForCrop = basket[c][cl];
          var districtPopulation = households_district[d];
          var clusterPopulation = households[cl];
          
          var districtDemandForCrop = (clusterTotalDemandForCrop * districtPopulation) / clusterPopulation;
          totalCropDemandInDistrict += districtDemandForCrop;
        }
      }
      
      demandLine += "," + totalCropDemandInDistrict;
    }
    
    f.writeln(demandLine); // Write the calculated demand for this district
  }
  
  f.close();
}
