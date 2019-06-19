require 'rexml/document'
require 'ars_models'

class BmcItsm7ChangeRetrieveV1

	# Prepare for execution by pre-loading Ars form definitions, building Hash
	# objects for necessary values, and validating the present state.  This method
	# sets the following instance variables:
	# * @input_document - A REXML::Document object that represents the input Xml.
	# * @debug_logging_enabled - A Boolean value indicating whether logging should
	#   be enabled or disabled.
	# * @parameters - A hash of supplied parameters. For this handle it is just the change_number
	#
	# This is a required method that is automatically called by the Kinetic Task Engine.
	#
	# ==== Parameters
	# * +input+ - The String of Xml that was built by evaluating the node.xml
	#   handler template.
	def initialize(input)
		# Set the input document attribute
		@input_document = REXML::Document.new(input)
		
		# Initialize the handler and pre-load form definitions using the credentials
		# supplied by the task info items.
		preinitialize_on_first_load(@input_document, ['CHG:Infrastructure Change'])
		
		# Determine if debug logging is enabled.
		@debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
		puts("Logging enabled.") if @debug_logging_enabled

		# Store parameters in the node.xml in a hash attribute named @parameters.
		@parameters = {}
		REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
			@parameters[node.attribute('name').value] = node.text
		end
		
		@search_by_field = case @parameters['search_by']
		when 'Instance ID'
		  "InstanceID"
		when 'Infrastructure Change ID'
		  "Infrastructure Change ID"
		else
		  raise(%|The value "#{@parameters['search_by']}" is not a valid value for the Search By parameter.|)
		end
		
		puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled	
	end
  
	# This is a required method that is automatically called by the Kinetic Task
	# Engine.
	#
	# ==== Returns
	# An Xml formatted String representing the return variable results.
	def execute()
	
		# Retrieve a single entry from CHG:Infrastructure Change based on Remedy Login ID
		entry = @@remedy_forms['CHG:Infrastructure Change'].find_entries(
		  :single,
		  :conditions => [%|'#{@search_by_field}' = "#{@parameters['search_value']}"|],
		  :fields     => :all
		)
		if entry.nil?
		  raise(%|Could not find entry on CHG:Infrastructure Change with '#{@search_by_field}'="#{@parameters['search_value']}"|)
		end
		

		#For backwards compability with ArsModels prior to v2 as prior versions do not have a .to_s method for the EnumFieldValue class.
		#Only Enum & non-remedy types are included in the temp hash of field values.
		hash_entry = {}
		entry.to_h.each do |key, value|
			if value.is_a? ArsModels::FieldValues::EnumFieldValue
				hash_entry[key] = value.value
			elsif !entry[key].is_a? ArsModels::FieldValues
				hash_entry[key] = value
			end
		end

		# Build the results to be returned by this handler
		results = <<-RESULTS
		<results>
			<result name="Actual Start Date">#{escape(hash_entry['Actual Start Date'])}</result>
			<result name="Actual End Date">#{escape(hash_entry['Actual End Date'])}</result>
			<result name="Change Timing">#{escape(hash_entry['Change Timing'])}</result>
			<result name="Change Type">#{escape(hash_entry['Change Type'])}</result>
			<result name="Company">#{escape(hash_entry['Company'])}</result>
			<result name="Company3">#{escape(hash_entry['Company3'])}</result>
			<result name="Completed Date">#{escape(hash_entry['Completed Date'])}</result>
			<result name="Description">#{escape(hash_entry['Description'])}</result>
			<result name="Detailed Description">#{escape(hash_entry['Detailed Description'])}</result>
			<result name="Earliest Start Date">#{escape(hash_entry['Earliest Start Date'])}</result>
			<result name="First Name">#{escape(hash_entry['First Name'])}</result>
			<result name="Impact">#{escape(hash_entry['Impact'])}</result>
			<result name="Last Name">#{escape(hash_entry['Last Name'])}</result>
			<result name="Location Company">#{escape(hash_entry['Location Company'])}</result>
			<result name="Risk Level">#{escape(hash_entry['Risk Level'])}</result>
			<result name="Scheduled End Date">#{escape(hash_entry['Scheduled End Date'])}</result>
			<result name="Scheduled Start Date">#{escape(hash_entry['Scheduled Start Date'])}</result>
			<result name="Status">#{escape(hash_entry['Change Request Status'])}</result>
			<result name="SRID">#{escape(hash_entry['SRID'])}</result>
			<result name="SRInstanceID">#{escape(hash_entry['SRInstanceID'])}</result>
			<result name="SRMSAOIGuid">#{escape(hash_entry['SRMSAOIGuid'])}</result>
			<result name="Submitter">#{escape(hash_entry['Submitter'])}</result>
			<result name="Support Group Name">#{escape(hash_entry['Support Group Name'])}</result>
			<result name="Support Organization">#{escape(hash_entry['Support Organization'])}</result>
			<result name="Urgency">#{escape(hash_entry['Urgency'])}</result>
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
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end