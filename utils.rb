require 'gl'
require 'glu'

include Gl
include Glu

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

VPLANE_RATIO = 75.0 / 800
def pointOnPlane(r, dst)
  dp = 100 - dst * VPLANE_RATIO
  [Gosu.offset_x(r, dp), Gosu.offset_y(r, dp), dst]
end
def drawVertexOnPlane(r, dst)
  dp = 100 - dst * VPLANE_RATIO
  glVertex3d(Gosu.offset_x(r, dp), Gosu.offset_y(r, dp), dst)
end

class FPSCounter
  attr_reader :fps

  def initialize
    @current_second = Gosu::milliseconds / 1000
    @accum_fps = 0
    @fps = 0
  end

  def register_tick
    @accum_fps += 1
    current_second = Gosu::milliseconds / 1000
    if current_second != @current_second
      @current_second = current_second
      @fps = @accum_fps
      @accum_fps = 0
    end
  end
end
