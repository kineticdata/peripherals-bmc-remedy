# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

class BmcItsm7IncidentRetrieveV1
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
    preinitialize_on_first_load(@input_document, ['HPD:Help Desk'])
	
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
  
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # Retrieve a single entry from HPD:Help Desk based on Remedy Login ID
    entry = @@remedy_forms['HPD:Help Desk'].find_entries(
      :single,
      :conditions => [%|'Incident Number' = "#{@parameters['incident_number']}"|],
      :fields     => :all
    )
    if entry.nil?
      raise(%|Could not find entry on HPD:Help Desk with 'Incident Number'="#{@parameters['incident_number']}"|)
    end
	
	priority=nil
	slm_status=nil
	service_type=nil
	status=nil
  status_reason=nil
	reported_source=nil
	impact=nil
	urgency=nil
	
	if !entry['Priority'].nil?
		priority=entry['Priority'].value
	end
	if !entry['SLM Status'].nil?
		slm_status = entry['SLM Status'].value
	end
	if !entry['Service Type'].nil?
		service_type = entry['Service Type'].value
	end
	if !entry['Status'].nil?
		status = entry['Status'].value
	end
  if !entry['Status_Reason'].nil?
    status_reason = entry['Status_Reason'].id
  end
	if !entry['Reported Source'].nil?
		reported_source = entry['Reported Source'].value
	end
	if !entry['Impact'].nil?
		impact = entry['Impact'].value
	end
	if !entry['Urgency'].nil?
		urgency = entry['Urgency'].value
	end
	
    # Build the results to be returned by this handler
    results = <<-RESULTS
    <results>
        <result name="Direct Contact Person ID">#{escape(entry['Direct Contact Person ID'])}</result>
        <result name="Direct Contact Department">#{escape(entry['Direct Contact Department'])}</result>
        <result name="Direct Contact Organization">#{escape(entry['Direct Contact Organization'])}</result>
        <result name="Direct Contact First Name">#{escape(entry['Direct Contact First Name'])}</result>
        <result name="Direct Contact Last Name">#{escape(entry['Direct Contact Last Name'])}</result>
        <result name="Direct Contact Company">#{escape(entry['Direct Contact Company'])}</result>
        <result name="Vendor Resolved Date">#{escape(entry['Vendor Resolved Date'])}</result>
        <result name="Vendor Responded On">#{escape(entry['Vendor Responded On'])}</result>
        <result name="Priority">#{escape(priority)}</result>
        <result name="SLM Status">#{escape(slm_status)}</result>
        <result name="Service Type">#{escape(service_type)}</result>
        <result name="Next Target Date">#{escape(entry['Next Target Date'])}</result>
        <result name="Resolution Category">#{escape(entry['Resolution Category'])}</result>
        <result name="Reported to Vendor">#{escape(entry['Reported to Vendor'])}</result>
        <result name="Original Incident Number">#{escape(entry['Original Incident Number'])}</result>
        <result name="Generic Categorization Tier 1">#{escape(entry['Generic Categorization Tier 1'])}</result>
        <result name="Owner">#{escape(entry['Owner'])}</result>
        <result name="Vendor Ticket Number">#{escape(entry['Vendor Ticket Number'])}</result>
        <result name="Status">#{escape(status)}</result>
        <result name="Owner Support Company">#{escape(entry['Owner Support Company'])}</result>
        <result name="Owner Group">#{escape(entry['Owner Group'])}</result>
        <result name="Assigned Group Shift Name">#{escape(entry['Assigned Group Shift Name'])}</result>
        <result name="Assigned Support Company">#{escape(entry['Assigned Support Company'])}</result>
        <result name="Assignee">#{escape(entry['Assignee'])}</result>
        <result name="Assigned Group">#{escape(entry['Assigned Group'])}</result>
        <result name="Reported Source">#{escape(reported_source)}</result>
        <result name="Incident Number">#{escape(entry['Incident Number'])}</result>
        <result name="Entry ID">#{escape(entry['Entry ID'])}</result>
        <result name="Priority Weight">#{escape(entry['Priority Weight'])}</result>
        <result name="Impact">#{escape(impact)}</result>
        <result name="Urgency">#{escape(urgency)}</result>
        <result name="Resolution">#{escape(entry['Resolution'])}</result>
        <result name="Detailed Decription">#{escape(entry['Detailed Decription'])}</result>
        <result name="Contact Company">#{escape(entry['Contact Company'])}</result>
        <result name="Person ID">#{escape(entry['Person ID'])}</result>
        <result name="Categorization Tier 3">#{escape(entry['Categorization Tier 3'])}</result>
        <result name="Categorization Tier 2">#{escape(entry['Categorization Tier 2'])}</result>
        <result name="Categorization Tier 1">#{escape(entry['Categorization Tier 1'])}</result>
        <result name="First Name">#{escape(entry['First Name'])}</result>
        <result name="Last Name">#{escape(entry['Last Name'])}</result>
        <result name="Organization">#{escape(entry['Organization'])}</result>
        <result name="Company">#{escape(entry['Company'])}</result>
        <result name="Description">#{escape(entry['Description'])}</result>
        <result name="Direct Contact Internet E-mail">#{escape(entry['Direct Contact Internet E-mail'])}</result>
        <result name="Status_Reason">#{escape(status_reason)}</result>
        <result name="Site">#{escape(entry['Site'])}</result>
        <result name="Product Model/Version">#{escape(entry['Product Model/Version'])}</result>
        <result name="Manufacturer">#{escape(entry['Manufacturer'])}</result>
        <result name="Product Name">#{escape(entry['Product Name'])}</result>
        <result name="Department">#{escape(entry['Department'])}</result>
        <result name="Product Categorization Tier 3">#{escape(entry['Product Categorization Tier 3'])}</result>
        <result name="Product Categorization Tier 2">#{escape(entry['Product Categorization Tier 2'])}</result>
        <result name="Product Categorization Tier 1">#{escape(entry['Product Categorization Tier 1'])}</result>
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