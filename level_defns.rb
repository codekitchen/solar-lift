class Level
  include Gosu

  attr_reader :objects, :tickers, :people_saved, :wall

  def initialize()
    super
    $level = self
    @objects = []
    @tickers = []
    $player = @player = Player.new
    @wall = Wall.new(600)

    last = 0
    3.times do
      r = last + 15 + 45 * rand
      last = r
      @objects << Planet.new(r, 150 + rand * 350)
    end

    @objects << @player
    @font1 = Gosu::Font.new($window, Gosu.default_font_name, 10)
    @people_saved = 0
    @ui_objects = []

    show_hint_if_not_seen(:wsad)
    show_hint_if_not_seen(:basics)
  end

  def objects_of_class(klass)
    @objects.find_all { |o| o.is_a?(klass) }
  end

  def button_up(butt)
    case butt
    when KbEscape
      $window.close
    when KbSpace
      @player.beam
    when KbP
      @pause = !@pause
    end
  end

  def update
    return if @pause
    if $window.button_down?(KbA)
      @player.left
    end
    if $window.button_down?(KbD)
      @player.right
    end
    if $window.button_down?(MsLeft)
      @player.fire
    end
    if $window.button_down?(KbS)
      @player.back
    end
    @player.forward if $window.button_down?(KbW)
    @tickers.reject! { |t| begin t.update; false; rescue WeakRef::RefError; true; end }
    @objects.reject! { |o| o.update == false }
    @ui_objects.reject! { |o| o.update == false }
    @wall.update

    if rand(700) == 0 && objects_of_class(Planet).length < 6
      @objects << Planet.new(360.0 * rand, 20)
    end
  end

  def width; $window.width; end
  def height; $window.height; end

  BGCOLOR = Gosu::Color.new(19, 20, 8)

  def draw
    # $window.draw_quad(0, 0, BGCOLOR,
    #                   width, 0, BGCOLOR,
    #                   0, height, BGCOLOR,
    #                   width, height, BGCOLOR)
    $window.gl do
      glGetError
      glEnable(GL_BLEND)
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
      glDisable(GL_DEPTH_TEST)
      # glClear(GL_COLOR_BUFFER_BIT)

      glMatrixMode(GL_PROJECTION)
      glLoadIdentity
      gluPerspective(45, width.to_f / height, 0.1, 2000)

      glMatrixMode(GL_MODELVIEW)
      glLoadIdentity
      gluLookAt(0, -65, -117 + @player.d,
                0, 0, 800 + @player.d,
                0, 1, 0)

      glRotated(-@player.r, 0, 0, 1)

      dp = 100

      glDraw(GL_QUAD_STRIP) do
        glColor4d(0.074, 0.078, 0.0313, 1)
        drawVertexOnPlane(0, 0)
        drawVertexOnPlane(0, 800)
        0.step(358, 2) do |i|
          # r = (360.0 / 10) * i
          drawVertexOnPlane(i, 0)
          drawVertexOnPlane(i, 800)
        end
        drawVertexOnPlane(0, 0)
        drawVertexOnPlane(0, 800)
      end

      @wall.draw_gl

      glDraw(GL_LINES) do
        10.times do |i|
          r = (360.0 / 10) * i
          glColor4d(1, 1, 1, 0.2)
          drawVertexOnPlane(r, 0)
          glColor4d(1, 1, 1, 0.05)
          drawVertexOnPlane(r, 800)
        end
      end

      glDraw(GL_LINES) do
        0.step(358, 2) do |i|
          glColor4d(1, 1, 1, 0.2)
          drawVertexOnPlane(i, 0)
          drawVertexOnPlane(i+2, 0)
          # glColor4d(0.56, 0.11, 0.04, 0.2)
          # drawVertexOnPlane(i, 800)
          # drawVertexOnPlane(i+2, 800)
        end
      end
      # glEnable(GL_DEPTH_TEST)
      # glClear(GL_DEPTH_BUFFER_BIT)

      @objects.sort_by { |o| -o.d }.each { |o| o.draw_gl }
    end

    @objects.each { |o| o.draw }

    @font1.draw("FPS: #{$window.fps.fps}", 5, 5, 0)
    @font1.draw("Peeps: #{people_saved}", 5, 15, 0)

    # beam charge
    color = 0xffffffff
    $window.draw_line(100, 5, color, width - 100, 5, color)
    $window.draw_line(100, 15, color, width - 100, 15, color)
    $window.draw_line(100, 5, color, 100, 15, color)
    $window.draw_line(width - 100, 5, color, width - 100, 15, color)
    center = 100 + ((width - 200) / 2)
    hlen = $player.beam_charge * (width - 200) / 2
    $window.draw_quad(center - hlen, 7, color,
              center + hlen, 7, color,
              center - hlen, 14, color,
              center + hlen, 14, color)
    # @font1.draw("Beam Charge: %d%%" % [@player.beam_charge * 100], 5, 25, 0)

    @ui_objects.each { |o| o.draw }
  end

  def save_people(val)
    @people_saved += val
    @player.beam_charge += val / 4_000_000.0
    if @player.beam_charge > 0.5
      show_hint_if_not_seen(:spacebar)
    end
  end

  def show_hint_if_not_seen(hint)
    return if SHOWN_HINTS[hint]
    @ui_objects << Hint.new(*HINTS[hint])
    SHOWN_HINTS[hint] = true
  end
end
