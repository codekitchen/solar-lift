require 'gl'
require 'glu'

include Gl
include Glu

require 'weakref'

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
DP = 100
def pointOnPlane(r, dst)
  # dp = 100 - dst * VPLANE_RATIO
  [Gosu.offset_x(r, DP), Gosu.offset_y(r, DP), dst]
end
def drawVertexOnPlane(r, dst)
  # dp = 100 - dst * VPLANE_RATIO
  glVertex3d(Gosu.offset_x(r, DP), Gosu.offset_y(r, DP), dst)
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

  def radius
    halfsize
  end

  def collide?(obj, extra_r = 0, extra_d = 0)
    collide_r?(obj, extra_r) &&
      obj.d > (d - radius - extra_d) &&
      obj.d < (d + radius + extra_d)
  end

  def collide_r?(obj, extra_r = 0)
    obj.r > (r - radius - extra_r) &&
      obj.r < (r + radius + extra_r)
  end
end

class Ticker
  def initialize(steps, rand_step = nil)
    @cur = @steps = steps
    @rand_step = rand_step
    $level.tickers << WeakRef.new(self)
  end

  def update
    @cur += 1
  end

  def fire
    if @cur >= @steps
      yield if block_given?
      @cur = @rand_step ? -rand(@rand_step) : 0
    end
  end
end

class Numeric
  def clamp(lo, hi)
    self < lo ? lo : self > hi ? hi : self
  end
end

class Array
  def random
    self[rand(length)]
  end
  def shuffle
    sort_by { rand }
  end
end

class Hint < Struct.new(:image_path, :x, :y, :duration, :fade_duration, :txt_height)

  def initialize(*args)
    super
    if image_path =~ %r{^images/}
      @image = Gosu::Image.new($window, image_path)
    else
      @image = Gosu::Image.from_text($window, image_path, Gosu.default_font_name, txt_height)
    end
    @color = Gosu::Color.new(0xffffffff)
    @start_msec = Gosu.milliseconds
  end

  def draw
    @image.draw_rot(x, y, 0, 0, 0.5, 0.5, 1, 1, @color)
  end

  def update
    if @fade_start
      diff = Gosu.milliseconds - @fade_start
      return false if diff >= fade_duration
      @color.alpha = (255 * (1 - diff / fade_duration.to_f)).to_i
    elsif Gosu.milliseconds - @start_msec >= duration
      @fade_start = Gosu.milliseconds
    end
  end

end

HINTS = {
  :wsad => ["images/wsad.png", 400, 300, 2500, 1500],
  :spacebar => ["images/spacebar.png", 400, 55, 2500, 1000],
  :bullets => ["It's absorbing our bullets!", 400, 360, 2000, 1500, 20],
  :basics => ["Approach the planets to evacuate our citizens. LMB to fire.", 400, 400, 2000, 1500, 20],
}

SHOWN_HINTS = {}
