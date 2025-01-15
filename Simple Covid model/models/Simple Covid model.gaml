/**
* Name: SimpleCovidmodel
* Based on the internal skeleton template. 
* Author: patrick taillandier
* Tags: 
*/


model SimpleCovidmodel

global {
	string SUSCEPTIBLE <- "s";
	string INFECTED <- "i";
	string IMMUNE <- "r";
	
	string RESIDENTIAL <- "residential";
	string SCHOOL <- "school";
	string OFFICE <- "office";
	
	int num_individuals <- 1000;
	geometry shape <- square(1#km);
	
	float step <- 1#h;
	
	int num_infected_init <- 5;
	
	float proba_infection_h <- 0.001;
	
	float proba_isolation_infected <- 0.5;
	
	float time_infectious <- 5.0; // in number of days
	
	float time_immunity <- 30.0; // in number of days
	
	bool optimization_not_move_agents <- true;
	
	int total_infected;

	
	map<string, rgb> color_per_type <- [RESIDENTIAL::#gray, OFFICE::#blue, SCHOOL::#yellow];
	map<string, rgb> color_per_state <- [SUSCEPTIBLE::#green, INFECTED::#red, IMMUNE::#pink];
	
	
	bool use_containment <- false;
	float begin_containment <- 30.0 ; // in number of days
	float time_containment <- 30.0 ;// in number of days
	
	float proba_respect_containment <- 1.0;
	
	int num_of_not_working_day;
	
	init {
		do build_city;
		list<building> residences <- building where (each.type = RESIDENTIAL);
		list<building> schools <- building where (each.type = SCHOOL);
		list<building> offices <- building where (each.type = OFFICE);
		
			
		time_infectious <- time_infectious  * #day;
		time_immunity <- time_immunity #days;
		begin_containment <- begin_containment #day;
		time_containment <- time_containment #day;
	
	
		
		
		create individual number: num_individuals {
			age <- rnd(10,90);
			leaving_place <- one_of(residences);
			working_place <-  age < 18 ? one_of(schools) : one_of(offices);
			agenda[rnd(6,10)] <- working_place;
			agenda[rnd(15,20)] <- leaving_place;
			current_building <- leaving_place;
			if not optimization_not_move_agents {location <- any_location_in(leaving_place);}
			
			current_building.individuals << self;
			do change_state(SUSCEPTIBLE);
		}
		
		ask num_infected_init among individual {
			do become_infected;
		}
		
		create government;
	}
	
	action build_city {
		list<geometry> bati_geoms <- world to_rectangles(10,10);
		create building from: bati_geoms {
			shape <- shape * 0.8;
			type <- RESIDENTIAL;
		}
		ask 2 among building {
			type <- SCHOOL;
		}
		ask 20 among building where (each.type = RESIDENTIAL) {
			type <- OFFICE;
		}
		ask building {
			color <- color_per_type[type];
		}
	}
	
}
species government {
	reflex begin_containment when: use_containment and time = begin_containment {
		ask individual  {
			if flip(proba_respect_containment) {
				do manage_isolated(true);
				num_of_not_working_day <- num_of_not_working_day + int(time_containment/#day);
			}
		}
	}
	
	reflex end_containment when: use_containment and time = (begin_containment + time_containment){
		ask individual  {
			do manage_isolated(false);
		}
	}
}
species individual {
	string state; 
	int age;
	building leaving_place;
	building working_place;
	map<int, building> agenda;
	rgb color <- #green;
	building current_building;
	float infected_time;
	float immune_time;
	bool isolated <- false;
	
	reflex move when: current_date.hour in agenda.keys and not isolated{
		if (current_building != nil) {
			current_building.individuals >> self;
		}
		current_building <- agenda[current_date.hour ];
		current_building.individuals << self;
		if not optimization_not_move_agents {location <- any_location_in(current_building);}
	}
	
	
	reflex infect_other when: state = INFECTED and not isolated  {
		ask current_building.individuals where (each.state = SUSCEPTIBLE){
				
			if flip(proba_infection_h) {
				do become_infected;
			}
		}
	}
	
	reflex recover when: state = INFECTED {
		infected_time <- infected_time + step;
		write""+ step +  " time_infectious: " + time_infectious;
		if (infected_time > time_infectious) {
			do change_state(IMMUNE);
			immune_time <- 0.0;
			if (isolated) {
				current_building.individuals << self;
			}
			isolated <- false;
		
		}
	}
	
	reflex end_of_immunity when: state = IMMUNE {
		immune_time <- immune_time + step;
		if (immune_time > time_immunity) {
			do change_state(SUSCEPTIBLE);
		}
	}
	
	action become_infected {
		do change_state(INFECTED);
		infected_time <- 0.0;
		total_infected <- total_infected +1;
		do manage_isolated(flip(proba_isolation_infected));
	}
	
	action manage_isolated(bool iso) {
		isolated <- iso; 
		if (isolated) {
			current_building.individuals >> self;
		}
	}
	
	action become_isolated {
		
	}
	
	action change_state (string new_state) {
		state <- new_state;
		color <- color_per_state[state];
	}
	
	aspect default {
		draw circle(10) color: color border: #black;
	}
	
	
}

species building {
	string type;
	rgb color;
	list<individual> individuals;
	aspect default {
		draw shape color: color border: #black;
	}
}


experiment impact_time_containment type: batch until: time > 6#month  repeat: 4{
	parameter time_containment var:time_containment among: [0.0, 5.0, 10.0, 20.0, 30.0];
	
	init {
		optimization_not_move_agents <- true;
	}
	reflex results {
		write "Containment duration (in days): " + int(time_containment / #day) + " -> " +  simulations mean_of(each.total_infected) + " : " +  simulations mean_of(each.num_of_not_working_day);
	}
}
	
	

experiment impact_stay_home type: batch until: time > 6#month  repeat: 4{
	parameter proba_stay_home_infected var:proba_isolation_infected among: [0.0, 0.25, 0.5, 0.75, 1.0];
	
	init {
		optimization_not_move_agents <- true;
	}
	reflex results {
		write sample(proba_isolation_infected) + " -> " +  simulations mean_of(each.total_infected);
	}
}
	

experiment SimpleCovidmodel_optimized type: gui {
	
	action _init_ {
		create simulation with:(optimization_not_move_agents: true);
	}
	
	output {
		display chart refresh: current_date.hour = 0 {
			chart "evolution of the population state" {
				data "num susceptibles" color: color_per_state[SUSCEPTIBLE] value: individual count (each.state = SUSCEPTIBLE);
				data "num infected" color: color_per_state[INFECTED] value: individual count (each.state = INFECTED);
				data "num immune" color: color_per_state[IMMUNE] value: individual count (each.state = IMMUNE);
			}
		}
	}
}

experiment SimpleCovidmodel type: gui {
    parameter "Proba Infection: " var: proba_infection_h  min: 0.0 max: 1.0 ;
    parameter "Time Infection: " var: time_infectious  min: 1.0max: 20.0 ;
    parameter "Time Immunity: " var: time_immunity  min: 1.0 max: 20.0 ;
    parameter "Proba Isolation: " var: proba_isolation_infected  min: 0.0 max: 1.0 ;
    parameter "Proba Respect Containment: " var: proba_respect_containment  min: 0.0 max: 1.0 ;
	
	output {
		display map {
			species building;
			species individual;
		}
		display chart {
			chart "evolution of the population state" {
				data "num susceptibles" color: color_per_state[SUSCEPTIBLE] value: individual count (each.state = SUSCEPTIBLE);
				data "num infected" color: color_per_state[INFECTED] value: individual count (each.state = INFECTED);
				data "num immune" color: color_per_state[IMMUNE] value: individual count (each.state = IMMUNE);
			}
		}
		monitor "num susceptibles" value: individual count (each.state = SUSCEPTIBLE);
		monitor "num infected" value: individual count (each.state = INFECTED);
		monitor "num immune" value: individual count (each.state = IMMUNE);
	}
}

