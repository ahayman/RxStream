Pod::Spec.new do |s|

  s.name = "RxStream"
  s.version = "2.1.1"
  s.summary = "Simple React in Swift"
  s.description  = <<-DESC
    RxStream is a simple React framework for Swift that seeks to integrate well into existing language paradigms instead of replacing them.
                   DESC
  s.homepage = "https://github.com/ahayman/RxStream"
  s.license = "MIT"
  s.author = { "Aaron Hayman" => "aaron@flexile.co" }

  s.ios.deployment_target = '8.1'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'
  s.source = { :git => "https://github.com/ahayman/RxStream.git", :tag => "#{s.version}" }

  s.source_files  = "RxStream/**/*.swift"
end
