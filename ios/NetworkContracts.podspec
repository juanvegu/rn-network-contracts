Pod::Spec.new do |s|
  s.name             = 'NetworkContracts'
  s.version          = '1.0.1'
  s.summary          = 'Shared network contracts for Scotia RN modules.'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Scotiabank Chile' => '' }
  s.homepage         = 'https://github.com/juanvegu/rn-network-contracts'
  s.platforms        = { :ios => '15.1' }
  s.swift_version    = '5.9'
  s.source           = { :git => 'https://github.com/juanvegu/rn-network-contracts.git', :branch => 'main' }

  s.source_files     = 'ios/Sources/NetworkContracts/**/*.swift'
end
