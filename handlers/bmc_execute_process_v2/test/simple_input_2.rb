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
    'command'                 => 'Application-Get-Form-Name Incidents',
    'await_server_response'   => 'Yes'
  },
  'task' => {
    'Deferral Token' => 'KSKineticTaskTestDeferralToken'
  }
}
