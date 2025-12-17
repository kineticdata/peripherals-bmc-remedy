# Load the ruby Mime Types library unless it has already been loaded.  This prevents
# multiple handlers using the same library from causing problems.
if not defined?(MIME)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, "vendor/mime-types-1.19/lib/")
  $:.unshift library_path
  # Require the library
  require "mime/types"
end

# Validate the the loaded Mime Types library is the library that is expected for
# this handler to execute properly.
if not defined?(MIME::Types::VERSION)
  raise "The Mime class does not define the expected VERSION constant."
elsif MIME::Types::VERSION != "1.19"
  raise "Incompatible library version #{MIME::Types::VERSION} for Mime Types.  Expecting version 1.19."
end

# Load the ruby Domain Name library unless it has already been loaded.  This prevents
# multiple handlers using the same library from causing problems.
if not defined?(DomainName)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, "vendor/domain_name-0.6.20240107/lib/")
  $:.unshift library_path
  # Require the library
  require "domain_name"
end

# Validate the the loaded Domain Name library is the library that is expected for
# this handler to execute properly.
if not defined?(DomainName::VERSION)
  raise "The Domain Name class does not define the expected VERSION constant."
elsif DomainName::VERSION != "0.6.20240107"
  raise "Incompatible library version #{DomainName::VERSION} for Domain Name.  Expecting version 0.6.20240107."
end

# Load the ruby HTTP Cookie library unless it has already been loaded.  This prevents
# multiple handlers using the same library from causing problems.
if not defined?(HTTP::Cookie)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, "vendor/http-cookie-1.1.0/lib/")
  $:.unshift library_path
  # Require the library
  require "http/cookie"
end

# Validate the the loaded HTTP Cookie library is the library that is expected for
# this handler to execute properly.
if not defined?(HTTP::Cookie::VERSION)
  raise "The HTTP Cookie class does not define the expected VERSION constant."
elsif HTTP::Cookie::VERSION != "1.1.0"
  raise "Incompatible library version #{HTTP::Cookie::VERSION} for HTTP Cookie.  Expecting version 1.1.0."
end

# Load the ruby HTTP Accept library unless it has already been loaded.  This prevents
# multiple handlers using the same library from causing problems.
if not defined?(HTTP::Accept)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, "vendor/http-accept-1.7.0/lib/")
  $:.unshift library_path
  # Require the library
  require "http/accept"
end

# Validate the the loaded HTTP Accept library is the library that is expected for
# this handler to execute properly.
if not defined?(HTTP::Accept::VERSION)
  raise "The HTTP Accept class does not define the expected VERSION constant."
elsif HTTP::Accept::VERSION != "1.7.0"
  raise "Incompatible library version #{HTTP::Accept::VERSION} for HTTP Accept.  Expecting version 1.7.0."
end

# Load the ruby Netrc library unless
# it has already been loaded.  This prevents multiple handlers using the same
# library from causing problems.
if not defined?(Netrc)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, "vendor/netrc-0.11.0/lib")
  $:.unshift library_path
  # Require the library
  require "netrc"
end

# Validate the the loaded rest-client library is the library that is expected for
# this handler to execute properly.
if not defined?(Netrc::VERSION)
  raise "The Netrc class does not define the expected VERSION constant."
elsif Netrc::VERSION.to_s != "0.11.0"
  raise "Incompatible library version #{Netrc::VERSION} for Netrc.  Expecting version 0.11.0."
end

# Load the ruby rest-client library (used by the Octokit library) unless
# it has already been loaded.  This prevents multiple handlers using the same
# library from causing problems.
if not defined?(RestClient)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, "vendor/rest-client-2.1.0/lib")
  $:.unshift library_path
  # Require the library
  require "rest-client"
end

# Validate the the loaded rest-client library is the library that is expected for
# this handler to execute properly.
if not defined?(RestClient.version)
  raise "The RestClient class does not define the expected VERSION constant."
elsif RestClient.version.to_s != "2.1.0"
  raise "Incompatible library version #{RestClient.version} for rest-client.  Expecting version 2.1.0."
end