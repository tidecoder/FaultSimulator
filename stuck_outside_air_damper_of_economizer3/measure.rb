# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/
# Author: Yanfei Li, The University of Alabama

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
#require_relative '../measure.rb'
require 'C:\Users\cfdcoder\OpenStudio\Measures\stuck_outside_air_damper_of_economizer/measure.rb'
require 'fileutils'

# start the measure
class StuckOutsideAirDamperOfEconomizer3 < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "StuckOutsideAirDamperOfEconomizer3"
  end

  # human readable description
  def description
    return "This measure is based on the EnableEconomizer. It specifies the percentage of the air damper opening, which is to be used by the compact schedule."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure needs the percentage of outside air damper of economizer, which is applied to the compact schedule. "
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
	
	 #make choice argument economizer control type
    choices = OpenStudio::StringVector.new
    choices << "FixedDryBulb"
    choices << "FixedEnthalpy"
    choices << "DifferentialDryBulb"
    choices << "DifferentialEnthalpy"
    choices << "FixedDewPointAndDryBulb"
    choices << "NoEconomizer"
    economizer_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("economizer_type", choices,true)
    economizer_type.setDisplayName("Economizer Control Type.")
    args << economizer_type
	
	#make an argument for econoMaxDryBulbTemp
    econoMaxDryBulbTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("econoMaxDryBulbTemp",true)
    econoMaxDryBulbTemp.setDisplayName("Economizer Maximum Limit Dry-Bulb Temperature (F).")
    econoMaxDryBulbTemp.setDefaultValue(69.0)
    args << econoMaxDryBulbTemp
	
	#make an argument for econoMaxEnthalpy
    econoMaxEnthalpy = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("econoMaxEnthalpy",true)
    econoMaxEnthalpy.setDisplayName("Economizer Maximum Enthalpy (Btu/lb).")
    econoMaxEnthalpy.setDefaultValue(28.0)
    args << econoMaxEnthalpy
	
	#make an argument for econoMaxDewpointTemp
    econoMaxDewpointTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("econoMaxDewpointTemp",true)
    econoMaxDewpointTemp.setDisplayName("Economizer Maximum Limit Dewpoint Temperature (F).")
    econoMaxDewpointTemp.setDefaultValue(55.0)
    args << econoMaxDewpointTemp

    #make an argument for econoMinDryBulbTemp
    econoMinDryBulbTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("econoMinDryBulbTemp",true)
    econoMinDryBulbTemp.setDisplayName("Economizer Minimum Limit Dry-Bulb Temperature (F).")
    econoMinDryBulbTemp.setDefaultValue(-148.0)
    args << econoMinDryBulbTemp
	
	
	#make an argument for nominal_min_outdoor_air_flow_rate
    nominal_min_outdoor_air_flow_rate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("norminal_min_outdoor_air_flow_rate",true)
    nominal_min_outdoor_air_flow_rate.setDisplayName("Minimum Outdoor Air Flow Rate (m3/s)")
	nominal_min_outdoor_air_flow_rate.setDefaultValue(0.0)
    args << nominal_min_outdoor_air_flow_rate

	#make an argument for nominal_max_outdoor_air_flow_rate
    nominal_max_outdoor_air_flow_rate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("norminal_max_outdoor_air_flow_rate",true)
    nominal_max_outdoor_air_flow_rate.setDisplayName("Maximum Outdoor Air Flow Rate (m3/s)")
	nominal_max_outdoor_air_flow_rate.setDefaultValue(0.0)
    args << nominal_max_outdoor_air_flow_rate
	
	
    return args
  end 
  #end of define arguments

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

	
	
    # assign the user inputs to variables
    object = runner.getOptionalWorkspaceObjectChoiceValue("object",user_arguments,model) #model is passed in because of argument type
    economizer_type = runner.getStringArgumentValue("economizer_type",user_arguments)
    econoMaxDryBulbTemp = runner.getDoubleArgumentValue("econoMaxDryBulbTemp",user_arguments)
    econoMaxEnthalpy = runner.getDoubleArgumentValue("econoMaxEnthalpy",user_arguments)
    econoMaxDewpointTemp = runner.getDoubleArgumentValue("econoMaxDewpointTemp",user_arguments)
    econoMinDryBulbTemp = runner.getDoubleArgumentValue("econoMinDryBulbTemp",user_arguments)
	
	nominal_min_outdoor_air_flow_rate=runner.getDoubleArgumentValue("nominal_min_outdoor_air_flow_rate",user_arguments)
	nominal_max_outdoor_air_flow_rate=runner.getDoubleArgumentValue("nominal_max_outdoor_air_flow_rate",user_arguments)
	
	
	
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
	
	 #check economizer values for reasonableness
    default = 69 #same value as default argument
    if econoMaxDryBulbTemp > default * 1.2
      runner.registerWarning("Economizer Maximum Limit Dry-Bulb Temperature of #{econoMaxDryBulbTemp}(F) seems high.")
    elsif econoMaxDryBulbTemp < default * 0.8
      runner.registerWarning("Economizer Maximum Limit Dry-Bulb Temperature of #{econoMaxDryBulbTemp}(F) seems low.")
    end
    #this argument has an error check in addition to the warning check.
    if econoMaxDryBulbTemp > 150
      runner.registerWarning("Economizer Maximum Limit Dry-Bulb Temperature of #{econoMaxDryBulbTemp}(F) is too high. Measure will not run.")
    elsif econoMaxDryBulbTemp < 20
      runner.registerWarning("Economizer Maximum Limit Dry-Bulb Temperature of #{econoMaxDryBulbTemp}(F) is too high. Measure will not run.")
    end

    default = 28 #same value as default argument
    if econoMaxEnthalpy > default * 1.1
      runner.registerWarning("Economizer Maximum Enthalpy of #{econoMaxEnthalpy}(Btu/lb) seems high.")
    elsif econoMaxEnthalpy < default * 0.9
      runner.registerWarning("Economizer Maximum Enthalpy of #{econoMaxEnthalpy}(Btu/lb) seems low.")
    end

    default = 55 #same value as default argument
    if econoMaxDewpointTemp > default * 1.2
      runner.registerWarning("Economizer Maximum Limit Dewpoint Temperature of #{econoMaxDewpointTemp}(F) seems high.")
    elsif econoMaxDewpointTemp < default * 0.8
      runner.registerWarning("Economizer Maximum Limit Dewpoint Temperature of #{econoMaxDewpointTemp}(F) seems low.")
    end

    # no current check in min dry bulb temp
	
	#get air loops for measure
    if apply_to_all_air_loops
      air_loops = model.getAirLoopHVACs
    else
      air_loops = []
      air_loops << air_loop #only run on a single space type
    end
	
	#info for initial condition
    initial_num_air_loops_economized = 0
    final_num_air_loops_economized = 0
    loops_with_outdoor_air = false

	#make changes to the model
	
		  
		
		  
    #loop through air loops
    air_loops.each do |air_loop|
      supply_components = air_loop.supplyComponents

      #find AirLoopHVACOutdoorAirSystem on loop
      supply_components.each do |supply_component|
        hVACComponent = supply_component.to_AirLoopHVACOutdoorAirSystem
        if hVACComponent.is_initialized
          hVACComponent = hVACComponent.get

          #set flag that at least one air loop has outdoor air objects
          loops_with_outdoor_air = true

          #get ControllerOutdoorAir
          controller_oa = hVACComponent.getControllerOutdoorAir

          #get ControllerMechanicalVentilation
          controller_mv = controller_oa.controllerMechanicalVentilation #not using this

		  #get Minimum Outdoor Air Flow Rate m3/s 
		  if (controller_oa.isMinimumOutdoorAirFlowRateAutosized)
		     runner.registerInfo("min outdoor air flow rate must be given values")    
			 controller_oa.setMinimumOutdoorAirFlowRate(nominal_min_outdoor_air_flow_rate)
		  else
		     controller_oa.setMinimumOutdoorAirFlowRate(nominal_min_outdoor_air_flow_rate)
		  end 
		  
		  #get Maximum Outdoor Air Flow Rate m3/s 
		  if (controller_oa.isMaximumOutdoorAirFlowRateAutosized)
		     runner.registerInfo("max outdoor air flow rate must be given values")    
			 controller_oa.setMaximumOutdoorAirFlowRate(nominal_max_outdoor_air_flow_rate)
		  else
		     controller_oa.setMaximumOutdoorAirFlowRate(nominal_max_outdoor_air_flow_rate)
		  end 
		  
		  
          #log initial economizer type
          if not controller_oa.getEconomizerControlType == "NoEconomizer"
            initial_num_air_loops_economized += 1
          end

          if controller_oa.getEconomizerControlType == economizer_type
            #report info about air loop
            runner.registerInfo("#{air_loop.name} already has the requested economizer type of #{economizer_type}.")
          else
            #store starting economizer type
            starting_econo_control_type =  controller_oa.getEconomizerControlType

            #set economizer to the requested control type
            controller_oa.setEconomizerControlType(economizer_type)
            
			#set the economizer to the created compact shcedule
			controller_oa.setMinimumFractionofOutdoorAirSchedule(sch_ruleset)
			
            #report info about air loop
            runner.registerInfo("Changing Economizer Control Type on #{air_loop.name} from #{starting_econo_control_type} to #{controller_oa.getEconomizerControlType} and adjusting temperature and enthalpy limits per measure arguments.")

          end

          #log final economizer type
          if not controller_oa.getEconomizerControlType == "NoEconomizer"
            final_num_air_loops_economized += 1
          end

          #measure does not alter EconomizerControlActionType

          #set maximum limit drybulb temperature
          controller_oa.setEconomizerMaximumLimitDryBulbTemperature(OpenStudio::convert(econoMaxDryBulbTemp,"F","C").get)

          #set maximum limit enthalpy
          controller_oa.setEconomizerMaximumLimitEnthalpy(OpenStudio::convert(econoMaxEnthalpy,"Btu/lb", "J/kg").get)

          #set maximum limit dewpoint temperature
          controller_oa.setEconomizerMaximumLimitDewpointTemperature(OpenStudio::convert(econoMaxDewpointTemp,"F","C").get)

          #set minimum limit drybulb temperature
          controller_oa.setEconomizerMinimumLimitDryBulbTemperature(OpenStudio::convert(econoMinDryBulbTemp,"F","C").get)
		  

        end #end if not hVACComponent.empty?

      end #end supply_components.each do

    end #end air_loops.each do
	
	
    if loops_with_outdoor_air == false
      runner.registerAsNotApplicable("The affected loop(s) do not have any outdoor air objects.")
      return true
    end

	
   
    return true


  end
  
end

# register the measure to be used by the application
StuckOutsideAirDamperOfEconomizer3.new.registerWithApplication
