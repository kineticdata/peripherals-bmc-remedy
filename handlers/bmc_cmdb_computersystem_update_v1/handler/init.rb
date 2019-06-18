require 'rexml/document'
require 'ars_models'

class BmcCmdbComputersystemUpdateV1
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of KS_SRV_CustomerSurvey_base database field names
  #   to the values to be used for the approval record.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml 
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)
    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['BMC.CORE:BMC_ComputerSystem_', 'BMC.CORE:BMC_BaseElement']
    )

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @base_element_parameters = {}
    REXML::XPath.match(@input_document, '/handler/base_element_parameters/parameter').each do |node|
		if (node.text != nil) 
			@base_element_parameters[node.attribute('name').value] = node.text
		end
    end
    puts(format_hash("Handler Parameters:", @base_element_parameters)) if @debug_logging_enabled
	
	# Store parameters in the node.xml in a hash attribute named @parameters.
    @computer_system_parameters = {}
    REXML::XPath.match(@input_document, '/handler/computer_system_parameters/parameter').each do |node|
		if (node.text != nil) 
			@computer_system_parameters[node.attribute('name').value] = node.text
		end
    end
    puts(format_hash("Handler Parameters:", @computer_system_parameters)) if @debug_logging_enabled
   end

  # Retrieve the ComputerSystem instance and set the optional Attributes
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  
  def execute()
    # Build up a qualification string by concatenating a list of conditions
    qualification = %|'179' = "#{@computer_system_parameters['InstanceId']}"|
    
    puts "CI Lookup Qualification 1: #{qualification}" if @debug_logging_enabled

    # Retrieve and update the CI that is associated with the
    # CI Instance ID parameter.
    ci = @@remedy_forms['BMC.CORE:BMC_ComputerSystem_'].find_entries(
    :single,
    :all,
    :conditions => [qualification]
    )
    
	#Don't allow this to take an item out of inventory since it does not also remove it from the inventory location, etc.
	if (@computer_system_parameters['AssetLifecycleStatus'] != nil && ci['AssetLifecycleStatus'] == "In Inventory")
		@computer_system_parameters['AssetLifecycleStatus'] = "In Inventory";
    end
       
	ci.update_attributes!(@computer_system_parameters)
	   
    # Build up a qualification string by concatenating a list of conditions
    qualification = %|'179' = "#{@base_element_parameters['InstanceId']}"|
    
    puts "CI Lookup Qualification 2: #{qualification}" if @debug_logging_enabled

    # Retrieve and update the CI that is associated with the
    # CI Instance ID parameter.
    ci2 = @@remedy_forms['BMC.CORE:BMC_BaseElement'].find_entries(
    :single,
    :all,
    :conditions => [qualification]
    )
    
	#Don't allow this to take an item out of inventory since it does not also remove it from the inventory location, etc.
	if (@base_element_parameters['AssetLifecycleStatus'] != nil && ci2['AssetLifecycleStatus'] == "In Inventory")
		@base_element_parameters['AssetLifecycleStatus'] = "In Inventory";
    end
	
    ci2.update_attributes!(@base_element_parameters)
    
       
    # Return a null result list
    return "<results/>"
 
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Unless this method has already been called...
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries.
      @@remedy_context = ArsModels::Context.new(
        :server         => get_info_value(input_document, 'server'),
        :username       => get_info_value(input_document, 'username'),
        :password       => get_info_value(input_document, 'password'),
        :port           => get_info_value(input_document, 'port'),
        :prognum        => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )
      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context))
      end
      # Store that we are preinitialized so that this method is not called twice.
      @@preinitialized = true
    end
  end

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

  # Builds a string that is formatted specifically for the Kinetic Task log file
  # by concatenating the provided header String with each of the provided hash
  # name/value pairs.  The String format looks like:
  #   HEADER
  #       KEY1: VAL1
  #       KEY2: VAL2
  # For example, given:
  #   field_values = {'Field 1' => "Value 1", 'Field 2' => "Value 2"}
  #   format_hash("Field Values:", field_values)
  # would produce:
  #   Field Values:
  #       Field 1: Value 1
  #       Field 2: Value 2
  def format_hash(header, hash)
    # Starting with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    hash.inject(header) do |result, (key, value)|
      result << "\n    #{key}: #{value}"
    end
  end

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end
