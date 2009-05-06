require "#{ENV["TM_SUPPORT_PATH"]}/lib/scriptmate"

class PhptScript < UserScript
  def lang; "Phpt" end
  # Disable display_errors so that errors are printed to stderr only
  # Enabling log_errors (without an error_log) sends errors to stdout
  def default_extension; ".phpt" end
  def args
    ['"$TM_BUNDLE_SUPPORT"/run-tests.php', '--show-exp', '--show-out']
  end
  def executable; ENV['TEST_PHP_EXECUTABLE'] || ENV['TM_PHP'] || @hashbang || 'php' end

  # Possibly override display_name to provide nicer-formatted test name
  # version_string ?
end

class PhptRunner < ScriptMate
  def emit_header
    super
    puts <<-HTML
    <style type="text/css" media="screen">
      table { width: 100%; }
      th { text-align: left; }
      h1 { color: red; }
      .output, .expected
      {
        float: left;
        width: 45%;
      }
      .expected
      {
        float: right;
      }
      .output_container pre
      {
        margin: 0;
        padding: 0;
      }
    </style>
    HTML
  end

  def current_section=(section)
    if @current_section
      # Leaving @current_section
      case @current_section
      when ''
        puts "</table>"
      when 'OUT'
        puts '</pre></div>'
      when 'EXP'
        puts '</pre></div>'
        puts '</div>'
        puts '<br style="clear: both" />'
      end
      @current_section = nil
    else
      # Entering section
      @current_section = section
      if section == '' and not @started_tests
        puts '<table border="1" cellspacing="0" cellpadding="2" id="environment_info">'
      elsif section == '' and @started_tests
        puts '<h1>Results</h1>'
        puts '<table border="1" cellspacing="0" cellpadding="2" id="result_stats">'
      elsif section == 'OUT'
        puts '<div class="output_container">'
        puts '<div class="output"><h2>Output</h2><pre>'
      elsif section == 'EXP'
        puts '<div class="expected"><h2>Expected Output</h2><pre>'
      end
    end
  end

  def process_output(str)
    if @current_section and not @started_tests
      # Env. info
      cols  = str.split(':', 2)
      title = cols[0].gsub('&nbsp;', '').strip
      value = cols[1].strip
      str   = <<-HTML
      <tr>
        <th>#{htmlize title}</th>
        <td>#{htmlize value}</td>
      </tr>
      HTML
    elsif @current_section and @current_section.empty? and @started_tests
      # Final stats
      if str =~ /^-+$\n?/
        str = <<-HTML
        <tr>
          <td colspan="3">&nbsp;</td>
        </tr>
        HTML
      elsif str =~ /^(.+?)\s*:\s*(\d+ (?:\(.+?\))?) (.+?)$/
        str = <<-HTML
        <tr>
          <th>#{htmlize $1}</th>
          <td align="right">#{htmlize $2}</td>
          <td align="right">#{htmlize $3}</td>
        </tr>
        HTML
      elsif str =~ /^(.+?)\s*:\s*(.+?)$/
        str = <<-HTML
        <tr>
          <th>#{htmlize $1}</th>
          <td colspan="2" align="right">#{htmlize $2}</td>
        </tr>
        HTML
      end
    elsif str == "Running selected tests.\n"
      str = ''
    elsif not %w[OUT EXP].include?(@current_section)
      str = htmlize(str)
    end
    str
  end

  def filter_stdout(str)
    if str =~ /^={8,}(\w+)?={8,}$\n?/
      self.current_section = $1.to_s
      str                  = ''
    elsif str.strip =~ %r{^TEST (\d+)/(\d+) \[(.+)\]$\n?}
      @in_test       = true
      @started_tests = true
      str            = "<h1 class='test_title'>Running test <span>#{$3}</span></h1>"
    elsif str.strip =~ %r{^(PASS|FAIL) .+ \[(.+)\]$\n?}
      @in_test = false
      str      = ''
    else
      str = process_output(str) unless str.strip.empty?
    end
    str
  end
end

script = PhptScript.new(STDIN.read)
PhptRunner.new(script).emit_html
