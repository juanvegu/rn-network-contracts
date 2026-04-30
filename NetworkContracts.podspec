Pod::Spec.new do |s|
  s.name             = 'NetworkContracts'
  s.version          = '1.0.0'
  s.summary          = 'Shared network contracts for Scotia RN modules.'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'Scotiabank Chile' => '' }
  s.homepage         = 'https://github.com/juanvegu/rn-network-contracts'
  s.platforms        = { :ios => '15.1' }
  s.swift_version    = '5.9'
  s.source           = { :git => 'https://github.com/juanvegu/rn-network-contracts.git', :tag => s.version }
  s.static_framework = true

  s.source_files     = 'Sources/NetworkContracts/**/*.swift'
end
