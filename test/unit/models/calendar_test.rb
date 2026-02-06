require "test_helper"
require "rcal/models/calendar"

module Rcal
  class CalendarTest < Minitest::Test
    # Basic attributes

    def test_has_id
      calendar = Calendar.new(id: "primary", name: "Personal")

      assert_equal "primary", calendar.id
    end

    def test_has_name
      calendar = Calendar.new(id: "primary", name: "Personal")

      assert_equal "Personal", calendar.name
    end

    def test_has_color
      calendar = Calendar.new(id: "primary", name: "Personal", color: "#4285f4")

      assert_equal "#4285f4", calendar.color
    end

    def test_color_defaults_to_nil
      calendar = Calendar.new(id: "primary", name: "Personal")

      assert_nil calendar.color
    end

    def test_has_timezone
      calendar = Calendar.new(id: "primary", name: "Personal", timezone: "America/New_York")

      assert_equal "America/New_York", calendar.timezone
    end

    def test_timezone_defaults_to_nil
      calendar = Calendar.new(id: "primary", name: "Personal")

      assert_nil calendar.timezone
    end

    def test_has_description
      calendar = Calendar.new(id: "primary", name: "Personal", description: "My personal calendar")

      assert_equal "My personal calendar", calendar.description
    end

    # Access role

    def test_has_access_role
      calendar = Calendar.new(id: "primary", name: "Personal", access_role: "owner")

      assert_equal "owner", calendar.access_role
    end

    def test_owner_predicate
      calendar = Calendar.new(id: "primary", name: "Personal", access_role: "owner")

      assert calendar.owner?
    end

    def test_not_owner_when_reader
      calendar = Calendar.new(id: "primary", name: "Personal", access_role: "reader")

      refute calendar.owner?
    end

    def test_writable_when_owner
      calendar = Calendar.new(id: "primary", name: "Personal", access_role: "owner")

      assert calendar.writable?
    end

    def test_writable_when_writer
      calendar = Calendar.new(id: "primary", name: "Personal", access_role: "writer")

      assert calendar.writable?
    end

    def test_not_writable_when_reader
      calendar = Calendar.new(id: "primary", name: "Personal", access_role: "reader")

      refute calendar.writable?
    end

    def test_not_writable_when_free_busy_reader
      calendar = Calendar.new(id: "primary", name: "Personal", access_role: "freeBusyReader")

      refute calendar.writable?
    end

    # Primary calendar

    def test_primary_predicate
      calendar = Calendar.new(id: "primary", name: "Personal", primary: true)

      assert calendar.primary?
    end

    def test_not_primary_by_default
      calendar = Calendar.new(id: "work@example.com", name: "Work")

      refute calendar.primary?
    end

    # Selected/visible

    def test_selected_predicate
      calendar = Calendar.new(id: "primary", name: "Personal", selected: true)

      assert calendar.selected?
    end

    def test_not_selected_by_default
      calendar = Calendar.new(id: "primary", name: "Personal")

      refute calendar.selected?
    end

    # Equality

    def test_equality_based_on_id
      cal1 = Calendar.new(id: "primary", name: "Personal")
      cal2 = Calendar.new(id: "primary", name: "Different Name")

      assert_equal cal1, cal2
    end

    def test_not_equal_with_different_id
      cal1 = Calendar.new(id: "primary", name: "Personal")
      cal2 = Calendar.new(id: "work@example.com", name: "Personal")

      refute_equal cal1, cal2
    end

    # To string

    def test_to_s_returns_name
      calendar = Calendar.new(id: "primary", name: "Personal")

      assert_equal "Personal", calendar.to_s
    end
  end
end
