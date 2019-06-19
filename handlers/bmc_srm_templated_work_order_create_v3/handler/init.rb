require 'rexml/document'
require 'ars_models'

class BmcSrmTemplatedWorkOrderCreateV3
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @field_values - A Hash of WOI:WorkOrderInterface_Create database field names
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
      ['WOI:WorkOrderInterface_Create','WOI:Template','CTM:People']
    )

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled
	
	# Retrieve the list of parameter values.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Parameters:", @parameters)) if @debug_logging_enabled

    # Retrieve the list of field values.
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
	  @field_values[node.attribute('name').value] = node.text if node.text != nil
    end
    puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled
  end

  # Creates a Work Order record using the WOI:WorkOrderInterface_Create form.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An XML formatted String representing the return variable results.
  def execute()
	
	#Get Work Order Template GUID based on Template name
	templateEntry = @@remedy_forms['WOI:Template'].find_entries(
	  :single,
	  :conditions => [%|'Template Name' = "#{@parameters['Work Order Template Name']}"|],
	  :fields => nil
	)
	# Raise error if unable to locate the entry
	raise("No matching entry on the WOI:Template form for the given Work Order Template Name [#{@parameters['Work Order Template Name']}]") if templateEntry.nil?

	@field_values['TemplateID'] = templateEntry['GUID']
    puts("Work Order Template GUID: #{@field_values['TemplateID']}" ) if @debug_logging_enabled

	#Get Person ID from CTM:People for Requester Login ID
    requesterEntry = @@remedy_forms['CTM:People'].find_entries(
      :single,
      :conditions => [%|'4' = "#{@parameters['Requester Login Id']}"|],
      :fields => nil
    )
	# Raise error if unable to locate the entry
	raise("No matching entry on the CTM:People form for the requester login id [#{@parameters['Requester Login Id']}]") if requesterEntry.nil?

	@field_values['Customer Person ID'] = requesterEntry['Person ID']
	@field_values['Person ID'] = requesterEntry['Person ID']
    puts("Requester Person ID: #{@field_values['Customer Person ID']}" ) if @debug_logging_enabled
	
	#Get Person ID from CTM:People for Submitter Login ID
    submitterEntry = @@remedy_forms['CTM:People'].find_entries(
      :single,
      :conditions => [%|'4' = "#{@parameters['Submitter Login Id']}"|],
      :fields => nil
    )
	# Raise error if unable to locate the entry
	raise("No matching entry on the CTM:People form for the submitter login id [#{@parameters['Submitter Login Id']}]") if submitterEntry.nil?

	@field_values['Requested By Person ID'] = submitterEntry['Person ID']
    puts("Submitter Person ID: #{@field_values['Requested By Person ID']}" ) if @debug_logging_enabled

	# Create the WOI:WorkOrderInterface_Create record using the @field_values hash
    # that was built up.  Pass 'WorkOrder_ID' and 'Request ID' to the fields
    # argument because these fields will be used in the results xml.
    entry = @@remedy_forms['WOI:WorkOrderInterface_Create'].create_entry!(
      :field_values => @field_values,
      :fields       => ['WorkOrder_ID', 'Request ID']
    )

    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Work Order ID">#{escape(entry['WorkOrder_ID'])}</result>
      <result name="Request ID">#{escape(entry['Request ID'])}</result>
	  <result name="Deferral Token">#{@field_values['SRMSAOIGuid']}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled

    # Return the results String
    return results
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