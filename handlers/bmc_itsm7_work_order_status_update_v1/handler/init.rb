require File.expand_path(File.join(File.dirname(__FILE__), 'ar_utility'))

class BmcItsm7WorkOrderStatusUpdateV1 < ArUtility
  # This class is just a wrapper around the parent class, ArUtility.
  # When the task handler calls this class, it actually calls the required
  # initialize and execute methods on the ArUtility class.
  #
  # The ArUtility class, in turn, is completely driven by the node.xml
  # and info.xml files.
  #
end
