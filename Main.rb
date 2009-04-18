#!/usr/bin/env ruby

begin
  require 'rubygems'
rescue LoadError
end
require 'gosu'
require 'gl'
require 'glu'

include Gl
include Glu

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

def saveMatrix
  glPushMatrix
  yield
  glPopMatrix
end

def glDraw(t)
  glBegin(t)
  yield
  glEnd
end

class Actor
end

VPLANE_RATIO = 75.0 / 800
def drawVertexOnPlane(r, dst)
  dp = 100 - dst * VPLANE_RATIO
  glVertex3d(Gosu.offset_x(r, dp), Gosu.offset_y(r, dp), dst)
end

class SolarLiftWindow < Gosu::Window
  include Gosu

  attr_reader :objects

  def initialize
    super(800, 600, false)
    @objects = []
    @r = 0
    @w = 500
  end

  def button_up(butt)
    case butt
    when KbEscape
      close
    end
  end

  def update
    @objects.reject! { |o| o.update == false }
    if button_down?(KbA)
      @r -= 0.4
      @r += 360.0 if @r < -360.0
    end
    if button_down?(KbD)
      @r += 0.4
      @r -= 360.0 if @r > 360.0
    end
    # @w -= 3
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

      col = 0.75 - 0.75 * (@w / 800.0)
      glDraw(GL_QUAD_STRIP) do
        glColor4d(1, 0, 0, col);
        drawVertexOnPlane(0, @w)
        glColor4d(1, 0, 0, 0);
        drawVertexOnPlane(0, 800)
        361.times do |i|
          glColor4d(1, 0, 0, col);
          drawVertexOnPlane(i, @w)
          glColor4d(1, 0, 0, 0);
          drawVertexOnPlane(i, 800)
        end
      end

      # glTranslated(-@pos.x, -@pos.y, -0.05 + @pos.z)
      @objects.each { |o| o.draw }
    end
  end
end

$window = SolarLiftWindow.new()
$window.show
