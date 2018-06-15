# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/
# Author: Yanfei Li, The University of Alabama

# start the measure
class StuckFan2< OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "StuckFan2"
  end

  # human readable description
  def description
    return "This measure assume the fan is stuck"
  end

  # human readable description of modeling approach
  def modeler_description
    return "This model is only applied to air loop"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
	#populate choice argument for constructions that are applied to surfaces in the model
    air_loop_handles = OpenStudio::StringVector.new
    air_loop_display_names = OpenStudio::StringVector.new
	
	#putting space types and names into hash
    air_loop_args = model.getAirLoopHVACs
    air_loop_args_hash = {}
    air_loop_args.each do |air_loop_arg|
      air_loop_args_hash[air_loop_arg.name.to_s] = air_loop_arg
    end
	
	#looping through sorted hash of air loops
    air_loop_args_hash.sort.map do |key,value|
      air_loop_handles << value.handle.to_s
      air_loop_display_names << key
    end
	
	#add building to string vector with air loops
    building = model.getBuilding
    air_loop_handles << building.handle.to_s
    air_loop_display_names << "*All Air Loops*"
	
	 #make an argument for air loops
    object = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("object", air_loop_handles, air_loop_display_names,true)
    object.setDisplayName("Choose an Air Loop to Alter.")
    object.setDefaultValue("*All Air Loops*") #if no air loop is chosen this will run on all air loops
    args << object
	
    # the name of the space to add to the model
    fan_power_min_airflow_rate= OpenStudio::Ruleset::OSArgument.makeDoubleArgument("fan_power_min_airflow_rate", true)
    fan_power_min_airflow_rate.setDisplayName("Fan Power Minimum Air Flow Rate (m3/s)")
    fan_power_min_airflow_rate.setDefaultValue(0.0)
    args << fan_power_min_airflow_rate


	
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
	object = runner.getOptionalWorkspaceObjectChoiceValue("object",user_arguments,model) #
    fan_power_min_airflow_rate = runner.getDoubleArgumentValue("fan_power_min_airflow_rate", user_arguments)


   #check the air_loop for reasonableness
    apply_to_all_air_loops = false
    air_loop = nil
    if object.empty?
      handle = runner.getStringArgumentValue("air_loop",user_arguments)
      if handle.empty?
        runner.registerError("No air loop was chosen.")
      else
        runner.registerError("The selected air_loop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not object.get.to_AirLoopHVAC.empty?
        air_loop = object.get.to_AirLoopHVAC.get
      elsif not object.get.to_Building.empty?
        apply_to_all_air_loops = true
      else
        runner.registerError("Script Error - argument not showing up as air loop.")
        return false
      end
    end  #end of if air_loop.empty?

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # ##add a new space to the model
	# coil_heating_water=OpenStudio::Model::CoilHeatingWater::CoilHeatingWater(model);
	# UFactorTimesAreaAutoSized=coil_heating_water.isUFactorTimesAreaValueAutoSized();
	# if (UFactorTimeAreaAutoSized)
			# UFactorTimeArea.setUFactorTimesAreaValue(uFactor_drop_percent*Nominal_UFactorTimesArea);
    # else
			# UFactorTimeArea.setUFactorTimesAreaValue(uFactor_drop_percent*Nominal_UFactorTimesArea);
	# end
					
	
	 #get air loops for measure
     if apply_to_all_air_loops
         air_loops = model.getAirLoopHVACs
     else
         air_loops = []
         air_loops << air_loop #only run on a single space type
     end
	
	autosized=false;
	
		air_loops.each do |air_loop|
			  supply_components = air_loop.supplyComponents(OpenStudio::Model::FanVariableVolume::iddObjectType)

			  supply_components.each do |supply_component|
					 fan_variable_volume = supply_component.to_FanVariableVolume.get # <-- this is safe because of how we called supplComps...
					#fan power coeff 1
					 input_method=fan_variable_volume.resetFanPowerMinimumFlowRateInputMethod();
					 
					 fan_variable_volume.setFanPowerMinimumAirFlowRate(fan_power_min_airflow_rate)
					
				
					
					
			  end

		end
	    
		# hot_water_coils = model.getCoilHeatingWaters
		
		# uFactorTimeArea= hot_water_coils.isUFactorTimesAreaValueAutoSized
				      # if (uFactorTimeArea)
						 # hot_water_coils.setUFactorTimesAreaValue(uFactor_drop_percent*nominal_UFactorTimesArea);
					 # else
						 # hot_water_coils.setUFactorTimesAreaValue(uFactor_drop_percent*nominal_UFactorTimesArea);
					 # end
		
		

    # # echo the new space's name back to the user
    #runner.registerInfo("Space #{heating_coil.name} was added.")

    # # report final condition of model
     runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")
  
    return true
    
	end
	
  end
  
  
  


# register the measure to be used by the application
StuckFan2.new.registerWithApplication