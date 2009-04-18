#!/usr/bin/env ruby

begin
  require 'rubygems'
rescue LoadError
end
require 'gosu'

class SolarLiftWindow < Gosu::Window
  include Gosu

  def initialize
    super(800, 600, false)
  end

  def button_up(butt)
    case butt
    when KbEscape
      close
    end
  end

  def update
  end

  def draw
  end
end

SolarLiftWindow.new().show
