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

require 'level_defns'
require 'utils'

include Gl
include Glu
include Glut

class EnemyShip < Struct.new(:r, :d)
  include GLSprite

  SPD = 0.75

  attr_accessor :killed

  def initialize(r, d)
    super
    @fire = Ticker.new(50, 100)
    @dir = -1
    @state = [:track, :planet, :wander].random
    @state = :wander
  end

  def sprite_name
    "images/player_ugly.png"
  end

  def halfsize
    7
  end

  def update
    if !$level.objects_of_class(EnemyShip).include?(self)
      puts "WTF I'm not in here"
    end
    return false if @killed
    send(@state)
    self.r %= 360.0
  end

  def track
    harass($player)
  end

  def planet
    @planet ||= $level.objects_of_class(Planet).random
    harass(@planet) if @planet
  end

  def wander
    self.d += 4 * @dir
    self.d -= 4 * @dir if d > 1000 || d < 0
    @dir = -@dir if rand(30) == 0
    self.r += rand(SPD*2) - SPD if rand(3) == 0
    fire
  end

  def fire
    @fire.fire do
      $level.objects << Bullet.new(self, r, d, -15)
      $window.play_sound :enemy
    end
  end

  def harass(target)
    diff = Gosu.angle_diff(self.r, target.r)
    if diff != 0
      if diff < 0
        self.r += diff > -SPD ? diff : -SPD
      else
        self.r += diff < SPD ? diff : SPD
      end
    end
    if diff.abs < 6
      self.d += 4 * @dir
      self.d -= 4 * @dir if d > 800 || d < 0
    end
    @dir = -@dir if rand(300) == 0 || (target.d > d + 100 && @dir < 0) || (target.d < d - 100 && @dir > 0)
    if diff.abs < 10
      fire
    end
    d <= 800 && d >= 0
  end
end

class Bullet < Struct.new(:owner, :r, :d, :speed)
  include GLSprite

  def initialize(owner, r, d, speed = 15)
    super
  end

  def sprite_name
    "images/bullet_ugly.png"
  end

  def halfsize
    3
  end

  def update
    $level.objects.each do |obj|
      next if obj == owner
      case obj
      when Planet
        if obj.collide?(self, 0, speed.abs)
          obj.damage!(500_000)
          return false
        end
      when EnemyShip
        if obj.collide?(self, 1, speed.abs)
          obj.killed = true
          return false
        end
      end
    end
    if $level.wall.collide?(r, d)
      $level.wall.grow!(r, 3, 7)
      $level.show_hint_if_not_seen(:bullets) if owner == $player
      return false
    end
    self.d += speed
    return false if self.d < 0 || self.d > 800
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
    self.d = $player.d + 15
    $level.objects.each do |obj|
      case obj
      when Planet
        if obj.collide_r?(self, 2) && obj.d >= d
          obj.damage!(50_000)
        end
      when EnemyShip
        if obj.collide_r?(self, 2) && obj.d >= d
          obj.killed = true
        end
      end
    end
    $level.wall.grow!(r, (5 + (@duration / 5) * 0.7).floor, -2)
  end
end

class Planet < Struct.new(:r, :d, :people)
  include GLSprite
  RADIUS = 10

  COLORS = [
    Gosu::Color.new(74, 93, 67),
    Gosu::Color.new(141, 144, 85),
    Gosu::Color.new(209, 195, 104),
  ]

  RED = Gosu::Color.new(225, 0, 0)
  WHITE = Gosu::Color.new(250, 250, 250)

  def initialize(r, d, people = 3_000_000 + rand(2_000_000))
    super
    @red = 0
    @color = COLORS.random
    self.people = people
  end

  def draw_gl
    saveMatrix do
      glRotated(r, 0, 0, 1)
      glTranslated(0, -100, d)
      color = blend_color(@people_color, RED, @red)
      glColor4d(color.red / 255.0, color.green / 255.0, color.blue / 255.0, 1)
      # glColor4d((@people_color + @red).clamp(0, 1), 1 - @red, (@people_color - @red).clamp(0, 1), 1)
      glutSolidSphere(RADIUS, 20, 20)
    end
  end

  def people=(val)
    super
    @people_color = blend_color(WHITE, @color, people / 5_000_000.0)
    # @people_color = 1.0 - (people / 5_000_000.0)
  end

  def radius
    RADIUS
  end

  def damage!(val)
    self.people = [people - val, 0].max
    @red = 1
    return false if people == 0
  end

  def update
    @red = [@red - 0.01, 0].max
    self.d += people == 0 ? 10 : $level.wall.pulling_speed
    if $level.wall.collide?(r, d)
      self.damage!(1_000_000)
    end
  end
end

class Player < Struct.new(:r, :d, :beam_charge)
  include GLSprite

  def initialize
    super(7.5, 300.0, 0.0)
    @fire = Ticker.new(10)
    @beaming = nil
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
    if $level.wall.collide?(r, d)
      #DEATH!
      # $window.close
    end
    collision = false
    $level.objects_of_class(Planet).each do |planet|
      if planet.collide?(self, 7, 25) && planet.people > 0
        collision = true
        peeps = [planet.people, 15_000].min
        planet.people -= peeps
        $level.save_people(peeps)
        @beaming ||= $window.sounds[:beamup].play(0.25, 1, true)
      end
    end
    (@beaming.stop; @beaming = nil) if @beaming && !collision
    # self.beam_charge += ($level.people_saved / 1_000_000.0) * 0.001
    self.beam_charge = 1.0 if beam_charge > 1.0
  end

  alias_method :draw_gl_1, :draw_gl
  def draw_gl
    $level.objects_of_class(Planet).each do |planet|
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
      $level.objects << Bullet.new(self, r, d)
      $window.play_sound(:bullet)
    end
  end

  def beam
    # lulz z-indexing
    if beam_charge > 0.25 && $level.objects_of_class(Beam).empty?
      $level.objects.unshift Beam.new(r, d)
    end
  end

  def halfsize
    10
  end
end

class Wall
  NUM = 180
  STEP = 360.0 / NUM

  attr_reader :pulling_speed, :fps

  def initialize(dst)
    slope = 0
    pos = dst
    # TODO: this code is jacked somehow, probably the constants
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
    if rand(200) == 0
      r = 360 * rand
      $level.objects << EnemyShip.new(r, self[r])
    end
  end

  def collide?(r, d)
    self[r] <= d
  end

  def grow!(r, d, h)
    r = r.floor
    (r-d .. r+d).each { |i| self[i] = (self[i] - h).clamp(0.0, 800.0) }
  end

  def draw_gl
    # fixme
    glDraw(GL_QUAD_STRIP) do
      # col = 0.75 - 0.75 * (@segs[0] / 800.0)
      mult = (800.0 - @segs[0]) / 800
      glColor4d(0.56 * mult, 0.11 * mult, 0.04 * mult, 1);
      drawVertexOnPlane(0, @segs[0])
      glColor4d(0, 0, 0, 1);
      drawVertexOnPlane(0, 800)
      @segs.each_with_index do |w,i|
        mult = (800.0 - w) / 800
        # col = 0.75 - 0.75 * (w / 800.0)
        glColor4d(0.56 * mult, 0.11 * mult, 0.04 * mult, 1);
        drawVertexOnPlane(i*STEP, w)
        glColor4d(0, 0, 0, 1);
        drawVertexOnPlane(i*STEP, 800)
      end
      # col = 0.75 - 0.75 * (@segs[0] / 800.0)
      mult = (800.0 - @segs[0]) / 800
      glColor4d(0.56 * mult, 0.11 * mult, 0.04 * mult, 1);
      drawVertexOnPlane(0, @segs[0])
      glColor4d(0, 0, 0, 1);
      drawVertexOnPlane(0, 800)
    end
  end
end

class SolarLiftWindow < Gosu::Window
  include Gosu

  attr_reader :fps, :sounds

  def initialize
    super(800, 600, false)
    $window = self
    @level = Level.new()
    @fps = FPSCounter.new
    @sounds = {
      :bullet => Gosu::Sample.new(self, "sounds/bullet.wav"),
      :enemy =>  Gosu::Sample.new(self, "sounds/enemy_bullet.wav"),
      :beamup => Gosu::Sample.new(self, "sounds/beamup.wav"),
    }
  end

  def button_up(butt)
    @level.button_up(butt)
  end

  def update
    @fps.register_tick
    @level.update
  end

  def draw
    @level.draw
  end

  def play_sound(snd)
    sample = @sounds[snd]
    return unless sample
    sample.play
  end
end

SolarLiftWindow.new().show
