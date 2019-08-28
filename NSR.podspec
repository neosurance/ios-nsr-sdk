Pod::Spec.new do |s|
  s.name             = 'NSR'
  s.version          = '2.2.12'
  s.summary          = 'Collects info from device sensors and from the hosting app'

  s.description      = <<-DESC
Neosurance SDK - Collects info from device sensors and from the hosting app - Exchanges info with the AI engines - Sends the push notification - Displays a landing page - Displays the list of the purchased policies
                       DESC

  s.homepage         = 'https://github.com/neosurance/ios-sdk2.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Neosurance' => 'info@neosurance.eu' }
  s.source           = { :git => 'https://github.com/neosurance/ios-sdk2.git', :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.source_files = 'NSR/Classes/**/*'
  s.resource_bundles = {
      'NSR' => ['NSR/Assets/*.*']
  }
  s.dependency 'AFNetworking'
end
