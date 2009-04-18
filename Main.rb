#!/usr/bin/env ruby

begin
  require 'rubygems'
rescue LoadError
end
require 'gosu'
require 'utils'
require 'gl'
require 'glu'
require 'glut'

require 'utils'

include Gl
include Glu
include Glut

class Bullet < Struct.new(:r, :d)
  include GLSprite

  def sprite_name
    "images/bullet_ugly.png"
  end

  def halfsize
    3
  end

  def update
    self.d += 15
    $window.objects_of_class(Planet).each do |planet|
      if planet.collide?(self, 0, 5)
        planet.damage!(100_000)
        return false
      end
    end
    if $window.wall.collide?(r, d)
      $window.wall.grow!(r, 3, 7)
      return false
    end
    return false if self.d > 800
  end
end

class Beam < Struct.new(:r, :d)
  def initialize(r, d)
    super
    @duration = 0
  end

  def draw_gl
    glDraw(GL_QUADS) do
      glColor4d(1, 1, 1, 1)
      drawVertexOnPlane(r-1.5, d)
      drawVertexOnPlane(r+1.5, d)
      drawVertexOnPlane(r-1.5, 800)
      drawVertexOnPlane(r+1.5, 800)
    end
  end

  def draw
  end

  def update
    @duration += 1
    $player.beam_charge -= 0.01
    return false if $player.beam_charge <= 0.0
    self.r = $player.r
    self.d = $player.d
    $window.objects_of_class(Planet).each do |planet|
      if planet.collide_r?(self, 2) && planet.d >= d
        planet.damage!(50_000)
      end
    end
    $window.wall.grow!(r, (5 + (@duration / 5) * 0.7).floor, -2)
  end
end

class Planet < Struct.new(:r, :d, :people)
  include GLSprite
  RADIUS = 10

  def initialize(r, d, people = 3_000_000 + rand(2_000_000))
    super
    @red = 0
    self.people = people
  end

  def draw_gl
    saveMatrix do
      glRotated(r, 0, 0, 1)
      glTranslated(0, -100, d)
      glColor4d((@people_color + @red).clamp(0, 1), 1 - @red, (@people_color - @red).clamp(0, 1), 1)
      glutSolidSphere(RADIUS, 20, 20)
    end
  end

  def people=(val)
    super
    @people_color = 1.0 - (people / 5_000_000.0)
  end

  def collide?(obj, extra_r = 0, extra_d = 0)
    collide_r?(obj, extra_r) &&
      obj.d > (d - RADIUS - extra_d) &&
      obj.d < (d + RADIUS + extra_d)
  end

  def collide_r?(obj, extra_r = 0)
    obj.r > (r - RADIUS - extra_r) &&
      obj.r < (r + RADIUS + extra_r)
  end

  def damage!(val)
    self.people = [people - val, 0].max
    @red = 1
    return false if people == 0
  end

  def update
    @red = [@red - 0.01, 0].max
    self.d += (people == 0 ? 20 : 1) * $window.wall.pulling_speed
    if $window.wall.collide?(r, d)
      self.damage!(1_000_000)
    end
  end
end

class Pod < Struct.new(:d, :r, :people)
  include GLSprite

  def sprite_name
    "images/bullet_ugly.png"
  end

  def halfsize
    8
  end

  def update
    send @state
  end

  def seeking
    self.d += 3
    return false if d > 800
    $window.objects_of_class(Planet).each do |planet|
      if planet.collide?(self, 2, 5)
        @planet = planet
        @state = :evac
        break
      end
    end
  end

  def evac
    self.d = @planet.d
    self.r = @planet.r
    peeps = [@planet.people, 5_000].min
    self.people += peeps
    @planet.people -= peeps
    if @planet.people <= 0
      @state = :flee
    end
  end

  def flee
    self.d -= 3
    if d < 0
      $window.save_people people
      return false
    end
  end

  def initialize(r)
    super(0.0, r, 0)
    @state = :seeking
  end

end

class Player < Struct.new(:r, :d, :beam_charge)
  include GLSprite

  def initialize
    super(7.5, 300.0, 1.0)
    @fire = Ticker.new(30)
    @pod = Ticker.new(80)
  end

  def sprite_name
    "images/player_ugly.png"
  end

  def right
    self.r -= 1
    self.r += 360.0 while r < 0
  end

  def left
    self.r += 1
    self.r -= 360.0 while r > 360.0
  end

  def back
    self.d = [d - 2, 0].max
  end

  def forward
    self.d += 2
  end

  def update
    if $window.wall.collide?(r, d)
      #DEATH
      $window.close
    end
    $window.objects_of_class(Planet).each do |planet|
      if planet.collide?(self, 7, 25)
        peeps = [planet.people, 5_000].min
        planet.people -= peeps
        $window.save_people(peeps)
      end
    end
    # self.beam_charge += ($window.people_saved / 1_000_000.0) * 0.001
    self.beam_charge = 1.0 if beam_charge > 1.0
  end

  alias_method :draw_gl_1, :draw_gl
  def draw_gl
    $window.objects_of_class(Planet).each do |planet|
      if planet.people > 0 && planet.collide?(self, 7, 25)
        glDraw(GL_LINES) do
          glColor4d(1, 1, 1, 1)
          drawVertexOnPlane(r, d)
          drawVertexOnPlane(planet.r, planet.d)
        end
      end
    end
    draw_gl_1
  end

  def fire
    @fire.fire do
      $window.objects << Bullet.new(r, d)
    end
  end

  def escape_pod
    @pod.fire { $window.objects << Pod.new(r) }
  end

  def beam
    # haha z-indexing
    if beam_charge > 0.25
      $window.objects.unshift Beam.new(r, d)
    end
  end

  def halfsize
    10
  end
end

class Wall
  NUM = 180
  STEP = 360.0 / NUM

  attr_reader :pulling_speed

  def initialize(dst)
    slope = 0
    pos = dst
    @segs = (0...NUM).map do |i|
      if rand(10) == 0
        slope += (rand(25) - 12)
        slope = slope.clamp(-50, 50)
      end
      pos += slope
      pos = pos.clamp(dst - 100, dst + 100)
      pos
    end
    @pulling_speed = 0.1
  end

  def [](r)
    @segs[(r.floor / STEP) % NUM]
  end

  def []=(r, v)
    @segs[(r.floor / STEP) % NUM] = v
  end

  def update
    @segs.length.times { |i| @segs[i] -= 0.05 }
  end

  def collide?(r, d)
    self[r] <= d
  end

  def grow!(r, d, h)
    r = r.floor
    (r-d .. r+d).each { |i| self[i] -= h }
  end

  def draw_gl
    # fixme
    glDraw(GL_QUAD_STRIP) do
      col = 0.75 - 0.75 * (@segs[0] / 800.0)
      glColor4d(1, 0, 0, col);
      drawVertexOnPlane(0, @segs[0])
      glColor4d(1, 0, 0, 0);
      drawVertexOnPlane(0, 800)
      @segs.each_with_index do |w,i|
        col = 0.75 - 0.75 * (w / 800.0)
        glColor4d(1, 0, 0, col);
        drawVertexOnPlane(i*STEP, w)
        glColor4d(1, 0, 0, 0);
        drawVertexOnPlane(i*STEP, 800)
      end
      col = 0.75 - 0.75 * (@segs[0] / 800.0)
      glColor4d(1, 0, 0, col);
      drawVertexOnPlane(0, @segs[0])
      glColor4d(1, 0, 0, 0);
      drawVertexOnPlane(0, 800)
    end
  end
end

class SolarLiftWindow < Gosu::Window
  include Gosu

  attr_reader :objects, :wall, :actions, :tickers, :people_saved

  def initialize
    super(800, 600, false)
    $window = self
    @tickers = []
    $player = @player = Player.new
    @wall = Wall.new(600)
    @objects = []
    last = 0
    3.times do
      r = last + 15 + 45 * rand
      last = r
      @objects << Planet.new(r, 150 + rand * 350)
    end
    @objects << @player
    @fps = FPSCounter.new
    @font1 = Gosu::Font.new(self, Gosu.default_font_name, 10)
    @people_saved = 0
  end

  def objects_of_class(klass)
    @objects.find_all { |o| o.is_a?(klass) }
  end

  def button_up(butt)
    case butt
    when KbEscape
      close
    when KbSpace
      @player.beam
    when KbP
      @pause = !@pause
    end
  end

  def update
    @fps.register_tick
    return if @pause

    if button_down?(KbA)
      @player.left
    end
    if button_down?(KbD)
      @player.right
    end
    if button_down?(MsLeft)
      @player.fire
    end
    if button_down?(KbS)
      @player.back
      # @player.escape_pod
    end
    @player.forward if button_down?(KbW)
    @tickers.each { |t| t.update }
    @objects.reject! { |o| o.update == false }
    @wall.update

    if rand(800) == 0 && objects_of_class(Planet).length < 6
      @objects << Planet.new(360.0 * rand, 20)
    end
  end

  def draw
    gl do
      glGetError
      glEnable(GL_BLEND)
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
      glDisable(GL_DEPTH_TEST)
      glClear(GL_COLOR_BUFFER_BIT)

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

      glDraw(GL_LINES) do
        10.times do |i|
          r = (360.0 / 10) * i
          glColor4d(1, 1, 1, 0.2)
          drawVertexOnPlane(r, 0)
          glColor4d(1, 1, 1, 0.05)
          drawVertexOnPlane(r, 800)
        end
        360.times do |i|
          glColor4d(1, 1, 1, 0.2)
          drawVertexOnPlane(i, 0)
          drawVertexOnPlane(i+1, 0)
          glColor4d(1, 1, 1, 0.05)
          drawVertexOnPlane(i, 800)
          drawVertexOnPlane(i+1, 800)
        end
      end

      @wall.draw_gl

      # glEnable(GL_DEPTH_TEST)
      # glClear(GL_DEPTH_BUFFER_BIT)

      @objects.sort_by { |o| -o.d }.each { |o| o.draw_gl }
    end

    @objects.each { |o| o.draw }

    @font1.draw("FPS: #{@fps.fps}", 5, 5, 0)
    @font1.draw("Peeps: #{people_saved}", 5, 15, 0)

    # beam charge
    color = 0xffffffff
    draw_line(100, 5, color, width - 100, 5, color)
    draw_line(100, 15, color, width - 100, 15, color)
    draw_line(100, 5, color, 100, 15, color)
    draw_line(width - 100, 5, color, width - 100, 15, color)
    center = 100 + ((width - 200) / 2)
    hlen = $player.beam_charge * (width - 200) / 2
    draw_quad(center - hlen, 7, color,
              center + hlen, 7, color,
              center - hlen, 14, color,
              center + hlen, 14, color)
    # @font1.draw("Beam Charge: %d%%" % [@player.beam_charge * 100], 5, 25, 0)
  end

  def save_people(val)
    @people_saved += val
    @player.beam_charge += val / 6_000_000.0
  end
end

SolarLiftWindow.new().show
