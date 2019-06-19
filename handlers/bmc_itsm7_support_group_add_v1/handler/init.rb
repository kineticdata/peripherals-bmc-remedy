require 'rexml/document'
require 'ars_models'

class BmcItsm7SupportGroupMemberAddV1
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
    preinitialize_on_first_load(
      @input_document,
      [
        'CTM:Support Group', 'CTM:Support Group Association', 'CTM:People'
      ]
    )
    
    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled
    
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled
	
	    # Retrieve the list of field values.
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
    puts("Field Values:#{@field_values.inspect}") if @debug_logging_enabled
	
  end
  
  # Retrieves a record from CTM:People using the remedy_login_id parameter.  If
  # there is an alternate approval assigned, it retrives the CTM:People record 
  # associated to the alternate approver's remedy login id.  Alternate approvers
  # are determinded using the get_approver() helper function.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.  
  def execute()
  
	person = @@remedy_forms['CTM:People'].find_entries(
	  :single,
	  :conditions => [%|'4' = "#{@parameters['assignee_id']}" |],
	  :fields => ['Person ID', 'Full Name', 'Support Staff']
	)
	
	if person.nil?
	raise "No matching entries in the CTM:People form for the given id [#{@parameters['assignee_id']}]" 
	end
	
	if person['Support Staff'] == "No"
	raise "[#{@parameters['assignee_id']}] is not support staff and cannot be added to a support group"
	else 
	@field_values['Person ID'] = person['Person ID']
	@field_values['Full Name'] = person['Full Name']
	end

	group = @@remedy_forms['CTM:Support Group'].find_entries(
	  :single,
	  :conditions => [%|'Company' = "#{@parameters['support_company']}" AND 'Support Organization' = "#{@parameters['support_org']}" AND 'Support Group Name' = "#{@parameters['support_group_name']}" |],
	  :fields => ['Support Group ID']
	)
	
	if group.nil?
	raise "No matching entries in the CTM:Support Group form for the given support group [#{@parameters['support_company']}, #{@parameters['support_org']}, #{@parameters['support_group_name']}]" 
	else
	@field_values['Support Group ID'] = group['Support Group ID']
	end

	puts("Final Field Values:#{@field_values.inspect}") if @debug_logging_enabled
	
	entry = @@remedy_forms['CTM:Support Group Association'].create_entry!(
      :field_values => @field_values,
      :fields       => ['Support Group Association ID']
    )   


	
    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Support Group Association ID">#{escape(entry['Support Group Association ID'])}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled
    return results
 
  end
  
  ##############################################################################
  # BMC ITSM7 Approver Lookup helper functions
  ##############################################################################

  # Retrieves the remedy login id for the available approver by recursively searching
  # for alternate approvers until an approver is found without any current alternates.
  #
  # Raises an exception if there was a loop detected in the current approver chain.
  #
  # ==== Parameters
  # * remedy_login_id (String) - The remedy login id of the potential approver.
  # * previous_login_ids (Array) - An array of remedy login ids that tracks the
  #   login ids that are already in the current approver chain, this is used to
  #   detect loops in the approver chain.
  #
  # ==== Returns
  # A String representing the field id of the KS_SRV_CustomerSurveyResults_join
  # "answer viewer" field that stores the first 255 characters of the associated
  # question.
  def get_approver(remedy_login_id, previous_login_ids = [])
    # Check for a loop using the previous_login_ids array.
    if previous_login_ids.member?(remedy_login_id)
      raise("A loop was detected in the chain of alternate approvers.")
    end
    # Query the AP:Alternate form with the given remedy login id to retrieve any
    # alternate approvers.
    entries = @@remedy_forms['AP:Alternate'].find_entries(
      :all,
      :conditions => [%|'2' = "#{remedy_login_id}" AND '7' = "Current"|],
      :fields     => ['Alternate']
    )
    # If no alternate approvers are found, return the current remedy login id as
    # the available approver.  Else make a recursive call to get_approver() with
    # the alternate approver's remedy login id.
    if entries.empty?
      remedy_login_id
    else
      get_approver(entries.first['Alternate'], previous_login_ids << remedy_login_id)
    end
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