module Rcal
  class Calendar
    attr_reader :id, :name, :color, :timezone, :description, :access_role

    WRITABLE_ROLES = %w[owner writer].freeze

    def initialize(
      id:,
      name:,
      color: nil,
      timezone: nil,
      description: nil,
      access_role: nil,
      primary: false,
      selected: false
    )
      @id = id
      @name = name
      @color = color
      @timezone = timezone
      @description = description
      @access_role = access_role
      @primary = primary
      @selected = selected
    end

    def owner?
      @access_role == "owner"
    end

    def writable?
      WRITABLE_ROLES.include?(@access_role)
    end

    def primary?
      !!@primary
    end

    def selected?
      !!@selected
    end

    def ==(other)
      return false unless other.is_a?(Calendar)

      @id == other.id
    end

    def eql?(other)
      self == other
    end

    def hash
      @id.hash
    end

    def to_s
      @name
    end
  end
end
