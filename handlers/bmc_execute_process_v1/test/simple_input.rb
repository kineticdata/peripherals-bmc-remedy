{
  'info' => {
    'server'         => '',
    'username'       => '',
    'password'       => '',
    'port'           => '',
    'prognum'        => '',
    'authentication' => '',
    'enable_debug_logging' => "Yes"
  },
  'parameters' => {
    'command'                 => 'Application-Command Approval "Add-Sig"  -s "CHG:Infrastructure Change" -e CRQ000000000104 -t "Change Level IA - Review" -o "Ian" -1 1  -2 999',
    'await_server_response'   => 'Yes',
  },
  'task' => {
    'Deferral Token' => 'KSKineticTaskTestDeferralToken'
  }
}