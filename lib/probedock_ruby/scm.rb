require 'ostruct'
require File.join(File.dirname(__FILE__), 'configurable.rb')

module ProbeDockProbe
  class ScmRemoteUrl
    include Configurable

    configurable({
      fetch: :string,
      push: :string
    })
  end

  class ScmRemote
    include Configurable

    configurable({
      name: :string,
      ahead: :integer,
      behind: :integer,
      url: ScmRemoteUrl
    })
  end

  class Scm
    include Configurable

    configurable({
      name: :string,
      version: :string,
      dirty: :boolean,
      remote: ScmRemote
    })
  end
end
