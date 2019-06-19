require 'rexml/document'
require 'ars_models'

class BmcItsm7PersonCreateV1
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(@input_document, ['SIT:Site', 'CTM:People', 'CTM:People WorkLog'])

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled

    # Store field values in the node.xml in a hash attribute named @field_values.
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/field_values/field_value').each do |node|
	  if (!node.text.nil?)
		@field_values[node.attribute('name').value] = node.text
	  end
    end
    puts("Field Values: #{@field_values.inspect}") if @debug_logging_enabled
  end
  
  # Uses the Remedy Login ID to retrieve a single entry from the ITSM v7.x
  # CTM:People form.  Then updates the person record given the field values 
  # and it also creates a CTM:People WorkLog record related to it that
  # audits the modification.
  def execute()
    # Retrieve a single entry from SIT:Site based on provided site
    siteEntry = @@remedy_forms['SIT:Site'].find_entries(
      :single,
      :conditions => [%|'Site' = "#{@parameters['site']}"|],
      :fields => :all
    )

    # Raise error if unable to locate the entry
    raise("No matching entry on the SIT:Site form for the given site [#{@parameters['site']}]") if siteEntry.nil?

    #Get values out of Site into fields
	@field_values["Site ID"] =  siteEntry["Site ID"]
	@field_values["Site City"] =  siteEntry["City"]
	@field_values["Site Country"] =  siteEntry["Country"]
	@field_values["Site State Province"] =  siteEntry["State Province"]
	@field_values["Site Street"] =  siteEntry["Street"]
	@field_values["Site Zip/Postal Code"] =  siteEntry["Zip/Postal Code"]
	@field_values["Time Zone"] =  siteEntry["Time Zone"]
	
	@create = 1
	begin
	# Create the CTM:People record using the @field_values hash
    # that was built up.  Pass 'Person ID' and 'InstanceId' to the fields
    # argument because these fields will be used in the results xml.
    entry = @@remedy_forms['CTM:People'].create_entry!(
      :field_values => @field_values,
      :fields       => ['Person ID']
    )
	rescue  Exception => e
		puts("Exception: #{e.message}") if @debug_logging_enabled
		puts("END OF EXCEPTION MESSAGE") if @debug_logging_enabled
		if e.message.include?("is already in use, please choose another Login ID")
			 entry = @@remedy_forms['CTM:People'].find_entries(
			  :single,
			  :conditions => [%|'Remedy Login ID' = "#{@parameters['remedy_login_id']}"|],
			  :fields => ['Person ID']
			)
			@create = 0
		end
	end
	
    # Create a notes string that will be stored within the audit record.  It
    # contains the author of the modifications as well as details about each of
    # the modified values.
    notes = "The CTM:People record was created by #{@parameters['author']}"
    @field_values.each do |field_id, value|
      notes << "\nfield '#{field_id}' was entered as '#{value}'"
    end

    # If any of the values were we checked are to be modified we save the
    # CTM:People record.  Then we create an entry in CTM:People WorkLog to audit
    # this modification.
    if !entry.nil? && @create == 1
      @@remedy_forms['CTM:People WorkLog'].create_entry!(:field_values => {
        'Person ID'            => entry.id,
        'Description'          => 'Created by BmcItsm7PersonCreate handler.',
        'Work Log Type'        => 'General Information',
        'Detailed Description' => notes,
        'Work Log Submitter'   => @parameters['author']
        },
        :fields => [])
	elsif @create == 0
		puts("Did not create new user, login ID Already in use: #{@parameters['remedy_login_id']}") if @debug_logging_enabled
    elsif entry.nil?
		# Raise error if unable to create the entry
		raise("Unable to create people record for [#{@parameters['remedy_login_id']}]")
	end
    
	
        # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Person ID">#{escape(entry['Person ID'])}</result>
     </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled
 #puts("Results: \n#{results}")

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