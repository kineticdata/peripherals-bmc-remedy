require 'rexml/document'
require 'ars_models'
require 'pp'

###############################################################################
# ArUtility -- init.rb abstract class for AR System
###############################################################################
#
# You can use this class wherever you need to perform any number of submit, 
# modify, or query operations against AR System forms.  It can handle multiple 
# forms on multiple servers, driven by action directives in the node.xml file.
#
# To use this class in a specific init.rb file, add this line to the top of
# the init.rb file:
#
# require File.expand_path(File.join(File.dirname(__FILE__), 'ar_utility'))
#
# After that, your class definition simply needs to define ArUtility as its
# parent abstract class, like this:
#
# class FooBarBazV1 < ArUtility
#
# end
#
class ArUtility
  DOC_LOCATION_ACTION = '/handler/actions/action'
  ACTION_SUBMIT = 'submit'
  ACTION_QUERY = 'query'
  ACTION_MODIFY = 'modify'
  VERSION = "0.9.8"

  # Prepare for execution by pre-loading form definitions, building array 
  # and hash objects for necessary values, and validating the present state.  
  # This method sets the following instance variables:
  #
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging 
  #     should be enabled or disabled.
  # * @filter_logging_enabled - A Boolean valued that indicates whether we
  #     should record filter logging when performing server actions.
  # * @form_field_values - An array of form/field value hashes that holds
  #     input and output field descriptions.
  # * @@remedy_contexts - A hash of context objects where the key is the
  #     server tag.
  #
  # This required method is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * input -- The rendered String output of XML, built by evaluating the 
  #   node.xml handler template.
  #
  def initialize(input)
    # Set the input document attribute.
    @input_document = REXML::Document.new(input)

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 
                                            'enable_debug_logging') == 'Yes'
    # Report the file name and version.
    spit "#{File.basename(__FILE__)} -- #{VERSION}"
    spit "--> Entering intialize method"
    spit "Here's what the @input_document looks like at runtime:" 
    spit @input_document 

    # See if optional filter logging is enabled.
    @filter_logging_enabled = get_info_value(@input_document, 
                                             'enable_filter_logging') == 'Yes'

    if (@filter_logging_enabled)
      spit "AR System filter logging enabled." 
    else
      spit "AR System filter logging is not enabled." 
    end

    # Read through the node.xml document to find server names, form names, and 
    # fields. Determine whether a field is for input or output, whether it's 
    # required, and whether a required field has a value. 
    # Then pre-initialize the forms.
    server_markers = []
    server_form_array = []

    # This form-field array uses the action sequence counter.
    @form_field_values = []

    spit "--> Entering loop over action nodes, building data structures."
    REXML::XPath.match(@input_document, DOC_LOCATION_ACTION).each do |action_node|

      # Get the action sequence.
      sequence = action_node.attribute('sequence').value.to_i
      spit "Sequence: #{sequence}."

      # Get the target server_marker. A server_marker is simply the dotted
      # prefix moniker prepended to AR server configuration items.
      server_marker = action_node.attribute('server_marker').value
      spit "Server Marker: #{server_marker}" 

      # Add to the array of server_markers.
      server_markers << server_marker
      
      # Get the current target form_name.
      form_name = action_node.attribute('form_name').value
      spit "Form Name: #{form_name}"

      # Add to the server_form_hash where key=server_marker and value=form_name
      server_form_array << { server_marker => form_name }

      # These hashes will contain name/value pairs for the fields on the form.
      input_field_hash = {}
      output_field_hash = {}

      # Iterate over the fields in this form and populate the field hashes.
      action_node.elements['fields'].each_element_with_attribute('name') do |field_node|
        field_name = field_node.attribute('name').value
        field_value = field_node.text unless field_node.text.nil?
        field_type = field_node.attribute('type').value
        field_required = field_node.attribute('required').value unless field_node.attribute('required').nil?

        # Test to see if required fields have values.
        if field_type == 'input' and field_required == 'true'
          # Create an array holder for missing required values.
          missing_values = []
          if field_value.nil? or field_value.empty? 
            # Add the field_name to the missing_value array.
            missing_values << field_name
          end

          # If there were any blank required field values, throw an exception.
          if missing_values.length > 0
            raise "The following blank node parameters are required: " +
              "#{missing_values.sort.join(', ')}"
          end
        end # of field_type test for required input fields

        # Fill temporary field hashes.
        if field_type == 'input'
          input_field_hash[field_name] = field_value
        elsif field_type == 'output'
          output_field_hash[field_name] = field_value
        end 
      end # of do loop over all action_node.elements (fields)

      # Populate the array of field hashes.
      @form_field_values[sequence] = 
      {
        :input_fields => input_field_hash,
        :output_fields => output_field_hash 
      }
    end # of do loop over each action_node
    spit "<-- Exiting loop over action nodes"

    # Pretty print the form-field mega-array.
    spit format_field_values("Form Field Structure:", @form_field_values) 

    # Remove possible dupes
    server_markers.uniq!
    spit "Pre-initializing servers and forms."
    preinitialize_on_first_load(@input_document, server_markers, server_form_array)

    spit "<-- Exiting intialize method"
  end

  # This method submits, queries, or modifies entries based on actions 
  # defined in the node.xml file.
  #
  # This required method is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An XML formatted String representing the return (:output) variable results.
  #
  def execute()
    spit "--> Entering execute method"
    # Create the XML string return object (to be added to as we go).
    results = "<results>\n"

    # Include the AR classes for logging.
    include_class 'com.remedy.arsys.api.Constants'
    include_class 'com.remedy.arsys.api.LoggingInfo'

    # Include work-around classes so we can modify entries on join forms.
    include_class 'com.remedy.arsys.api.EntryFactory'
    include_class 'com.remedy.arsys.api.EntryKey'
    include_class 'com.remedy.arsys.api.EntryID'
    include_class 'com.remedy.arsys.api.JoinEntryID'
    include_class 'com.remedy.arsys.api.NameID'

    # Initialize an array to store results from actions.  Subsequent
    # actions can refer to data retrieved and stored by previous actions.
    @action_results = []

    # Get the list of actions from node.xml and execute them.
    REXML::XPath.match(@input_document, DOC_LOCATION_ACTION).each do |action|
      # Get the string value of the action type.
      sequence =  action.attribute('sequence').value.to_i
      action_type = action.attribute('type').value
      server_marker = action.attribute('server_marker').value
      form_name = action.attribute('form_name').value

      spit "Sequence: #{sequence}"
      spit "Action Type: #{action_type}"
      spit "Server Marker: #{server_marker}"

      # If the conditional is absent, we execute the action.
      # If the conditional is present and true, we execute the action.
      # If the conditional is present and false, we skip the action.
      # If the conditional is mangled, we skip the action.
      if !action.elements['conditional'].nil?
        conditional = action.elements['conditional'].text
        spit "Conditional Statement: #{conditional}"

        # It's possible that our conditional doesn't even evaluate
        # properly. So in the event it throws an exception, we'll
        # wrap it in a rescue block.
        begin
          if (eval "#{conditional}").to_bool
            spit "The conditional is true.  Executing the action."
          else
            spit "The conditional is false.  Skipping the action."
            next
          end
        rescue
          spit "The conditional couldn't be evaluated.  Skipping the action."
          next
        end
      else
        spit "Conditional Statement: undefined. Executing the action."
      end

      # Get the underlying Java ARServerUser object.
      server_user = @@remedy_contexts[server_marker].ars_context.get_context

      # If filter logging is enabled, set it in the current context.
      if @filter_logging_enabled
        # Create a LoggingInfo object with enabled, writing to a local file.
        @logging_info = LoggingInfo.new(true, Constants.AR_DEBUG_SERVER_FILTER, 
                                    Constants.AR_WRITE_TO_FILE, 'filter.log')
        # Set the context with the LoggingInfo object
        server_user.set_logging(@logging_info)
      end

      # Perform action now
      case action_type
      when ACTION_SUBMIT
        # Submit action: 
        # Call the #create_entry! method and collect the results.
        spit "Submit Mode.  Creating entry in the #{form_name} form."
        spit "Our known action_results: #{@action_results[0].pretty_inspect}"

        # Create an input field array.
        input_field_hash = {} 

        # Iterate over the input fields to see if they need to be expanded
        @form_field_values[sequence][:input_fields].each_pair do |field_name, field_value|
          spit "Input field:  #{field_name} :: #{field_value}"
          this_field_value = nil;
          
          # Are we supposed to evaluate this field_value?
          field_node = REXML::XPath.first(action, "//fields/field[@name='#{field_name}']")

          if !field_node.attribute('eval').nil? and
            field_node.attribute('eval').value.to_bool and
            !field_value.nil?
            spit "The eval attribute is present and true."
            # Calling eval on the variable forces interpolation.
            begin
              this_field_value = eval field_value
            rescue
              # If the eval threw an exception, skip it.
              spit "Skipping value, because it wasn't evaluated."
              next # Skip it.
            end
          elsif !field_value.nil?
            this_field_value = field_value
          else
            spit "Skipping value, because it's nil."
            next # Skip it.
          end

          # Pack the array
          input_field_hash[field_name] = this_field_value 
        end

        spit "Raw input fields"
        spit @form_field_values[sequence][:input_fields].pretty_inspect
        spit input_field_hash.pretty_inspect
        spit "Processed input fields"
        spit @form_field_values[sequence][:output_fields].keys.pretty_inspect

        entry = @@remedy_forms[server_marker][form_name].create_entry!(
          :field_values => input_field_hash,
          :fields       => @form_field_values[sequence][:output_fields].keys
        )

        # Add the entry results (as a hash) to the @action_results array.
        @action_results[sequence] = { form_name => entry.to_h }
        spit "Pretty action_results" 
        spit @action_results.pretty_inspect

        # Convert returned field values to a hash, then stuff into XML.
        entry.to_h.each_pair do |ret_key, ret_value|
          spit "The key is #{ret_key}" 
          spit "The value is #{ret_value}" 
          xml_tag = nil

          # The output field "value" in node.xml is what we want to use as the 
          # XML tag in the output document.
          @form_field_values[sequence][:output_fields].each_pair do | key, value |
            if "#{key}" == "#{ret_key}"
              xml_tag = value
            end
          end

          # If there is no xml_tag, it means we didn't want any XML output.
          if !xml_tag.nil?
            results << "  <result name=\"#{xml_tag}\">"
            results << escape(ret_value)
            results << "</result>\n"
          end
        end
        # ACTION_SUBMIT has finished.

      when ACTION_QUERY
        # Query action: Search for the values by the given
        # qualification and collect the results.
        spit "Query Mode.  Searching for data in the #{form_name} form." 

        # If this action requires output for subsequent actions to continue
        # executing, set the optional 'nillable' attribute to false.
        nillable = true
        if !action.attribute('nillable').nil?
          nillable = action.attribute('nillable').value.to_bool
        end
        spit "Nillable: #{nillable}"

        # Note: You have to evaluate the value to force expansion of the 
        # substitution variables found in node.xml.  You can shield field data 
        # in the node.xml file from unwanted evaluation by wrapping it in
        # double quotes.
        query_qual = eval action.elements['qualification'].text
        spit "The query qualification is #{query_qual}" 

        entry = @@remedy_forms[server_marker][form_name].find_entries(
          :single,
          :conditions => [ query_qual ],
          :fields     => @form_field_values[sequence][:output_fields].keys
        )
        
        # Did the query return anything?
        if !entry.nil?
          spit "The query succeeded. Packing the results array."
          @action_results[sequence] = { 
            :success => true,
            form_name => entry.to_h
          }

          # Iterate over the return values and assemble results document
          entry.to_h.each_pair do |ret_key, ret_value|
            spit "The return key is #{ret_key}" 
            spit "The return value is #{ret_value}" 
            xml_tag = nil

            # The output field "value" in node.xml is what we want to use a the 
            # XML tag in the output document.
            @form_field_values[sequence][:output_fields].each_pair do | key, value |
              if "#{key}" == "#{ret_key}"
                xml_tag = value
              end
            end

            # If there is no xml_tag, it means we didn't want any XML output.
            if !xml_tag.nil?
              results << "  <result name=\"#{xml_tag}\">"
              results << escape(ret_value)
              results << "</result>\n"
            end
          end
        else
          if nillable
            # The query failed.  Mark the success Boolean as false.
            # Using this flag, actions can discover whether previous actions
            # have succeeded or failed.
            spit "The query returned no entries.  Setting :success value to false."
            @action_results[sequence] = { 
              :success => false
            }
          else
            # If the action entry in node.xml sets nillable to false,
            # then we need to halt processing.
            spit "Error:  No entries found! (nillable was set to false)"
            raise "Found no matching entries on #{form_name} where #{query_qual}"
          end
        end # of if !entry.nil?
        
        spit "Pretty action_results:"
        spit @action_results.pretty_inspect
        # ACTION_QUERY has finished.

      when ACTION_MODIFY
        # Modify action: Search for an entry using the provided qualification,
        # then modify it with the given input fields.
        spit "Modify Mode.  Updating entry in the #{form_name} form." 

        # Note: You have to evaluate the value to force expansion of the 
        # substitution variables found in node.xml.
        query_qual = eval action.elements['qualification'].text

        spit "The query qualification is #{query_qual}"

        # Find the entry.  Notice we don't need any return fields,
        # because all we need is the entry.id.
        entry = @@remedy_forms[server_marker][form_name].find_entries(
          :single,
          :conditions => [ query_qual ]
        )

        # Initialize and array to store the EntryItem values.
        entry_item_array = []

        # Iterate over the input fields
        @form_field_values[sequence][:input_fields].each_pair do |field_name, field_value|
          spit "Input field:  #{field_name} :: #{field_value}"

          # Are we supposed to evaluate this field_value?
          field_node = REXML::XPath.first(action, "//fields/field[@name='#{field_name}']")

          this_field_value = nil;

          if !field_node.attribute('eval').nil? and
            field_node.attribute('eval').value.to_bool and
            !field_value.nil?
            spit "The eval attribute is present and true."
            # Calling eval on the variable forces interpolation.
            begin
              this_field_value = eval field_value
            rescue
              # If the eval threw an exception, skip it.
              spit "Skipping value, because it wasn't evaluated."
              next # Skip it.
            end
          elsif !field_value.nil?
            this_field_value = field_value
          else
            spit "Skipping value, because it's nil."
            next # Skip it.
          end

          my_field_value = nil

          # Loop over each field in the entry form object
          entry.ars_entry.form.get_fields.each do | ars_field |

            # Act on the form field if the name matches the input field name
            if field_name == ars_field.name

              # Fill the field_value based on datatype
              case ars_field.get_datatype
              when "CHAR"
                spit "The CHAR field value will be #{this_field_value}." 
                my_field_value = Java::ComKdArsModelsData::ArsFieldValue.build_text_value(ars_field, this_field_value)

              when "ENUM"
                spit "The ENUM field value will be #{this_field_value}." 
                my_option = ars_field.get_option_by_name(this_field_value)
                spit "My option is #{my_option.get_id}" 
                my_field_value = Java::ComKdArsModelsData::ArsFieldValue.build_enum_value(ars_field, my_option.get_id.to_i)
                
              when "TIME"
                spit "The TIME field value will be #{this_field_value}." 
                my_field_value = Java::ComKdArsModelsData::ArsFieldValue.build_time_value(ars_field, this_field_value)

              when "INTEGER"
                spit "The INTEGER field value will be #{this_field_value}." 
                my_field_value = Java::ComKdArsModelsData::ArsFieldValue.build_text_value(ars_field, this_field_value)

              end # of case
            end # of key matches field name
          end # of input field loop

          # Create an EntryItem object based on the field value
          if my_field_value != nil
            entry_item = my_field_value.generateEntryItem()
            entry_item_array << entry_item
          else
            # This should not happen
            puts "[#{__LINE__}] Sorry.  The ArsFieldValue object is nil."
          end
        end

        # Create an entry using the raw API
        schema_type = entry.ars_entry.form.get_schema_type
        spit "The SchemaType is #{schema_type}" 

        my_entry_key = nil
        if schema_type == "JOIN"
          my_entry_key = EntryKey.new(NameID.new(form_name), JoinEntryID.new(entry.id))
        else
          my_entry_key = EntryKey.new(NameID.new(form_name), EntryID.new(entry.id))
        end

        my_entry = EntryFactory.getFactory().newInstance()
        my_entry.setContext(server_user)
        my_entry.setKey(my_entry_key)
        my_entry.setEntryItems(entry_item_array)
        my_entry.store()

        # This doesn't work if the target is a join form.
        #== entry.update_attributes!(@form_field_values[form_name][:input_fields])
        #
        # ACTION_MODIFY has finished.
  
      else
        spit "Warning: Unknown action type!"

      end  # of the case action type

      # Turn off filter logging.
      if @filter_logging_enabled
        @logging_info.enable(false)
        server_user.setLogging(@logging_info)
      end

    end # of the action loop
    
    # Cap off the results
    results << "</results>"
    spit "Results: \n#{results}"

    spit "<-- Exiting execute method"
    # Return the results XML document
    return results
  end # of the execute method

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # Preinitialize expensive operations that are not task node dependent (i.e.,
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  These processes will very frequently utilize task info items to 
  # do things such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, server_markers, server_form_array)
    # Unless this method has already been called...
    unless self.class.class_variable_defined?('@@preinitialized')

      # Loop over the server markers, get the info_value data, and create
      # context objects for AR System
      @@remedy_contexts = {}
      server_markers.each do |server_marker|
        spit "Creating context for server #{server_marker}." 
        my_context = ArsModels::Context.new(
          :server         => get_info_value(
            input_document, server_marker + '.hostname'),
          :username       => get_info_value(
            input_document, server_marker + '.username'),
          :password       => get_info_value(
            input_document, server_marker + '.password'),
          :port           => get_info_value(
            input_document, server_marker + '.port'),
          :prognum        => get_info_value(
            input_document, server_marker + '.prognum'),
          :authentication => get_info_value(
            input_document, server_marker + '.authentication')
        )
        # The server_marker is the key for accessing the context object.
        @@remedy_contexts[server_marker] = my_context
      end

      # Initialize the remedy forms that will be used by this handler.
      # This hash has a key that's the name of the form with a value
      # that's the form object, so at any point you can call it by name.
      # server_marker => { 
      #   form_name => form_obj,
      #   form_name => form_obj,
      #   form_name => form_obj
      # }
      @@remedy_forms = {}

      server_form_array.each do |form_def|
        form_def.each_pair do |server_marker, form_name|

          # Has this form already been initialized?
          if !@@remedy_forms[server_marker].nil? and \
             !@@remedy_forms[server_marker][form_name].nil?
            spit "#{form_name} is already initialized. Skipping."
            next
          end

          spit "Initializing form #{form_name} on server_marker #{server_marker}" 
          # The key tells us which server the form (value) belongs to.
          form_obj = ArsModels::Form.find(form_name, :context => @@remedy_contexts[server_marker])

          # Pack the hash.
          if @@remedy_forms[server_marker].nil?
            @@remedy_forms[server_marker] = {form_name => form_obj}
          else
            @@remedy_forms[server_marker].merge!({form_name => form_obj})
          end
        end
      end
      spit @@remedy_forms.pretty_inspect

      # Set a global boolean that indicates we're preinitialized so that 
      # this method isn't called twice.
      @@preinitialized = true
    end
  end # of preinitialize_on_first_load

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these types of methods can be copied and reused 
  # between handlers.
  #
  def get_info_value(document, name)
    # Retrieve the XML node representing the desired info value.
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")

    # If the desired element is nil, return nil; otherwise return the text 
    # value of the element.
    info_element.nil? ? nil : info_element.text
  end

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  #
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

  # Builds a string that is formatted specifically for the Kinetic Task log file
  # by concatenating the provided header String with each of the provided array
  # of hash elements.  The string output looks like this:
  # [HEADER]
  #   Sequence: [SEQUENCE]
  #     Type: [input_fields | output_fields]
  #       NAME: VALUE
  #       NAME: VALUE
  #       NAME: VALUE
  def format_field_values(header, field_array)
    # Starting with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    result = String.new(header)

    #hash.each do |sequence, type_hash|
    field_array.each_with_index do |type_hash, sequence|
      result << "\nSequence: #{sequence}"

      # If the node.xml implies an array with nils, skip them 
      next if type_hash.nil?
      type_hash.each_pair do |type_name, field_hash|
        result << "\n  Type: #{type_name} -- "

        field_hash.each_pair do |field_name, field_value|
          result << "\n    #{field_name}: #{field_value}"
        end
      end
    end
    return result
  end # of format_field_values 

  # This method allows us to print log messages to stdout while showing
  # current line numbers and without adding if @debug_logging_enabled
  # after every puts statement.
  def spit(log_message)
    if @debug_logging_enabled
      puts "[#{caller.first.split(":")[-2]}] #{log_message}"
    end
  end # of spit
end # of class ArUtility

# This class extends the String class to convert values to Booleans.
#
class String
  # Returns true if the incoming string looks "true".
  # Returns false if the incoming string is empty or looks "false".
  #
  # Note: Most of the time the string will be "Yes".
  #
  def to_bool
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.empty? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

