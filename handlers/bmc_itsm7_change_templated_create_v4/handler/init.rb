require 'rexml/document'
require 'ars_models'

class BmcItsm7ChangeTemplatedCreateV4
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of CHG:ChangeInterface_Create database field names
  #   to the values to be used for the record.
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
      ['CHG:ChangeInterface_Create', 'CHG:Template']
    )

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

    # Retrieve the list of field values
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end

    # Validate the required field values that are set from node parameters
    # contain a value and raise an exception if one or more are missing.
    validate_presence_of_required_values!(@field_values, REQUIRED_FIELDS)
  end

  # Creates a CHG:Infrastructure Change record using the CHG:ChangeInterface_Create
  # form.  The CHG:ChangeInterface_Create is used as a staging form for creating
  # entries in the Changes form in ITSM.  Before creating the record on the
  # CHG:ChangeInterface_Create form, it retrieves the 'InstanceId' of the given
  # change template using the get_template_id() method.
  # 
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # Set the 'TemplateID' field of the record to create to the result of a call
    # to get_template_id().
    @field_values['TemplateID'] = get_template_id(@parameters['change_template_name'])
    puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled
    
    # Create the CHG:ChangeInterface_Create record using the @field_values hash
    # that was built up.  Pass 'Infrastructure Change Id' and 'InstanceId' to the
    # fields argument because these fields will be used in the results xml.
    entry = @@remedy_forms['CHG:ChangeInterface_Create'].create_entry!(
      :field_values => @field_values,
      :fields       => ['Infrastructure Change Id', 'InstanceId']
    )

    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Change Number">#{escape(entry['Infrastructure Change Id'])}</result>
      <result name="Change Instance Id">#{escape(entry['InstanceId'])}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled

    # Return the results String
    return results
  end

  ##############################################################################
  # Validation Helpers
  ##############################################################################

  # Defines a hash of Remedy field names (for the 'CHG:ChangeInterface_Create'
  # form) to Kinetic Task node parameter names that are required to complete
  # this action.  This constant is used to validate that all required fields
  # were included as parameters and have a non-blank value.
  REQUIRED_FIELDS = {
    'Company'              => 'Requester Support Company',
  #  'First Name'           => 'Requester First Name',
  #  'Last Name'            => 'Requester Last Name',
    'Company3'             => 'Change Manager Support Company',
    'Support Organization' => 'Change Manager Support Organization',
    'Support Group Name'   => 'Change Manager Support Group Name',
    'Submitter'            => 'Submitter Login Id'
  }

  # Iterates over the required hash (a mapping of required hash keys to the
  # display value to use for that hash key) and raises an exception if any of
  # the required keys map to a nil? or empty? value.
  #
  # ==== Parameters
  # * value_hash (Hash) - The hash of key to value pairs that should be checked
  #   for required values.
  # * required_hash (Hash) - A hash of keys that should be associated with a
  #   required value in the value_hash to the display value to use in the error
  #   message if the value associated with the key is nil? or empty?
  def validate_presence_of_required_values!(value_hash, required_hash)
    # Validate that all of the parameters have values
    missing_parameters = []
    # Validate that all of the required parameters have values
    required_hash.each do |field_name, parameter_name|
      if value_hash[field_name].nil? || value_hash[field_name].empty?
        missing_parameters << parameter_name
      end
    end

    # If there were any blank field values
    if missing_parameters.length > 0
      # Raise an exception
      raise "The following node parameters are required: #{missing_parameters.sort.join(', ')}"
    end
  end

  ##############################################################################
  # BMC_ITSM7_Change_TemplatedCreate handler utility functions
  ##############################################################################

  # Retrieves the String 'InstanceId' of the CHG:Template record that is associated
  # to the specified change template name.
  #
  # Raises an exception if there was no CHG:Template record that had 'Template Name'
  # equal to the specified change_template_name parameter.
  #
  # ==== Parameters
  # * change_template_name (String) - The name of the desired change template.
  def get_template_id(change_template_name)
    # Retrieve the CHG:Template entry using the change_template_name parameter in
    # the qualification.
    entry = @@remedy_forms['CHG:Template'].find_entries(
      :first,
      :conditions => [%|'Template Name' = "#{change_template_name}" AND 'Status' = "Enabled"|],
      :fields     => ['InstanceId']
    )
    # Raise an exception if no CHG:Template entry was found with the given name.
    if entry.nil?
      raise("Could not find CHG:Template with name: #{change_template_name}")
    end
    # Return the 'InstanceId' of the CHG:Template entry.
    entry['InstanceId']
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