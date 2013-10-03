require "minitest/autorun"

module MiniTest::Assertions
  def assert_link(obj, msg = nil)
    msg = message(msg) { "Expected #{mu_pp(obj)} to be a link." }

    assert_includes obj, "<a",    msg
    assert_includes obj, "</a>",  msg
    assert_includes obj, "href=", msg
  end

  def refute_link(obj, msg = nil)
    msg = message(msg) { "Expected #{mu_pp(obj)} to not be a link." }

    refute_includes obj, "<a",    msg
    refute_includes obj, "</a>",  msg
    refute_includes obj, "href=", msg
  end

  def assert_remote_link(obj, msg=nil)
    msg = message(msg) { "Expected #{mu_pp(obj)} to be a remote link." }
    assert_link(obj)
    assert_includes obj, 'data-remote="true"'
  end

  def refute_remote_link(obj, msg=nil)
    msg = message(msg) { "Expected #{mu_pp(obj)} to not be a remote link." }

    refute_link(obj, msg)
    refute_includes obj, 'data-remote="true"', msg
  end

  def assert_link_to(exp, act, msg=nil)
    msg = message(msg) {
      "Expected #{mu_pp(act)} to be a link to #{mu_pp(exp)}."
    }

    assert_includes act, exp, msg
  end

  def refute_link_to(exp, act, msg=nil)
    msg = message(msg) {
      "Expected #{mu_pp(act)} to not be a link to #{mu_pp(exp)}."
    }

    refute_includes act, exp, msg
  end

  def assert_icon_for(exp, act, msg=nil)
    msg = message(msg) {
      "Expected #{mu_pp(act)} class attribute to be set to icon-#{mu_pp(exp)}."
    }

    assert_includes act, "icon-#{exp}", msg
  end

  def refute_icon(obj, msg=nil)
    msg = message(msg) {
      "Expected #{mu_pp(act)} class attribute to not be set to icon-#{mu_pp(exp)}."
    }

    refute_includes act, "icon-#{exp}", msg
  end
end

# String.infect_an_assertion :assert_link, :must_be_link
# String.infect_an_assertion :assert_remote_link, :must_be_remote_link