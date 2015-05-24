Pod::Spec.new do |s|
s.name = 'RequestKit'
s.version = '0.1.6'
s.license = 'MIT'
s.summary = 'Easy Request'
s.homepage = 'http://www.muukii.me/'
s.social_media_url = 'http://twitter.com/muukii0803'
s.authors = { 'Muukii' => 'muukii.muukii@gmail.com' }
s.source = { :git => 'https://github.com/muukii0803/RequestKit.git', :tag => s.version }
s.dependency 'Alamofire'

s.ios.deployment_target = '8.0'
s.osx.deployment_target = '10.10'

s.source_files = 'RequestKit/Source/*.swift'

s.requires_arc = true
end
