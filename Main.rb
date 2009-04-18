#!/usr/bin/env ruby

begin
  require 'rubygems'
rescue LoadError
end
require 'gosu'
require 'utils'
require 'gl'
require 'glu'

require 'utils'

include Gl
include Glu

class Bullet < Struct.new(:r, :d)
  def initialize(r, d)
    super
    @@sprite = Gosu::Image.new($window, "images/bullet_ugly.png") unless defined?(@@sprite)
  end

  def update
    self.d += 8
    if $window.wall.collide?(r, d)
      $window.wall.grow!(r, d, 7)
      return false
    end
    return false if self.d > 800
  end

  def draw_gl
    info = @@sprite.gl_tex_info
    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, info.tex_name)
    glDraw(GL_QUADS) do
      glColor4d(1, 1, 1, 1)
      pt = pointOnPlane(r, d)
      glTexCoord2d(info.left, info.top)
      glVertex3d(pt[0]-3, pt[1]+3, pt[2])
      glTexCoord2d(info.left, info.bottom)
      glVertex3d(pt[0]-3, pt[1]-3, pt[2])
      glTexCoord2d(info.right, info.bottom)
      glVertex3d(pt[0]+3, pt[1]-3, pt[2])
      glTexCoord2d(info.right, info.top)
      glVertex3d(pt[0]+3, pt[1]+3, pt[2])
    end
    glDisable(GL_TEXTURE_2D)
  end

  def draw
  end
end

class Player
  def initialize
    @sprite = Gosu::Image.new($window, "images/player_ugly.png")
    @fire = Ticker.new(30)
  end

  def update
    @fire.tick
  end

  def fire
    @fire.fire do
      $window.objects << Bullet.new(-$window.r, 0)
    end
  end

  def draw
    @sprite.draw_rot(400, 575, 0, 0)
  end

  def draw_gl
  end
end

class Ticker
  def initialize(steps)
    @steps = steps
    @cur = 1
  end

  def tick
    @cur += 1
  end

  def fire
    if @cur >= @steps
      yield if block_given?
      @cur = 0
    end
  end
end

class Wall
  NUM = 180
  STEP = 360.0 / NUM
  def initialize(dst)
    @segs = [dst] * NUM
  end

  def [](r)
    @segs[(r.floor / STEP) % NUM]
  end

  def []=(r, v)
    @segs[(r.floor / STEP) % NUM] = v
  end

  def update
    @segs.length.times { |i| @segs[i] -= 0.25 }
  end

  def collide?(r, d)
    self[r] <= d
  end

  def grow!(r, d, h)
    r = r.floor
    (r-3 .. r+3).each { |i| self[i] -= h }
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

  attr_reader :objects, :r, :wall, :actions

  def initialize
    super(800, 600, false)
    $window = self
    @player = Player.new
    @wall = Wall.new(500)
    @objects = [@player]
    @r = 7.5
    @fps = FPSCounter.new
    @font1 = Gosu::Font.new(self, Gosu.default_font_name, 10)
  end

  def button_up(butt)
    case butt
    when KbEscape
      close
    when KbSpace
      @pause = !@pause
    end
  end

  def update
    @fps.register_tick
    return if @pause
    @objects.reject! { |o| o.update == false }
    if button_down?(KbA)
      @r -= 0.4
      @r += 360.0 if @r < -360.0
    end
    if button_down?(KbD)
      @r += 0.4
      @r -= 360.0 if @r > 360.0
    end
    if button_down?(MsLeft)
      @player.fire
    end
    # @w -= 3
    @wall.update
  end

  def draw
    gl do
      glGetError
      glEnable(GL_BLEND)
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
      glDisable(GL_DEPTH_TEST)
      glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT)

      glMatrixMode(GL_PROJECTION)
      glLoadIdentity
      gluPerspective(45, width.to_f / height, 0.1, 2000)

      glMatrixMode(GL_MODELVIEW)
      glLoadIdentity
      gluLookAt(0, -65, -125,
                0, 0, 800,
                0, 1, 0)
      # gluLookAt(0, 0, -275,
      #           0, 0, 1,
      #           0, 1, 0)

      glRotated(@r, 0, 0, 1)

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

      # glTranslated(-@pos.x, -@pos.y, -0.05 + @pos.z)
      @objects.each { |o| o.draw_gl }
    end

    @objects.each { |o| o.draw }

    @font1.draw("FPS: #{@fps.fps}", 5, 5, 0)
  end
end

SolarLiftWindow.new().show
