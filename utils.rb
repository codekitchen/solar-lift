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
  # dp = 100 - dst * VPLANE_RATIO
  dp = 100
  [Gosu.offset_x(r, dp), Gosu.offset_y(r, dp), dst]
end
def drawVertexOnPlane(r, dst)
  dp = 100 - dst * VPLANE_RATIO
  dp = 100
  glVertex3d(Gosu.offset_x(r, dp), Gosu.offset_y(r, dp), dst)
end
def plane_distance(o1, o2)
  # TODO: this isn't even nearly correct
  # length of arc with radius r and angle t in radians = t*r
  xdist = (o1.r.gosu_to_radians - o2.r.gosu_to_radians).abs * 100
  xdist + Math.sqrt((o1.d - o2.d) * (o1.d - o2.d))
  # Gosu.distance(o1.r * 3, o1.d, o2.r * 3, o2.d)
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

module GLSprite
  def draw_gl
    info = sprite.gl_tex_info
    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, info.tex_name)
    saveMatrix do
      pt = pointOnPlane(r, d)
      glTranslated(pt[0], pt[1], pt[2])
      glRotated(r, 0, 0, 1)
      glDraw(GL_QUADS) do
        glColor4d(1, 1, 1, 1)
        glTexCoord2d(info.left, info.top)
        glVertex3d(-halfsize, halfsize, 0)
        glTexCoord2d(info.left, info.bottom)
        glVertex3d(-halfsize, -halfsize, 0)
        glTexCoord2d(info.right, info.bottom)
        glVertex3d(halfsize, -halfsize, 0)
        glTexCoord2d(info.right, info.top)
        glVertex3d(halfsize, halfsize, 0)
      end
    end
    glDisable(GL_TEXTURE_2D)
  end

  def draw
  end

  def sprite
    @sprite ||= Gosu::Image.new($window, sprite_name)
  end
end

class Ticker
  def initialize(steps)
    @cur = @steps = steps
    $window.tickers << self
  end

  def update
    @cur += 1
  end

  def fire
    if @cur >= @steps
      yield if block_given?
      @cur = 0
    end
  end
end

class Numeric
  def clamp(lo, hi)
    self < lo ? lo : self > hi ? hi : self
  end
end
