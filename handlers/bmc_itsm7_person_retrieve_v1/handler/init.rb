# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

class BmcItsm7PersonRetrieveV1
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
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
    preinitialize_on_first_load(@input_document, ['CTM:People'])
	
    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled	
  end
  
  # Uses the Remedy Login ID to retrieve a single entry from the ITSM v7.x
  # CTM:People form.  The purpose of this is to return data elements associated
  # to the entry found.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # Retrieve a single entry from CTM:People based on Remedy Login ID
    entry = @@remedy_forms['CTM:People'].find_entries(
      :single,
      :conditions => [%|'4' = "#{@parameters['remedy_login_id']}"|],
      :fields => :all
    )
	
	# Raise error if unable to locate the entry
	raise("No matching entry on the CTM:People form for the given login id [#{@parameters['remedy_login_id']}]") if entry.nil?

	# Raise error if manager field is blank
	if (entry['ManagerLoginID'].nil? || entry['ManagerLoginID']=="")
		raise("No manager listed for [#{@parameters['remedy_login_id']}]")
	end
	
	# Check for active manager ID
	manager = @@remedy_forms['CTM:People'].find_entries(
      :single,
      :conditions => [%|'4' = "#{entry['ManagerLoginID']}"|],
      :fields => :all
    )
	
	if (manager.nil?)
		raise("Manager [#{entry['ManagerLoginID']}] for person [#{@parameters['remedy_login_id']}] was not found.")
	end
	
	if (manager['Profile Status'].value != "Enabled")
		raise("Manager [#{entry['ManagerLoginID']}] is not active for person [#{@parameters['remedy_login_id']}]")
	end
	
    # Build up a list of all field names and values for this record
    field_values = entry.field_values.collect do |field_id, value|
      "#{@@remedy_forms['CTM:People'].field_for(field_id).name}: #{value}"
    end
	puts("Field Values: #{field_values.inspect}") if @debug_logging_enabled	
	
    # Build the results to be returned by this handler
    results = <<-RESULTS
    <results>
      <result name="Remedy Login ID">#{escape(entry['Remedy Login ID'])}</result>
      <result name="Email">#{escape(entry['Internet E-mail'])}</result>
      <result name="First Name">#{escape(entry['First Name'])}</result>
      <result name="Middle Initial">#{escape(entry['Middle Initial'])}</result>
      <result name="Last Name">#{escape(entry['Last Name'])}</result>
      <result name="Job Title">#{escape(entry['JobTitle'])}</result>
      <result name="Nick Name">#{escape(entry['Nick Name'])}</result>
      <result name="Corporate ID">#{escape(entry['Corporate ID'])}</result>
      <result name="Profile Status">#{escape(entry['Profile Status'].value)}</result>
      <result name="Contact Type">#{escape(entry['Contact Type'])}</result>
      <result name="Client Sensitivity">#{escape(entry['Client Sensitivity'].value)}</result>
      <result name="VIP">#{escape(entry['VIP'].value)}</result>
      <result name="Support Staff">#{escape(entry['Support Staff'].value)}</result>
      <result name="Assignment Availability">#{escape(entry['Assignment Availability'])}</result>
      <result name="Company">#{escape(entry['Company'])}</result>
      <result name="Organization">#{escape(entry['Organization'])}</result>
      <result name="Department">#{escape(entry['Department'])}</result>
      <result name="Region">#{escape(entry['Region'])}</result>
      <result name="Site Group">#{escape(entry['Site Group'])}</result>
      <result name="Site">#{escape(entry['Site'])}</result>
      <result name="Desk Location">#{escape(entry['Desk Location'])}</result>
      <result name="Mail Station">#{escape(entry['Mail Station'])}</result>
      <result name="Phone Number Business">#{escape(entry['Phone Number Business'])}</result>
      <result name="Phone Number Mobile">#{escape(entry['Phone Number Mobile'])}</result>
      <result name="Phone Number Fax">#{escape(entry['Phone Number Fax'])}</result>
      <result name="Phone Number Pager">#{escape(entry['Phone Number Pager'])}</result>
      <result name="ACD Phone Num">#{escape(entry['ACD Phone Num'])}</result>
      <result name="Corporate E-Mail">#{escape(entry['Corporate E-Mail'])}</result>
      <result name="Accounting Number">#{escape(entry['Accounting Number'])}</result>
      <result name="ManagersName">#{escape(entry['ManagersName'])}</result>
      <result name="ManagerLoginID">#{escape(entry['ManagerLoginID'])}</result>
      <result name="Cost Center Code">#{escape(entry['Cost Center Code'])}</result>
      <result name="Person ID">#{escape(entry['Person ID'])}</result>
    </results>
    RESULTS
	puts(results) if @debug_logging_enabled	
	
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

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desired info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end