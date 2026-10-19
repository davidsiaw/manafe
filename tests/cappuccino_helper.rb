# frozen_string_literal: true

module CappuccinoHelper
  VIEW_WALK_JS = <<~JS
    function cappViews(pred) {
      var acc  = [];
      var app  = objj_msgSend(objj_getClass("CPApplication"), "sharedApplication");
      var wins = objj_msgSend(app, "windows");
      var nWin = objj_msgSend(wins, "count");
      function walk(view) {
        if (!view || !view.isa) return;
        try { if (pred(view)) acc.push(view); } catch (e) {}
        var subs = objj_msgSend(view, "subviews");
        if (!subs) return;
        var n = objj_msgSend(subs, "count");
        for (var i = 0; i < n; i++) walk(objj_msgSend(subs, "objectAtIndex:", i));
      }
      for (var w = 0; w < nWin; w++) {
        walk(objj_msgSend(objj_msgSend(wins, "objectAtIndex:", w), "contentView"));
      }
      return acc;
    }
    function cappIsKind(view, className) {
      return objj_msgSend(view, "isKindOfClass:", objj_getClass(className));
    }
    // Not isHiddenOrHasHiddenAncestor: AppKit clears that on a hidden view
    // when an ancestor is shown again (docs/cappuccino.md).
    function cappIsShown(view) {
      for (var v = view; v; v = objj_msgSend(v, "superview"))
        if (objj_msgSend(v, "isHidden")) return false;
      return true;
    }
  JS

  def wait_for_cappuccino(wait: Capybara.default_max_wait_time)
    poll("wait_for_cappuccino", wait) do
      page.evaluate_script(<<~JS)
        (function() {
          if (typeof objj_getClass !== "function") return false;
          var cls = objj_getClass("CPApplication");
          if (!cls) return false;
          var app = objj_msgSend(cls, "sharedApplication");
          return !!app && objj_msgSend(objj_msgSend(app, "windows"), "count") > 0;
        })();
      JS
    end
  end

  def cappuccino_text_values
    page.evaluate_script(<<~JS)
      (function() {
        #{VIEW_WALK_JS}
        return cappViews(function(v) { return cappIsKind(v, "CPTextField"); })
          .map(function(v) { return String(objj_msgSend(v, "stringValue")); });
      })();
    JS
  end

  def wait_for_cappuccino_text(text, wait: Capybara.default_max_wait_time)
    poll("wait_for_cappuccino_text(#{text.inspect})", wait) do
      cappuccino_text_values.include?(text)
    end
  end

  def cappuccino_button_visible?(title)
    page.evaluate_script(<<~JS, title)
      (function(wanted) {
        #{VIEW_WALK_JS}
        return cappViews(function(v) {
          return cappIsKind(v, "CPButton") &&
                 objj_msgSend(v, "title") == wanted &&
                 cappIsShown(v);
        }).length > 0;
      })(arguments[0]);
    JS
  end

  def wait_for_cappuccino_button(title, wait: Capybara.default_max_wait_time)
    poll("wait_for_cappuccino_button(#{title.inspect})", wait) do
      cappuccino_button_visible?(title)
    end
  end

  def click_cappuccino_button(title)
    result = page.execute_script(<<~JS, title)
      return (function(wanted) {
        #{VIEW_WALK_JS}
        var buttons = cappViews(function(v) {
          return cappIsKind(v, "CPButton") && objj_msgSend(v, "title") == wanted;
        });
        if (buttons.length == 0) return "no CPButton titled '" + wanted + "'";
        var target = objj_msgSend(buttons[0], "target");
        var action = objj_msgSend(buttons[0], "action");
        if (!target || !action) return "button has no target/action";
        objj_msgSend(target, action, buttons[0]);
        return "ok";
      })(arguments[0]);
    JS
    raise "click_cappuccino_button(#{title.inspect}): #{result}" unless result == 'ok'
  end

  # Clicks the CPRadio with this title, as a user would; its radio group then
  # turns the others off.
  def choose_cappuccino_radio(title)
    result = page.execute_script(<<~JS, title)
      return (function(wanted) {
        #{VIEW_WALK_JS}
        var radios = cappViews(function(v) {
          return cappIsKind(v, "CPRadio") && objj_msgSend(v, "title") == wanted;
        });
        if (radios.length == 0) return "no CPRadio titled '" + wanted + "'";
        objj_msgSend(radios[0], "performClick:", null);
        return "ok";
      })(arguments[0]);
    JS
    raise "choose_cappuccino_radio(#{title.inspect}): #{result}" unless result == 'ok'
  end

  def cappuccino_selected_radio_titles
    page.evaluate_script(<<~JS)
      (function() {
        #{VIEW_WALK_JS}
        return cappViews(function(v) {
          return cappIsKind(v, "CPRadio") && objj_msgSend(v, "state") == 1;
        }).map(function(v) { return String(objj_msgSend(v, "title")); });
      })();
    JS
  end

  # The text of every visible row of every CPOutlineView, top to bottom, as
  # its data source supplies it. Collapsed children are not rows.
  def cappuccino_outline_rows
    page.evaluate_script(<<~JS)
      (function() {
        #{VIEW_WALK_JS}
        var out = [];
        cappViews(function(v) { return cappIsKind(v, "CPOutlineView"); }).forEach(function(ov) {
          var ds = objj_msgSend(ov, "dataSource"),
              column = objj_msgSend(objj_msgSend(ov, "tableColumns"), "objectAtIndex:", 0);
          for (var i = 0; i < objj_msgSend(ov, "numberOfRows"); i++) {
            var item = objj_msgSend(ov, "itemAtRow:", i);
            out.push(String(objj_msgSend(ds, "outlineView:objectValueForTableColumn:byItem:", ov, column, item)));
          }
        });
        return out;
      })();
    JS
  end

  def wait_for_cappuccino_outline_row(text, wait: Capybara.default_max_wait_time)
    poll("wait_for_cappuccino_outline_row(#{text.inspect})", wait) do
      cappuccino_outline_rows.include?(text)
    end
  end

  # Waits until the text appears in any CPTextField, matching a substring.
  def wait_for_cappuccino_text_including(text, wait: Capybara.default_max_wait_time)
    poll("wait_for_cappuccino_text_including(#{text.inspect})", wait) do
      cappuccino_text_values.any? { |value| value.include?(text) }
    end
  end

  # Types into the editable CPTextField showing this placeholder.
  def fill_cappuccino_field(placeholder, value)
    result = page.execute_script(<<~JS, placeholder, value)
      return (function(wanted, value) {
        #{VIEW_WALK_JS}
        var fields = cappViews(function(v) {
          return cappIsKind(v, "CPTextField") && objj_msgSend(v, "isEditable") &&
                 objj_msgSend(v, "placeholderString") == wanted;
        });
        if (fields.length == 0) return "no editable CPTextField with placeholder '" + wanted + "'";
        objj_msgSend(fields[0], "setStringValue:", value);
        return "ok";
      })(arguments[0], arguments[1]);
    JS
    raise "fill_cappuccino_field(#{placeholder.inspect}): #{result}" unless result == 'ok'
  end

  # Replaces the program in the visible code editor (CodeEditor.j), as a
  # problem in Ruby, which is what the specs use.
  def fill_cappuccino_code(code)
    result = page.execute_script(<<~JS, code)
      return (function(code) {
        #{VIEW_WALK_JS}
        var editors = cappViews(function(v) {
          return cappIsKind(v, "CodeEditor") && !objj_msgSend(v, "isPlain") &&
                 cappIsShown(v);
        });
        if (editors.length == 0) return "no visible CodeEditor";
        objj_msgSend(editors[0], "setCode:language:", code, "ruby");
        return "ok";
      })(arguments[0]);
    JS
    raise "fill_cappuccino_code: #{result}" unless result == 'ok'
  end

  # Types into the box where a local code problem's output is pasted.
  def paste_cappuccino_output(text)
    result = page.execute_script(<<~JS, text)
      return (function(text) {
        #{VIEW_WALK_JS}
        var boxes = cappViews(function(v) {
          return cappIsKind(v, "CodeEditor") && objj_msgSend(v, "isPlain") &&
                 cappIsShown(v);
        });
        if (boxes.length == 0) return "no visible output box";
        objj_msgSend(boxes[0], "setCode:language:", text, null);
        return "ok";
      })(arguments[0]);
    JS
    raise "paste_cappuccino_output: #{result}" unless result == 'ok'
  end

  # The code of every visible code block in problem text (CodeBlockView).
  def cappuccino_code_blocks
    page.evaluate_script(<<~JS)
      (function() {
        #{VIEW_WALK_JS}
        return cappViews(function(v) { return cappIsKind(v, "CodeBlockView") && cappIsShown(v); })
          .map(function(v) { return String(objj_msgSend(v, "code")); });
      })();
    JS
  end

  # The program in the visible code editor, or nil without one.
  def cappuccino_code
    page.evaluate_script(<<~JS)
      (function() {
        #{VIEW_WALK_JS}
        var editors = cappViews(function(v) {
          return cappIsKind(v, "CodeEditor") && !objj_msgSend(v, "isPlain") &&
                 cappIsShown(v);
        });
        return editors.length ? String(objj_msgSend(editors[0], "code")) : null;
      })();
    JS
  end

  # Clicks into the visible code editor, for typing with real key presses
  # (page.driver.browser.action.send_keys). Waits for the editor to load.
  def click_cappuccino_code_editor
    first('.cm-content', visible: true).click
  end

  def cappuccino_main_menu_titles
    page.evaluate_script(<<~JS)
      (function() {
        var app   = objj_msgSend(objj_getClass("CPApplication"), "sharedApplication");
        var menu  = objj_msgSend(app, "mainMenu");
        if (!menu) return [];
        var items = objj_msgSend(menu, "itemArray");
        var out   = [];
        for (var i = 0; i < objj_msgSend(items, "count"); i++) {
          out.push(String(objj_msgSend(objj_msgSend(items, "objectAtIndex:", i), "title")));
        }
        return out;
      })();
    JS
  end

  def cappuccino_menu_bar_visible?
    page.evaluate_script('objj_msgSend(objj_getClass("CPMenu"), "menuBarVisible") ? true : false;')
  end

  private

  def poll(what, wait)
    deadline = Time.now + wait
    loop do
      return true if yield
      raise "#{what}: not satisfied after #{wait}s" if Time.now > deadline

      sleep 0.1
    end
  end
end
