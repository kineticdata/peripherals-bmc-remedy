# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

# Define the handler class which should:
#  * Be named in the format <GROUP><ITEM><ACTION>HandlerV<VERSION>
#  * Include an initialize method that takes a single String of XML.
#  * Include an execute method that returns XML in the expected format
class BmcItsm7ChangeStatusUpdateV1



  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler based on the task info items.  Since this likely
    # won't change and is relatively expensive to execute, we only call the
    # method once and maintain the values between handler executions.  This same
    # strategy can be used to help improve handler performance with other logic
    # that is only dependent on info items.
    preinitialize_on_first_load(@input_document, 'CHG:Infrastructure Change')
		
	# Bring in parameters
    @default_web_server = get_parameter_value(@input_document, 'default_web_server')
  
	
	#Initialize IncidnetID
	@ChangeID = get_field_value(@input_document, 'ChangeID')
	#puts @ChangeID
	
	# Initialize the field values hash and Set Status & Status Reason
    #puts REXML::XPath.first(@input_document, "/handler/fields/field[@name='#{'Status'}']").text
	@field_values = {}
	@field_values['Change Request Status'] = get_field_value(@input_document, 'Status') 
	@field_values['Status Reason'] = get_field_value(@input_document, 'Status_Reason') 
	#puts @field_values
	
  end

  def execute()
	# Create the entry using the ArsModels form setup the first time this
    # handler is executed.  The :field_values parameter takes a Hash of field
    # names to value mappings (which was built in the #initialize method).  The
    # :fields parameter is an optional Array of field values to return with the
    # entry.  By default (when the :fields parameter is omitted), all field
    # values are returned.  For large forms, the performance gained by
    # specifying a smaller subset of fields can be significant.
    entry = @@remedy_form.find_entries(
      # Retrieve a single record; this will throw an error if 0 or more than 1 record is found
      :single,
      # Set the conditions for retrieval
	  
	  :conditions => [%|'1000000182'="#{@ChangeID}"|]
    )

	raise "Unable to retrieve record for id #{@ChangeID}" if entry.nil?
	
	# Update customer survey base entry
    @@remedy_form.update_entry!(
	  entry, :field_values => @field_values
    )

    # Return the results
    results = <<-RESULTS
    <results>
      <result name="Entry ID">#{entry.id}</result>
    </results>
    RESULTS
	  #puts results
	  return results
  end


    
   
  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_name)
    # Unless this method has already been called
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries
      @@remedy_context = ArsModels::Context.new(
        :server => get_info_value(input_document, 'server'),
        :username => get_info_value(input_document, 'username'),
        :password => get_info_value(input_document, 'password'),
        :port => get_info_value(input_document, 'port'),
        :prognum => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )

      # Initialize the remedy form that represents the HPD Helpdesk schema.
      @@remedy_form = ArsModels::Form.find(
        form_name, :context => @@remedy_context
      )

      # Store that we are preinitialized so that this method is not called a second time
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
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] }
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

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_parameter_value(document, name)
    # Retrieve the XML node representing the desird info value
    parameter_element = REXML::XPath.first(document, "/handler/parameters/parameter[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    parameter_element.nil? ? nil : parameter_element.text
  end
  
  def get_field_value(document, name)
    # Retrieve the XML node representing the desird info value
    parameter_element = REXML::XPath.first(document, "/handler/fields/field[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    parameter_element.nil? ? nil : parameter_element.text
  end
end