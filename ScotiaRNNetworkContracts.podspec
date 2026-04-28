Pod::Spec.new do |s|
  s.name             = 'ScotiaRNNetworkContracts'
  s.version          = '1.0.0'
  s.summary          = 'Shared NetworkProvider contracts for Scotia RN modules.'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Scotiabank Chile' => '' }
  s.homepage         = ''
  s.platforms        = { :ios => '15.1' }
  s.swift_version    = '5.9'
  s.source           = { :git => 'https://github.com/juanvegu/rn-network-contracts.git', :branch => 'main' }
  s.static_framework = true

  s.source_files     = 'Sources/ScotiaRNNetworkContracts/**/*.swift'
end
