Pod::Spec.new do |s|
  s.name             = 'IMYHiveMind' 
  s.version          = '1.0'
  s.summary          = 'IMYHiveMind is a kind of modular programming method.'
  s.description      = 'Developer can use IMYHiveMind make iOS programming easier'
  
  s.homepage         = 'https://github.com/li6185377/IMYHiveMind'
  s.license          = "MIT"
  s.author           = { 'Jianghuai Li' => 'li6185377@163.com' }

  s.source           = { :git => 'https://github.com/li6185377/IMYHiveMind.git', :tag => '1.0' }
  
  s.requires_arc = true
  s.ios.deployment_target = '9.0'

  s.source_files = 'Source/*.{h,m}'
  
end
