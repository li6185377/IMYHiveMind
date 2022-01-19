Pod::Spec.new do |s|
  s.name             = 'MobA'
  s.version          = '1.0'
  s.summary          = 'IMYHiveMind Demo: MobA.'
  s.homepage         = 'https://github.com/li6185377/IMYHiveMind'
  
  s.license          = "MIT"
  s.author           = { 'Jianghuai Li' => 'li6185377@163.com' }
  s.source           = { :git => 'https://github.com/li6185377/IMYHiveMind.git', :tag => '1.0' }
  
  s.requires_arc = true
  s.ios.deployment_target = '9.0'
  
  s.source_files = '*.{h,m}'

  s.dependency 'IMYHiveMind'

end
