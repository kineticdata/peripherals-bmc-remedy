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
    'command'                 => 'Application-Delete-Entry KS_SRV_CustomerSurvey_base REQ000000002520',
    'command'                 => 'Application-Query-Delete-Entry KS_SRV_CustomerSurvey_base \'179\' = "AG005056960001ipJFUgF33vDgcNcF"',
    'await_server_response'   => 'Yes'
  },
  'task' => {
    'Deferral Token' => 'KSKineticTaskTestDeferralToken'
  }
}
