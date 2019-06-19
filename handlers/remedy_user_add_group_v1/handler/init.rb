require 'rexml/document'
require 'ars_models'

class RemedyUserAddGroupV1
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of User database field names
  #   to the values that will be set on the submission record.
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
      ['User','Group']
    )

    # Determine if debug logging is enabled. Value is set in the info.xml.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters from the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

    # Initialize an Array to track any errors that come up during validation.
    errors = []

    # If there are any errors in the errors Array, raise an exception that contains
    # all of the error messages.
    if errors.any?
      raise %|The following errors were found while validating the parameters:\n#{errors.join("\n")}|
    end
  end

  # Updates the value of the fields on the User record
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  # No records returned by this handler
  def execute()
    # Retrieve the entry for the Kinetic Request submission that is being
    # updated and don't return any field values.
    user = retrieve_user(@parameters['login_name'],["Group List"])
    group = retrieve_group(@parameters['group_name'],["Group ID"])

    group_id = group["Group ID"].to_s
	
	  puts "User #{user["Group List"]}"
	  puts "Group #{group_id}"
	  puts group_id.class
    
    # User could be in no groups -- lets catch that
    if (user["Group List"].nil?)
      group_list = Array.new
    else
  	  group_list = user["Group List"].gsub(/\s/,"").split(/;/)
    end

	  puts "Group list #{group_list.inspect}"
	  
	  unless group_list.member?(group_id) 

      group_list << group_id
      puts "Adding group to user"
      user.update_attributes!({'Group List'=>group_list.join(" ")})

    end
	
#    user.update_attributes!({'Group'=>@parameters['group_name']})
	
    # Return an empty results String
    return "<results/>"
  end

  ##############################################################################
  # Kinetic handler utility functions
  ##############################################################################

  # Retrieve the ArsModels::Entry object for the KS_SRV_CustomerSuvey_base
  # record associated to the specified instance id and include the specified
  # fields.
  #
  # Raises an exception if a record associated to the specified instance id does
  # not exist.
  #
# TODO -- Needs updating to be accurate
  # ==== Parameters
  # * id (String) - The instance Id of the KS_SRV_CustomerSurvey_base record
  #   that should be retrieved.
  # * field_identifiers (Array) - An array of field identifiers, typically field
  #   ids (specified as numbers) or field names (specified as strings), that
  #   should be returned with the requested submission.
  #
  # ==== Returns
  # An ArsModels::Entry record that includes the field values of the located
  # KS_SRV_CustomerSurvey_base record.
  def retrieve_user(login_name, field_identifiers=[])
    entry = @@remedy_forms['User'].find_entries(
      :single, :fields => field_identifiers, :conditions => [%`'Login Name' = "#{login_name}"`]
    )
    raise %|Unable to find the User record for '#{login_name}'.| if entry.nil?
    entry
  end


  # An ArsModels::Entry record that includes the field values of the located
  # in Group record
  def retrieve_group(group_name, field_identifiers=[])
    entry = @@remedy_forms['Group'].find_entries(
      :single, :fields => field_identifiers, :conditions => [%`'Group Name' = "#{group_name}"`]
    )
    raise %|Unable to find the Group record for '#{group_name}'.| if entry.nil?
    entry
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
    # Staring with the "header" parameter string, concatenate each of the
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
